import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../services/mqtt_service.dart';

class ChatProvider extends ChangeNotifier {
  final MQTTService _mqttService = MQTTService();
  final _uuid = const Uuid();

  final List<ChatMessage> _messages = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;

  Future<void> initialize(String currentUserId, String otherUserId) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      _connectionSubscription?.cancel();
      _connectionSubscription = _mqttService.connectionStream.listen((connected) {
        _isConnected = connected;
        notifyListeners();
      });

      _messageSubscription?.cancel();
      _messageSubscription = _mqttService.messageStream.listen((message) {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          notifyListeners();
        }
      });

      await _mqttService.connect(currentUserId, otherUserId);
      _isConnecting = false;
      notifyListeners();
    } catch (e) {
      _isConnecting = false;
      _error = 'Failed to connect: $e';
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    if (!_isConnected) {
      _error = 'Not connected to chat server';
      notifyListeners();
      return;
    }

    if (content.trim().isEmpty) return;

    final message = ChatMessage(
      id: _uuid.v4(),
      senderId: 'user1',
      receiverId: 'user2',
      content: content.trim(),
      timestamp: DateTime.now(),
      isRead: false,
    );

    try {
      await _mqttService.sendMessage(message);
      _messages.add(message);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      notifyListeners();
    } catch (e) {
      _error = 'Failed to send message: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}
