import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  final List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;
  String? _currentChatUserId;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;

  StreamSubscription<bool>? _typingSubscription;
  bool _otherUserTyping = false;
  bool get otherUserTyping => _otherUserTyping;

  /// Initialize and start chat with another user
  Future<void> initialize(String currentUserId, String otherUserId) async {
    _isConnecting = true;
    _error = null;
    _currentChatUserId = otherUserId;
    notifyListeners();

    try {
      // Initialize chat service if needed
      await _chatService.initialize();
      
      // Connect to MQTT
      await _chatService.connect();
      _isConnected = true;

      // Start chat and listen for messages
      await _chatService.startChat(otherUserId, (message) {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          notifyListeners();
          
          // Mark as delivered if message is from other user
          if (message.senderId == otherUserId) {
            _chatService.markAsDelivered(message.id, message.senderId);
          }
        }
      });

      // Load message history
      final history = _chatService.getMessageHistory(otherUserId);
      _messages.clear();
      _messages.addAll(history);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Listen to typing indicators
      _typingSubscription?.cancel();
      _typingSubscription = _chatService.onTypingIndicator(otherUserId).listen((isTyping) {
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

  /// Send a text message
  Future<void> sendMessage(String content) async {
    if (!_isConnected) {
      _error = 'Not connected to chat server';
      notifyListeners();
      return;
    }

    if (content.trim().isEmpty || _currentChatUserId == null) return;

    try {
      await _chatService.sendMessage(
        recipientId: _currentChatUserId!,
        content: content.trim(),
      );
      // Message will be added via the startChat callback when echoed back
    } catch (e) {
      _error = 'Failed to send message: $e';
      notifyListeners();
    }
  }

  /// Send typing indicator
  Future<void> sendTypingIndicator(bool isTyping) async {
    if (!_isConnected || _currentChatUserId == null) return;
    
    try {
      await _chatService.sendTypingIndicator(_currentChatUserId!, isTyping);
    } catch (e) {
      // Silently fail - typing indicator is not critical
    }
  }

  /// Mark all messages from other user as read
  Future<void> markMessagesAsRead() async {
    if (_currentChatUserId == null) return;
    
    for (final message in _messages) {
      if (message.senderId == _currentChatUserId && message.status != MessageStatus.read) {
        await _chatService.markAsRead(message.id, message.senderId);
        message.status = MessageStatus.read;
      }
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _typingSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }
}
