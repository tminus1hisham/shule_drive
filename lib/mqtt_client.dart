import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'api/api_exceptions.dart';
import 'services/app_config.dart';
import 'services/secure_token_storage.dart';

/// MQTT Service - Handles connections with authentication for chat and notifications
class MqttService {
  static final MqttService _singleton = MqttService._internal();
  late MqttServerClient _client;
  bool _isConnected = false;

  // Subscriptions map: topic -> callback
  final Map<String, List<Function(String topic, String message)>>
  _subscriptions = {};

  // Connection status stream
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionController.stream;

  // Message stream for general consumption
  final StreamController<MqttMessageEvent> _messageController =
      StreamController<MqttMessageEvent>.broadcast();
  Stream<MqttMessageEvent> get messages => _messageController.stream;

  // Secure storage
  final SecureTokenStorage _tokenStorage = SecureTokenStorage();

  // Reconnect timer
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;

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

  Future<void>? _connecting;

  /// Stable per-install id so the broker keeps this client's session (and
  /// queues QoS 1 messages) across reconnects instead of starting fresh.
  static Future<String> _installId() async {
    const key = 'mqtt_install_id';
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(key);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(key, id);
    }
    return id;
  }

  /// Initialize and connect to MQTT broker. Concurrent callers share one
  /// attempt so two clients are never created.
  Future<void> connect() {
    if (_isConnected) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {

    print('🔄 Connecting to MQTT broker...');

    _manualDisconnect = false;

    try {
      final userId = await _tokenStorage.getUserId();
      final token = await _tokenStorage.getAccessToken();

      print('   ├─ User ID: ${userId ?? "NOT FOUND"}');
      print(
        '   ├─ Token: ${token != null ? "${token.substring(0, min(20, token.length))}..." : "NOT FOUND"}',
      );

      if (userId == null || token == null) {
        print('   └─ ❌ Missing credentials - cannot connect');
        throw UnauthorizedException(message: 'No authentication credentials');
      }

      final broker = appConfig.getOrDefault(
        'MQTT_BROKER',
        'analytics.teleeza.africa',
      );
      final username = appConfig.getOrDefault(
        'MQTT_USERNAME',
        'teleezaAnalytics',
      );
      final password = appConfig.getOrDefault(
        'MQTT_PASSWORD',
        'teleezaAnalyticsAdmin2023',
      );

      _client = MqttServerClient(broker, '');
      _client.logging(on: false);
      _client.setProtocolV311();
      _client.keepAlivePeriod = 20;
      _client.connectTimeoutPeriod = 2000;
      _client.onConnected = _onConnected;
      _client.onDisconnected = _onDisconnected;
      _client.onSubscribed = _onSubscribed;
      _client.onSubscribeFail = _onSubscribeFail;

      // Set up the connection message
      final connMess = MqttConnectMessage()
          .withClientIdentifier('shuledrive_${userId}_${await _installId()}')
          .withWillTopic('users/$userId/status')
          .withWillMessage(
            jsonEncode({
              'status': 'offline',
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .withWillQos(MqttQos.atLeastOnce)
          .withWillRetain()
          .authenticateAs(username, password);

      _client.connectionMessage = connMess;

      // Attempt connection
      await _client.connect();

      // Setup message listener
      _client.updates!.listen(_onMessage);

      // Publish online status
      await publish(
        'users/$userId/status',
        jsonEncode({
          'status': 'online',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        retain: true,
      );

      print('✅ MQTT setup complete - listening for messages');

      final senderPhone = await _tokenStorage.getUserPhone();
      if (senderPhone != null && senderPhone.isNotEmpty) {
        _subscriptions.putIfAbsent('chats/$senderPhone', () => [handleMessage]);
      }

      // A reconnect builds a new client, so every known topic (guardian
      // status, trip events, chat) must be subscribed again.
      for (final topic in _subscriptions.keys) {
        _client.subscribe(topic, MqttQos.atLeastOnce);
      }
    } on UnauthorizedException {
      rethrow; // No session yet; login connects again.
    } on SocketException catch (e) {
      print('❌ MQTT CONNECTION FAILED: Network error - $e');
      if (!_manualDisconnect) _scheduleReconnect();
      throw NetworkException();
    } catch (e) {
      print('❌ MQTT CONNECTION FAILED: $e');
      if (!_manualDisconnect) _scheduleReconnect();
      throw ApiException(message: 'MQTT connection failed: $e');
    }
  }

  void handleMessage(String topic, String message) {
    print('Received message on $topic: $message');
    // Do something with the message
  }

  /// Disconnect from MQTT broker
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();

    if (_isConnected) {
      final userId = await _tokenStorage.getUserId();
      if (userId != null) {
        // Publish offline status
        await publish(
          'users/$userId/status',
          jsonEncode({
            'status': 'offline',
            'timestamp': DateTime.now().toIso8601String(),
          }),
          retain: true,
        );
      }

      _client.disconnect();
    }

    // Manual disconnect means logout: don't resubscribe the old user's topics.
    _subscriptions.clear();
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Subscribe to a topic
  Future<void> subscribe(
    String topic,
    Function(String topic, String message) callback,
  ) async {
    // Register before connecting: connect() subscribes every known topic,
    // and queued session messages can arrive right after the handshake.
    final isNewTopic = !_subscriptions.containsKey(topic);
    final callbacks = _subscriptions.putIfAbsent(topic, () => []);
    if (!callbacks.contains(callback)) callbacks.add(callback);

    if (!_isConnected) {
      await connect();
    } else if (isNewTopic) {
      _client.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribe(
    String topic, [
    Function(String topic, String message)? callback,
  ]) async {
    if (callback != null && _subscriptions.containsKey(topic)) {
      _subscriptions[topic]!.remove(callback);

      if (_subscriptions[topic]!.isEmpty) {
        _subscriptions.remove(topic);
        if (_isConnected) {
          _client.unsubscribe(topic);
        }
      }
    } else {
      // Unsubscribe all callbacks for this topic
      _subscriptions.remove(topic);
      if (_isConnected) {
        _client.unsubscribe(topic);
      }
    }
  }

  /// Publish a message to a topic
  Future<void> publish(
    String topic,
    String message, {
    bool retain = false,
  }) async {
    if (!_isConnected) {
      throw ApiException(message: 'MQTT not connected');
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(message);

    final result = _client.publishMessage(
      topic,
      MqttQos.exactlyOnce,
      builder.payload!,
      retain: retain,
    );

    if (kDebugMode) {
      print('📤 MQTT Publish: topic=$topic, retain=$retain, result=$result');
    }
  }

  /// Publish a JSON message
  Future<void> publishJson(
    String topic,
    Map<String, dynamic> data, {
    bool retain = false,
  }) async {
    await publish(topic, jsonEncode(data), retain: retain);
  }

  // Get the client instance
  MqttServerClient get client => _client;

  // Check if the client is connected
  bool get isConnected => _isConnected;

  // Callbacks
  void _onConnected() {
    _isConnected = true;
    _reconnectTimer?.cancel();
    _connectionController.add(true);
    print('✅ MQTT CONNECTION SUCCESSFUL');
    print('   ├─ Broker: ${_client.server}');
    print('   ├─ Client ID: ${_client.clientIdentifier}');
    print('   ├─ Connected at: ${DateTime.now().toIso8601String()}');
    print('   └─ Status: Online');
  }

  void _onDisconnected() {
    print('⚠️ MQTT DISCONNECTED from broker');
    _isConnected = false;
    _connectionController.add(false);
    if (!_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  void _onSubscribed(String topic) {
    print('Subscribed to: $topic');
  }

  void _onSubscribeFail(String topic) {
    print('Failed to subscribe to: $topic');
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final received in messages) {
      final topic = received.topic;
      final message = received.payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(
        message.payload.message,
      );

      // Add to message stream
      _messageController.add(MqttMessageEvent(topic: topic, message: payload));

      // Notify specific subscribers
      if (_subscriptions.containsKey(topic)) {
        for (final callback in _subscriptions[topic]!) {
          callback(topic, payload);
        }
      }

      // Check wildcard subscriptions
      _subscriptions.forEach((subscribedTopic, callbacks) {
        if (_topicMatches(subscribedTopic, topic)) {
          for (final callback in callbacks) {
            callback(topic, payload);
          }
        }
      });
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect().catchError((e) {
          if (kDebugMode) {
            print('MQTT reconnect failed: $e');
          }
        });
      }
    });
  }

  bool _topicMatches(String subscription, String topic) {
    // Handle wildcards: + for single level, # for multi level
    if (subscription.contains('+') || subscription.contains('#')) {
      final subParts = subscription.split('/');
      final topicParts = topic.split('/');

      for (var i = 0; i < subParts.length; i++) {
        if (subParts[i] == '#') return true;
        if (subParts[i] == '+') continue;
        if (i >= topicParts.length || subParts[i] != topicParts[i]) {
          return false;
        }
      }
      return subParts.length == topicParts.length;
    }
    return false;
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _connectionController.close();
    _messageController.close();
    disconnect();
  }
}

/// MQTT Message Event
class MqttMessageEvent {
  final String topic;
  final String message;
  final DateTime timestamp;

  MqttMessageEvent({required this.topic, required this.message})
    : timestamp = DateTime.now();

  Map<String, dynamic> toJson() => jsonDecode(message);
}

/// MQTT Topic Builder - Role-aware topic generation
class MqttTopics {
  final String userId;
  final UserRole role;

  MqttTopics({required this.userId, required this.role});

  // User-specific topics
  String get userChat => 'users/$userId/chat';
  String get userNotifications => 'users/$userId/notifications';
  String get userStatus => 'users/$userId/status';

  // Trip topics (role-filtered)
  String routeTripStatus(String routeId) => 'routes/$routeId/trip-status';
  String tripEvents(String tripId) => 'trips/$tripId/events';

  // Chat topics
  String chatWithUser(String otherUserId) =>
      'chat/${_sortedIds(userId, otherUserId)}';

  // Helper to create consistent chat room IDs
  String _sortedIds(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}

enum UserRole { driver, guardian, unknown }
