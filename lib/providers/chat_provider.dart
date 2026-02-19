import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/secure_token_storage.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final ApiClient _apiClient = ApiClient();
  final SecureTokenStorage _tokenStorage = SecureTokenStorage();

  // Messages for current chat
  final List<ChatMessage> _messages = [];
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

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;
  
  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  bool get isLoadingConversations => _isLoadingConversations;
  String? get conversationsError => _conversationsError;
  
  List<ChatUser> get availableUsers => List.unmodifiable(_availableUsers);
  bool get isLoadingUsers => _isLoadingUsers;
  String? get usersError => _usersError;

  StreamSubscription<bool>? _typingSubscription;
  bool _otherUserTyping = false;
  bool get otherUserTyping => _otherUserTyping;

  // ============================================================================
  // CONVERSATIONS (Chat List)
  // ============================================================================

  /// Fetch all conversations for the current user
  // Set to true to use mock data (API endpoint has issues)
  static const bool _useMockData = false;

  Future<List<ChatConversation>> getConversations({bool forceRefresh = false}) async {
    if (!forceRefresh && _conversations.isNotEmpty) {
      return _conversations;
    }

    _isLoadingConversations = true;
    _conversationsError = null;
    await Future.microtask(() => notifyListeners());

    // NOTE: Using mock data because the API endpoint /api/chats/get 
    // requires receiverId which doesn't make sense for getting all conversations
    // TODO: Fix backend API or implement proper conversation storage
    await Future.delayed(const Duration(milliseconds: 500));
    _conversations = _getMockConversations();

    _isLoadingConversations = false;
    await Future.microtask(() => notifyListeners());
    return _conversations;
  }

  /// Get total unread count across all conversations
  int get totalUnreadCount {
    return _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }

  // ============================================================================
  // AVAILABLE USERS (New Chat)
  // ============================================================================

  /// Fetch available users to start a chat with (drivers and guardians)
  Future<List<ChatUser>> getAvailableUsers({bool forceRefresh = false}) async {
    debugPrint('🔄 getAvailableUsers called, forceRefresh=$forceRefresh, cached=${_availableUsers.length}');
    
    if (!forceRefresh && _availableUsers.isNotEmpty) {
      debugPrint('📦 Returning cached users: ${_availableUsers.length}');
      return _availableUsers;
    }

    _isLoadingUsers = true;
    _usersError = null;
    
    // Use microtask to avoid setState during build
    await Future.microtask(() => notifyListeners());

    if (_useMockData) {
      // Use mock data for development/testing
      debugPrint('🧪 Using mock data');
      await Future.delayed(const Duration(seconds: 1));
      _availableUsers = _getMockUsers();
    } else {
      try {
        // Get current user ID to exclude self
        final currentUserId = await _tokenStorage.getUserId();
        debugPrint('👤 Current user ID: $currentUserId');
        if (currentUserId == null) {
          _usersError = 'Not authenticated';
          _isLoadingUsers = false;
          await Future.microtask(() => notifyListeners());
          return _availableUsers;
        }

        final List<ChatUser> allUsers = [];

        // Fetch drivers
        try {
          // Request all drivers without pagination
          final driversResponse = await _apiClient.get(
            Endpoints.getActiveDrivers,
            queryParams: {'limit': '1000', 'page': '1'},
          );
          debugPrint('🚗 Drivers response type: ${driversResponse.runtimeType}');
          if (driversResponse is List) {
            debugPrint('🚗 Drivers raw count: ${driversResponse.length}');
          } else if (driversResponse is Map) {
            debugPrint('🚗 Drivers response keys: ${driversResponse.keys.toList()}');
          }
          
          List<dynamic> driversData = [];
          
          if (driversResponse is List) {
            driversData = driversResponse;
          } else if (driversResponse is Map) {
            driversData = driversResponse['data'] as List? ?? 
                         driversResponse['drivers'] as List? ?? 
                         driversResponse['users'] as List? ?? [];
          }
          
          debugPrint('🚗 Drivers parsed count: ${driversData.length}');
          
          if (driversData.isNotEmpty) {
            debugPrint('📥 Processing ${driversData.length} drivers');
            final drivers = driversData
                .where((d) => d['userId']?.toString() != currentUserId && d['id']?.toString() != currentUserId) // Exclude self
                .map((d) => ChatUser(
                      id: d['userId']?.toString() ?? d['id']?.toString() ?? '',
                      name: d['fullname'] ?? d['fullName'] ?? d['name'] ?? d['userName'] ?? 'Unknown Driver',
                      avatar: d['avatar'] ?? d['profileImage'] ?? d['profilePicture'],
                      role: 'Driver',
                      phone: d['phoneNumber'] ?? d['phone'] ?? d['mobile'],
                      isOnline: d['isOnline'] ?? d['isActive'] ?? false,
                    ))
                .where((u) => u.id.isNotEmpty && u.id != 'null')
                .toList();
            allUsers.addAll(drivers);
            debugPrint('✅ Loaded ${drivers.length} drivers');
          }
        } catch (e, stackTrace) {
          debugPrint('⚠️ Failed to load drivers: $e');
          debugPrint('Stack: $stackTrace');
        }

        // Fetch guardians
        try {
          // Request all guardians without pagination
          final guardiansResponse = await _apiClient.get(
            Endpoints.getAllGuardians,
            queryParams: {'limit': '1000', 'page': '1'},
          );
          debugPrint('👨‍👩‍👧 Guardians response type: ${guardiansResponse.runtimeType}');
          if (guardiansResponse is List) {
            debugPrint('👨‍👩‍👧 Guardians raw count: ${guardiansResponse.length}');
          } else if (guardiansResponse is Map) {
            debugPrint('👨‍👩‍👧 Guardians response keys: ${guardiansResponse.keys.toList()}');
            debugPrint('👨‍👩‍👧 Guardians data count: ${(guardiansResponse['data'] as List?)?.length ?? 0}');
          }
          
          List<dynamic> guardiansData = [];
          
          if (guardiansResponse is List) {
            guardiansData = guardiansResponse;
          } else if (guardiansResponse is Map) {
            guardiansData = guardiansResponse['data'] as List? ?? 
                           guardiansResponse['guardians'] as List? ?? 
                           guardiansResponse['users'] as List? ?? [];
          }
          
          debugPrint('👨‍👩‍👧 Guardians parsed count: ${guardiansData.length}');
          
          if (guardiansData.isNotEmpty) {
            debugPrint('📥 Processing ${guardiansData.length} guardians');
            final guardians = guardiansData
                .where((g) => g['userId']?.toString() != currentUserId && g['id']?.toString() != currentUserId) // Exclude self
                .map((g) => ChatUser(
                      id: g['userId']?.toString() ?? g['id']?.toString() ?? '',
                      name: g['fullname'] ?? g['fullName'] ?? g['name'] ?? g['userName'] ?? 'Unknown Guardian',
                      avatar: g['avatar'] ?? g['profileImage'] ?? g['profilePicture'],
                      role: 'Guardian',
                      phone: g['phoneNumber'] ?? g['phone'] ?? g['mobile'],
                      isOnline: g['isOnline'] ?? g['isActive'] ?? false,
                    ))
                .where((u) => u.id.isNotEmpty && u.id != 'null')
                .toList();
            allUsers.addAll(guardians);
            debugPrint('✅ Loaded ${guardians.length} guardians');
          }
        } catch (e, stackTrace) {
          debugPrint('⚠️ Failed to load guardians: $e');
          debugPrint('Stack: $stackTrace');
        }

        // Remove duplicates by ID
        final uniqueUsers = <String, ChatUser>{};
        for (final user in allUsers) {
          uniqueUsers[user.id] = user;
        }
        
        _availableUsers = uniqueUsers.values.toList();
        
        // Sort by name
        _availableUsers.sort((a, b) => a.name.compareTo(b.name));
        
        debugPrint('✅ Total unique users: ${_availableUsers.length}');
        
        if (_availableUsers.isEmpty) {
          _usersError = 'No users found';
        }
      } catch (e, stackTrace) {
        _usersError = 'Error: $e';
        debugPrint('❌ Error loading available users: $e');
        debugPrint('Stack: $stackTrace');
      }
    }

    _isLoadingUsers = false;
    await Future.microtask(() => notifyListeners());
    return _availableUsers;
  }

  // ============================================================================
  // SINGLE CHAT (Existing Functionality)
  // ============================================================================

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

  /// Clear messages (call when leaving chat)
  void clearMessages() {
    _messages.clear();
    _currentChatUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _typingSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  // ============================================================================
  // MOCK DATA (For Development/Testing)
  // ============================================================================

  List<ChatConversation> _getMockConversations() {
    return [
      ChatConversation(
        id: 'conv_1',
        otherUserId: 'user_2',
        otherUserName: 'John Smith',
        otherUserRole: 'Driver',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_1',
          senderId: 'user_2',
          recipientId: 'user_1',
          content: 'I\'ll be there in 5 minutes to pick up the kids',
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
          status: MessageStatus.read,
        ),
        unreadCount: 0,
        lastActivity: DateTime.now().subtract(const Duration(minutes: 5)),
        isOnline: true,
      ),
      ChatConversation(
        id: 'conv_2',
        otherUserId: 'user_3',
        otherUserName: 'Sarah Johnson',
        otherUserRole: 'Guardian',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_2',
          senderId: 'user_3',
          recipientId: 'user_1',
          content: 'Thanks for the update!',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          status: MessageStatus.read,
        ),
        unreadCount: 0,
        lastActivity: DateTime.now().subtract(const Duration(hours: 2)),
        isOnline: false,
      ),
      ChatConversation(
        id: 'conv_3',
        otherUserId: 'user_4',
        otherUserName: 'Michael Brown',
        otherUserRole: 'Driver',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_3',
          senderId: 'user_4',
          recipientId: 'user_1',
          content: 'The bus has arrived at the school',
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          status: MessageStatus.delivered,
        ),
        unreadCount: 1,
        lastActivity: DateTime.now().subtract(const Duration(hours: 5)),
        isOnline: true,
      ),
      ChatConversation(
        id: 'conv_4',
        otherUserId: 'user_5',
        otherUserName: 'Emily Davis',
        otherUserRole: 'Staff',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_4',
          senderId: 'user_1',
          recipientId: 'user_5',
          content: 'Can you help me with the pickup schedule?',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          status: MessageStatus.sent,
        ),
        unreadCount: 0,
        lastActivity: DateTime.now().subtract(const Duration(days: 1)),
        isOnline: false,
      ),
      ChatConversation(
        id: 'conv_5',
        otherUserId: 'user_6',
        otherUserName: 'David Wilson',
        otherUserRole: 'Guardian',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_5',
          senderId: 'user_6',
          recipientId: 'user_1',
          content: 'My child will be absent today due to illness',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          status: MessageStatus.read,
        ),
        unreadCount: 0,
        lastActivity: DateTime.now().subtract(const Duration(days: 2)),
        isOnline: false,
      ),
    ];
  }

  List<ChatUser> _getMockUsers() {
    return [
      ChatUser(
        id: 'user_2',
        name: 'John Smith',
        role: 'Driver',
        phone: '+1 234 567 8901',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      ChatUser(
        id: 'user_3',
        name: 'Sarah Johnson',
        role: 'Guardian',
        phone: '+1 234 567 8902',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      ChatUser(
        id: 'user_4',
        name: 'Michael Brown',
        role: 'Driver',
        phone: '+1 234 567 8903',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      ChatUser(
        id: 'user_5',
        name: 'Emily Davis',
        role: 'Staff',
        phone: '+1 234 567 8904',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatUser(
        id: 'user_6',
        name: 'David Wilson',
        role: 'Guardian',
        phone: '+1 234 567 8905',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ChatUser(
        id: 'user_7',
        name: 'Jennifer Lee',
        role: 'Guardian',
        phone: '+1 234 567 8906',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
      ChatUser(
        id: 'user_8',
        name: 'Robert Taylor',
        role: 'Driver',
        phone: '+1 234 567 8907',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ChatUser(
        id: 'user_9',
        name: 'Lisa Anderson',
        role: 'Staff',
        phone: '+1 234 567 8908',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      ChatUser(
        id: 'user_10',
        name: 'James Martinez',
        role: 'Guardian',
        phone: '+1 234 567 8909',
        isOnline: false,
        lastSeen: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      ChatUser(
        id: 'user_11',
        name: 'Amanda White',
        role: 'Driver',
        phone: '+1 234 567 8910',
        isOnline: true,
        lastSeen: DateTime.now(),
      ),
    ];
  }
}
