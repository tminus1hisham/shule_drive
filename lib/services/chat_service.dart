import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../api/services/auth_service.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../mqtt_client.dart';
import 'notification_service.dart';
import 'secure_token_storage.dart';
import 'local_database_service.dart';

/// A chat message that arrived on this user's inbox topic.
class IncomingChat {
  final ChatMessage message;
  final String senderName;
  IncomingChat(this.message, this.senderName);
}

/// Chat over MQTT. Each user has one inbox topic, `chat/{phone}`, listened
/// to app-wide from login ([startInbox]) so messages land whatever screen is
/// open. Senders also push (FCM) so a closed app still hears about it; the
/// broker's persistent session hands the message itself over on reconnect.
/// Chats are short-lived: kept on the device for [retention], not the server.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final MqttService _mqttService = MqttService();
  final SecureTokenStorage _tokenStorage = SecureTokenStorage();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final AuthService _authService = AuthService();
  final _uuid = const Uuid();

  static const Duration retention = Duration(days: 2);

  /// Push title prefix; the FCM foreground handler uses it to leave chat
  /// pushes to the inbox (which knows whether that chat is open).
  static const String pushPrefix = '💬 ';
  static bool isChatPush(Object? title) =>
      title?.toString().startsWith(pushPrefix) ?? false;

  final StreamController<IncomingChat> _incoming =
      StreamController<IncomingChat>.broadcast();
  Stream<IncomingChat> get incoming => _incoming.stream;

  /// Phone (or group id) of the chat on screen; its messages don't notify.
  String? activeChatPhone;

  String? _inboxTopic;
  final List<String> _seenIds = [];

  // Raw typing events per own typing topic; each chat filters its sender.
  final Map<String, StreamController<Map<String, dynamic>>> _typing = {};

  // ==========================================================================
  // INBOX
  // ==========================================================================

  /// Listen on [myPhone]'s inbox. Idempotent.
  Future<void> startInbox(String myPhone) async {
    if (myPhone.isEmpty) return;
    final topic = 'chat/$myPhone';
    if (_inboxTopic == topic) return;
    await stopInbox();
    _inboxTopic = topic;
    unawaited(
      _localDb.clearOldChatMessages(daysToKeep: retention.inDays).catchError(
        (_) => 0,
      ),
    );
    try {
      // MqttService keeps the callback through failed connects/reconnects.
      await _mqttService.subscribe(topic, _onInbox);
      debugPrint('💬 Chat inbox listening on $topic');
    } catch (e) {
      debugPrint('⚠️ Chat inbox pending MQTT reconnect: $e');
    }
  }

  Future<void> stopInbox() async {
    final topic = _inboxTopic;
    _inboxTopic = null;
    activeChatPhone = null;
    if (topic == null) return;
    try {
      await _mqttService.unsubscribe(topic, _onInbox);
    } catch (_) {
      // Logout disconnects anyway.
    }
  }

  Future<void> _onInbox(String topic, String raw) async {
    final Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (e) {
      debugPrint('❌ Bad chat message: $e');
      return;
    }
    final senderId = data['senderId']?.toString() ?? '';
    final content = data['message']?.toString() ?? '';
    if (senderId.isEmpty || content.isEmpty) return;

    final id = data['id']?.toString() ?? _uuid.v4();
    if (!_markNew(id)) return; // QoS 1 may deliver twice

    final senderName = _firstName(data['senderName']) ?? senderId;
    // Trip group threading. The driver owns the group (has its members):
    // a reply carrying the group id belongs in that thread, not a 1:1.
    // A guardian just remembers it, so their replies carry it back.
    final groupId = data['groupId']?.toString();
    var recipientId = data['receiverId']?.toString() ?? '';
    if (groupId != null && isGroup(groupId)) {
      if (await groupMembers(groupId) != null) {
        recipientId = groupId;
      } else {
        await _rememberReplyGroup(senderId, groupId);
      }
    }
    final message = ChatMessage(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      content: content,
      timestamp:
          DateTime.tryParse(data['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      status: MessageStatus.delivered,
    );
    debugPrint('📨 Chat from $senderId: $content');

    await rememberName(senderId, senderName);
    await _saveMessageToDb(message);
    _incoming.add(IncomingChat(message, senderName));
    await _notify(message, senderName);
  }

  bool _markNew(String id) {
    if (_seenIds.contains(id)) return false;
    _seenIds.add(id);
    if (_seenIds.length > 200) _seenIds.removeAt(0);
    return true;
  }

  /// The conversation an incoming [message] belongs to: its group, else
  /// its sender.
  static String threadOf(ChatMessage message) =>
      isGroup(message.recipientId) ? message.recipientId : message.senderId;

  Future<void> _notify(ChatMessage message, String senderName) async {
    final thread = threadOf(message);
    if (thread == activeChatPhone) return;
    final notifications = NotificationService();
    if (notifications.currentBackend == NotificationBackend.firebase) {
      // The sender pushed too: the OS shows that while we're backgrounded,
      // and a backlog replayed on reconnect was pushed when it was sent.
      final resumed =
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      final stale =
          DateTime.now().difference(message.timestamp) >
          const Duration(minutes: 2);
      if (!resumed || stale) return;
    }
    await notifications.showLocalNotification(
      title: '$pushPrefix$senderName',
      body: message.content,
      channelId: 'chat_messages',
      payload: jsonEncode({
        'type': 'chat_message',
        'conversation_id': thread,
      }),
    );
  }

  // ==========================================================================
  // SEND
  // ==========================================================================

  /// Send [content] to [recipientPhone]'s inbox over MQTT, then push it.
  /// A group (`trip_…`) message goes to each member's own inbox instead
  /// ([deliverTo], or the members saved by [setGroupMembers]); it's stored
  /// once, under [recipientPhone].
  Future<ChatMessage> sendMessage({
    required String recipientPhone,
    required String content,
    String? senderName,
    String? recipientName,
    List<String>? deliverTo,
  }) async {
    final me = await _tokenStorage.getUserPhone();
    if (me == null) throw Exception('Not authenticated');
    final myName =
        _firstName(senderName ?? await _tokenStorage.getUserName()) ??
        'Unknown';

    final targets =
        deliverTo ??
        await groupMembers(recipientPhone) ??
        (isGroup(recipientPhone) ? const <String>[] : [recipientPhone]);
    if (targets.isEmpty) throw Exception('No one to send this to');

    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: me,
      recipientId: recipientPhone,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
    if (recipientName != null) await rememberName(recipientPhone, recipientName);
    final groupId = isGroup(recipientPhone)
        ? recipientPhone
        : await _replyGroupFor(recipientPhone);

    var published = 0;
    for (final phone in targets) {
      try {
        await _mqttService.publishJson('chat/$phone', {
          'chat': true,
          'id': message.id,
          'senderId': me,
          'senderName': myName,
          'receiverId': phone,
          'receiverName': _firstName(recipientName) ?? 'Unknown',
          'message': content,
          'createdAt': message.timestamp.toUtc().toIso8601String(),
          'groupId': ?groupId,
        });
        published++;
      } catch (e) {
        debugPrint('❌ Chat publish to $phone failed: $e');
        continue;
      }
      unawaited(
        _authService
            .sendGuardianPush(
              guardianPhone: phone,
              title: '$pushPrefix$myName',
              message: content,
            )
            .catchError((e) => debugPrint('⚠️ Chat push to $phone failed: $e')),
      );
    }
    if (published == 0) throw Exception('Chat server not connected');

    await _saveMessageToDb(message);
    debugPrint('📤 Chat sent to ${targets.length} inbox(es): $content');
    return message;
  }

  static bool isGroup(String id) => id.startsWith('trip_');

  // ==========================================================================
  // LOCAL HISTORY
  // ==========================================================================

  /// Messages with [otherPhone] (or group) still on this device, oldest first.
  Future<List<ChatMessage>> loadHistory(String otherPhone) async {
    final me = await _tokenStorage.getUserPhone();
    if (me == null) return [];
    if (isGroup(otherPhone)) {
      // Group rows are filed under the group, whoever sent them.
      final rows = await _localDb.getChatMessagesSince(
        DateTime.now().subtract(retention),
      );
      return rows
          .where((r) => r['recipient_id'] == otherPhone)
          .map(_fromRow)
          .toList();
    }
    final rows = await _localDb.getChatMessagesBetween(me, otherPhone);
    return rows.map(_fromRow).toList();
  }

  /// One conversation per counterparty with a message on this device,
  /// newest first.
  Future<List<ChatConversation>> recentConversations() async {
    final me = await _tokenStorage.getUserPhone();
    if (me == null) return [];
    final rows = await _localDb.getChatMessagesSince(
      DateTime.now().subtract(retention),
    );
    final latest = <String, ChatMessage>{};
    for (final m in rows.map(_fromRow)) {
      final other = m.senderId == me ? m.recipientId : threadOf(m);
      if (other.isNotEmpty) latest[other] = m; // rows are oldest first
    }
    final names = await _names();
    return latest.entries
        .map(
          (e) => ChatConversation(
            id: getChatTopic(me, e.key),
            otherUserPhone: e.key,
            otherUserName: names[e.key] ?? e.key,
            lastMessage: e.value,
            lastActivity: e.value.timestamp,
          ),
        )
        .toList()
      ..sort((a, b) => b.lastActivity!.compareTo(a.lastActivity!));
  }

  Future<void> _saveMessageToDb(ChatMessage message) async {
    try {
      await _localDb.saveChatMessage(
        id: message.id,
        senderId: message.senderId,
        recipientId: message.recipientId,
        content: message.content,
        timestamp: message.timestamp,
        status: message.status.name,
        chatTopic: getChatTopic(message.senderId, message.recipientId),
        synced: true,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to save chat message: $e');
    }
  }

  ChatMessage _fromRow(Map<String, dynamic> row) => ChatMessage(
    id: row['id'],
    senderId: row['sender_id'],
    recipientId: row['recipient_id'],
    content: row['content'],
    timestamp: DateTime.parse(row['timestamp']),
    status: MessageStatus.values.firstWhere(
      (s) => s.name == row['status'],
      orElse: () => MessageStatus.sent,
    ),
    replyToMessageId: row['reply_to_message_id'],
  );

  // ==========================================================================
  // NAMES & GROUPS (device-local)
  // ==========================================================================

  static const _namesKey = 'chat_contact_names';
  static const _groupsKey = 'chat_group_members';

  Future<Map<String, String>> _names() async =>
      Map<String, String>.from(await _readMap(_namesKey));

  Future<void> rememberName(String phone, String name) async {
    final names = await _readMap(_namesKey);
    if (name.isEmpty || names[phone] == name) return;
    names[phone] = name;
    await _writeMap(_namesKey, names);
  }

  /// Remember who a group (trip) chat delivers to, so it can be reopened
  /// from the chat list and still reach everyone.
  Future<void> setGroupMembers(String groupId, List<String> phones) async {
    final groups = await _readMap(_groupsKey);
    groups[groupId] = phones;
    await _writeMap(_groupsKey, groups);
  }

  Future<List<String>?> groupMembers(String groupId) async {
    if (!isGroup(groupId)) return null;
    final members = (await _readMap(_groupsKey))[groupId];
    return members is List ? members.map((e) => e.toString()).toList() : null;
  }

  static const _replyGroupsKey = 'chat_reply_groups';
  static const _replyGroupTtl = Duration(hours: 12);

  /// Guardian side: [senderPhone] last wrote from trip group [groupId].
  Future<void> _rememberReplyGroup(String senderPhone, String groupId) async {
    final groups = await _readMap(_replyGroupsKey);
    groups[senderPhone] = {
      'g': groupId,
      'at': DateTime.now().toIso8601String(),
    };
    await _writeMap(_replyGroupsKey, groups);
  }

  /// The trip group a reply to [phone] belongs to, while that trip is fresh.
  Future<String?> _replyGroupFor(String phone) async {
    final entry = (await _readMap(_replyGroupsKey))[phone];
    if (entry is! Map) return null;
    final at = DateTime.tryParse(entry['at']?.toString() ?? '');
    if (at == null || DateTime.now().difference(at) > _replyGroupTtl) {
      return null;
    }
    return entry['g']?.toString();
  }

  Future<Map<String, dynamic>> _readMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return Map<String, dynamic>.from(
        jsonDecode(prefs.getString(key) ?? '{}') as Map,
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeMap(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value));
  }

  static String? _firstName(Object? name) {
    final s = name?.toString().split('-').first.trim() ?? '';
    return s.isEmpty ? null : s;
  }

  // ==========================================================================
  // TYPING & RECEIPTS
  // ==========================================================================

  Future<void> sendTypingIndicator(String recipientPhone, bool isTyping) async {
    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null || isGroup(recipientPhone)) return;

    await _mqttService.publishJson('typing/$recipientPhone', {
      'userPhone': currentUserPhone,
      'isTyping': isTyping,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Listen to typing indicators from a user (using phone numbers)
  Stream<bool> onTypingIndicator(String otherUserPhone) {
    final currentUserPhone = _tokenStorage.getUserPhoneSync();
    if (currentUserPhone == null) return const Stream.empty();

    final typingTopic = 'typing/$currentUserPhone';
    final events = _typing.putIfAbsent(typingTopic, () {
      final controller = StreamController<Map<String, dynamic>>.broadcast();
      _mqttService.subscribe(typingTopic, (topic, message) {
        try {
          controller.add(Map<String, dynamic>.from(jsonDecode(message)));
        } catch (e) {
          debugPrint('Failed to parse typing indicator: $e');
        }
      });
      return controller;
    });

    return events.stream
        .where((d) => d['userPhone'] == otherUserPhone)
        .map((d) => d['isTyping'] == true);
  }

  /// Mark message as delivered (using phone numbers)
  Future<void> markAsDelivered(String messageId, String senderPhone) async {
    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null) return;

    await _mqttService.publishJson('status/$messageId', {
      'messageId': messageId,
      'status': 'delivered',
      'deliveredBy': currentUserPhone,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Mark message as read (using phone numbers)
  Future<void> markAsRead(String messageId, String senderPhone) async {
    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null) return;

    await _mqttService.publishJson('status/$messageId', {
      'messageId': messageId,
      'status': 'read',
      'readBy': currentUserPhone,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  String getChatTopic(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'chat/${ids[0]}_${ids[1]}';
  }
}
