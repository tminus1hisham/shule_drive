import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic>? actionData;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.type = NotificationType.general,
    this.isRead = false,
    this.actionRoute,
    this.actionData,
  });

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}

enum NotificationType {
  trip,
  message,
  alert,
  general,
  payment,
  child,
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<NotificationItem> _notifications = [];
  
  List<NotificationItem> get filteredNotifications {
    if (_tabController.index == 0) return _notifications;
    if (_tabController.index == 1) {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications.where((n) => n.type == NotificationType.trip).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));
    
    // Mock data for demonstration
    final mockNotifications = [
      NotificationItem(
        id: '1',
        title: 'Trip Started',
        message: 'Your child\'s bus has started the morning route.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        type: NotificationType.trip,
        isRead: false,
        actionRoute: '/trips',
      ),
      NotificationItem(
        id: '2',
        title: 'New Message',
        message: 'Driver John sent you a message about today\'s pickup.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: NotificationType.message,
        isRead: false,
        actionRoute: '/chat',
      ),
      NotificationItem(
        id: '3',
        title: 'Child Picked Up',
        message: 'Mary has been safely picked up by the bus.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        type: NotificationType.child,
        isRead: true,
      ),
      NotificationItem(
        id: '4',
        title: 'Payment Reminder',
        message: 'Your monthly transportation fee is due in 3 days.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: NotificationType.payment,
        isRead: true,
      ),
      NotificationItem(
        id: '5',
        title: 'Route Change',
        message: 'There is a temporary route change due to road construction.',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        type: NotificationType.alert,
        isRead: true,
      ),
      NotificationItem(
        id: '6',
        title: 'Trip Completed',
        message: 'The afternoon trip has been completed successfully.',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        type: NotificationType.trip,
        isRead: true,
      ),
    ];
    
    if (mounted) {
      setState(() {
        _notifications = mockNotifications;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = NotificationItem(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          timestamp: _notifications[index].timestamp,
          type: _notifications[index].type,
          isRead: true,
          actionRoute: _notifications[index].actionRoute,
          actionData: _notifications[index].actionData,
        );
      }
    });
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _notifications = _notifications.map((n) => NotificationItem(
        id: n.id,
        title: n.title,
        message: n.message,
        timestamp: n.timestamp,
        type: n.type,
        isRead: true,
        actionRoute: n.actionRoute,
        actionData: n.actionData,
      )).toList();
    });
  }

  Future<void> _deleteNotification(String id) async {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  void _handleNotificationTap(NotificationItem notification) {
    _markAsRead(notification.id);
    
    if (notification.actionRoute != null) {
      Navigator.pushNamed(context, notification.actionRoute!);
    }
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    return MainScaffold(
      title: 'Notifications',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 2,
      onBottomNavTap: (index) {
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/landing');
        } else if (index == 1) {
          Navigator.pushNamed(context, '/chat');
        } else if (index == 3) {
          Navigator.pushNamed(context, '/profile');
        }
      },
      actions: [
        if (_unreadCount > 0)
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: Color(0xFF6B9B5B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6B9B5B),
              unselectedLabelColor: isDarkMode ? Colors.white60 : Colors.grey,
              indicatorColor: const Color(0xFF6B9B5B),
              tabs: [
                const Tab(text: 'All'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Unread'),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B9B5B),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Tab(text: 'Trips'),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState(isDarkMode)
                : filteredNotifications.isEmpty
                    ? _buildEmptyState(isDarkMode)
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        color: const Color(0xFF6B9B5B),
                        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filteredNotifications.length,
                          itemBuilder: (context, index) {
                            final notification = filteredNotifications[index];
                            return _buildNotificationTile(notification, isDarkMode);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
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
            width: 48,
            height: 48,
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
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withAlpha(10) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
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

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withAlpha(10)
                    : const Color(0xFF6B9B5B).withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 48,
                color: isDarkMode ? Colors.white38 : const Color(0xFF6B9B5B),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _tabController.index == 1
                  ? 'No unread notifications'
                  : 'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tabController.index == 1
                  ? 'You\'re all caught up!'
                  : 'When you receive notifications, they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white54 : const Color(0xFF666666),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(NotificationItem notification, bool isDarkMode) {
    final icon = _getIconForType(notification.type);
    final color = _getColorForType(notification.type);

    return Dismissible(
      key: Key(notification.id),
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
      onDismissed: (_) => _deleteNotification(notification.id),
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
          border: notification.isRead
              ? null
              : Border.all(
                  color: const Color(0xFF6B9B5B).withAlpha(50),
                  width: 1,
                ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => _handleNotificationTap(notification),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 24,
                        ),
                      ),
                      if (!notification.isRead)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B9B5B),
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
                                notification.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            Text(
                              notification.timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.trip:
        return Icons.directions_bus;
      case NotificationType.message:
        return Icons.chat_bubble_outline;
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.child:
        return Icons.child_care;
      case NotificationType.general:
        return Icons.notifications_none;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.trip:
        return const Color(0xFF6B9B5B);
      case NotificationType.message:
        return const Color(0xFF2196F3);
      case NotificationType.alert:
        return const Color(0xFFFF9800);
      case NotificationType.payment:
        return const Color(0xFF9C27B0);
      case NotificationType.child:
        return const Color(0xFFE91E63);
      case NotificationType.general:
        return const Color(0xFF607D8B);
    }
  }
}
