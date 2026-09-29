import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/services/user_service.dart';
import '../../providers/app_provider.dart';
import '../../widgets/main_scaffold.dart';

import '../../theme/app_colors.dart';
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
  final UserService _userService = UserService();
  
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
    // Show cached data immediately if available
    final hasExistingData = _notifications.isNotEmpty;
    if (!hasExistingData) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Fetch real notifications from API
      final apiNotifications = await _userService.getNotifications(
        page: 1,
        limit: 50,
      );
      
      // Convert API notifications to UI notification items
      final notifications = apiNotifications.map((n) => NotificationItem(
        id: n.id,
        title: n.title,
        message: n.body,
        timestamp: n.createdAt,
        type: _mapNotificationType(n.type),
        isRead: n.isRead,
        actionRoute: n.tripId != null ? '/trips' : null,
        actionData: n.tripId != null ? {'tripId': n.tripId} : null,
      )).toList();
      
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading notifications: $e');
      }
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load notifications: $e'),
            backgroundColor: AppPalette.error,
          ),
        );
      }
    }
  }
  
  /// Map API notification type to UI notification type
  NotificationType _mapNotificationType(String? type) {
    switch (type?.toLowerCase()) {
      case 'trip':
      case 'trip_started':
      case 'trip_completed':
        return NotificationType.trip;
      case 'message':
      case 'chat':
        return NotificationType.message;
      case 'alert':
      case 'warning':
        return NotificationType.alert;
      case 'payment':
        return NotificationType.payment;
      case 'child':
      case 'student':
        return NotificationType.child;
      default:
        return NotificationType.general;
    }
  }

  Future<void> _markAsRead(String id) async {
    // Optimistically update UI
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
    
    // Call API to mark as read
    try {
      await _userService.markNotificationRead(id);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking notification as read: $e');
      }
    }
  }

  Future<void> _markAllAsRead() async {
    // Optimistically update UI
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
    
    // Call API to mark all as read
    try {
      await _userService.markAllNotificationsRead();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error marking all notifications as read: $e');
      }
    }
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
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/dashboard');
            break;
          case 1:
            Navigator.pushNamed(context, '/chat');
            break;
          case 2:
            // Already on notifications/alerts
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
        if (_unreadCount > 0)
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: AppPalette.emerald,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: isDarkMode ? AppPalette.surfaceDark : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppPalette.emerald,
              unselectedLabelColor: isDarkMode ? Colors.white60 : AppPalette.textMutedLight,
              indicatorColor: AppPalette.emerald,
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
                            color: AppPalette.emerald,
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
                        color: AppPalette.emerald,
                        backgroundColor: isDarkMode ? AppPalette.surfaceDark : Colors.white,
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
        color: isDarkMode ? AppPalette.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withAlpha(10) : AppPalette.outlineLight,
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
                    color: isDarkMode ? Colors.white.withAlpha(10) : AppPalette.outlineLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withAlpha(10) : AppPalette.outlineLight,
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
                    : AppPalette.emerald.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none,
                size: 48,
                color: isDarkMode ? Colors.white38 : AppPalette.emerald,
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
                color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
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
                color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
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
          color: isDarkMode ? AppPalette.surfaceDark : Colors.white,
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
                  color: AppPalette.emerald.withAlpha(50),
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
                              color: AppPalette.emerald,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode ? AppPalette.surfaceDark : Colors.white,
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
                                  color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
                                ),
                              ),
                            ),
                            Text(
                              notification.timeAgo,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? AppPalette.textMutedDark : AppPalette.textMutedLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
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
        return AppPalette.emerald;
      case NotificationType.message:
        return AppPalette.info;
      case NotificationType.alert:
        return AppPalette.warning;
      case NotificationType.payment:
        return const Color(0xFF9C27B0);
      case NotificationType.child:
        return const Color(0xFFE91E63);
      case NotificationType.general:
        return const Color(0xFF607D8B);
    }
  }
}
