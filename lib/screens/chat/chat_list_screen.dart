import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_conversation.dart';
import '../../mqtt_client.dart';

import '../../providers/chat_provider.dart';
import '../../widgets/main_scaffold.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _isLoading = true;
  String? _error;
  List<ChatConversation> _conversations = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

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
    Navigator.pushNamed(
      context,
      '/chat-users',
    ).then((_) => _loadConversations(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MainScaffold(
      title: 'Messages',
      showBackButton: false,
      showBottomNav: true,
      bottomNavIndex: 1,
      actions: [
        if (!_isLoading && _conversations.isNotEmpty)
          IconButton(
            icon: Icon(Icons.edit_square, color: c.brand),
            tooltip: 'New message',
            onPressed: _navigateToNewChat,
          ).pop(),
      ],
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          AsyncBody(
            loading: _isLoading,
            error: _error,
            onRetry: _loadConversations,
            isEmpty: _conversations.isEmpty,
            empty: EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No Messages Yet',
              message: 'Start a conversation with drivers or guardians',
              actionLabel: 'New Message',
              onAction: _navigateToNewChat,
            ),
            onRefresh: _loadConversations,
            child: _buildConversationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    final c = context.colors;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Search bar (opens the new-chat picker)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: AppCard(
              onTap: _navigateToNewChat,
              color: c.surfaceSubtle,
              shadow: const [],
              border: Border.all(color: c.outline),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: c.textMuted),
                  AppSpacing.hXs,
                  Text(
                    'Search Messages',
                    style: context.text.bodyLarge?.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ).enter(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          sliver: SliverList.separated(
            itemCount: _conversations.length,
            separatorBuilder: (_, _) => AppSpacing.vXs,
            itemBuilder: (context, index) {
              final conversation = _conversations[index];
              // Keyed by conversation, so a chat arriving via the 30s poll
              // animates in while existing rows stay put.
              return KeyedSubtree(
                key: ValueKey(conversation.id),
                child: _buildConversationTile(conversation).enterList(index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConversationTile(ChatConversation conversation) {
    final c = context.colors;
    final hasUnread = conversation.unreadCount > 0;
    final avatarUrl = conversation.otherUserAvatar;
    final hasValidUrl =
        avatarUrl != null &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    return AppCard(
      onTap: () => _navigateToChat(conversation),
      shadow: hasUnread ? c.shadowSm : const [],
      color: hasUnread
          ? Color.alphaBlend(
              c.brand.withValues(alpha: 0.05),
              context.scheme.surface,
            )
          : context.scheme.surface,
      border: Border.all(
        color: hasUnread ? c.brand.withValues(alpha: 0.25) : c.outline,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(
                imageUrl: hasValidUrl ? avatarUrl : null,
                name: conversation.otherUserName,
                size: 52,
              ),
              if (conversation.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: c.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.scheme.surface,
                        width: 2,
                      ),
                    ),
                  ).pop(),
                ),
            ],
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.otherUserName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: hasUnread
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    AppSpacing.hXs,
                    Text(
                      _formatTime(conversation.lastActivity),
                      style: context.text.labelSmall?.copyWith(
                        color: hasUnread ? c.brand : c.textMuted,
                        fontWeight: hasUnread ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.lastMessagePreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(
                          color: hasUnread
                              ? context.scheme.onSurface
                              : c.textSecondary,
                        ),
                      ),
                    ),
                    // Unread count springs in and re-pops when it changes.
                    AnimatedScale(
                      scale: hasUnread ? 1 : 0,
                      duration: AppDuration.medium,
                      curve: Curves.easeOutBack,
                      child: AnimatedSwitcher(
                        duration: AppDuration.medium,
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Container(
                          key: ValueKey(conversation.unreadCount),
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          constraints: const BoxConstraints(minWidth: 20),
                          decoration: BoxDecoration(
                            gradient: c.brandGradient,
                            borderRadius: AppRadius.brPill,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : conversation.unreadCount.toString(),
                            style: context.text.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
}
