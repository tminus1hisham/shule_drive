class ChatMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final DateTime timestamp;
  MessageStatus status;
  final String? replyToMessageId;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.replyToMessageId,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'replyToMessageId': replyToMessageId,
      'metadata': metadata,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      recipientId: json['recipientId'] ?? json['recipient_id'] ?? json['receiverId'] ?? '',
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      status: MessageStatus.values.firstWhere(
        (s) => s.name == (json['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      replyToMessageId: json['replyToMessageId'] ?? json['reply_to_message_id'],
      metadata: json['metadata'],
    );
  }

  bool get isMe => senderId == recipientId;
  bool get isRead => status == MessageStatus.read;
}

enum MessageStatus {
  sent,
  delivered,
  read,
  failed,
}

/// Chat Conversation Model
class ChatConversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? lastActivity;

  ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastActivity,
  });
}
