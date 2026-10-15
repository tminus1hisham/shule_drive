import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../mqtt_client.dart';
import '../services/chat_service.dart';
import '../services/secure_token_storage.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider() {
    _incomingSub = _chatService.incoming.listen(_onIncoming);
  }

  final ChatService _chatService = ChatService();
  StreamSubscription<IncomingChat>? _incomingSub;
  final ApiClient _apiClient = ApiClient();
  final SecureTokenStorage _tokenStorage = SecureTokenStorage();

  // Messages for current chat - sorted by time ascending (oldest first)
  List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;
  String? _currentChatUserId;

  // Conversations list
  List<ChatConversation> _conversations = [];
  bool _isLoadingConversations = false;
  String? _conversationsError;

  // Available users for new chats
  List<ChatUser> _availableUsers = [];
  bool _isLoadingUsers = false;
  String? _usersError;
  StreamSubscription<bool>? _typingSubscription;
  bool _otherUserTyping = false;

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  bool get otherUserTyping => _otherUserTyping;
  String? get currentChatUserId => _currentChatUserId;
  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;
  List<ChatUser> get availableUsers => List.unmodifiable(_availableUsers);
  bool get isLoadingUsers => _isLoadingUsers;
  String? get usersError => _usersError;

  int get totalUnreadCount {
    return _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }

  /// Fetch all conversations
  Future<List<ChatConversation>> getConversations({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _conversations.isNotEmpty) {
      return _conversations;
    }

    _isLoadingConversations = true;
    _conversationsError = null;
    await Future.microtask(() => notifyListeners());

    try {
      final currentUserPhone = await _tokenStorage.getUserPhone();
      if (currentUserPhone == null) {
        _conversationsError = 'Not authenticated';
        _isLoadingConversations = false;
        await Future.microtask(() => notifyListeners());
        return _conversations;
      }

      final unread = {
        for (final c in _conversations) c.otherUserPhone: c.unreadCount,
      };
      final merged = <String, ChatConversation>{
        for (final c in await _fetchChatContactsFromApi(
          senderPhone: currentUserPhone,
        ))
          c.otherUserPhone: c,
      };
      for (final c in await _chatService.recentConversations()) {
        final fromApi = merged[c.otherUserPhone];
        if (fromApi == null ||
            (c.lastActivity?.isAfter(fromApi.lastActivity ?? DateTime(0)) ??
                false)) {
          merged[c.otherUserPhone] = c;
        }
      }
      _conversations = merged.values
          .map((c) => _withUnread(c, unread[c.otherUserPhone] ?? 0))
          .toList();
      _sortConversations();
      debugPrint('✅ Loaded ${_conversations.length} conversations');
    } catch (e) {
      _conversationsError = 'Error loading conversations: $e';
      debugPrint('❌ Error loading conversations: $e');
    }

    _isLoadingConversations = false;
    await Future.microtask(() => notifyListeners());
    return _conversations;
  }

  /// Fetch chat contacts from API
  Future<List<ChatConversation>> _fetchChatContactsFromApi({
    required String senderPhone,
  }) async {
    try {
      final url = Endpoints.buildUrl(
        Endpoints.getChatContacts,
        queryParams: {'senderId': senderPhone},
      );

      debugPrint('🔷 Fetching chat contacts: $url');
      final response = await _apiClient.get(
        url.replaceFirst(Endpoints.baseUrl, ''),
      );
      final contactsData = ApiClient.unwrapList(response);

      debugPrint('📥 Received ${contactsData.length} contacts from API');

      return contactsData.map((json) {
        final otherUserPhone = json['receiverId']?.toString() ?? '';
        final otherUserName = json['receiverName']?.toString() ?? 'Unknown';
        final lastMessageText = json['message']?.toString() ?? '';
        final lastMessageTime = json['createdAt']?.toString() ?? '';

        return ChatConversation(
          id: '${senderPhone}_$otherUserPhone',
          otherUserPhone: otherUserPhone,
          otherUserName: otherUserName,
          otherUserAvatar: json['avatar']?.toString(),
          lastMessage: lastMessageText.isNotEmpty
              ? ChatMessage(
                  id: json['id']?.toString() ?? '',
                  senderId: json['senderId']?.toString() ?? '',
                  recipientId: otherUserPhone,
                  content: lastMessageText,
                  timestamp:
                      DateTime.tryParse(lastMessageTime) ?? DateTime.now(),
                  status: MessageStatus.sent,
                )
              : null,
          unreadCount: 0,
          lastActivity: DateTime.tryParse(lastMessageTime),
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ API fetch contacts failed: $e');
    }
    return [];
  }

  /// Fetch available users
  Future<List<ChatUser>> getAvailableUsers({bool forceRefresh = false}) async {
    if (!forceRefresh && _availableUsers.isNotEmpty) {
      return _availableUsers;
    }

    _isLoadingUsers = true;
    _usersError = null;
    await Future.microtask(() => notifyListeners());

    try {
      final currentUserId = await _tokenStorage.getUserId();
      if (currentUserId == null) {
        _usersError = 'Not authenticated';
        _isLoadingUsers = false;
        await Future.microtask(() => notifyListeners());
        return _availableUsers;
      }

      final List<ChatUser> allUsers = [];

      // Fetch drivers
      try {
        final driversResponse = await _apiClient.get(
          Endpoints.getActiveDrivers,
        );
        final driversData = ApiClient.unwrapList(driversResponse);

        for (final d in driversData) {
          final phone = d['phoneNumber']?.toString() ?? d['phone']?.toString();
          if (phone != null && phone.isNotEmpty) {
            allUsers.add(
              ChatUser(
                id: d['userId']?.toString() ?? d['id']?.toString() ?? '',
                phone: phone,
                name: d['fullname'] ?? d['name'] ?? 'Unknown Driver',
                avatar: d['avatar'] ?? d['profileImage'],
                role: 'Driver',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to load drivers: $e');
      }

      // Fetch guardians
      try {
        final guardiansResponse = await _apiClient.get(
          Endpoints.getAllGuardians,
        );
        final guardiansData = ApiClient.unwrapList(guardiansResponse);

        for (final g in guardiansData) {
          final phone = g['phoneNumber']?.toString() ?? g['phone']?.toString();
          if (phone != null && phone.isNotEmpty) {
            allUsers.add(
              ChatUser(
                id: g['userId']?.toString() ?? g['id']?.toString() ?? '',
                phone: phone,
                name: g['fullname'] ?? g['name'] ?? 'Unknown Guardian',
                avatar: g['avatar'] ?? g['profileImage'],
                role: 'Guardian',
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to load guardians: $e');
      }

      // Remove duplicates by phone
      final uniqueUsers = <String, ChatUser>{};
      for (final user in allUsers) {
        if (user.phone.isNotEmpty) {
          uniqueUsers[user.phone] = user;
        }
      }

      _availableUsers = uniqueUsers.values.toList();
      _availableUsers.sort((a, b) => a.name.compareTo(b.name));
    } catch (e) {
      _usersError = 'Error: $e';
      debugPrint('❌ Error loading available users: $e');
    }

    _isLoadingUsers = false;
    await Future.microtask(() => notifyListeners());
    return _availableUsers;
  }

  /// Open the chat with [otherUserPhone] (or a `trip_…` group delivering to
  /// [memberPhones]). Incoming messages arrive via the app-wide inbox.
  Future<void> initialize(
    String currentUserPhone,
    String otherUserPhone, {
    List<String>? memberPhones,
  }) async {
    _isConnecting = true;
    _error = null;
    _currentChatUserId = otherUserPhone;
    _chatService.activeChatPhone = otherUserPhone;
    _messages = [];
    _clearUnread(otherUserPhone);
    notifyListeners();

    try {
      if (memberPhones != null && memberPhones.isNotEmpty) {
        await _chatService.setGroupMembers(otherUserPhone, memberPhones);
      }
      if (!_mqtt.isConnected) await _mqtt.connect();
      _isConnected = true;

      debugPrint('💬 Starting chat with phone: $otherUserPhone');
      _addMessages(await _chatService.loadHistory(otherUserPhone));
      await _loadMessageHistory(currentUserPhone, otherUserPhone);

      _typingSubscription?.cancel();
      _typingSubscription = _chatService
          .onTypingIndicator(otherUserPhone)
          .listen((isTyping) {
            _otherUserTyping = isTyping;
            notifyListeners();
          });

      _isConnecting = false;
      notifyListeners();
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _error = 'Failed to connect: $e';
      notifyListeners();
    }
  }

  /// Load message history from API
  Future<void> _loadMessageHistory(
    String currentUserPhone,
    String otherUserPhone,
  ) async {
    try {
      debugPrint('📥 Loading message history from API...');
      final url = Endpoints.buildUrl(
        Endpoints.getChats,
        queryParams: {
          'senderId': currentUserPhone,
          'receiverId': otherUserPhone,
        },
      );

      final response = await _apiClient.get(
        url.replaceFirst(Endpoints.baseUrl, ''),
      );
      final messagesData = ApiClient.unwrapList(response);

      debugPrint('📥 Received ${messagesData.length} messages from API');

      _addMessages(messagesData
          .map(
            (json) => ChatMessage(
              id: json['id']?.toString() ?? '',
              senderId: json['senderId']?.toString() ?? '',
              recipientId: json['receiverId']?.toString() ?? '',
              content: json['message']?.toString() ?? '',
              timestamp:
                  DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
              status: MessageStatus.sent,
            ),
          ));

      debugPrint('📥 Total messages loaded: ${_messages.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Failed to load message history: $e');
    }
  }

  /// Send a text message
  Future<void> sendMessage(
    String content, {
    String? senderName,
    String? recipientName,
  }) async {
    if (!_isConnected) {
      _error = 'Not connected to chat server';
      notifyListeners();
      return;
    }

    if (content.trim().isEmpty || _currentChatUserId == null) return;

    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null) return;

    // Create message
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUserPhone,
      recipientId: _currentChatUserId!,
      content: content.trim(),
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    // Add to messages - it will be the newest (last in list)
    _messages.add(message);
    notifyListeners();

    try {
      final sent = await _chatService.sendMessage(
        recipientPhone: _currentChatUserId!,
        content: content.trim(),
        senderName: senderName,
        recipientName: recipientName,
      );
      _messages[_messages.indexOf(message)] = sent;

      // Update conversation
      await _updateConversationAfterSend(
        recipientPhone: _currentChatUserId!,
        recipientName: recipientName ?? 'Unknown',
        message: sent,
      );

      notifyListeners();
    } catch (e) {
      message.status = MessageStatus.failed;
      _error = 'Failed to send message: $e';
      notifyListeners();
    }
  }

  /// Update conversations after sending
  Future<void> _updateConversationAfterSend({
    required String recipientPhone,
    required String recipientName,
    required ChatMessage message,
  }) async {
    final existingIndex = _conversations.indexWhere(
      (c) => c.otherUserPhone == recipientPhone,
    );

    if (existingIndex >= 0) {
      final existing = _conversations[existingIndex];
      _conversations[existingIndex] = ChatConversation(
        id: existing.id,
        otherUserPhone: existing.otherUserPhone,
        otherUserName: existing.otherUserName,
        otherUserAvatar: existing.otherUserAvatar,
        lastMessage: message,
        unreadCount: existing.unreadCount,
        lastActivity: message.timestamp,
        isOnline: existing.isOnline,
      );
    } else {
      _conversations.add(
        ChatConversation(
          id: '${message.senderId}_$recipientPhone',
          otherUserPhone: recipientPhone,
          otherUserName: recipientName,
          lastMessage: message,
          unreadCount: 0,
          lastActivity: message.timestamp,
        ),
      );
    }

    _sortConversations();
  }

  // ==========================================================================
  // INBOX
  // ==========================================================================

  final MqttService _mqtt = MqttService();

  void _onIncoming(IncomingChat chat) {
    final message = chat.message;
    // Replies to a trip group thread under the group, not the sender.
    final thread = ChatService.threadOf(message);
    final isOpen = thread == _currentChatUserId;
    if (isOpen) {
      _addMessages([message]);
      unawaited(_chatService.markAsDelivered(message.id, message.senderId));
    }

    final i = _conversations.indexWhere((c) => c.otherUserPhone == thread);
    final existing = i >= 0 ? _conversations[i] : null;
    final updated = ChatConversation(
      id: existing?.id ?? thread,
      otherUserPhone: thread,
      otherUserName: existing?.otherUserName ?? chat.senderName,
      otherUserAvatar: existing?.otherUserAvatar,
      otherUserRole: existing?.otherUserRole,
      lastMessage: message,
      unreadCount: isOpen ? 0 : (existing?.unreadCount ?? 0) + 1,
      lastActivity: message.timestamp,
    );
    if (i >= 0) {
      _conversations[i] = updated;
    } else {
      _conversations.add(updated);
    }
    _sortConversations();
    notifyListeners();
  }

  void _addMessages(Iterable<ChatMessage> incoming) {
    for (final m in incoming) {
      if (!_messages.any((e) => e.id == m.id)) _messages.add(m);
    }
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    notifyListeners();
  }

  void _clearUnread(String phone) {
    final i = _conversations.indexWhere((c) => c.otherUserPhone == phone);
    if (i >= 0) _conversations[i] = _withUnread(_conversations[i], 0);
  }

  static ChatConversation _withUnread(ChatConversation c, int unread) =>
      ChatConversation(
        id: c.id,
        otherUserPhone: c.otherUserPhone,
        otherUserName: c.otherUserName,
        otherUserAvatar: c.otherUserAvatar,
        otherUserRole: c.otherUserRole,
        lastMessage: c.lastMessage,
        unreadCount: unread,
        lastActivity: c.lastActivity,
        isOnline: c.isOnline,
      );

  void _sortConversations() {
    _conversations.sort((a, b) {
      if (a.lastActivity == null && b.lastActivity == null) return 0;
      if (a.lastActivity == null) return 1;
      if (b.lastActivity == null) return -1;
      return b.lastActivity!.compareTo(a.lastActivity!);
    });
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator(bool isTyping) async {
    if (!_isConnected || _currentChatUserId == null) return;

    try {
      await _chatService.sendTypingIndicator(_currentChatUserId!, isTyping);
    } catch (e) {
      // Silently fail
    }
  }

  /// Mark all messages as read
  Future<void> markMessagesAsRead() async {
    if (_currentChatUserId == null) return;

    for (final message in _messages) {
      if (message.senderId == _currentChatUserId &&
          message.status != MessageStatus.read) {
        await _chatService.markAsRead(message.id, message.senderId);
        message.status = MessageStatus.read;
      }
    }
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// The chat screen closed: its messages notify again.
  void leaveChat() {
    _typingSubscription?.cancel();
    if (_chatService.activeChatPhone == _currentChatUserId) {
      _chatService.activeChatPhone = null;
    }
    _currentChatUserId = null;
  }

  @override
  void dispose() {
    _typingSubscription?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }
}
