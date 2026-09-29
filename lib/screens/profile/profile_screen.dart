import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/trip_history_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/autoload_trips_toggle.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Real trip stats from TripHistoryService
  DriverStats _driverStats = DriverStats.empty();

  @override
  void initState() {
    super.initState();
    _loadRealStats();
  }

  Future<void> _loadRealStats() async {
    final authProvider = context.read<AuthProvider>();
    final driverId = authProvider.userId ?? '';
    if (driverId.isEmpty) return;

    try {
      final historyService = TripHistoryService();
      final stats = await historyService.getDriverStats(driverId);
      if (mounted) {
        setState(() {
          _driverStats = stats;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load driver stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;

    return MainScaffold(
      title: 'Profile',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 3,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              _buildProfileHeader(userData, authProvider).enter(),
              AppSpacing.vXl,
              if (authProvider.isDriver) ...[
                _buildStatsCard().enterList(1),
                AppSpacing.vXl,
                _buildPreferencesSection(context).enterList(2),
                AppSpacing.vXl,
              ],
              _buildMenuSection(context).enterList(3),
              AppSpacing.vXl,
              AppButton(
                label: 'Logout',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.danger,
                onPressed: _confirmLogout,
              ).enterList(4),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    // AuthWrapper handles navigation once logged out.
    if (confirmed && mounted) await context.read<AuthProvider>().logout();
  }

  void _showImagePickerOptions(
    BuildContext parentContext,
    AuthProvider authProvider,
  ) {
    Future<void> pick(BuildContext sheet, ImageSource source) async {
      Navigator.pop(sheet);
      // Small delay to ensure bottom sheet is fully closed
      await Future.delayed(const Duration(milliseconds: 200));
      if (!parentContext.mounted) return;
      final bool hasPermission;
      if (source == ImageSource.camera) {
        hasPermission = await PermissionHelper.requestCameraPermission(
          parentContext,
        );
      } else {
        hasPermission = await PermissionHelper.requestPhotoLibraryPermission(
          parentContext,
        );
      }
      if (hasPermission && parentContext.mounted) {
        await _pickAndUploadImage(parentContext, authProvider, source);
      }
    }

    showAppBottomSheet<void>(
      context: parentContext,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Update Profile Photo',
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          AppSpacing.vSm,
          AppListTile(
            icon: Icons.camera_alt_rounded,
            title: 'Take Photo',
            subtitle: 'Use camera to take a photo',
            onTap: () => pick(sheet, ImageSource.camera),
          ).enterList(0),
          AppListTile(
            icon: Icons.photo_library_rounded,
            title: 'Choose from Gallery',
            subtitle: 'Select a photo from your gallery',
            iconColor: sheet.colors.info,
            onTap: () => pick(sheet, ImageSource.gallery),
          ).enterList(1),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    AuthProvider authProvider,
    ImageSource source,
  ) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null || !context.mounted) return;

      // Loading indicator on the root navigator to avoid context issues
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) => Center(
          child: GlassPanel(
            child: CircularProgressIndicator(color: dialogContext.colors.brand),
          ),
        ),
      );

      final avatarUrl = await authProvider.updateUserAvatar(pickedFile.path);

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      if (avatarUrl != null) {
        AppSnackbar.success(context, 'Profile photo updated successfully');
      } else {
        AppSnackbar.error(context, 'Failed to upload photo. Please try again.');
      }
    } catch (e, stackTrace) {
      debugPrint('📸 Error in _pickAndUploadImage: $e\n$stackTrace');
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be closed
        }
        AppSnackbar.error(context, 'Error: $e');
      }
    }
  }

  Widget _buildProfileHeader(
    Map<String, dynamic> userData,
    AuthProvider authProvider,
  ) {
    final c = context.colors;
    final avatar = userData['avatar'];
    final meta = context.text.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.9),
    );

    Widget line(IconData icon, String text) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text(text, style: meta),
      ],
    );

    return GradientHeroCard(
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showImagePickerOptions(context, authProvider),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 3,
                    ),
                  ),
                  child: AppAvatar(
                    imageUrl:
                        avatar is String &&
                            (avatar.startsWith('http://') ||
                                avatar.startsWith('https://'))
                        ? avatar
                        : null,
                    name: userData['name']?.toString(),
                    size: 90,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ).pop(),
          AppSpacing.vMd,
          Text(
            userData['name'],
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          AppSpacing.vXs,
          StatusPill(
            label: userData['role'],
            color: Colors.white,
            icon: Icons.verified_user_outlined,
            dense: true,
          ),
          AppSpacing.vMd,
          line(Icons.phone_outlined, userData['phone']),
          AppSpacing.vXxs,
          line(Icons.email_outlined, userData['email']),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final c = context.colors;
    // Numbers count up from zero, so the brief "0" before stats load reads
    // as the start of the roll rather than wrong data.
    Widget stat(IconData icon, int value, String label, Color color) => Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        AppSpacing.vXs,
        AnimatedCount(
          value,
          countUp: true,
          style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: context.text.labelSmall?.copyWith(color: c.textSecondary),
        ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: stat(
                Icons.route_outlined,
                _driverStats.totalTrips,
                'Trips',
                c.brand,
              ),
            ),
            VerticalDivider(color: c.outline, width: 1),
            Expanded(
              child: stat(
                Icons.people_outline_rounded,
                _driverStats.totalStudents,
                'Students',
                c.info,
              ),
            ),
            VerticalDivider(color: c.outline, width: 1),
            Expanded(
              child: stat(
                Icons.check_circle_outline_rounded,
                _driverStats.totalPicked,
                'Picked Up',
                c.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Driver preferences card — currently just the autoload switch.
  Widget _buildPreferencesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Preferences',
          padding: EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.sm),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: const AutoloadTripsToggle(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context) {
    final c = context.colors;
    final items = [
      (
        Icons.person_outline_rounded,
        'Edit Profile',
        'Update your information',
        '/edit-profile',
        c.brand,
      ),
      (
        Icons.lock_outline_rounded,
        'Change Password',
        'Update your security',
        '/change-password',
        c.info,
      ),
      (
        Icons.phone_outlined,
        'Contact',
        'Get in touch with us',
        '/contact',
        c.accent,
      ),
      (
        Icons.description_outlined,
        'Terms of Service',
        'Legal information',
        '/terms',
        c.textSecondary,
      ),
      (
        Icons.privacy_tip_outlined,
        'Privacy Policy',
        'Data protection',
        '/privacy',
        c.textSecondary,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (final item in items) ...[
            AppListTile(
              icon: item.$1,
              title: item.$2,
              subtitle: item.$3,
              iconColor: item.$5,
              onTap: () => Navigator.pushNamed(context, item.$4),
            ),
            Divider(
              height: 1,
              indent: 68,
              endIndent: AppSpacing.md,
              color: c.outline,
            ),
          ],
          AppListTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            subtitle: 'Remove your data',
            destructive: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
