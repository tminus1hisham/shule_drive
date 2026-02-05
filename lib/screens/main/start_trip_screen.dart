import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';

/// Start Trip Screen - Beautiful, modern trip initialization
class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen>
    with TickerProviderStateMixin {
  String? _selectedVehicle;
  String? _selectedRoute;
  String? _selectedAttendant;

  bool _isLoading = false;
  int _currentStep = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final provider = context.read<AppProvider>();

    if (kDebugMode) {
      print('🚀 StartTripScreen: Loading data from API...');
    }

    try {
      // Fetch all routes and buses from API
      await Future.wait([
        provider.fetchRoutes(), // GET /api/routes/get/all
        provider.fetchBuses(), // GET /api/buses/get/all
      ]);

      if (kDebugMode) {
        print('✅ StartTripScreen: Data loaded successfully');
        print('📍 Routes: ${provider.routes.length}');
        print('🚌 Buses: ${provider.buses.length}');
        for (final route in provider.routes) {
          print('  - Route: ${route.name} (ID: ${route.id})');
        }
        for (final bus in provider.buses) {
          print('  - Bus: ${bus.registrationNumber} (ID: ${bus.id})');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ StartTripScreen: Error loading data: $e');
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _canStartTrip => _selectedRoute != null && _selectedVehicle != null;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDarkMode = provider.isDarkMode;

    return MainScaffold(
      title: 'New Trip',
      showBackButton: true,
      showBottomNav: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [const Color(0xFF1A1A1A), const Color(0xFF0D0D0D)]
                : [const Color(0xFFF5F5F0), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section with Animation
              _buildHeader(isDarkMode, authProvider),

              // Progress Indicator
              _buildProgressIndicator(isDarkMode),

              // Main Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _isLoading
                        ? _buildLoadingState(isDarkMode)
                        : _buildSelectionContent(provider, isDarkMode),
                  ),
                ),
              ),

              // Bottom Action Button
              _buildBottomButton(isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode, AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Animated Bus Icon
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B9B5B).withAlpha(100),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Ready to Roll?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure your trip details below',
            style: TextStyle(
              fontSize: 15,
              color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildStepDot(0, 'Route', isDarkMode),
          _buildStepLine(_selectedRoute != null, isDarkMode),
          _buildStepDot(1, 'Vehicle', isDarkMode),
          _buildStepLine(_selectedVehicle != null, isDarkMode),
          _buildStepDot(2, 'Attendant', isDarkMode),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label, bool isDarkMode) {
    final isActive = step <= _currentStep;
    final isCompleted =
        step < _currentStep ||
        (step == 0 && _selectedRoute != null) ||
        (step == 1 && _selectedVehicle != null) ||
        (step == 2 && _selectedAttendant != null);

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: isCompleted
                  ? const LinearGradient(
                      colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                    )
                  : null,
              color: isCompleted
                  ? null
                  : isActive
                  ? const Color(0xFF6B9B5B).withAlpha(30)
                  : isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? const Color(0xFF6B9B5B) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? const Color(0xFF6B9B5B)
                            : isDarkMode
                            ? Colors.white38
                            : Colors.grey,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive
                  ? const Color(0xFF6B9B5B)
                  : isDarkMode
                  ? Colors.white38
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isCompleted, bool isDarkMode) {
    return Expanded(
      flex: 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 3,
        margin: const EdgeInsets.only(bottom: 25),
        decoration: BoxDecoration(
          gradient: isCompleted
              ? const LinearGradient(
                  colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                )
              : null,
          color: isCompleted
              ? null
              : isDarkMode
              ? const Color(0xFF2C2C2C)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your trips...',
            style: TextStyle(
              color: isDarkMode ? Colors.white60 : Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionContent(AppProvider provider, bool isDarkMode) {
    final routes = provider.routes;
    final buses = provider.buses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route Selection
          _buildSectionTitle('Select Route', isDarkMode),
          const SizedBox(height: 12),
          ...routes.map((route) {
            final title = route.schoolName ?? 'School Route';
            final subtitle = route.name.isNotEmpty
                ? route.name
                : 'Route ${route.id}';
            

            if (kDebugMode) {
              print(
                '🛣️ Route Card: id=${route.id}, title=$title, school=$subtitle',
              );
            }

            return _buildSelectionCard(
              title: title,
              subtitle: subtitle,
              icon: Icons.route,
              isSelected: _selectedRoute == route.id, // Use ID for selection
              onTap: () {
                setState(() {
                  _selectedRoute = route.id; // Store ID instead of name
                  _currentStep = 1;
                });
                HapticFeedback.lightImpact();
              },
              isDarkMode: isDarkMode,
            );
          }),

          if (routes.isEmpty)
            _buildEmptyState('No routes available', isDarkMode),

          const SizedBox(height: 28),

          // Vehicle Selection
          _buildSectionTitle('Select Vehicle', isDarkMode),
          const SizedBox(height: 12),
          ...buses.map((bus) {
            // Try multiple possible field names for the numberplate
            final numberplate = bus.registrationNumber.isNotEmpty
                ? bus.registrationNumber
                : 'Vehicle ${bus.id}';
            final subtitle = bus.capacity != null && bus.capacity!.isNotEmpty
                ? '${bus.capacity} seats'
                : 'School Bus';

            if (kDebugMode) {
              print(
                '🚌 Bus Card: id=${bus.id}, numberplate=$numberplate, capacity=${bus.capacity}',
              );
            }

            return _buildSelectionCard(
              title: numberplate,
              subtitle: subtitle,
              icon: Icons.directions_bus_filled,
              isSelected: _selectedVehicle == bus.id, // Use ID for selection
              onTap: () {
                setState(() {
                  _selectedVehicle = bus.id; // Store ID instead of numberplate
                  _currentStep = 2;
                });
                HapticFeedback.lightImpact();
              },
              isDarkMode: isDarkMode,
            );
          }),

          if (buses.isEmpty)
            _buildEmptyState('No vehicles available', isDarkMode),

          const SizedBox(height: 28),

          // Attendant Selection
          _buildSectionTitle('Select Attendant (Optional)', isDarkMode),
          const SizedBox(height: 12),
          _buildAttendantChips(isDarkMode),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF6B9B5B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                    )
                  : null,
              color: isSelected
                  ? null
                  : isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : isDarkMode
                    ? Colors.white12
                    : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6B9B5B).withAlpha(100),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDarkMode ? 30 : 10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withAlpha(30)
                        : const Color(0xFF6B9B5B).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : const Color(0xFF6B9B5B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : isDarkMode
                              ? Colors.white
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? Colors.white.withAlpha(230)
                              : isDarkMode
                              ? Colors.white60
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : isDarkMode
                          ? Colors.white24
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Color(0xFF6B9B5B),
                          size: 18,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendantChips(bool isDarkMode) {
    final attendants = ['James Kadere', 'John Doe', 'Jane Smith', 'None'];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: attendants.map((attendant) {
        final isSelected =
            _selectedAttendant == attendant ||
            (attendant == 'None' && _selectedAttendant == null);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedAttendant = attendant == 'None' ? null : attendant;
                });
                HapticFeedback.lightImpact();
              },
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF6B9B5B), Color(0xFF5A8A4A)],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : isDarkMode
                        ? Colors.white12
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check, color: Colors.white, size: 16),
                    if (isSelected) const SizedBox(width: 8),
                    Text(
                      attendant,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isDarkMode
                            ? Colors.white70
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String message, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: isDarkMode ? Colors.white38 : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDarkMode ? Colors.white60 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isDarkMode
                ? const Color(0xFF0D0D0D).withAlpha(0)
                : Colors.white.withAlpha(0),
            isDarkMode ? const Color(0xFF0D0D0D) : Colors.white,
          ],
        ),
      ),
      child: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _canStartTrip
                ? () {
                    HapticFeedback.mediumImpact();
                    Navigator.pushNamed(context, '/select-students');
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B9B5B),
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDarkMode
                  ? const Color(0xFF2C2C2C)
                  : Colors.grey.shade300,
              disabledForegroundColor: isDarkMode
                  ? Colors.white38
                  : Colors.grey,
              elevation: _canStartTrip ? 8 : 0,
              shadowColor: const Color(0xFF6B9B5B).withAlpha(100),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _canStartTrip
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Start Trip',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(Icons.arrow_forward_rounded),
                      ],
                    )
                  : const Text(
                      'Select Route & Vehicle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
