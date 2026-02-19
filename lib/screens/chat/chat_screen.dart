import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/main_scaffold.dart';

class ChatScreen extends StatefulWidget {
  final String? receiverPhone;  // Phone number of the receiver (used as chat ID)
  final String? receiverName;
  final String? receiverAvatar;
  final String? tripId;
  final bool isTripChat;

  const ChatScreen({
    super.key,
    this.receiverPhone,
    this.receiverName,
    this.receiverAvatar,
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Defer initialization until after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeChat());
    // Check trip status if this is a trip-based chat
    if (widget.isTripChat && widget.tripId != null) {
      _checkTripStatus();
    } else {
      setState(() => _isLoadingTripStatus = false);
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
          final trip = allTrips.firstWhere(
            (t) => t.id == widget.tripId,
          );
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

    _messageController.clear();
    HapticFeedback.lightImpact();
    
    // Pass sender and recipient names for MQTT message format
    await chatProvider.sendMessage(
      content,
      senderName: authProvider.userName ?? 'Unknown',
      recipientName: widget.receiverName ?? 'Unknown',
    );
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isDarkMode = appProvider.isDarkMode;
    final receiverName = widget.receiverName ?? 'Chat';
    final bool isReadOnly = widget.isTripChat && !_isTripActive && !_isLoadingTripStatus;

    if (_isInitializing) {
      return _buildLoadingScreen(isDarkMode);
    }

    if (_initError != null) {
      return _buildErrorScreen(isDarkMode, receiverName);
    }

    return MainScaffold(
      title: receiverName,
      showBackButton: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              isDarkMode ? 'assets/dark_chat_bg.jpg' : 'assets/chat_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFE8E8E8),
              ),
            ),
          ),
          Column(
            children: [
              _buildErrorBanner(),
              // Trip status banner
              if (widget.isTripChat) _buildTripStatusBanner(isDarkMode, isReadOnly),
              Expanded(
                child: _buildMessagesList(isDarkMode),
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _isTripActive
            ? Colors.green.withAlpha(30)
            : Colors.orange.withAlpha(30),
        border: Border(
          bottom: BorderSide(
            color: _isTripActive
                ? Colors.green.withAlpha(50)
                : Colors.orange.withAlpha(50),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isTripActive ? Icons.circle : Icons.history,
            size: 12,
            color: _isTripActive ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isTripActive
                  ? 'Trip is active - Chat is enabled'
                  : 'Trip has ended - Chat history is read-only',
              style: TextStyle(
                fontSize: 13,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          if (_isTripActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 18,
              color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              'This chat is archived and read-only',
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                fontSize: 14,
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
        // Use phone number for comparison since that's what we use as senderId
        final currentUserPhone = authProvider.userPhone ?? '';

        if (messages.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_showScrollToBottom) {
            _scrollToBottom(animated: false);
          }
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            // Compare using phone numbers
            final isMe = message.senderId == currentUserPhone;
            final showDate = index == 0 || !_isSameDay(messages[index - 1].timestamp, message.timestamp);

            return Column(
              children: [
                if (showDate) _buildDateSeparator(message.timestamp, isDarkMode),
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
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(
                  colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isMe
              ? null
              : isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: isMe
                  ? const Color(0xFF6B9B5B).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : isDarkMode ? Colors.white.withValues(alpha: 0.95) : const Color(0xFF1A1A1A),
                fontSize: 15,
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
                        ? Colors.white.withValues(alpha: 0.75)
                        : isDarkMode
                            ? Colors.white.withValues(alpha: 0.54)
                            : const Color(0xFF666666),
                    fontSize: 10,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1E1E1E).withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.add_circle_outline, color: isDarkMode ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF666666)),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A), fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: isDarkMode ? Colors.white.withValues(alpha: 0.38) : Colors.grey.shade500, fontSize: 15),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(Icons.emoji_emotions_outlined, color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade500),
                      onPressed: () {},
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                final canSend = chatProvider.isConnected && _messageController.text.trim().isNotEmpty;
                return Material(
                  color: canSend ? const Color(0xFF6B9B5B) : isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: canSend ? _sendMessage : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(Icons.send_rounded, color: canSend ? Colors.white : isDarkMode ? Colors.white.withValues(alpha: 0.3) : Colors.grey.shade400, size: 20),
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
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, isDarkMode ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.12)],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                color: isDarkMode ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF666666),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [isDarkMode ? Colors.white.withValues(alpha: 0.24) : Colors.black.withValues(alpha: 0.12), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withValues(alpha: 0.05) : const Color(0xFF6B9B5B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: isDarkMode ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF6B9B5B),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No messages yet',
            style: TextStyle(
              color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF666666),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation by sending a message!',
            style: TextStyle(
              color: isDarkMode ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF999999),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDarkMode) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(isDarkMode ? 'assets/dark_chat_bg.jpg' : 'assets/chat_bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Connecting to chat...',
                style: TextStyle(
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF666666),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(bool isDarkMode, String receiverName) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(receiverName, style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A))),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              Text(
                'Connection Failed',
                style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A), fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                _initError!,
                style: TextStyle(color: isDarkMode ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF666666)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isInitializing = true;
                    _initError = null;
                  });
                  _initializeChat();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
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
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(chatProvider.error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              GestureDetector(
                onTap: () => chatProvider.clearError(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollToBottomButton(bool isDarkMode) {
    return Material(
      color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _scrollToBottom(),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(Icons.keyboard_arrow_down_rounded, color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF6B9B5B)),
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
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) return 'Yesterday';
    if (now.difference(date).inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMMM d, yyyy').format(date);
  }
}
