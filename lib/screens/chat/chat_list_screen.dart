import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_conversation.dart';
import '../../mqtt_client.dart';
import '../../providers/app_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/main_scaffold.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  String? _error;
  List<ChatConversation> _conversations = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    _loadConversations();
    _connectMqtt();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadConversations(silent: true);
    });
  }

  Future<void> _connectMqtt() async {
    try {
      final mqtt = MqttService();
      if (!mqtt.isConnected) {
        await mqtt.connect();
      }
    } catch (e) {
      debugPrint('MQTT auto-connect failed: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    
    try {
      final chatProvider = context.read<ChatProvider>();
      final conversations = await chatProvider.getConversations();
      
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
          _error = null;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load conversations';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToChat(ChatConversation conversation) {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      '/chat-detail',
      arguments: {
        'receiverPhone': conversation.otherUserPhone,
        'receiverName': conversation.otherUserName,
        'receiverAvatar': conversation.otherUserAvatar,
        'receiverRole': conversation.otherUserRole,
      },
    ).then((_) => _loadConversations(silent: true));
  }

  void _navigateToNewChat() {
    HapticFeedback.lightImpact();
    Navigator.pushNamed(context, '/chat-users')
        .then((_) => _loadConversations(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDarkMode = appProvider.isDarkMode;

    return MainScaffold(
      title: 'Messages',
      showBackButton: false,
      showBottomNav: true,
      bottomNavIndex: 1,
      onBottomNavTap: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/dashboard');
            break;
          case 1:
            break;
          case 2:
            Navigator.pushNamed(context, '/notifications');
            break;
          case 3:
            Navigator.pushNamed(context, '/profile');
            break;
          case 4:
            Navigator.pushNamed(context, '/start-trip');
            break;
        }
      },
      actions: [
        if (!_isLoading && _conversations.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.edit_square,
              color: isDarkMode ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
            ),
            onPressed: _navigateToNewChat,
          ),
      ],
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return _buildLoadingState(isDarkMode);
    }

    if (_error != null) {
      return _buildErrorState(isDarkMode);
    }

    if (_conversations.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return _buildConversationsList(isDarkMode);
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 10,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 80,
        color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
      ),
      itemBuilder: (context, index) => _buildSkeletonItem(isDarkMode),
    );
  }

  Widget _buildSkeletonItem(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 180,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFFC7C7CC),
          ),
          const SizedBox(height: 12),
          Text(
            'Couldn\'t load messages',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadConversations,
            child: Text(
              'Try Again',
              style: TextStyle(
                color: isDarkMode ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 28,
                color: isDarkMode ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Messages Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a conversation with drivers or guardians',
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _navigateToNewChat,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('New Message'),
              style: TextButton.styleFrom(
                foregroundColor: isDarkMode ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadConversations,
        color: isDarkMode ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Search bar
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: _navigateToNewChat,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 18,
                        color: isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Search Messages',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Conversations list
            SliverList.separated(
              itemCount: _conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 80,
                color: isDarkMode ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
              ),
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                return _buildConversationTile(conversation, isDarkMode, index);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    ChatConversation conversation,
    bool isDarkMode,
    int index,
  ) {
    final hasUnread = conversation.unreadCount > 0;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.03;
        final value = (_animationController.value - delay).clamp(0.0, 1.0) / (1 - delay);
        
        return Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToChat(conversation),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                _buildAvatar(conversation, isDarkMode),
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name and time row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.otherUserName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                                color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(conversation.lastActivity),
                            style: TextStyle(
                              fontSize: 13,
                              color: hasUnread
                                  ? isDarkMode ? const Color(0xFF0A84FF) : const Color(0xFF007AFF)
                                  : isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Message preview row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessagePreview,
                              style: TextStyle(
                                fontSize: 15,
                                color: hasUnread
                                    ? isDarkMode ? Colors.white : const Color(0xFF1C1C1E)
                                    : isDarkMode ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Unread badge
                          if (hasUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              constraints: const BoxConstraints(minWidth: 18),
                              alignment: Alignment.center,
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : conversation.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ChatConversation conversation, bool isDarkMode) {
    final avatarUrl = conversation.otherUserAvatar;
    final hasValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));
    
    final initials = conversation.otherUserName
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: hasValidUrl ? NetworkImage(avatarUrl) : null,
            backgroundColor: _getAvatarColor(conversation.otherUserName),
            onBackgroundImageError: hasValidUrl ? (e, s) {
              if (kDebugMode) debugPrint('Failed to load avatar: $e');
            } : null,
            child: !hasValidUrl
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
          ),
          // Online indicator
          if (conversation.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDay == today) {
      return DateFormat('h:mm a').format(dateTime).toLowerCase();
    } else if (today.difference(messageDay).inDays == 1) {
      return 'Yesterday';
    } else if (today.difference(messageDay).inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('M/d/yy').format(dateTime);
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFFFF2D55),
      const Color(0xFF5856D6),
      const Color(0xFF5AC8FA),
      const Color(0xFFFF3B30),
      const Color(0xFFAF52DE),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }
}
