import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../mqtt_client.dart';
import 'secure_token_storage.dart';

/// Chat Service - Real-time messaging using MQTT
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final MqttService _mqttService = MqttService();
  final SecureTokenStorage _tokenStorage = SecureTokenStorage();
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

  /// Disconnect
  Future<void> disconnect() async {
    _messageSubscription?.cancel();
    await _mqttService.disconnect();
  }

  /// Start a chat with another user
  Future<void> startChat(String otherUserId, Function(ChatMessage) onMessage) async {
    final currentUserId = await _tokenStorage.getUserId();
    if (currentUserId == null) throw Exception('Not authenticated');

    final chatTopic = _getChatTopic(currentUserId, otherUserId);

    // Subscribe to chat topic
    await _mqttService.subscribe(chatTopic, (topic, message) {
      try {
        final data = jsonDecode(message);
        final chatMessage = ChatMessage.fromJson(data);
        onMessage(chatMessage);

        // Store in history
        _addToHistory(chatTopic, chatMessage);
      } catch (e) {
        print('Failed to parse chat message: $e');
      }
    });
  }

  /// Send a text message
  Future<void> sendMessage({
    required String recipientId,
    required String content,
    String? replyToMessageId,
  }) async {
    final currentUserId = await _tokenStorage.getUserId();
    if (currentUserId == null) throw Exception('Not authenticated');

    final chatTopic = _getChatTopic(currentUserId, recipientId);

    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: currentUserId,
      recipientId: recipientId,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      replyToMessageId: replyToMessageId,
    );

    await _mqttService.publishJson(chatTopic, message.toJson());
    _addToHistory(chatTopic, message);
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator(String recipientId, bool isTyping) async {
    final currentUserId = await _tokenStorage.getUserId();
    if (currentUserId == null) return;

    final typingTopic = 'typing/${_getChatTopic(currentUserId, recipientId)}';

    await _mqttService.publishJson(typingTopic, {
      'userId': currentUserId,
      'isTyping': isTyping,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Listen to typing indicators from a user
  Stream<bool> onTypingIndicator(String otherUserId) {
    final currentUserId = _tokenStorage.getUserId();
    if (currentUserId == null) return Stream.empty();

    final typingTopic = 'typing/${_getChatTopic(currentUserId as String, otherUserId)}';

    if (!_typingControllers.containsKey(typingTopic)) {
      _typingControllers[typingTopic] = StreamController<bool>.broadcast();

      _mqttService.subscribe(typingTopic, (topic, message) {
        try {
          final data = jsonDecode(message);
          if (data['userId'] == otherUserId) {
            _typingControllers[typingTopic]!.add(data['isTyping'] as bool);
          }
        } catch (e) {
          print('Failed to parse typing indicator: $e');
        }
      });
    }

    return _typingControllers[typingTopic]!.stream;
  }

  /// Get message history for a chat
  List<ChatMessage> getMessageHistory(String otherUserId) {
    final currentUserId = _tokenStorage.getUserIdSync();
    if (currentUserId == null) return [];

    final chatTopic = _getChatTopic(currentUserId, otherUserId);
    return _messageHistory[chatTopic] ?? [];
  }

  /// Mark message as delivered
  Future<void> markAsDelivered(String messageId, String senderId) async {
    final currentUserId = await _tokenStorage.getUserId();
    if (currentUserId == null) return;

    final statusTopic = 'status/$messageId';
    await _mqttService.publishJson(statusTopic, {
      'messageId': messageId,
      'status': 'delivered',
      'deliveredBy': currentUserId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Mark message as read
  Future<void> markAsRead(String messageId, String senderId) async {
    final currentUserId = await _tokenStorage.getUserId();
    if (currentUserId == null) return;

    final statusTopic = 'status/$messageId';
    await _mqttService.publishJson(statusTopic, {
      'messageId': messageId,
      'status': 'read',
      'readBy': currentUserId,
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
        final message = messages.firstWhere((m) => m.id == messageId, orElse: () => null as ChatMessage);
        if (message != null) {
          message.status = MessageStatus.values.firstWhere(
            (s) => s.name == status,
            orElse: () => message.status,
          );
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
