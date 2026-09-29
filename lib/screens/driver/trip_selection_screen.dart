import 'package:flutter/material.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/ui/ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../api/services/trip_service.dart';
import '../../models/master_trip.dart';
import '../../models/preloaded_trip_data.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';

/// Trip Selection Screen
/// Displays available master trips for the driver to select from
class TripSelectionScreen extends StatefulWidget {
  const TripSelectionScreen({super.key});

  @override
  State<TripSelectionScreen> createState() => _TripSelectionScreenState();
}

class _TripSelectionScreenState extends State<TripSelectionScreen> {
  final TripService _tripService = TripService();

  bool _isLoading = true;
  String? _error;
  List<MasterTrip> _masterTrips = [];
  MasterTrip? _selectedTrip;

  // Pre-loaded trip data for instant navigation
  PreloadedTripData? _preloadedData;
  bool _isPreloading = false;

  @override
  void initState() {
    super.initState();
    _loadMasterTrips();
  }

  Future<void> _loadMasterTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final driverId = authProvider.currentUser?.id;
      if (driverId == null || driverId.isEmpty) {
        setState(() {
          _error = 'Driver ID not found. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      debugPrint('🚌 TripSelection: Loading trips for driver ID: $driverId');

      // Use cache-first pattern: show cached data immediately, refresh in background
      final trips = await _tripService.getMasterTripsByDriverCached(
        driverId,
        onRefresh: (freshTrips) {
          // Background refresh callback - update UI with fresh data
          if (mounted && freshTrips.isNotEmpty) {
            debugPrint(
              '🔄 TripSelection: Background refresh with ${freshTrips.length} trips',
            );
            setState(() {
              _masterTrips = freshTrips;
            });
            // Show subtle indicator that data was updated
            AppSnackbar.info(context, 'Trips updated');
          }
        },
      );

      debugPrint(
        '🚌 TripSelection: Loaded ${trips.length} trips (from cache or API)',
      );

      if (mounted) {
        setState(() {
          _masterTrips = trips;
          _isLoading = false;
        });

        // Dashboard's "trip starting soon" prompt names the trip to open;
        // otherwise auto-advance when there's only one.
        final args = ModalRoute.of(context)?.settings.arguments;
        final autoId = args is Map ? args['autoSelectTripId'] : null;
        final requested = trips.where((t) => t.id == autoId).firstOrNull;
        if (requested != null) {
          _onTripSelected(requested);
        } else if (trips.length == 1) {
          _onTripSelected(trips.first);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ TripSelection: Error loading trips: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Failed to load trips. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _onTripSelected(MasterTrip trip) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedTrip = trip;
    });

    // Pre-load trip data in background and auto-advance
    _preloadTripData(trip).then((_) {
      if (mounted) {
        _onContinue();
      }
    });
  }

  /// Pre-load all trip data in background
  Future<void> _preloadTripData(MasterTrip trip) async {
    if (_isPreloading) return;

    setState(() {
      _isPreloading = true;
    });

    try {
      debugPrint('🚀 Pre-loading trip data for: ${trip.tripName}');

      final tripData = await _tripService.fetchCompleteTripData(
        masterTrip: trip,
      );

      if (mounted) {
        setState(() {
          _preloadedData = PreloadedTripData(
            masterTrip: tripData['masterTrip'],
            students: tripData['students'],
            vehicle: tripData['vehicle'],
            routeId: tripData['routeId'],
          );
          _isPreloading = false;
        });

        debugPrint('✅ Trip data pre-loaded:');
        debugPrint('   📊 Students: ${_preloadedData!.students.length}');
        debugPrint(
          '   🚗 Vehicle: ${_preloadedData!.vehicle?.registrationNumber ?? 'Not selected'}',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to pre-load trip data: $e');
      if (mounted) {
        setState(() {
          _isPreloading = false;
          _preloadedData = null;
        });
      }
    }
  }

  void _onContinue() {
    if (_selectedTrip == null) return;

    HapticFeedback.mediumImpact();

    // Navigate to vehicle selection with pre-loaded data (as Map for serialization)
    Navigator.pushNamed(
      context,
      '/vehicle-selection',
      arguments: {
        'masterTrip': _selectedTrip,
        'preloadedData': _preloadedData?.toJson(),
      },
    );
  }

  Future<void> _manageTrips() async {
    await Navigator.pushNamed(context, '/manage-master-trips');
    if (mounted) await _loadMasterTrips();
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_isLoading && _error == null && _masterTrips.isNotEmpty;

    return MainScaffold(
      title: 'Select Trip',
      showBackButton: false,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: AsyncBody(
                    loading: _isLoading,
                    error: _error,
                    onRetry: _loadMasterTrips,
                    isEmpty: _masterTrips.isEmpty,
                    skeleton: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: 4,
                      itemBuilder: (_, _) => const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppSkeleton(
                          height: 104,
                          borderRadius: AppRadius.brLg,
                        ),
                      ),
                    ),
                    empty: EmptyState(
                      icon: Icons.calendar_today_rounded,
                      title: 'No Scheduled Trips',
                      message:
                          'You don\'t have any master trips assigned. '
                          'Create a trip before starting your journey.',
                      actionLabel: 'Manage Trips',
                      onAction: _manageTrips,
                    ),
                    onRefresh: _loadMasterTrips,
                    child: _buildTripsList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: ready ? _buildBottomButton() : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: context.colors.brandGradient,
              borderRadius: AppRadius.brXl,
              boxShadow: [
                BoxShadow(
                  color: context.colors.brand.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 36,
            ),
          ).pop(),
          AppSpacing.vLg,
          Text(
            'Your Scheduled Trips',
            style: context.text.headlineSmall,
          ).enter(delay: const Duration(milliseconds: 80)),
          AppSpacing.vXs,
          Text(
            'Select a trip to get started',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ).enter(delay: const Duration(milliseconds: 120)),
        ],
      ),
    );
  }

  Widget _buildTripsList() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: _masterTrips.length,
      separatorBuilder: (_, _) => AppSpacing.vSm,
      itemBuilder: (context, index) {
        final trip = _masterTrips[index];
        final isSelected = _selectedTrip?.id == trip.id;
        return _buildTripCard(
          trip,
          isSelected,
          isSelected && _isPreloading,
        ).enterList(index);
      },
    );
  }

  Widget _buildTripCard(MasterTrip trip, bool isSelected, bool isPreloading) {
    final c = context.colors;
    final dateFormat = DateFormat('EEE, MMM d');
    final meta = context.text.bodySmall?.copyWith(color: c.textSecondary);

    Widget metaRow(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.textMuted),
        const SizedBox(width: 4),
        Text(text, style: meta),
      ],
    );

    return SelectableCard(
      selected: isSelected,
      onTap: () => _onTripSelected(trip),
      child: Row(
        children: [
          // The bus tile turns into a spinner while this trip preloads.
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isSelected ? c.brandGradient : null,
              color: isSelected ? null : c.brandSoft,
              borderRadius: AppRadius.brSm,
            ),
            child: AnimatedSwitcher(
              duration: AppDuration.medium,
              child: isPreloading
                  ? const Padding(
                      key: ValueKey('loading'),
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.directions_bus_rounded,
                      key: ValueKey(isSelected),
                      color: isSelected ? Colors.white : c.brand,
                    ),
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.tripName,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trip.route,
                  style: context.text.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                AppSpacing.vXs,
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    metaRow(Icons.access_time_rounded, trip.tripTime),
                    metaRow(
                      Icons.calendar_today_rounded,
                      dateFormat.format(trip.createdAt),
                    ),
                    if (trip.numberPlate != null &&
                        trip.numberPlate!.isNotEmpty)
                      metaRow(
                        Icons.confirmation_number_outlined,
                        trip.numberPlate!,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return BottomActionBar(
      primary: AppButton(
        label: 'Continue',
        icon: Icons.arrow_forward_rounded,
        iconTrailing: true,
        loading: _isPreloading,
        onPressed: _selectedTrip != null ? _onContinue : null,
      ),
      secondary: AppButton(
        label: 'Manage Trips',
        variant: AppButtonVariant.tertiary,
        size: AppButtonSize.medium,
        onPressed: _manageTrips,
      ),
    ).enter(offsetY: 40);
  }
}
