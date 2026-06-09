import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_message.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/main_scaffold.dart';

class ChatScreen extends StatefulWidget {
  final String? receiverPhone; // Phone number of the receiver (used as chat ID)
  final String? receiverName;
  final String? receiverAvatar;
  final String? receiverRole;
  final String? tripId;
  final bool isTripChat;

  const ChatScreen({
    super.key,
    this.receiverPhone,
    this.receiverName,
    this.receiverAvatar,
    this.receiverRole,
    this.tripId,
    this.isTripChat = false,
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
      await chatProvider.initialize(currentUserPhone, widget.receiverPhone!);

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

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isDarkMode = appProvider.isDarkMode;
    final receiverName = widget.receiverName ?? 'Chat';
    final bool isReadOnly =
        widget.isTripChat && !_isTripActive && !_isLoadingTripStatus;

    if (_isInitializing) {
      return _buildLoadingScreen(isDarkMode);
    }

    if (_initError != null) {
      return _buildErrorScreen(isDarkMode, receiverName);
    }

    return MainScaffold(
      titleWidget: _buildAppBarTitle(receiverName, isDarkMode),
      showBackButton: true,
      actions: [_buildVoiceCallButton(isDarkMode)],
      body: Stack(
        children: [
          // Original themed background
          Positioned.fill(
            child: Image.asset(
              isDarkMode ? 'assets/dark_chat_bg.jpg' : 'assets/chat_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: isDarkMode
                    ? const Color(0xFF121212)
                    : const Color(0xFFE8E8E8),
              ),
            ),
          ),
          Column(
            children: [
              _buildErrorBanner(),
              // Trip status banner
              if (widget.isTripChat)
                _buildTripStatusBanner(isDarkMode, isReadOnly),
              Expanded(child: _buildMessagesList(isDarkMode)),
              if (isReadOnly)
                _buildReadOnlyBanner(isDarkMode)
              else
                _buildMessageInput(isDarkMode),
            ],
          ),
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: isReadOnly ? 20 : 100,
              child: _buildScrollToBottomButton(isDarkMode),
            ),
        ],
      ),
    );
  }

  Widget _buildTripStatusBanner(bool isDarkMode, bool isReadOnly) {
    if (_isLoadingTripStatus) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: _isTripActive
            ? const Color(0xFFF0FFF4)
            : const Color(0xFFFEF3C7),
        border: Border(
          bottom: BorderSide(
            color: _isTripActive
                ? const Color(0xFF86EFAC)
                : const Color(0xFFFCD34D),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isTripActive ? Icons.circle : Icons.history,
            size: 10,
            color: _isTripActive
                ? const Color(0xFF22C55E)
                : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isTripActive
                  ? 'Trip active - Chat enabled'
                  : 'Trip ended - Chat read-only',
              style: TextStyle(
                fontSize: 13,
                color: _isTripActive
                    ? const Color(0xFF166534)
                    : const Color(0xFF92400E),
              ),
            ),
          ),
          if (_isTripActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFE5E5EA),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 16,
              color: isDarkMode
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF8E8E93),
            ),
            const SizedBox(width: 8),
            Text(
              'This chat is archived',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF8E8E93),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(bool isDarkMode) {
    return Consumer2<ChatProvider, AuthProvider>(
      builder: (context, chatProvider, authProvider, child) {
        final messages = chatProvider.messages;
        final currentUserPhone = authProvider.userPhone ?? '';

        debugPrint('🔨 Building message list with ${messages.length} messages');

        if (messages.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        // Standard ListView: oldest first (top), newest last (bottom)
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == currentUserPhone;
            final showDate =
                index == 0 ||
                !_isSameDay(messages[index - 1].timestamp, message.timestamp);

            return Column(
              children: [
                if (showDate)
                  _buildDateSeparator(message.timestamp, isDarkMode),
                _buildMessageBubble(message, isMe, isDarkMode),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool isDarkMode) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF007AFF) // iOS blue - professional
              : isDarkMode
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFF2F2F7), // iOS light gray
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
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : isDarkMode
                    ? Colors.white
                    : const Color(0xFF1C1C1E),
                fontSize: 16,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(message.timestamp),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : isDarkMode
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF8E8E93),
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(message.status),
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
        return Icon(Icons.error_outline, size: 14, color: Colors.red.shade200);
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white.withValues(alpha: 0.9),
        );
      default:
        return Icon(
          Icons.done,
          size: 14,
          color: Colors.white.withValues(alpha: 0.6),
        );
    }
  }

  Widget _buildMessageInput(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(
            color: isDarkMode
                ? const Color(0xFF2C2C2E)
                : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field - Shule Drive style
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message about the trip...',
                    hintStyle: TextStyle(
                      color: isDarkMode
                          ? const Color(0xFF8E8E93)
                          : const Color(0xFF8E8E93),
                      fontSize: 16,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: InputBorder.none,
                  ),
                  maxLines: 6,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Send button - clean
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final canSend = chatProvider.isConnected && _hasText;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: canSend ? _sendMessage : null,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        Icons.arrow_upward,
                        color: canSend
                            ? const Color(0xFF007AFF)
                            : isDarkMode
                            ? const Color(0xFF3A3A3C)
                            : const Color(0xFFBDBDBD),
                        size: 24,
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

  Widget _buildDateSeparator(DateTime date, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatDate(date),
          style: TextStyle(
            color: isDarkMode
                ? const Color(0xFF8E8E93)
                : const Color(0xFF8E8E93),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: isDarkMode
                ? const Color(0xFF3A3A3C)
                : const Color(0xFFC7C7CC),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFF8E8E93)
                  : const Color(0xFF8E8E93),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
              ),
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting...',
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF8E8E93),
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(bool isDarkMode, String receiverName) {
    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: isDarkMode
            ? const Color(0xFF1C1C1E)
            : const Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode
                ? const Color(0xFF0A84FF)
                : const Color(0xFF007AFF),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          receiverName,
          style: TextStyle(
            color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: const Color(0xFFFF3B30),
              ),
              const SizedBox(height: 16),
              Text(
                'Connection Failed',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _initError!,
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFF8E8E93)
                      : const Color(0xFF8E8E93),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                onPressed: () {
                  setState(() {
                    _isInitializing = true;
                    _initError = null;
                  });
                  _initializeChat();
                },
                child: Text(
                  'Try Again',
                  style: TextStyle(
                    color: isDarkMode
                        ? const Color(0xFF0A84FF)
                        : const Color(0xFF007AFF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        if (chatProvider.error == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFFF3B30),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chatProvider.error!,
                  style: const TextStyle(
                    color: Color(0xFFFF3B30),
                    fontSize: 13,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => chatProvider.clearError(),
                child: const Icon(
                  Icons.close,
                  color: Color(0xFFFF3B30),
                  size: 18,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollToBottomButton(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _scrollToBottom(),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: isDarkMode
                  ? const Color(0xFF0A84FF)
                  : const Color(0xFF007AFF),
              size: 24,
            ),
          ),
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
    if (_isSameDay(date, now.subtract(const Duration(days: 1))))
      return 'Yesterday';
    if (now.difference(date).inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // Professional AppBar widgets
  Widget _buildAppBarTitle(String receiverName, bool isDarkMode) {
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
        // Clean avatar
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF3A3A3C)
                : const Color(0xFF007AFF),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              receiverName.isNotEmpty ? receiverName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Name and role
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              receiverName,
              style: TextStyle(
                color: isDarkMode ? Colors.white : const Color(0xFF1C1C1E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              roleText,
              style: TextStyle(
                color: isDarkMode
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF8E8E93),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceCallButton(bool isDarkMode) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
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
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            Icons.phone,
            color: isDarkMode
                ? const Color(0xFF0A84FF)
                : const Color(0xFF007AFF),
            size: 22,
          ),
        ),
      ),
    );
  }
}
