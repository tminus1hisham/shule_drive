import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../models/chat_conversation.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/secure_token_storage.dart';
import '../services/local_database_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final ApiClient _apiClient = ApiClient();
  final SecureTokenStorage _tokenStorage = SecureTokenStorage();
  final LocalDatabaseService _localDb = LocalDatabaseService();

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

    try {
      // Load conversations from contacts API (single call, much faster)
      final currentUserPhone = await _tokenStorage.getUserPhone();
      if (currentUserPhone == null) {
        _conversationsError = 'Not authenticated';
        _isLoadingConversations = false;
        await Future.microtask(() => notifyListeners());
        return _conversations;
      }

      // Fetch contacts from API using the contacts endpoint
      _conversations = await _fetchChatContactsFromApi(senderPhone: currentUserPhone);
      
      debugPrint('✅ Loaded ${_conversations.length} conversations from contacts API');
    } catch (e) {
      _conversationsError = 'Error loading conversations: $e';
      debugPrint('❌ Error loading conversations: $e');
    }

    _isLoadingConversations = false;
    await Future.microtask(() => notifyListeners());
    return _conversations;
  }
  
  /// Fetch chat contacts from API - returns list of users with whom current user has chatted
  Future<List<ChatConversation>> _fetchChatContactsFromApi({
    required String senderPhone,
  }) async {
    try {
      final url = Endpoints.buildUrl(
        Endpoints.getChatContacts,
        queryParams: {
          'senderId': senderPhone,
        },
      );
      
      debugPrint('🔷 Fetching chat contacts: $url');
      final response = await _apiClient.get(url.replaceFirst(Endpoints.baseUrl, ''));
      
      // Response is already decoded - handle as List
      final List<dynamic> contactsData = response is List ? response : (response['data'] ?? []);
      
      debugPrint('📥 Received ${contactsData.length} contacts from API');
      
      return contactsData.map((json) {
        final otherUserPhone = json['phoneNumber']?.toString() ?? 
                              json['phone']?.toString() ?? 
                              json['receiverId']?.toString() ?? '';
        final otherUserName = json['fullname']?.toString() ?? 
                             json['name']?.toString() ?? 
                             json['receiverName']?.toString() ?? 'Unknown';
        final lastMessageText = json['lastMessage']?.toString() ?? 
                               json['message']?.toString() ?? '';
        final lastMessageTime = json['lastMessageTime']?.toString() ?? 
                               json['createdAt']?.toString() ?? '';
        final unreadCount = json['unreadCount'] ?? json['unread'] ?? 0;
        
        final chatTopic = _chatService.getChatTopic(senderPhone, otherUserPhone);
        
        return ChatConversation(
          id: chatTopic,
          otherUserPhone: otherUserPhone,
          otherUserName: otherUserName,
          otherUserAvatar: json['avatar']?.toString(),
          otherUserRole: json['role']?.toString(),
          lastMessage: lastMessageText.isNotEmpty ? ChatMessage(
            id: json['id']?.toString() ?? '',
            senderId: json['senderId']?.toString() ?? '',
            recipientId: otherUserPhone,
            content: lastMessageText,
            timestamp: DateTime.tryParse(lastMessageTime) ?? DateTime.now(),
            status: MessageStatus.sent,
          ) : null,
          unreadCount: unreadCount is int ? unreadCount : int.tryParse(unreadCount.toString()) ?? 0,
          lastActivity: DateTime.tryParse(lastMessageTime),
          isOnline: json['isOnline'] ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('⚠️ API fetch contacts failed: $e');
    }
    return [];
  }

  /// Get total unread count across all conversations
  int get totalUnreadCount {
    return _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
  }

  /// Fetch chat history from API using phone numbers (for loading messages in chat screen)
  Future<List<ChatMessage>> _fetchChatHistoryFromApi({
    required String senderPhone,
    required String receiverPhone,
  }) async {
    try {
      final url = Endpoints.buildUrl(
        Endpoints.getChats,
        queryParams: {
          'senderId': senderPhone,
          'receiverId': receiverPhone,
        },
      );
      
      debugPrint('🔷 Fetching chat history: $url');
      final response = await _apiClient.get(url.replaceFirst(Endpoints.baseUrl, ''));
      
      // Response is already decoded - handle as List
      final List<dynamic> messagesData = response is List ? response : (response['data'] ?? []);
      
      debugPrint('📥 Received ${messagesData.length} messages from API');
      
      return messagesData.map((json) => ChatMessage(
        id: json['id']?.toString() ?? '',
        senderId: json['senderId']?.toString() ?? '',
        recipientId: json['receiverId']?.toString() ?? '',
        content: json['message']?.toString() ?? '',
        timestamp: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        status: MessageStatus.sent,
      )).toList();
    } catch (e) {
      debugPrint('⚠️ API fetch failed: $e');
    }
    return [];
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

  /// Initialize and start chat with another user (using phone numbers)
  Future<void> initialize(String currentUserPhone, String otherUserPhone) async {
    _isConnecting = true;
    _error = null;
    _currentChatUserId = otherUserPhone;  // Store phone number instead of userId
    notifyListeners();

    try {
      // Initialize chat service if needed
      await _chatService.initialize();
      
      // Connect to MQTT
      await _chatService.connect();
      _isConnected = true;

      // Start chat and listen for messages (using phone numbers)
      debugPrint('💬 Starting chat with phone: $otherUserPhone');
      debugPrint('💬 Current user phone: $currentUserPhone');
      await _chatService.startChat(otherUserPhone, (message) {
        debugPrint('💬 Received message in callback: ${message.id}');
        debugPrint('   ├─ Sender (phone): ${message.senderId}');
        debugPrint('   ├─ Content: ${message.content}');
        debugPrint('   └─ Current user (phone): $currentUserPhone');
        if (!_messages.any((m) => m.id == message.id)) {
          debugPrint('💬 Adding new message to list');
          _messages.add(message);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          notifyListeners();
          
          // Mark as delivered if message is from other user
          if (message.senderId == otherUserPhone) {
            _chatService.markAsDelivered(message.id, message.senderId);
          }
        } else {
          debugPrint('💬 Message already exists, skipping');
        }
      });

      // Load message history from API first
      debugPrint('📥 Loading message history from API...');
      final apiMessages = await _fetchChatHistoryFromApi(
        senderPhone: currentUserPhone,
        receiverPhone: otherUserPhone,
      );
      debugPrint('📥 Loaded ${apiMessages.length} messages from API');
      
      // Also load from local database for offline messages
      final localHistory = _chatService.getMessageHistory(otherUserPhone);
      debugPrint('📥 Loaded ${localHistory.length} messages from local DB');
      
      // Merge and deduplicate messages
      final allMessages = <ChatMessage>[];
      final messageIds = <String>{};
      
      // Add API messages first
      for (final msg in apiMessages) {
        if (!messageIds.contains(msg.id)) {
          allMessages.add(msg);
          messageIds.add(msg.id);
        }
      }
      
      // Add local messages that aren't already in the list
      for (final msg in localHistory) {
        if (!messageIds.contains(msg.id)) {
          allMessages.add(msg);
          messageIds.add(msg.id);
        }
      }
      
      _messages.clear();
      _messages.addAll(allMessages);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      debugPrint('📥 Total messages after merge: ${_messages.length}');

      // Listen to typing indicators (using phone numbers)
      _typingSubscription?.cancel();
      _typingSubscription = _chatService.onTypingIndicator(otherUserPhone).listen((isTyping) {
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

  /// Send a text message (using phone numbers)
  Future<void> sendMessage(String content, {String? senderName, String? recipientName}) async {
    if (!_isConnected) {
      _error = 'Not connected to chat server';
      notifyListeners();
      return;
    }

    if (content.trim().isEmpty || _currentChatUserId == null) return;

    try {
      await _chatService.sendMessage(
        recipientPhone: _currentChatUserId!,  // This is now a phone number
        content: content.trim(),
        senderName: senderName,
        recipientName: recipientName,
      );
      // Message will be added via the startChat callback when echoed back
    } catch (e) {
      _error = 'Failed to send message: $e';
      notifyListeners();
    }
  }

  /// Send typing indicator (using phone numbers)
  Future<void> sendTypingIndicator(bool isTyping) async {
    if (!_isConnected || _currentChatUserId == null) return;
    
    try {
      await _chatService.sendTypingIndicator(_currentChatUserId!, isTyping);  // Phone number
    } catch (e) {
      // Silently fail - typing indicator is not critical
    }
  }

  /// Mark all messages from other user as read (using phone numbers)
  Future<void> markMessagesAsRead() async {
    if (_currentChatUserId == null) return;
    
    for (final message in _messages) {
      if (message.senderId == _currentChatUserId && message.status != MessageStatus.read) {
        await _chatService.markAsRead(message.id, message.senderId);  // senderId is now phone number
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
        otherUserPhone: '+254700000001',
        otherUserName: 'John Smith',
        otherUserRole: 'Driver',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_1',
          senderId: '+254700000001',
          recipientId: '+254700000000',
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
        otherUserPhone: '+254700000002',
        otherUserName: 'Sarah Johnson',
        otherUserRole: 'Guardian',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_2',
          senderId: '+254700000002',
          recipientId: '+254700000000',
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
        otherUserPhone: '+254700000003',
        otherUserName: 'Michael Brown',
        otherUserRole: 'Driver',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_3',
          senderId: '+254700000003',
          recipientId: '+254700000000',
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
        otherUserPhone: '+254700000004',
        otherUserName: 'Emily Davis',
        otherUserRole: 'Staff',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_4',
          senderId: '+254700000000',
          recipientId: '+254700000004',
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
        otherUserPhone: '+254700000005',
        otherUserName: 'David Wilson',
        otherUserRole: 'Guardian',
        otherUserAvatar: null,
        lastMessage: ChatMessage(
          id: 'msg_5',
          senderId: '+254700000005',
          recipientId: '+254700000000',
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
