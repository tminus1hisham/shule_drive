import 'chat_message.dart';

/// Chat Conversation Model - Represents a conversation between users
/// NOTE: Uses phone numbers as user identifiers
class ChatConversation {
  final String id;
  /// Other user's phone number (used as chat identifier)
  final String otherUserPhone;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? otherUserRole;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? lastActivity;
  final bool isOnline;

  ChatConversation({
    required this.id,
    required this.otherUserPhone,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserRole,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastActivity,
    this.isOnline = false,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] ?? '',
      otherUserPhone: json['otherUserPhone'] ?? json['otherUserId'] ?? json['user_id'] ?? json['phone'] ?? '',
      otherUserName: json['otherUserName'] ?? json['name'] ?? 'Unknown',
      otherUserAvatar: json['otherUserAvatar'] ?? json['avatar'],
      otherUserRole: json['otherUserRole'] ?? json['role'],
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? json['unread_count'] ?? 0,
      lastActivity: json['lastActivity'] != null
          ? DateTime.parse(json['lastActivity'])
          : json['last_activity'] != null
              ? DateTime.parse(json['last_activity'])
              : null,
      isOnline: json['isOnline'] ?? json['is_online'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'otherUserPhone': otherUserPhone,
      'otherUserName': otherUserName,
      'otherUserAvatar': otherUserAvatar,
      'otherUserRole': otherUserRole,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
      'lastActivity': lastActivity?.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  /// Get formatted last activity time
  String get formattedLastActivity {
    if (lastActivity == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(lastActivity!);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${lastActivity!.day}/${lastActivity!.month}/${lastActivity!.year}';
  }

  /// Get preview of last message
  String get lastMessagePreview {
    if (lastMessage == null) return 'No messages yet';
    if (lastMessage!.content.length > 30) {
      return '${lastMessage!.content.substring(0, 30)}...';
    }
    return lastMessage!.content;
  }
}

/// Chat User Model - Represents a user available for chatting
/// NOTE: Uses phone number as the primary identifier for chat
class ChatUser {
  /// User ID (from database) - kept for reference but NOT used for chat
  final String id;
  /// Phone number - USED as the primary chat identifier (senderId/receiverId)
  final String phone;
  final String name;
  final String? avatar;
  final String? role;
  final bool isOnline;
  final DateTime? lastSeen;

  ChatUser({
    required this.id,
    required this.phone,
    required this.name,
    this.avatar,
    this.role,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    final phoneNumber = json['phoneNumber']?.toString() ?? 
                       json['phone']?.toString() ?? 
                       json['mobile']?.toString() ?? '';
    return ChatUser(
      id: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      phone: phoneNumber,
      name: json['fullname'] ?? json['fullName'] ?? json['name'] ?? json['userName'] ?? 'Unknown',
      avatar: json['avatar'] ?? json['profileImage'] ?? json['profilePicture'],
      role: json['role'] ?? json['user_role'],
      isOnline: json['isOnline'] ?? json['is_active'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : json['last_seen'] != null
              ? DateTime.parse(json['last_seen'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'avatar': avatar,
      'role': role,
      'phone': phone,
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  /// Get initials for avatar placeholder
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Get formatted last seen
  String get formattedLastSeen {
    if (isOnline) return 'Online';
    if (lastSeen == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(lastSeen!);
    
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inHours < 1) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Last seen ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Last seen yesterday';
    if (diff.inDays < 7) return 'Last seen ${diff.inDays}d ago';
    
    return 'Last seen ${lastSeen!.day}/${lastSeen!.month}/${lastSeen!.year}';
  }
}
