import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_conversation.dart';
import '../../providers/app_provider.dart';
import '../../providers/chat_provider.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    
    _loadUsers();
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
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
        final matchesSearch = user.name.toLowerCase().contains(query) ||
            (user.phone?.toLowerCase().contains(query) ?? false);
        final matchesFilter = _selectedFilter == 'All' ||
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
        _animationController.forward();
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
        'receiverPhone': user.phone,  // Use phone number instead of user ID
        'receiverName': user.name,
        'receiverAvatar': user.avatar,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDarkMode = appProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
      appBar: _buildAppBar(isDarkMode),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(isDarkMode),
          
          // Filter Chips
          _buildFilterChips(isDarkMode),
          
          // Content
          Expanded(
            child: _buildBody(isDarkMode),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'New Chat',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
      actions: [
        if (_isLoading)
          Center(
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.white70 : const Color(0xFF6B9B5B),
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
            ),
            onPressed: _loadUsers,
          ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: TextStyle(
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
          ),
          decoration: InputDecoration(
            hintText: 'Search by name or phone...',
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDarkMode ? Colors.white54 : Colors.grey.shade500,
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _filterUsers();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(bool isDarkMode) {
    return Container(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            // Display plural labels for better UX
            final displayLabel = {
              'Driver': 'Drivers',
              'Guardian': 'Guardians',
            }[filter] ?? filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(displayLabel),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : isDarkMode
                          ? Colors.white70
                          : const Color(0xFF666666),
                ),
                backgroundColor: isDarkMode
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey.shade100,
                selectedColor: const Color(0xFF6B9B5B),
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.transparent
                        : isDarkMode
                            ? Colors.white12
                            : Colors.grey.shade300,
                  ),
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedFilter = filter;
                    _filterUsers();
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return _buildLoadingState(isDarkMode);
    }

    if (_error != null) {
      return _buildErrorState(isDarkMode);
    }

    if (_filteredUsers.isEmpty) {
      return _buildEmptyState(isDarkMode);
    }

    return _buildUserList(isDarkMode);
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
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
            width: 52,
            height: 52,
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
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withAlpha(10) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
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
              'Couldn\'t load users',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap refresh to try again',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    final isSearching = _searchController.text.isNotEmpty;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
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
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSearching ? Icons.search_off : Icons.people_outline,
                  size: 48,
                  color: isDarkMode ? Colors.white30 : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isSearching ? 'No users found' : 'No users available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSearching
                    ? 'Try a different search term'
                    : 'There are no users to chat with at the moment',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : const Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(bool isDarkMode) {
    // Group users by first letter of name
    final groupedUsers = <String, List<ChatUser>>{};
    for (final user in _filteredUsers) {
      final firstLetter = user.name.isNotEmpty
          ? user.name[0].toUpperCase()
          : '#';
      groupedUsers.putIfAbsent(firstLetter, () => []).add(user);
    }
    
    final sortedKeys = groupedUsers.keys.toList()..sort();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sortedKeys.length,
        itemBuilder: (context, sectionIndex) {
          final letter = sortedKeys[sectionIndex];
          final usersInSection = groupedUsers[letter]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B9B5B),
                  ),
                ),
              ),
              
              // Users in this section
              ...usersInSection.asMap().entries.map((entry) {
                final index = entry.key;
                final user = entry.value;
                return _buildUserTile(user, isDarkMode, sectionIndex * 100 + index);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserTile(ChatUser user, bool isDarkMode, int index) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = index * 0.05;
        final value = (_animationController.value - delay).clamp(0.0, 1.0) / (1 - delay);
        
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
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
            onTap: () => _startChat(user),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      _buildAvatar(user, isDarkMode),
                      if (user.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
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
                  
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (user.role != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getRoleColor(user.role!).withAlpha(30),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  user.role!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _getRoleColor(user.role!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                user.isOnline
                                    ? 'Online'
                                    : user.formattedLastSeen,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: user.isOnline
                                      ? const Color(0xFF4CAF50)
                                      : isDarkMode
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Chat Button
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 20,
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

  Widget _buildAvatar(ChatUser user, bool isDarkMode) {
    final avatarUrl = user.avatar;
    // Check if it's a valid network URL
    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      return CircleAvatar(
        radius: 26,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey.shade200,
        onBackgroundImageError: (e, s) {
          if (kDebugMode) print('⚠️ Failed to load avatar: $e');
        },
      );
    }

    return CircleAvatar(
      radius: 26,
      backgroundColor: _getAvatarColor(user.name),
      child: Text(
        user.initials,
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'driver':
        return const Color(0xFF2196F3);
      case 'guardian':
      case 'parent':
        return const Color(0xFF9C27B0);
      case 'admin':
      case 'staff':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF6B9B5B);
    }
  }
}
