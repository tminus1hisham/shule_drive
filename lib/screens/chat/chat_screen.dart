import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_message.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/trip_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

class ChatScreen extends StatefulWidget {
  final String? receiverPhone; // Phone number of the receiver (used as chat ID)
  final String? receiverName;
  final String? receiverAvatar;
  final String? receiverRole;
  final String? tripId;
  final bool isTripChat;

  /// Guardians a `trip_…` group chat delivers to.
  final List<String>? memberPhones;

  const ChatScreen({
    super.key,
    this.receiverPhone,
    this.receiverName,
    this.receiverAvatar,
    this.receiverRole,
    this.tripId,
    this.isTripChat = false,
    this.memberPhones,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isInitializing = true;
  String? _initError;
  bool _showScrollToBottom = false;
  bool _isTripActive = false;
  bool _isLoadingTripStatus = true;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Listen to text changes to update send button state
    _messageController.addListener(_onTextChanged);
    // Defer initialization until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeChat());
    // Check trip status if this is a trip-based chat
    if (widget.isTripChat && widget.tripId != null) {
      _checkTripStatus();
    } else {
      setState(() => _isLoadingTripStatus = false);
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  Future<void> _checkTripStatus() async {
    try {
      final tripProvider = context.read<TripProvider>();
      // Get fresh trip data
      await tripProvider.fetchActiveTrip();

      // Check if the trip is still active
      final activeTrip = tripProvider.activeTrip;
      if (activeTrip != null && activeTrip.id == widget.tripId) {
        setState(() => _isTripActive = true);
      } else {
        // Check if trip exists but is completed
        final allTrips = tripProvider.trips;
        try {
          final trip = allTrips.firstWhere((t) => t.id == widget.tripId);
          setState(() => _isTripActive = trip.status == 'active');
        } catch (e) {
          // Trip not found in list
          setState(() => _isTripActive = false);
        }
      }
    } catch (e) {
      // If we can't determine trip status, default to read-only
      setState(() => _isTripActive = false);
    } finally {
      setState(() => _isLoadingTripStatus = false);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final showButton = maxScroll - currentScroll > 200;

      if (showButton != _showScrollToBottom) {
        setState(() => _showScrollToBottom = showButton);
      }
    }
  }

  Future<void> _initializeChat() async {
    if (widget.receiverPhone == null) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = 'Invalid user selected';
        });
      }
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      // Get current user's phone number for chat
      final currentUserPhone = authProvider.userPhone;

      if (currentUserPhone == null) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _initError = 'Not authenticated';
          });
        }
        return;
      }

      final chatProvider = context.read<ChatProvider>();
      // Initialize chat using phone numbers
      await chatProvider.initialize(
        currentUserPhone,
        widget.receiverPhone!,
        memberPhones: widget.memberPhones,
      );

      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = 'Failed to connect: $e';
        });
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      // Scroll to end to show newest messages
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  Future<void> _sendMessage() async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // Clear text and update UI immediately
    _messageController.clear();
    setState(() => _hasText = false);

    HapticFeedback.lightImpact();

    // Send message
    await chatProvider.sendMessage(
      content,
      senderName: authProvider.userName ?? 'Unknown',
      recipientName: widget.receiverName ?? 'Unknown',
    );

    // Scroll to bottom to show new message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: true);
    });
  }

  late final ChatProvider _chatProvider = context.read<ChatProvider>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider; // resolve while the context is still active
  }

  @override
  void dispose() {
    _chatProvider.leaveChat();
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Messages below this index were already there when the chat opened, so
  /// they render still; only ones arriving afterwards animate in.
  int? _animateFrom;
  int _lastMessageCount = 0;

  /// Keeps the view pinned to the newest message: on first load, and when a
  /// message arrives while the user is already at (or near) the bottom.
  void _followNewMessages(int count) {
    if (count == _lastMessageCount) return;
    final firstLoad = _lastMessageCount == 0;
    _lastMessageCount = count;
    _animateFrom ??= count;
    if (!firstLoad && _showScrollToBottom) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(animated: !firstLoad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiverName = widget.receiverName ?? 'Chat';
    final bool isReadOnly =
        widget.isTripChat && !_isTripActive && !_isLoadingTripStatus;

    if (_isInitializing) {
      return MainScaffold(
        title: receiverName,
        showBackButton: true,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: context.colors.brand),
              AppSpacing.vMd,
              Text(
                'Connecting...',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_initError != null) {
      return MainScaffold(
        title: receiverName,
        showBackButton: true,
        body: EmptyState.error(
          title: 'Connection Failed',
          message: _initError,
          onRetry: () {
            setState(() {
              _isInitializing = true;
              _initError = null;
            });
            _initializeChat();
          },
        ),
      );
    }

    return MainScaffold(
      titleWidget: _buildAppBarTitle(receiverName),
      showBackButton: true,
      actions: [_buildVoiceCallButton()],
      body: Stack(
        children: [
          // Themed wallpaper
          Positioned.fill(
            child: Image.asset(
              context.isDark ? 'assets/dark_chat_bg.jpg' : 'assets/chat_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const AppBackdrop(),
            ),
          ),
          Column(
            children: [
              _buildErrorBanner(),
              if (widget.isTripChat) _buildTripStatusBanner(),
              Expanded(child: _buildMessagesList()),
              AnimatedSwitcher(
                duration: AppDuration.medium,
                child: isReadOnly
                    ? _buildReadOnlyBanner()
                    : _buildMessageInput(),
              ),
            ],
          ),
          Positioned(
            right: AppSpacing.md,
            bottom: isReadOnly ? 20 : 100,
            child: AnimatedScale(
              scale: _showScrollToBottom ? 1 : 0,
              duration: AppDuration.medium,
              curve: _showScrollToBottom
                  ? Curves.easeOutBack
                  : AppCurves.easeOut,
              child: _buildScrollToBottomButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatusBanner() {
    final c = context.colors;
    return AnimatedSize(
      duration: AppDuration.medium,
      curve: AppCurves.easeOut,
      child: _isLoadingTripStatus
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.brand,
                  ),
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                0,
              ),
              child: GlassPanel(
                tint: _isTripActive ? c.success : c.warning,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Icon(
                      _isTripActive
                          ? Icons.directions_bus_rounded
                          : Icons.history_rounded,
                      size: 18,
                      color: _isTripActive ? c.success : c.warning,
                    ),
                    AppSpacing.hXs,
                    Expanded(
                      child: Text(
                        _isTripActive
                            ? 'Trip active - Chat enabled'
                            : 'Trip ended - Chat read-only',
                        style: context.text.labelLarge,
                      ),
                    ),
                    if (_isTripActive)
                      StatusPill(
                        label: 'LIVE',
                        color: c.success,
                        pulse: true,
                        dense: true,
                      ),
                  ],
                ),
              ).enter(offsetY: -12),
            ),
    );
  }

  Widget _buildReadOnlyBanner() {
    final c = context.colors;
    return Container(
      key: const ValueKey('read-only'),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: c.textMuted),
            AppSpacing.hXs,
            Text(
              'This chat is archived',
              style: context.text.bodySmall?.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return Consumer2<ChatProvider, AuthProvider>(
      builder: (context, chatProvider, authProvider, child) {
        final messages = chatProvider.messages;
        final currentUserPhone = authProvider.userPhone ?? '';
        _followNewMessages(messages.length);

        if (messages.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            message: 'Say hello to start the conversation',
            compact: true,
          );
        }

        // Oldest first (top), newest last (bottom)
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == currentUserPhone;
            final showDate =
                index == 0 ||
                !_isSameDay(messages[index - 1].timestamp, message.timestamp);
            final bubble = _buildMessageBubble(message, isMe);
            final isNew = index >= (_animateFrom ?? messages.length);

            return Column(
              children: [
                if (showDate) _buildDateSeparator(message.timestamp),
                isNew
                    // A new bubble grows from its tail corner.
                    ? bubble.pop(
                        origin: isMe
                            ? Alignment.bottomRight
                            : Alignment.bottomLeft,
                      )
                    : bubble,
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final c = context.colors;
    final fg = isMe ? Colors.white : context.scheme.onSurface;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(
          bottom: AppSpacing.xs,
          left: AppSpacing.md,
          right: AppSpacing.md,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isMe ? c.brandGradient : null,
          color: isMe ? null : context.scheme.surface,
          border: isMe ? null : Border.all(color: c.outline),
          boxShadow: c.shadowSm,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: context.text.bodyLarge?.copyWith(color: fg, height: 1.3),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: context.text.labelSmall?.copyWith(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.75)
                        : c.textMuted,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  AnimatedSwitcher(
                    duration: AppDuration.medium,
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: KeyedSubtree(
                      key: ValueKey(message.status),
                      child: _buildStatusIcon(message.status),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        );
      case MessageStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 14,
          color: Color(0xFFFECACA),
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: 0.95),
        );
      default:
        return Icon(
          Icons.done_rounded,
          size: 14,
          color: Colors.white.withValues(alpha: 0.65),
        );
    }
  }

  Widget _buildMessageInput() {
    final c = context.colors;
    return Container(
      key: const ValueKey('input'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: context.text.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Message about the trip...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.brXl,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.brXl,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.brXl,
                    borderSide: BorderSide(color: c.brand, width: 1.5),
                  ),
                  filled: true,
                  fillColor: c.surfaceSubtle,
                ),
                maxLines: 6,
                minLines: 1,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            AppSpacing.hXs,
            // Send lights up (brand gradient + scale) once there's text.
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final canSend = chatProvider.isConnected && _hasText;
                return AnimatedScale(
                  scale: canSend ? 1 : 0.85,
                  duration: AppDuration.medium,
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: AppDuration.medium,
                    decoration: BoxDecoration(
                      gradient: canSend ? c.brandGradient : null,
                      color: canSend ? null : c.surfaceSubtle,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: canSend ? _sendMessage : null,
                      tooltip: 'Send',
                      icon: Icon(
                        Icons.arrow_upward_rounded,
                        color: canSend ? Colors.white : c.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: GlassPanel(
          borderRadius: AppRadius.brPill,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: Text(
            _formatDate(date),
            style: context.text.labelMedium?.copyWith(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final c = context.colors;
        return AnimatedSize(
          duration: AppDuration.medium,
          curve: AppCurves.easeOut,
          child: chatProvider.error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    0,
                  ),
                  child: GlassPanel(
                    tint: c.error,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: c.error,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            chatProvider.error!,
                            style: context.text.bodySmall?.copyWith(
                              color: c.error,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: chatProvider.clearError,
                          tooltip: 'Dismiss',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            Icons.close_rounded,
                            color: c.error,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildScrollToBottomButton() {
    return Material(
      color: context.scheme.surface,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black26,
      child: IconButton(
        onPressed: _scrollToBottom,
        tooltip: 'Jump to latest',
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: context.colors.brand,
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    if (now.difference(date).inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Widget _buildAppBarTitle(String receiverName) {
    final role = widget.receiverRole;
    final roleText = role != null && role.isNotEmpty
        ? role.toLowerCase() == 'driver'
              ? 'Driver'
              : role.toLowerCase() == 'guardian'
              ? 'Guardian'
              : role
        : 'User';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(
          name: receiverName,
          imageUrl: widget.receiverAvatar,
          size: 36,
        ),
        AppSpacing.hSm,
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                receiverName,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                roleText,
                style: context.text.labelSmall?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceCallButton() {
    return IconButton(
      tooltip: 'Call',
      icon: Icon(Icons.phone_rounded, color: context.colors.brand),
      onPressed: () async {
        final phoneNumber = widget.receiverPhone;
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
          try {
            await launchUrl(launchUri, mode: LaunchMode.externalApplication);
          } catch (e) {
            debugPrint('Could not launch phone dialer: $e');
          }
        }
      },
    );
  }
}
