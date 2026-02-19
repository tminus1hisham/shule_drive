import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_conversation.dart';
import '../../mqtt_client.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
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
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    _loadConversations();
    
    // Auto-connect to MQTT when chat page opens
    _connectMqtt();
    
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadConversations(silent: true);
    });
  }

  Future<void> _connectMqtt() async {
    try {
      final mqtt = MqttService();
      if (!mqtt.isConnected) {
        await mqtt.connect();

        //if(mqtt.is)
      }
    } catch (e) {
      // Silently log error - don't show to user
      print('⚠️ MQTT auto-connect failed: $e');
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
    Navigator.pushNamed(
      context,
      '/chat-detail',
      arguments: {
        'receiverPhone': conversation.otherUserPhone,  // Use phone number
        'receiverName': conversation.otherUserName,
        'receiverAvatar': conversation.otherUserAvatar,
      },
    ).then((_) => _loadConversations(silent: true));
  }

  void _navigateToNewChat() {
    Navigator.pushNamed(context, '/chat-users')
        .then((_) => _loadConversations(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDarkMode = appProvider.isDarkMode;
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;

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
            // Already on chat
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
        if (_conversations.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.edit_square,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
            onPressed: _navigateToNewChat,
          ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadConversations,
        color: const Color(0xFF6B9B5B),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: _buildBody(isDarkMode, userData),
      ),
      floatingActionButton: _conversations.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _navigateToNewChat,
              backgroundColor: const Color(0xFF6B9B5B),
              elevation: 4,
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: const Text(
                'New Chat',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(bool isDarkMode, Map<String, dynamic>? userData) {
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => _buildSkeletonItem(isDarkMode),
    );
  }

  Widget _buildSkeletonItem(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withAlpha(10) : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withAlpha(10) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withAlpha(10) : Colors.grey.shade200,
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Couldn\'t load messages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to retry',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Illustration
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6B9B5B).withAlpha(30),
                      const Color(0xFF6B9B5B).withAlpha(10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B9B5B).withAlpha(80),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                'No Messages Yet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'Start chatting with drivers, guardians, and school staff',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? Colors.white60 : const Color(0xFF666666),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // CTA Button
              SizedBox(
                width: 220,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _navigateToNewChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B9B5B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  icon: const Icon(Icons.add_comment, size: 22),
                  label: const Text(
                    'Start New Chat',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Secondary hint
              Text(
                'Find people to connect with',
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList(bool isDarkMode) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          final conversation = _conversations[index];
          return _buildConversationTile(conversation, isDarkMode, index);
        },
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
        final delay = index * 0.1;
        final value = (_animationController.value - delay).clamp(0.0, 1.0) / (1 - delay);
        
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key(conversation.id),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
        onDismissed: (_) {
          // TODO: Implement delete/archive conversation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Conversation archived'),
              action: SnackBarAction(
                label: 'UNDO',
                textColor: const Color(0xFF6B9B5B),
                onPressed: () {
                  // TODO: Restore conversation
                },
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDarkMode ? 30 : 10),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _navigateToChat(conversation),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar with online indicator
                    Stack(
                      children: [
                        _buildAvatar(conversation, isDarkMode),
                        if (conversation.isOnline)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation.otherUserName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                conversation.formattedLastActivity,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasUnread
                                      ? const Color(0xFF6B9B5B)
                                      : isDarkMode ? Colors.white38 : Colors.grey.shade400,
                                  fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conversation.lastMessagePreview,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: hasUnread
                                        ? isDarkMode ? Colors.white : const Color(0xFF1A1A1A)
                                        : isDarkMode ? Colors.white54 : const Color(0xFF666666),
                                    fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasUnread) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    conversation.unreadCount > 99
                                        ? '99+'
                                        : conversation.unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }

  Widget _buildAvatar(ChatConversation conversation, bool isDarkMode) {
    final avatarUrl = conversation.otherUserAvatar;
    // Check if it's a valid network URL
    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
        onBackgroundImageError: (e, s) {
          if (kDebugMode) print('⚠️ Failed to load avatar: $e');
        },
      );
    }

    // Generate initials avatar
    final initials = conversation.otherUserName
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    return CircleAvatar(
      radius: 28,
      backgroundColor: _getAvatarColor(conversation.otherUserName),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF6B9B5B),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFF9C27B0),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
      const Color(0xFF795548),
    ];
    return colors[name.hashCode % colors.length];
  }
}
