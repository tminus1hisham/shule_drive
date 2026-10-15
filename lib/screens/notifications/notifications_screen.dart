import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/services/user_service.dart';
import '../../services/guardian_trip_notification_service.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

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

enum NotificationType { trip, message, alert, general, payment, child }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// 0 All, 1 Unread, 2 Trips.
  int _tab = 0;
  bool _isLoading = true;
  String? _error;
  List<NotificationItem> _notifications = [];
  final UserService _userService = UserService();
  static const _localPrefix = 'local_';

  List<NotificationItem> get filteredNotifications {
    if (_tab == 0) return _notifications;
    if (_tab == 1) {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications
        .where((n) => n.type == NotificationType.trip)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    // Show cached data immediately if available
    final hasExistingData = _notifications.isNotEmpty;
    if (!hasExistingData) {
      setState(() => _isLoading = true);
    }

    try {
      // The service answers failures with [] (or a stale cache); without
      // this flag a 403 looked like "No notifications yet".
      var loadFailed = false;
      final apiNotifications = await _userService.getNotifications(
        page: 1,
        limit: 50,
        onFallback: () => loadFailed = true,
      );
      // Trip alerts this device received live (the server list 403s for
      // guardians). Opening the screen clears the Alerts badge.
      final alerts = GuardianTripNotificationService();
      final localAlerts = await alerts.alertHistory();
      unawaited(alerts.markAlertsRead());
      if (loadFailed && apiNotifications.isEmpty && localAlerts.isEmpty) {
        throw Exception("Couldn't reach the server");
      }

      // Convert API notifications to UI notification items
      final notifications = [
        ...apiNotifications.map(
          (n) => NotificationItem(
            id: n.id,
            title: n.title,
            message: n.body,
            timestamp: n.createdAt,
            type: _mapNotificationType(n.type),
            isRead: n.isRead,
            actionRoute: n.tripId != null ? '/trips' : null,
            actionData: n.tripId != null ? {'tripId': n.tripId} : null,
          ),
        ),
        for (final (i, a) in localAlerts.indexed)
          NotificationItem(
            id: '$_localPrefix$i',
            title: a['title']?.toString() ?? '',
            message: a['body']?.toString() ?? '',
            timestamp:
                DateTime.tryParse(a['at']?.toString() ?? '') ?? DateTime.now(),
            type: NotificationType.trip,
            isRead: a['read'] == true,
            actionRoute: '/trips',
          ),
      ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading notifications: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load notifications';
        });
        // With cached items on screen, keep them and just flag the failure.
        if (_notifications.isNotEmpty) {
          AppSnackbar.error(context, 'Failed to load notifications: $e');
        }
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

    // Device-side alerts have no server record (marked read on open).
    if (id.startsWith(_localPrefix)) return;
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
      _notifications = _notifications
          .map(
            (n) => NotificationItem(
              id: n.id,
              title: n.title,
              message: n.message,
              timestamp: n.timestamp,
              type: n.type,
              isRead: true,
              actionRoute: n.actionRoute,
              actionData: n.actionData,
            ),
          )
          .toList();
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
    final c = context.colors;
    final items = filteredNotifications;

    return MainScaffold(
      title: 'Notifications',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 2,
      actions: [
        AnimatedSwitcher(
          duration: AppDuration.medium,
          child: _unreadCount > 0
              ? TextButton(
                  key: const ValueKey('mark'),
                  onPressed: _markAllAsRead,
                  child: const Text('Mark all read'),
                )
              : const SizedBox.shrink(),
        ),
      ],
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: SegmentedFilter(
                  selected: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                  segments: [
                    FilterSegment('All', count: _notifications.length),
                    FilterSegment('Unread', count: _unreadCount),
                    const FilterSegment('Trips'),
                  ],
                ).enter(),
              ),
              Expanded(
                child: AsyncBody(
                  loading: _isLoading,
                  error: _notifications.isEmpty ? _error : null,
                  onRetry: _loadNotifications,
                  isEmpty: items.isEmpty,
                  empty: EmptyState(
                    icon: _tab == 1
                        ? Icons.done_all_rounded
                        : Icons.notifications_none_rounded,
                    iconColor: _tab == 1 ? c.success : null,
                    title: _tab == 1
                        ? 'No unread notifications'
                        : 'No notifications yet',
                    message: _tab == 1
                        ? 'You\'re all caught up!'
                        : 'When you receive notifications, they will appear here.',
                  ),
                  onRefresh: _loadNotifications,
                  // Keyed by tab so switching tabs cross-fades the lists.
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: _buildNotificationTile(
                          items[index],
                        ).enterList(index),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationItem notification) {
    final c = context.colors;
    final icon = _getIconForType(notification.type);
    final color = _getColorForType(notification.type);
    final unread = !notification.isRead;

    return SwipeAction(
      key: ValueKey('notif-${notification.id}'),
      end: SwipeSpec(
        label: 'Delete',
        icon: Icons.delete_outline_rounded,
        color: c.error,
        onTrigger: () async => true,
      ),
      onDismissed: () => _deleteNotification(notification.id),
      child: PressScale(
        scale: 0.985,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleNotificationTap(notification),
            borderRadius: AppRadius.brLg,
            // Unread cards carry a brand tint + edge that fade out when read.
            child: AnimatedContainer(
              duration: AppDuration.slow,
              curve: AppCurves.easeOut,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: unread
                    ? Color.alphaBlend(
                        c.brand.withValues(alpha: 0.06),
                        context.scheme.surface,
                      )
                    : context.scheme.surface,
                borderRadius: AppRadius.brLg,
                border: Border.all(
                  color: unread ? c.brand.withValues(alpha: 0.3) : c.outline,
                ),
                boxShadow: unread ? c.shadowSm : const [],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color.withValues(alpha: 0.22),
                              color.withValues(alpha: 0.08),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: AppIconSize.lg),
                      ),
                      Positioned(
                        right: -1,
                        top: -1,
                        child: AnimatedScale(
                          scale: unread ? 1 : 0,
                          duration: AppDuration.medium,
                          curve: unread ? Curves.easeOutBack : Curves.easeIn,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: c.brand,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.scheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedDefaultTextStyle(
                                duration: AppDuration.medium,
                                style: context.text.titleSmall!.copyWith(
                                  fontWeight: unread
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                                child: Text(notification.title),
                              ),
                            ),
                            Text(
                              notification.timeAgo,
                              style: context.text.labelSmall?.copyWith(
                                color: unread ? c.brand : c.textMuted,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.vXxs,
                        Text(
                          notification.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: c.textSecondary,
                            height: 1.4,
                          ),
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
        return Icons.directions_bus_rounded;
      case NotificationType.message:
        return Icons.chat_bubble_outline_rounded;
      case NotificationType.alert:
        return Icons.warning_amber_rounded;
      case NotificationType.payment:
        return Icons.payment_rounded;
      case NotificationType.child:
        return Icons.child_care_rounded;
      case NotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    final c = context.colors;
    switch (type) {
      case NotificationType.trip:
        return c.accent;
      case NotificationType.message:
        return c.info;
      case NotificationType.alert:
        return c.warning;
      case NotificationType.payment:
        return c.success;
      case NotificationType.child:
        return c.brand;
      case NotificationType.general:
        return c.textSecondary;
    }
  }
}
