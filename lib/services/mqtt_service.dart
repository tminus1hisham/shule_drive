import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/chat_message.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  MqttServerClient? _client;
  final StreamController<ChatMessage> _messageController = StreamController<ChatMessage>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _client?.connectionStatus?.state == MqttConnectionState.connected;

  static const String _broker = 'broker.hivemq.com';
  static const int _port = 1883;
  static const String _clientIdPrefix = 'shuledrive_chat_';

  String? _currentUserId;
  String? _otherUserId;

  Future<void> connect(String userId, String otherUserId) async {
    _currentUserId = userId;
    _otherUserId = otherUserId;

    final clientId = '$_clientIdPrefix${userId}_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort(_broker, clientId, _port);
    
    _client!.keepAlivePeriod = 30;
    _client!.onDisconnected = () => _connectionController.add(false);
    _client!.onConnected = () {
      _connectionController.add(true);
      _subscribeToTopic(userId, otherUserId);
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
    } catch (e) {
      _connectionController.add(false);
    }
  }

  void _subscribeToTopic(String userId, String otherUserId) {
    if (_client == null || !isConnected) return;

    final userIds = [userId, otherUserId]..sort();
    final topic = 'shuledrive/chat/${userIds[0]}/${userIds[1]}';

    _client!.subscribe(topic, MqttQos.atLeastOnce);

    _client!.updates!.listen((messages) {
      for (final message in messages) {
        try {
          final payload = message.payload as MqttPublishMessage;
          final messageString = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
          final jsonData = jsonDecode(messageString);
          final chatMessage = ChatMessage.fromJson(jsonData);
          _messageController.add(chatMessage);
        } catch (e) {
          // Parse error
        }
      }
    });
  }

  Future<void> sendMessage(ChatMessage message) async {
    if (_client == null || !isConnected) throw Exception('Not connected');

    final userIds = [message.senderId, message.receiverId]..sort();
    final topic = 'shuledrive/chat/${userIds[0]}/${userIds[1]}';

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(message.toJson()));

    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void dispose() {
    _messageController.close();
    _connectionController.close();
    _client?.disconnect();
  }
}
