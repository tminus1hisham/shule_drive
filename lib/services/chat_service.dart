import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../mqtt_client.dart';
import 'secure_token_storage.dart';
import 'local_database_service.dart';

/// Chat Service - Real-time messaging using MQTT
/// Backend handles persistence via MQTT bridge
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final MqttService _mqttService = MqttService();
  final SecureTokenStorage _tokenStorage = SecureTokenStorage();
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final _uuid = const Uuid();

  // Message history (in-memory cache)
  final Map<String, List<ChatMessage>> _messageHistory = {};

  // Typing indicators
  final Map<String, StreamController<bool>> _typingControllers = {};

  // Connection to MQTT
  StreamSubscription<MqttMessageEvent>? _messageSubscription;

  /// Initialize chat service
  Future<void> initialize() async {
    // Listen to all incoming MQTT messages
    _messageSubscription = _mqttService.messages.listen(_handleIncomingMessage);
  }

  /// Connect to MQTT (if not already connected)
  Future<void> connect() async {
    if (!_mqttService.isConnected) {
      await _mqttService.connect();
    }
  }

  /// Stop chat listening. The MQTT connection is shared with trip events and
  /// guardian alerts, so it stays up (logout closes it).
  Future<void> disconnect() async {
    _messageSubscription?.cancel();
  }

  /// Start a chat with another user (using phone numbers)
  /// Subscribes to user's own topic 'chat/{currentUserPhone}' to receive messages
  Future<void> startChat(
    String otherUserPhone,
    Function(ChatMessage) onMessage,
  ) async {
    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null) throw Exception('Not authenticated');

    final chatTopic = _getChatTopic(currentUserPhone, otherUserPhone);
    // Subscribe to own topic to receive messages sent to current user
    final receiveTopic = 'chat/$currentUserPhone';

    debugPrint('📱 Current user phone: $currentUserPhone');
    debugPrint('📱 Other user phone: $otherUserPhone');
    debugPrint('📱 Chat topic (for DB): $chatTopic');
    debugPrint('📱 Receive topic (MQTT): $receiveTopic');

    // Load message history from local database first
    await _loadMessageHistoryFromDb(chatTopic, onMessage);

    // Subscribe to user's own topic for incoming messages
    debugPrint('📥 Subscribing to receive topic: $receiveTopic');
    await _mqttService.subscribe(receiveTopic, (topic, message) {
      debugPrint('📨 Received message on topic: $topic');
      try {
        final data = jsonDecode(message) as Map<String, dynamic>;

        // Parse message from backend format
        final senderId = data['senderId']?.toString() ?? '';
        final receiverId = data['receiverId']?.toString() ?? '';
        final messageText = data['message']?.toString() ?? '';
        final createdAt = data['createdAt']?.toString() ?? '';

        // Only process if this message is for the current chat
        if (senderId != otherUserPhone && receiverId != otherUserPhone) {
          debugPrint('   ℹ️ Message not for current chat, ignoring');
          return;
        }

        final chatMessage = ChatMessage(
          id: _uuid.v4(),
          senderId: senderId,
          recipientId: receiverId,
          content: messageText,
          timestamp: DateTime.tryParse(createdAt) ?? DateTime.now(),
          status: MessageStatus.delivered,
        );

        debugPrint('   ├─ From (phone): ${chatMessage.senderId}');
        debugPrint('   ├─ To (phone): ${chatMessage.recipientId}');
        debugPrint('   ├─ Content: ${chatMessage.content}');
        debugPrint('   └─ Timestamp: ${chatMessage.timestamp}');

        // Determine the correct chat topic for storage
        final msgChatTopic = _getChatTopic(senderId, receiverId);

        // Save to local database
        _saveMessageToDb(msgChatTopic, chatMessage);

        // Notify listener
        onMessage(chatMessage);

        // Store in memory cache
        _addToHistory(msgChatTopic, chatMessage);

        debugPrint('✅ Message processed successfully');
      } catch (e) {
        debugPrint('❌ Failed to parse chat message: $e');
      }
    });
  }

  /// Load message history from local database
  Future<void> _loadMessageHistoryFromDb(
    String chatTopic,
    Function(ChatMessage) onMessage,
  ) async {
    try {
      final messages = await _localDb.getChatMessages(chatTopic);

      for (final msgData in messages) {
        final message = ChatMessage(
          id: msgData['id'],
          senderId: msgData['sender_id'],
          recipientId: msgData['recipient_id'],
          content: msgData['content'],
          timestamp: DateTime.parse(msgData['timestamp']),
          status: MessageStatus.values.firstWhere(
            (s) => s.name == msgData['status'],
            orElse: () => MessageStatus.sent,
          ),
          replyToMessageId: msgData['reply_to_message_id'],
        );

        _addToHistory(chatTopic, message);
        onMessage(message);
      }

      if (kDebugMode && messages.isNotEmpty) {
        print('📦 Loaded ${messages.length} messages from local database');
      }
    } catch (e) {
      print('⚠️ Failed to load message history: $e');
    }
  }

  /// Save message to local database under sender's phone path
  /// Format: chats/$senderPhone/$chatTopic
  Future<void> _saveMessageToDb(
    String chatTopic,
    ChatMessage message, {
    String? senderPhone,
  }) async {
    try {
      // Create sender-specific path: chats/$senderPhone
      final senderPath = senderPhone ?? message.senderId;
      final fullPath = 'chats/$senderPath/$chatTopic';

      await _localDb.saveChatMessage(
        id: message.id,
        senderId: message.senderId,
        recipientId: message.recipientId,
        content: message.content,
        timestamp: message.timestamp,
        status: message.status.name,
        chatTopic: fullPath, // Save with full path including sender
        replyToMessageId: message.replyToMessageId,
        synced: true,
      );

      debugPrint('💾 Saved to DB: $fullPath');
    } catch (e) {
      print('⚠️ Failed to save message to database: $e');
    }
  }

  /// Send a text message via MQTT (backend handles persistence)
  /// Publishes to 'chat/{receiverPhone}' topic
  Future<void> sendMessage({
    required String recipientPhone,
    required String content,
    String? senderName,
    String? recipientName,
  }) async {
    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null) throw Exception('Not authenticated');

    // Get current user's name if not provided
    final currentUserName =
        senderName ?? await _tokenStorage.getUserName() ?? 'Unknown';
    final receiverUserName = recipientName ?? 'Unknown';

    // Publish to receiver's topic: chat/{receiverPhone}
    final publishTopic = 'chat/$recipientPhone';

    debugPrint('📤 Sending message via MQTT:');
    debugPrint('   ├─ Topic: $publishTopic');
    debugPrint('   ├─ From: $currentUserPhone ($currentUserName)');
    debugPrint('   ├─ To: $recipientPhone ($receiverUserName)');
    debugPrint('   └─ Content: $content');

    // Build message in backend format
    final messageData = {
      'chat': true,
      'senderId': currentUserPhone,
      'senderName': currentUserName.split('-').first.trim(),
      'receiverId': recipientPhone,
      'receiverName': receiverUserName.split('-').first.trim(),
      'message': content,
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Save to local database for immediate UI feedback
    final chatTopic = _getChatTopic(currentUserPhone, recipientPhone);
    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: currentUserPhone,
      recipientId: recipientPhone,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
    await _saveMessageToDb(chatTopic, message, senderPhone: currentUserPhone);
    _addToHistory(chatTopic, message);

    // Publish via MQTT - backend will handle persistence and forwarding
    try {
      await _mqttService.publishJson(publishTopic, messageData, retain: false);
      debugPrint('✅ Message published to MQTT successfully');
    } catch (e) {
      debugPrint('❌ Failed to publish message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator(String recipientPhone, bool isTyping) async {
    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null) return;

    final typingTopic = 'typing/$recipientPhone';

    await _mqttService.publishJson(typingTopic, {
      'userPhone': currentUserPhone,
      'isTyping': isTyping,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Listen to typing indicators from a user (using phone numbers)
  Stream<bool> onTypingIndicator(String otherUserPhone) {
    final currentUserPhone = _tokenStorage.getUserPhoneSync();
    if (currentUserPhone == null) return Stream.empty();

    final typingTopic = 'typing/$currentUserPhone';

    if (!_typingControllers.containsKey(typingTopic)) {
      _typingControllers[typingTopic] = StreamController<bool>.broadcast();

      _mqttService.subscribe(typingTopic, (topic, message) {
        try {
          final data = jsonDecode(message);
          if (data['userPhone'] == otherUserPhone) {
            _typingControllers[typingTopic]!.add(data['isTyping'] as bool);
          }
        } catch (e) {
          print('Failed to parse typing indicator: $e');
        }
      });
    }

    return _typingControllers[typingTopic]!.stream;
  }

  /// Get message history for a chat (using phone numbers)
  List<ChatMessage> getMessageHistory(String otherUserPhone) {
    final currentUserPhone = _tokenStorage.getUserPhoneSync();
    if (currentUserPhone == null) return [];

    final chatTopic = _getChatTopic(currentUserPhone, otherUserPhone);
    return _messageHistory[chatTopic] ?? [];
  }

  /// Mark message as delivered (using phone numbers)
  Future<void> markAsDelivered(String messageId, String senderPhone) async {
    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null) return;

    final statusTopic = 'status/$messageId';
    await _mqttService.publishJson(statusTopic, {
      'messageId': messageId,
      'status': 'delivered',
      'deliveredBy': currentUserPhone, // Use phone number
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Mark message as read (using phone numbers)
  Future<void> markAsRead(String messageId, String senderPhone) async {
    final currentUserPhone = await _tokenStorage.getUserPhone();
    if (currentUserPhone == null) return;

    final statusTopic = 'status/$messageId';
    await _mqttService.publishJson(statusTopic, {
      'messageId': messageId,
      'status': 'read',
      'readBy': currentUserPhone, // Use phone number
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle incoming MQTT messages
  void _handleIncomingMessage(MqttMessageEvent event) {
    // Handle message status updates
    if (event.topic.startsWith('status/')) {
      _handleStatusUpdate(event);
    }
  }

  void _handleStatusUpdate(MqttMessageEvent event) {
    try {
      final data = event.toJson();
      final messageId = data['messageId'];
      final status = data['status'];

      // Update message status in history
      _messageHistory.forEach((topic, messages) {
        try {
          final message = messages.firstWhere((m) => m.id == messageId);
          message.status = MessageStatus.values.firstWhere(
            (s) => s.name == status,
            orElse: () => message.status,
          );
        } catch (_) {
          // Message not found in this topic, continue
        }
      });
    } catch (e) {
      print('Failed to handle status update: $e');
    }
  }

  String _getChatTopic(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'chat/${ids[0]}_${ids[1]}';
  }

  /// Public method to get chat topic for two users
  String getChatTopic(String userId1, String userId2) {
    return _getChatTopic(userId1, userId2);
  }

  void _addToHistory(String chatTopic, ChatMessage message) {
    if (!_messageHistory.containsKey(chatTopic)) {
      _messageHistory[chatTopic] = [];
    }
    _messageHistory[chatTopic]!.add(message);

    // Keep only last 100 messages per chat
    if (_messageHistory[chatTopic]!.length > 100) {
      _messageHistory[chatTopic]!.removeAt(0);
    }
  }

  void dispose() {
    _messageSubscription?.cancel();
    _typingControllers.values.forEach((c) => c.close());
    _typingControllers.clear();
  }
}
