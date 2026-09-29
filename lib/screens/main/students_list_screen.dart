import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../models/student.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/main_scaffold.dart';

import '../../theme/app_colors.dart';
/// Students List Screen - Professional UI for managing student pickups
/// 
/// Features:
/// - Premium header with sticky student count
/// - Trip progress card showing real-time status
/// - Professional search bar with filtering
/// - Custom segmented controls for status filtering
/// - Modern student cards with swipe actions
class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen>
    with TickerProviderStateMixin {
  final int _currentIndex = 0;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoading = true;
  List<Student> students = [];
  Trip? _trip;
  bool _isUpdating = false;
  
  // Store provider reference for listener removal
  TripProvider? _tripProvider;

  // Animation controller for smooth transitions
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Load students from active trip
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentsFromTrip();
    });
    
    // Listen to TripProvider changes to sync status updates
    _tripProvider = context.read<TripProvider>();
    _tripProvider?.addListener(_onTripProviderChanged);
  }
  
  void _onTripProviderChanged() {
    // Refresh students when provider updates
    if (mounted && _trip != null) {
      _syncStudentsFromProvider();
    }
  }
  
  void _syncStudentsFromProvider() {
    final tripProvider = context.read<TripProvider>();
    
    // Find updated trip data
    Trip? updatedTrip;
    try {
      updatedTrip = tripProvider.trips.firstWhere((t) => t.id == _trip!.id);
    } catch (_) {
      // Try active trip
      if (tripProvider.activeTrip?.id == _trip!.id) {
        updatedTrip = tripProvider.activeTrip;
      }
    }
    
    if (updatedTrip != null) {
      _trip = updatedTrip;
      // Update students list with new status
      setState(() {
        for (var i = 0; i < students.length; i++) {
          final student = students[i];
          try {
            final updatedStudent = updatedTrip!.students.firstWhere(
              (s) => s.id == student.id,
            );
            students[i] = Student(
              id: student.id,
              name: student.name,
              className: student.className,
              avatar: student.avatar,
              status: _mapStatus(updatedStudent.status),
            );
          } catch (_) {
            // Student not found in updated trip, keep existing
          }
        }
      });
    }
  }

  @override
  void dispose() {
    // Remove TripProvider listener
    _tripProvider?.removeListener(_onTripProviderChanged);
    
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
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
      
      // Log raw student data from API
      if (kDebugMode) {
        print('🎓 StudentsListScreen: Trip found - ${trip.routeName}');
        print('🎓 StudentsListScreen: Raw students from API - ${trip.students.length}');
        for (final s in trip.students) {
          print('   - ${s.name} (${s.id}): status=${s.status}');
        }
      }
      
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
        print('   tripId from args: $tripId');
        print('   activeTrip: ${tripProvider.activeTrip?.id}');
        print('   trips in provider: ${tripProvider.trips.length}');
      }
    }

    setState(() => _isLoading = false);
    _animationController.forward();
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

  void _updateStudentStatus(String id, StudentStatus status) async {
    if (_isUpdating) return;
    
    setState(() => _isUpdating = true);
    HapticFeedback.lightImpact();

    // Update local state immediately for responsive UI
    setState(() {
      final student = students.firstWhere((s) => s.id == id);
      student.status = status;
    });

    // Sync with backend
    try {
      final tripProvider = context.read<TripProvider>();
      final tripId = _trip?.id;
      if (tripId != null) {
        final statusString = status == StudentStatus.picked 
            ? 'picked' 
            : status == StudentStatus.absent 
                ? 'absent' 
                : status == StudentStatus.dropped
                    ? 'dropped'
                    : 'pending';
        
        await tripProvider.updateStudentStatus(
          tripId: tripId,
          studentId: id,
          status: statusString,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update student status: $e');
      }
      // Optionally revert on error
    } finally {
      setState(() => _isUpdating = false);
    }
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
      case 3:
        return filtered.where((s) => s.status == StudentStatus.dropped).toList();
      default:
        return filtered;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    if (_isLoading) {
      return MainScaffold(
        title: 'Students',
        showBackButton: true,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppPalette.emerald,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading students...',
                style: TextStyle(
                  color: provider.textMutedColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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
    final droppedCount = students
        .where((s) => s.status == StudentStatus.dropped)
        .length;
    final pendingCount = students
        .where((s) => s.status == StudentStatus.pending)
        .length;
    // Progress includes both picked and dropped as completed
    final completedCount = pickedCount + droppedCount;
    final progress = students.isEmpty ? 0.0 : completedCount / students.length;

    return MainScaffold(
      title: 'Students',
      showBackButton: true,
      showBottomNav: false,
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
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Premium Header Section ──
                SliverToBoxAdapter(
                  child: _buildPremiumHeader(isDarkMode, provider),
                ),

                // ── Trip Progress Card ──
                SliverToBoxAdapter(
                  child: _buildTripProgressCard(
                    isDarkMode,
                    provider,
                    progress,
                    pickedCount,
                    pendingCount,
                    absentCount,
                  ),
                ),

                // ── Search Bar ──
                SliverToBoxAdapter(
                  child: _buildSearchBar(isDarkMode, provider),
                ),

                // ── Custom Segmented Control ──
                SliverToBoxAdapter(
                  child: _buildSegmentedControl(
                    isDarkMode,
                    provider,
                    pickedCount,
                    absentCount,
                    droppedCount,
                  ),
                ),

                // ── Pick All / Drop All Buttons ──
                SliverToBoxAdapter(
                  child: _buildBulkActionButtons(isDarkMode, provider),
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
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Premium header with sticky student count
  Widget _buildPremiumHeader(bool isDarkMode, AppProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF2D3B2D), const Color(0xFF1E2A1E)]
              : [AppPalette.emerald, AppPalette.emeraldPressed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppPalette.emerald.withValues(alpha: isDarkMode ? 0.2 : 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row with icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trip?.routeName ?? 'Active Trip',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${students.length} students',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'In Progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Trip Progress Card with real-time status
  Widget _buildTripProgressCard(
    bool isDarkMode,
    AppProvider provider,
    double progress,
    int pickedCount,
    int pendingCount,
    int absentCount,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppPalette.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : AppPalette.outlineLight,
        ),
        boxShadow: isDarkMode
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assessment_outlined,
                    size: 18,
                    color: provider.textMutedColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trip Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: provider.textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: progress >= 1.0
                        ? [AppPalette.emerald, AppPalette.emeraldPressed]
                        : [AppPalette.info, AppPalette.info],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // Background
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppPalette.surfaceSubtleLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Progress - fill available width based on progress
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  height: 10,
                  width: (MediaQuery.of(context).size.width - 72) * progress,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.emerald, AppPalette.emeraldBright],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.emerald.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Stats row
          Row(
            children: [
              _buildProgressStat(
                Icons.check_circle_rounded,
                pickedCount.toString(),
                'Picked',
                AppPalette.emerald,
                isDarkMode,
              ),
              const SizedBox(width: 12),
              _buildProgressStat(
                Icons.hourglass_bottom_rounded,
                pendingCount.toString(),
                'Pending',
                Colors.orange.shade600,
                isDarkMode,
              ),
              const SizedBox(width: 12),
              _buildProgressStat(
                Icons.cancel_outlined,
                absentCount.toString(),
                'Absent',
                Colors.red.shade400,
                isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(
    IconData icon,
    String value,
    String label,
    Color color,
    bool isDarkMode,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDarkMode ? 0.1 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: isDarkMode ? 0.2 : 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Professional search bar
  Widget _buildSearchBar(bool isDarkMode, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : AppPalette.surfaceSubtleLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.1)
                : AppPalette.outlineLight,
          ),
          boxShadow: isDarkMode
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: provider.textColor,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search students by name...',
            hintStyle: TextStyle(
              color: provider.textMutedColor,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppPalette.emerald.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.search_rounded,
                color: AppPalette.emerald,
                size: 18,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                      setState(() {});
                    },
                    child: Container(
                      margin: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppPalette.textMutedLight.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: provider.textMutedColor,
                      ),
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// Custom segmented control for filtering
  Widget _buildSegmentedControl(
    bool isDarkMode,
    AppProvider provider,
    int pickedCount,
    int absentCount,
    int droppedCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF252525)
              : AppPalette.surfaceSubtleLight,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildSegment(
              0,
              'All',
              students.length,
              isDarkMode,
              provider,
            ),
            _buildSegment(
              1,
              'Picked',
              pickedCount,
              isDarkMode,
              provider,
            ),
            _buildSegment(
              2,
              'Absent',
              absentCount,
              isDarkMode,
              provider,
            ),
            _buildSegment(
              3,
              'Dropped',
              droppedCount,
              isDarkMode,
              provider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegment(
    int index,
    String label,
    int count,
    bool isDarkMode,
    AppProvider provider,
  ) {
    final isSelected = _tabController.index == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          _tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? AppPalette.emerald
                : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppPalette.emerald.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : provider.textMutedColor,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : isDarkMode
                            ? Colors.white.withValues(alpha: 0.1)
                            : AppPalette.outlineLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : provider.textMutedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bulk action buttons (Pick All / Drop All)
  Widget _buildBulkActionButtons(bool isDarkMode, AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          // Pick All Button
          Expanded(
            child: GestureDetector(
              onTap: _pickAllStudents,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2D3B2D)
                      : AppPalette.emeraldSoftLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppPalette.emerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: AppPalette.emerald,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pick All',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Drop All Button
          Expanded(
            child: GestureDetector(
              onTap: _dropAllStudents,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1E3A5F)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.blue.shade600.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.home_outlined,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Drop All',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Modern student card with enhanced styling
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showStudentActions(student),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? AppPalette.surfaceDark
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppPalette.surfaceSubtleLight,
                width: 1.5,
              ),
              boxShadow: isDarkMode
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Avatar with status indicator
                _buildStudentAvatar(student, statusColor, isDarkMode),
                const SizedBox(width: 16),
                
                // Name & Status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: provider.textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: isDarkMode ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Quick actions or status icon
                if (student.status == StudentStatus.pending) ...[
                  _buildQuickAction(
                    icon: Icons.check_rounded,
                    color: AppPalette.emerald,
                    onTap: () =>
                        _updateStudentStatus(student.id, StudentStatus.picked),
                  ),
                  const SizedBox(width: 10),
                  _buildQuickAction(
                    icon: Icons.close_rounded,
                    color: Colors.orange.shade600,
                    onTap: () =>
                        _updateStudentStatus(student.id, StudentStatus.absent),
                  ),
                ] else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      statusIcon,
                      size: 22,
                      color: statusColor,
                    ),
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
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppPalette.emerald, AppPalette.emeraldPressed],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppPalette.emerald.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'Pick Up',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        secondaryBackground: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade600,
                Colors.orange.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppPalette.warning.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
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
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 10),
              Icon(Icons.cancel_rounded, color: Colors.white, size: 28),
            ],
          ),
        ),
        child: card,
      );
    }

    return card;
  }

  Widget _buildStudentAvatar(Student student, Color statusColor, bool isDarkMode) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                statusColor.withValues(alpha: 0.2),
                statusColor.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: student.avatar.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    student.avatar,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildAvatarFallback(student.name, statusColor),
                  ),
                )
              : _buildAvatarFallback(student.name, statusColor),
        ),
        // Status indicator dot
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode ? AppPalette.surfaceDark : Colors.white,
                width: 3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarFallback(String name, Color color) {
    return Center(
      child: Text(
        _getInitials(name),
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  /// Floating action button for completing trip
  Widget _buildFloatingActionButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [AppPalette.emerald, AppPalette.emeraldPressed],
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.emerald.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _endTrip,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        icon: const Icon(Icons.check_circle_outline_rounded, size: 24),
        label: const Text(
          'Complete Trip',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  /// End the trip and navigate to dashboard
  Future<void> _endTrip() async {
    if (_trip == null) {
      // No trip to end, just go to dashboard
      Navigator.pushReplacementNamed(
        context,
        '/dashboard',
        arguments: {'fromTripEnd': true},
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Trip'),
        content: const Text('Are you sure you want to end this trip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.emerald,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final tripProvider = context.read<TripProvider>();
      final authProvider = context.read<AuthProvider>();

      final success = await tripProvider.endTrip(
        _trip!.id,
        driverId: authProvider.userId,
        driverName: authProvider.userName,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip completed successfully'),
              backgroundColor: AppPalette.emerald,
            ),
          );
          Navigator.pushReplacementNamed(
            context,
            '/dashboard',
            arguments: {'fromTripEnd': true},
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to complete trip: ${tripProvider.errorMessage ?? "Unknown error"}',
              ),
              backgroundColor: AppPalette.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppPalette.error),
        );
      }
    }
  }

  /// Pick all students in the trip
  Future<void> _pickAllStudents() async {
    if (_trip == null || _isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final tripProvider = context.read<TripProvider>();
      final ok = await tripProvider.pickAllStudents(_trip!.id);
      if (!ok) throw Exception(tripProvider.errorMessage ?? 'Request failed');

      setState(() {
        for (var i = 0; i < students.length; i++) {
          if (students[i].status == StudentStatus.pending) {
            students[i].status = StudentStatus.picked;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All students picked up'),
            backgroundColor: AppPalette.emerald,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to pick all students: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick all: $e'),
            backgroundColor: AppPalette.error,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  /// Drop all students in the trip
  Future<void> _dropAllStudents() async {
    if (_trip == null || _isUpdating) return;

    setState(() => _isUpdating = true);

    try {
      final tripProvider = context.read<TripProvider>();
      final ok = await tripProvider.dropAllStudents(_trip!.id);
      if (!ok) throw Exception(tripProvider.errorMessage ?? 'Request failed');

      setState(() {
        for (var i = 0; i < students.length; i++) {
          if (students[i].status == StudentStatus.picked) {
            students[i].status = StudentStatus.dropped;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All students dropped off'),
            backgroundColor: AppPalette.info,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to drop all students: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to drop all: $e'),
            backgroundColor: AppPalette.error,
          ),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showStudentActions(Student student) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = context.read<AppProvider>().isDarkMode;
        final statusColor = _getStatusColor(student.status);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : AppPalette.outlineLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Student avatar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    backgroundImage: student.avatar.isNotEmpty
                        ? NetworkImage(student.avatar)
                        : null,
                    child: student.avatar.isEmpty
                        ? Text(
                            _getInitials(student.name),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Student name
                Text(
                  student.name,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Current status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(student.status),
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getStatusLabel(student.status),
                        style: TextStyle(
                          fontSize: 14,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        icon: Icons.check_circle_rounded,
                        label: 'Pick Up',
                        color: AppPalette.emerald,
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
                const SizedBox(height: 12),
                
                // Drop Off button (only if picked)
                if (student.status == StudentStatus.picked)
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionBtn(
                      icon: Icons.home_rounded,
                      label: 'Drop Off',
                      color: Colors.blue.shade600,
                      enabled: true,
                      onTap: () {
                        _updateStudentStatus(student.id, StudentStatus.dropped);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // Reset button (if not pending)
                if (student.status != StudentStatus.pending)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _updateStudentStatus(student.id, StudentStatus.pending);
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: isDark ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
                      ),
                      label: Text(
                        'Reset to Pending',
                        style: TextStyle(
                          color: isDark ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : AppPalette.outlineLight,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
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
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: enabled
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.15),
                      color.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: enabled ? 0.3 : 0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
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
        return AppPalette.emerald;
      case StudentStatus.absent:
        return Colors.orange.shade600;
      case StudentStatus.dropped:
        return Colors.blue.shade600;
      case StudentStatus.pending:
        return Colors.blueGrey;
    }
  }

  String _getStatusLabel(StudentStatus status) {
    switch (status) {
      case StudentStatus.picked:
        return 'Picked Up';
      case StudentStatus.absent:
        return 'Absent';
      case StudentStatus.dropped:
        return 'Dropped Off';
      case StudentStatus.pending:
        return 'Pending';
    }
  }

  IconData _getStatusIcon(StudentStatus status) {
    switch (status) {
      case StudentStatus.picked:
        return Icons.check_circle_rounded;
      case StudentStatus.absent:
        return Icons.cancel_rounded;
      case StudentStatus.dropped:
        return Icons.home_rounded;
      case StudentStatus.pending:
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
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppPalette.emerald.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _searchController.text.isNotEmpty
                    ? Icons.search_off_rounded
                    : Icons.person_off_outlined,
                size: 48,
                color: AppPalette.emerald,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No matching students'
                  : 'No students here',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try adjusting your search'
                  : 'All students are in this category',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
                height: 1.5,
              ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear Search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.emerald,
                  side: const BorderSide(color: AppPalette.emerald),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
