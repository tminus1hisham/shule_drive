import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';
import 'package:provider/provider.dart';
import '../../models/chat_conversation.dart';

import '../../providers/chat_provider.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = true;
  String? _error;
  List<ChatUser> _users = [];
  List<ChatUser> _filteredUsers = [];
  String _selectedFilter = 'All';
  Timer? _searchDebounce;

  final List<String> _filters = ['All', 'Driver', 'Guardian', 'Staff'];

  @override
  void initState() {
    super.initState();

    _loadUsers();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _filterUsers();
    });
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final matchesSearch =
            user.name.toLowerCase().contains(query) ||
            user.phone.toLowerCase().contains(query);
        final matchesFilter =
            _selectedFilter == 'All' ||
            user.role?.toLowerCase() == _selectedFilter.toLowerCase();
        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  Future<void> _loadUsers() async {
    // Use WidgetsBinding to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isLoading = true);
      }
    });

    try {
      final chatProvider = context.read<ChatProvider>();
      debugPrint('🔄 Loading available users...');
      final users = await chatProvider.getAvailableUsers();
      debugPrint('✅ Loaded ${users.length} users');

      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading users: $e');
      debugPrint('Stack: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Failed to load users: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startChat(ChatUser user) {
    // Use phone number as the receiver identifier for chat
    Navigator.pushReplacementNamed(
      context,
      '/chat-detail',
      arguments: {
        'receiverPhone': user.phone, // Use phone number instead of user ID
        'receiverName': user.name,
        'receiverAvatar': user.avatar,
        'receiverRole': user.role,
      },
    );
  }

  static const _filterLabels = {'Driver': 'Drivers', 'Guardian': 'Guardians'};

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MainScaffold(
      title: 'New Chat',
      showBackButton: true,
      actions: [
        AnimatedSwitcher(
          duration: AppDuration.medium,
          child: _isLoading
              ? Padding(
                  key: const ValueKey('busy'),
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.brand,
                    ),
                  ),
                )
              : IconButton(
                  key: const ValueKey('refresh'),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                  onPressed: _loadUsers,
                ),
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
                  AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    AppTextField(
                      controller: _searchController,
                      hint: 'Search by name or phone...',
                      prefixIcon: Icons.search_rounded,
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                _filterUsers();
                              },
                            ),
                    ).enter(),
                    AppSpacing.vSm,
                    SegmentedFilter(
                      selected: _filters.indexOf(_selectedFilter),
                      onChanged: (i) {
                        setState(() => _selectedFilter = _filters[i]);
                        _filterUsers();
                      },
                      segments: [
                        for (final f in _filters)
                          FilterSegment(_filterLabels[f] ?? f),
                      ],
                    ).enter(delay: const Duration(milliseconds: 60)),
                  ],
                ),
              ),
              Expanded(
                child: AsyncBody(
                  loading: _isLoading,
                  error: _error == null ? null : 'Tap refresh to try again',
                  onRetry: _loadUsers,
                  isEmpty: _filteredUsers.isEmpty,
                  empty: _buildEmptyState(),
                  // Re-keyed per search/filter so the new result set
                  // cross-fades in with a fresh stagger.
                  child: KeyedSubtree(
                    key: ValueKey('$_selectedFilter|${_searchController.text}'),
                    child: _buildUserList(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    return EmptyState(
      icon: isSearching
          ? Icons.search_off_rounded
          : Icons.people_outline_rounded,
      title: isSearching ? 'No users found' : 'No users available',
      message: isSearching
          ? 'Try a different search term'
          : 'There are no users to chat with at the moment',
    );
  }

  Widget _buildUserList() {
    final c = context.colors;
    // Group users by first letter of name
    final groupedUsers = <String, List<ChatUser>>{};
    for (final user in _filteredUsers) {
      final firstLetter = user.name.isNotEmpty
          ? user.name[0].toUpperCase()
          : '#';
      groupedUsers.putIfAbsent(firstLetter, () => []).add(user);
    }
    final sortedKeys = groupedUsers.keys.toList()..sort();
    var i = 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        for (final letter in sortedKeys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Text(
              letter,
              style: context.text.labelLarge?.copyWith(
                color: c.brand,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final user in groupedUsers[letter]!)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _buildUserTile(user).enterList(i++),
            ),
        ],
      ],
    );
  }

  Widget _buildUserTile(ChatUser user) {
    final c = context.colors;
    final avatarUrl = user.avatar;
    final hasValidUrl =
        avatarUrl != null &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    return AppCard(
      onTap: () => _startChat(user),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(
                imageUrl: hasValidUrl ? avatarUrl : null,
                name: user.name,
                size: 52,
              ),
              if (user.isOnline)
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
                  ),
                ),
            ],
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AppSpacing.vXxs,
                Row(
                  children: [
                    if (user.role != null) ...[
                      StatusPill(
                        label: user.role!,
                        color: _getRoleColor(user.role!),
                        showDot: false,
                        dense: true,
                      ),
                      AppSpacing.hXs,
                    ],
                    Expanded(
                      child: Text(
                        user.isOnline ? 'Online' : user.formattedLastSeen,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: user.isOnline ? c.success : c.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: c.brandGradient,
              borderRadius: AppRadius.brSm,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    final c = context.colors;
    switch (role.toLowerCase()) {
      case 'driver':
        return c.accent;
      case 'guardian':
      case 'parent':
        return c.info;
      case 'admin':
      case 'staff':
        return c.warning;
      default:
        return c.brand;
    }
  }
}
