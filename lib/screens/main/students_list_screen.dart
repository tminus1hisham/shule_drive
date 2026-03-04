import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../models/student.dart';
import '../../providers/app_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/main_scaffold.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<Student> students = [];
  Trip? _trip;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    // Load students from active trip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentsFromTrip();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadStudentsFromTrip() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final tripId = args?['tripId']?.toString();

    final tripProvider = context.read<TripProvider>();

    // Try to get trip from provider
    Trip? trip;
    if (tripId != null) {
      try {
        trip = tripProvider.trips.firstWhere((t) => t.id == tripId);
      } catch (_) {
        trip = null;
      }
    }
    trip ??= tripProvider.activeTrip;

    if (trip != null) {
      _trip = trip;
      // Convert StudentPickup to Student
      students = trip.students
          .map(
            (s) => Student(
              id: s.id,
              name: s.name,
              className: '', // Not available in StudentPickup
              avatar: s.photo ?? '',
              status: _mapStatus(s.status),
            ),
          )
          .toList();

      if (kDebugMode) {
        print(
          '🎓 StudentsListScreen: Loaded ${students.length} students from trip',
        );
      }
    } else {
      if (kDebugMode) {
        print('⚠️ StudentsListScreen: No active trip found');
      }
    }

    setState(() => _isLoading = false);
  }

  StudentStatus _mapStatus(String status) {
    switch (status) {
      case 'picked':
        return StudentStatus.picked;
      case 'absent':
        return StudentStatus.absent;
      case 'dropped':
        return StudentStatus.picked; // Treat dropped as picked for UI
      default:
        return StudentStatus.pending;
    }
  }

  void _updateStudentStatus(String id, StudentStatus status) {
    setState(() {
      final student = students.firstWhere((s) => s.id == id);
      student.status = status;
    });
    HapticFeedback.lightImpact();
  }

  List<Student> _getFilteredStudents() {
    final query = _searchController.text.toLowerCase();
    var filtered = students;

    if (query.isNotEmpty) {
      filtered = filtered
          .where((s) => s.name.toLowerCase().contains(query))
          .toList();
    }

    switch (_tabController.index) {
      case 1:
        return filtered.where((s) => s.status == StudentStatus.picked).toList();
      case 2:
        return filtered.where((s) => s.status == StudentStatus.absent).toList();
      default:
        return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    if (_isLoading) {
      return const MainScaffold(
        title: 'Students',
        showBackButton: true,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
        ),
      );
    }

    final filteredStudents = _getFilteredStudents();
    final pickedCount = students
        .where((s) => s.status == StudentStatus.picked)
        .length;
    final absentCount = students
        .where((s) => s.status == StudentStatus.absent)
        .length;
    final pendingCount = students
        .where((s) => s.status == StudentStatus.pending)
        .length;
    final progress = students.isEmpty ? 0.0 : pickedCount / students.length;

    return MainScaffold(
      title: 'Students',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: (index) {
        if (index == 1) {
          Navigator.pushNamed(context, '/chat');
        } else if (index == 3) {
          Navigator.pushNamed(context, '/profile');
        }
      },
      body: Column(
        children: [
          // Scrollable Header + Tabs
          Expanded(
            child: CustomScrollView(
              slivers: [
                // ── Hero Stats Section ──
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B9B5B), Color(0xFF4A7A3E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6B9B5B).withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _trip?.routeName ?? 'Active Trip',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${students.length} students assigned',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Trip Progress',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Stats row
                        Row(
                          children: [
                            _buildStatChip(
                              Icons.check_circle_outline,
                              '$pickedCount',
                              'Picked',
                              Colors.white,
                            ),
                            const SizedBox(width: 12),
                            _buildStatChip(
                              Icons.hourglass_bottom_rounded,
                              '$pendingCount',
                              'Pending',
                              Colors.amber.shade200,
                            ),
                            const SizedBox(width: 12),
                            _buildStatChip(
                              Icons.cancel_outlined,
                              '$absentCount',
                              'Absent',
                              Colors.red.shade200,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Search Bar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.shade200,
                        ),
                        boxShadow: isDarkMode
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          color: provider.textColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by name...',
                          hintStyle: TextStyle(
                            color: provider.textMutedColor,
                            fontSize: 14,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Icon(
                              Icons.search_rounded,
                              color: provider.textMutedColor,
                              size: 22,
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                    color: provider.textMutedColor,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Tab Bar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? const Color(0xFF252525)
                            : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: const Color(0xFF6B9B5B),
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6B9B5B).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: provider.textMutedColor,
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        labelPadding: EdgeInsets.zero,
                        tabs: [
                          _buildTab('All', students.length),
                          _buildTab('Picked', pickedCount),
                          _buildTab('Absent', absentCount),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Students List ──
                if (filteredStudents.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(provider),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount:
                          filteredStudents.length + 1, // +1 for bottom spacer
                      itemBuilder: (context, index) {
                        if (index == filteredStudents.length) {
                          return const SizedBox(height: 100);
                        }
                        final student = filteredStudents[index];
                        return _buildStudentCard(
                          student,
                          index,
                          isDarkMode,
                          provider,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Color(0xFF6B9B5B), Color(0xFF4A7A3E)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6B9B5B).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
          label: const Text(
            'Complete Trip',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatChip(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(
    Student student,
    int index,
    bool isDarkMode,
    AppProvider provider,
  ) {
    final statusColor = _getStatusColor(student.status);
    final statusLabel = _getStatusLabel(student.status);
    final statusIcon = _getStatusIcon(student.status);

    final card = AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showStudentActions(student),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade100,
              ),
              boxShadow: isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Avatar with status ring
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.25),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: statusColor.withOpacity(0.1),
                    backgroundImage: student.avatar.isNotEmpty
                        ? NetworkImage(student.avatar)
                        : null,
                    child: student.avatar.isEmpty
                        ? Text(
                            _getInitials(student.name),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                // Name & Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: provider.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Quick actions
                if (student.status == StudentStatus.pending) ...[
                  _buildQuickAction(
                    icon: Icons.check_rounded,
                    color: const Color(0xFF6B9B5B),
                    onTap: () =>
                        _updateStudentStatus(student.id, StudentStatus.picked),
                  ),
                  const SizedBox(width: 8),
                  _buildQuickAction(
                    icon: Icons.close_rounded,
                    color: Colors.orange.shade600,
                    onTap: () =>
                        _updateStudentStatus(student.id, StudentStatus.absent),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(statusIcon, size: 18, color: statusColor),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Wrap pending students with swipe-to-act
    if (student.status == StudentStatus.pending) {
      return Dismissible(
        key: Key('swipe_${student.id}'),
        direction: DismissDirection.horizontal,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.3,
          DismissDirection.endToStart: 0.3,
        },
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            HapticFeedback.mediumImpact();
            _updateStudentStatus(student.id, StudentStatus.picked);
          } else {
            HapticFeedback.heavyImpact();
            _updateStudentStatus(student.id, StudentStatus.absent);
          }
          return false;
        },
        background: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF6B9B5B),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 26),
              SizedBox(width: 8),
              Text(
                'Pick Up',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.orange.shade600,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Absent',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.cancel_rounded, color: Colors.white, size: 26),
            ],
          ),
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildQuickAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  void _showStudentActions(Student student) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = context.read<AppProvider>().isDarkMode;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Student info
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF6B9B5B).withOpacity(0.1),
                child: Text(
                  _getInitials(student.name),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B9B5B),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                student.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getStatusIcon(student.status),
                    size: 16,
                    color: _getStatusColor(student.status),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusLabel(student.status),
                    style: TextStyle(
                      fontSize: 14,
                      color: _getStatusColor(student.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.check_circle_rounded,
                      label: 'Pick Up',
                      color: const Color(0xFF6B9B5B),
                      enabled: student.status == StudentStatus.pending,
                      onTap: () {
                        _updateStudentStatus(student.id, StudentStatus.picked);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.cancel_rounded,
                      label: 'Absent',
                      color: Colors.orange.shade600,
                      enabled: student.status == StudentStatus.pending,
                      onTap: () {
                        _updateStudentStatus(student.id, StudentStatus.absent);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(enabled ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(enabled ? 0.3 : 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(StudentStatus status) {
    switch (status) {
      case StudentStatus.picked:
        return const Color(0xFF6B9B5B);
      case StudentStatus.absent:
        return Colors.orange.shade600;
      case StudentStatus.pending:
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusLabel(StudentStatus status) {
    switch (status) {
      case StudentStatus.picked:
        return 'Picked Up';
      case StudentStatus.absent:
        return 'Absent';
      case StudentStatus.pending:
      default:
        return 'Pending';
    }
  }

  IconData _getStatusIcon(StudentStatus status) {
    switch (status) {
      case StudentStatus.picked:
        return Icons.check_circle_rounded;
      case StudentStatus.absent:
        return Icons.cancel_rounded;
      case StudentStatus.pending:
      default:
        return Icons.schedule_rounded;
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Widget _buildEmptyState(AppProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF6B9B5B).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 52,
                color: Color(0xFF6B9B5B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No students found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try a different search term'
                  : 'No students match this filter',
              style: TextStyle(fontSize: 14, color: provider.textMutedColor),
            ),
          ],
        ),
      ),
    );
  }
}
