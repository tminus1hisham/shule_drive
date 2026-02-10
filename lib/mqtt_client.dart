import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:math';

class MqttService {
  static final MqttService _singleton = MqttService._internal();
  late MqttServerClient _client;
  bool _isConnected = false;

  // Private constructor
  MqttService._internal();

  factory MqttService() {
    return _singleton;
  }

  String generateRandomString(int length) {
    const characters =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
            (_) => characters.codeUnitAt(random.nextInt(characters.length)),
      ),
    );
  }

  // Initialize MQTT Client
  Future<void> initializeMqtt() async {
    _client = MqttServerClient('analytics.teleeza.africa', '');
    _client.logging(on: false);
    _client.setProtocolV311();
    _client.keepAlivePeriod = 20;
    _client.connectTimeoutPeriod = 2000;
    _client.onConnected = onConnected;
    _client.onDisconnected = onDisconnected;

    // Set up the connection message
    final connMess = MqttConnectMessage()
        .withClientIdentifier(generateRandomString(40))
        .startClean() // Non-persistent session for testing
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .withWillQos(MqttQos.atLeastOnce)
        .authenticateAs('teleezaAnalytics', 'teleezaAnalyticsAdmin2023');

    _client.connectionMessage = connMess;

    try {
      await _client.connect();
    } on Exception catch (e) {
      print('Error connecting to MQTT broker: $e');
    }

    if (_client.connectionStatus?.state == MqttConnectionState.connected) {
      _isConnected = true;
      print('Connected to MQTT broker');
    } else {
      print('Failed to connect to MQTT broker');
    }
  }

  // Get the client instance
  MqttServerClient get client => _client;

  // Check if the client is connected
  bool get isConnected => _isConnected;

  // Connection success callback
  void onConnected() {
    //print('Connected to MQTT broker');
  }

  // Disconnection callback
  void onDisconnected() {
    print('Disconnected from MQTT broker');
    _isConnected = false;
    initializeMqtt();
  }

  // Publish a message to a topic
  Future<void> publishMessage(String topic, String message) async {
    if (_isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
    } else {
      print('Not connected to MQTT broker');
      initializeMqtt();
    }
  }

  // Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    if (_isConnected) {
      _client.subscribe(topic, MqttQos.exactlyOnce);
    } else {
      print('Not connected to MQTT broker');
      initializeMqtt();
    }
  }

  // Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    if (_isConnected) {
      _client.unsubscribe(topic);
    } else {
      print('Not connected to MQTT broker');
      initializeMqtt();
    }
  }
}
