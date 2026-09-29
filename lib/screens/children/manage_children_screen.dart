import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/main_scaffold.dart';

import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/ui/ui.dart';

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen>
    with SingleTickerProviderStateMixin {
  // FAB animation controller
  AnimationController? _fabController;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Fetch children when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchGuardianStudents();
    });
  }

  @override
  void dispose() {
    _fabController?.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabController?.forward();
      } else {
        _fabController?.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final children = provider.apiStudents;

    return MainScaffold(
      title: 'My Children',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: 3,
      floatingActionButton: _buildSpeedDialFab(provider),
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          AsyncBody(
            loading: provider.isLoading && children.isEmpty,
            error: children.isEmpty ? provider.errorMessage : null,
            onRetry: provider.fetchGuardianStudents,
            isEmpty: children.isEmpty,
            empty: const EmptyState(
              icon: Icons.child_care_rounded,
              title: 'No children added yet',
              message: 'Tap the + button to add your first child',
            ),
            onRefresh: provider.fetchGuardianStudents,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                96, // clear the FAB
              ),
              itemCount: children.length,
              itemBuilder: (context, index) => _buildChildCard(
                context,
                provider,
                children[index],
              ).enterList(index),
            ),
          ),
        ],
      ),
    );
  }

  /// Speed-dial options grow out of the main FAB (bottom-right) instead of
  /// popping in fully formed.
  Widget _speedDialOption(Widget child) {
    return AnimatedSize(
      duration: AppDuration.fast,
      curve: AppCurves.easeOut,
      child: AnimatedSwitcher(
        duration: AppDuration.fast,
        switchInCurve: AppCurves.easeOut,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(animation),
            alignment: Alignment.bottomRight,
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }

  /// Speed-dial FAB: Add Child / Add Guardian fan out above it.
  Widget _buildSpeedDialFab(AppProvider provider) {
    final c = context.colors;
    Widget option(
      String tag,
      IconData icon,
      String label,
      VoidCallback onTap,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: FloatingActionButton.extended(
        heroTag: tag,
        onPressed: () {
          _toggleFab();
          onTap();
        },
        backgroundColor: context.scheme.surface,
        foregroundColor: c.brand,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _speedDialOption(
          _isFabExpanded
              ? option(
                  'addGuardian',
                  Icons.people_outline_rounded,
                  'Add Guardian',
                  () => _showAddExtendedGuardianDialog(context, provider),
                )
              : const SizedBox.shrink(),
        ),
        _speedDialOption(
          _isFabExpanded
              ? option(
                  'addChild',
                  Icons.person_add_rounded,
                  'Add Child',
                  () => _showAddChildDialog(context),
                )
              : const SizedBox.shrink(),
        ),
        FloatingActionButton(
          heroTag: 'mainFab',
          onPressed: _toggleFab,
          backgroundColor: c.brand,
          foregroundColor: context.scheme.onPrimary,
          tooltip: _isFabExpanded ? 'Close' : 'Add',
          child: AnimatedBuilder(
            animation: _fabController!,
            builder: (context, child) => Transform.rotate(
              angle:
                  AppCurves.easeInOut.transform(_fabController!.value) *
                  0.785398,
              child: child,
            ),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
        ).pop(delay: const Duration(milliseconds: 250)),
      ],
    );
  }

  Widget _buildChildCard(
    BuildContext context,
    AppProvider provider,
    api.Student child,
  ) {
    final c = context.colors;
    return Dismissible(
      key: Key(child.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.error.withValues(alpha: 0.75), c.error],
          ),
          borderRadius: AppRadius.brLg,
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Remove',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: AppSpacing.xs),
            Icon(Icons.delete_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (_) => confirmDialog(
        context,
        title: 'Delete Child?',
        message: 'Are you sure you want to remove ${child.name}?',
        confirmLabel: 'Delete',
        icon: Icons.delete_outline_rounded,
        destructive: true,
      ),
      onDismissed: (_) async {
        final success = await provider.deleteChildAPI(child.id);
        if (success && context.mounted) {
          AppSnackbar.success(context, '${child.name} removed');
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        // Flat + hairline outline: a list of peers doesn't need elevation.
        child: AppCard(
          onTap: () => Navigator.pushNamed(
            context,
            '/child-profile',
            arguments: {'childId': child.id},
          ),
          shadow: const [],
          border: Border.all(color: c.outline),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showImagePickerOptions(context, child),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Flies to the child profile header.
                    Hero(
                      tag: 'child-avatar-${child.id}',
                      child: AppAvatar(
                        imageUrl: child.photo,
                        name: child.name,
                        size: 64,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.scheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name.isNotEmpty ? child.name : 'Unknown',
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.vXxs,
                    Text(
                      child.schoolName ?? 'No School',
                      style: context.text.bodySmall?.copyWith(
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.vXs,
                    StatusPill(
                      label: child.route ?? 'No route assigned',
                      color: child.route != null ? c.brand : c.textMuted,
                      icon: Icons.route_rounded,
                      dense: true,
                    ),
                  ],
                ),
              ),
              if (child.guardianPhone != null &&
                  child.guardianPhone!.isNotEmpty)
                IconButton(
                  tooltip: 'Guardian contact',
                  onPressed: () => _showGuardianPhone(context, child),
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  color: c.brand,
                  style: IconButton.styleFrom(backgroundColor: c.brandSoft),
                ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Show sheet to add an extended guardian
  void _showAddExtendedGuardianDialog(
    BuildContext context,
    AppProvider provider,
  ) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    showAppBottomSheet<void>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Add Extended Guardian',
            subtitle:
                'Add another guardian who can track and manage all your '
                'children',
          ),
          AppSpacing.vLg,
          AppTextField(
            controller: nameController,
            label: 'Full Name',
            hint: 'Enter guardian name',
            prefixIcon: Icons.person_outline_rounded,
          ).enterList(0),
          AppSpacing.vMd,
          AppTextField(
            controller: phoneController,
            label: 'Phone Number',
            hint: 'e.g., +254 712 345 678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ).enterList(1),
          AppSpacing.vMd,
          AppTextField(
            controller: relationshipController,
            label: 'Relationship (Optional)',
            hint: 'e.g., Father, Aunt, Uncle',
            prefixIcon: Icons.people_outline_rounded,
          ).enterList(2),
          AppSpacing.vXl,
          AppButton(
            label: 'Add Guardian',
            icon: Icons.person_add_rounded,
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  phoneController.text.isNotEmpty) {
                _addExtendedGuardian(
                  context: context,
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  relationship: relationshipController.text.trim(),
                );
                Navigator.pop(context);
              }
            },
          ),
          AppSpacing.vXs,
          AppButton(
            label: 'Cancel',
            variant: AppButtonVariant.tertiary,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Add extended guardian (placeholder - connect to API as needed)
  void _addExtendedGuardian({
    required BuildContext context,
    required String name,
    required String phone,
    String? relationship,
  }) {
    // TODO: Connect to your API to add extended guardian
    // For now, show a success message
    AppSnackbar.success(
      context,
      'Extended guardian "$name" added successfully',
    );
  }

  /// Show guardian phone number sheet
  void _showGuardianPhone(BuildContext context, api.Student child) {
    showAppBottomSheet<void>(
      context: context,
      builder: (context) {
        final c = context.colors;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAvatar(imageUrl: child.photo, name: child.name, size: 72).pop(),
            AppSpacing.vMd,
            Text(child.name, style: context.text.headlineSmall),
            AppSpacing.vXxs,
            Text(
              'Guardian Contact',
              style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
            AppSpacing.vMd,
            AppCard(
              color: c.brandSoft,
              shadow: const [],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone_rounded, color: c.brand),
                  AppSpacing.hSm,
                  Text(
                    child.guardianPhone!,
                    style: context.text.titleMedium?.copyWith(
                      color: c.onBrandSoft,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ).enter(delay: const Duration(milliseconds: 80)),
            AppSpacing.vXl,
            AppButton(
              label: 'Call Guardian',
              icon: Icons.call_rounded,
              onPressed: () => _callGuardian(child.guardianPhone!),
            ),
            AppSpacing.vXs,
            AppButton(
              label: 'Close',
              variant: AppButtonVariant.tertiary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  /// Call guardian using device's phone app
  Future<void> _callGuardian(String phone) async {
    if (kDebugMode) debugPrint('📞 Attempting to call guardian: $phone');

    // Clean up the phone number (remove spaces, dashes, parentheses, etc.)
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Ensure phone starts with + for international format, or add country code if needed
    final formattedPhone = cleanPhone.startsWith('+')
        ? cleanPhone
        : (cleanPhone.startsWith('0')
              ? '+254${cleanPhone.substring(1)}' // Convert 0... to +254... for Kenya
              : (cleanPhone.startsWith('254')
                    ? '+$cleanPhone'
                    : '+254$cleanPhone'));

    final uri = Uri(scheme: 'tel', path: formattedPhone);

    try {
      // Try to launch directly without canLaunchUrl check
      // On Android 11+, canLaunchUrl may return false even when dialer is available
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        // If external application mode fails, try platform default
        final fallbackLaunched = await launchUrl(uri);

        if (!fallbackLaunched && mounted) {
          AppSnackbar.error(
            context,
            'Could not open phone dialer. Please check your phone app.',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error launching phone dialer: $e');
      if (mounted) AppSnackbar.error(context, 'Error opening dialer: $e');
    }
  }

  void _showAddChildDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddChildForm(),
    );
  }

  void _showImagePickerOptions(BuildContext context, api.Student child) {
    showAppBottomSheet<void>(
      context: context,
      builder: (context) => Column(
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
            onTap: () async {
              Navigator.pop(context);
              // Request camera permission first
              final hasPermission =
                  await PermissionHelper.requestCameraPermission(context);
              if (hasPermission && context.mounted) {
                await _pickAndUploadImage(context, child, ImageSource.camera);
              }
            },
          ).enterList(0),
          AppListTile(
            icon: Icons.photo_library_rounded,
            title: 'Choose from Gallery',
            subtitle: 'Select a photo from your gallery',
            iconColor: context.colors.info,
            onTap: () async {
              Navigator.pop(context);
              // Request photo library permission first
              final hasPermission =
                  await PermissionHelper.requestPhotoLibraryPermission(context);
              if (hasPermission && context.mounted) {
                await _pickAndUploadImage(context, child, ImageSource.gallery);
              }
            },
          ).enterList(1),
          if (child.photo != null)
            AppListTile(
              icon: Icons.delete_outline_rounded,
              title: 'Remove Photo',
              subtitle: 'Delete current profile photo',
              destructive: true,
              onTap: () {
                Navigator.pop(context);
                _removeStudentImage(context, child);
              },
            ).enterList(2),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(
    BuildContext context,
    api.Student child,
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

      if (pickedFile == null) return;

      if (!context.mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: GlassPanel(
            child: CircularProgressIndicator(color: context.colors.brand),
          ),
        ),
      );

      if (!context.mounted) return;
      final provider = context.read<AppProvider>();
      final imageUrl = await provider.uploadStudentImage(
        studentId: child.id,
        imagePath: pickedFile.path,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (imageUrl != null) {
        AppSnackbar.success(
          context,
          '${child.name}\'s photo updated successfully',
        );
      } else if (context.mounted) {
        AppSnackbar.error(context, 'Failed to upload photo. Please try again.');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        AppSnackbar.error(context, 'Error: $e');
      }
    }
  }

  Future<void> _removeStudentImage(
    BuildContext context,
    api.Student child,
  ) async {
    try {
      final provider = context.read<AppProvider>();
      await provider.updateChildAPI(studentId: child.id, photo: null);

      if (context.mounted) {
        AppSnackbar.success(context, '${child.name}\'s photo removed');
      }
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, 'Failed to remove photo');
    }
  }
}

/// Add Child Form with Dropdowns for School and Route
class AddChildForm extends StatefulWidget {
  const AddChildForm({super.key});

  @override
  State<AddChildForm> createState() => _AddChildFormState();
}

class _AddChildFormState extends State<AddChildForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _classController = TextEditingController();

  // Dropdown selections
  String? _selectedSchool;
  String? _selectedRoute;

  bool _isLoading = false;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    // Fetch routes when form opens (for school and route dropdowns)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchRoutes();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    super.dispose();
  }

  /// Get unique schools from routes
  List<String> _getSchoolsFromRoutes(List<api.BusRoute> routes) {
    final schools = routes
        .where((r) => r.schoolName != null && r.schoolName!.isNotEmpty)
        .map((r) => r.schoolName!)
        .toSet()
        .toList();
    schools.sort();
    return schools;
  }

  /// Get unique route names from routes
  List<String> _getRouteNames(List<api.BusRoute> routes) {
    final routeNames = routes
        .where((r) => r.name.isNotEmpty)
        .map((r) => r.name)
        .toSet()
        .toList();
    routeNames.sort();
    return routeNames;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _showImagePickerOptions() {
    showAppBottomSheet<void>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Add Profile Photo',
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          AppSpacing.vSm,
          AppListTile(
            icon: Icons.camera_alt_rounded,
            title: 'Take Photo',
            onTap: () async {
              Navigator.pop(context);
              // Request camera permission first
              final hasPermission =
                  await PermissionHelper.requestCameraPermission(context);
              if (hasPermission && context.mounted) {
                _pickImage(ImageSource.camera);
              }
            },
          ).enterList(0),
          AppListTile(
            icon: Icons.photo_library_rounded,
            title: 'Choose from Gallery',
            iconColor: context.colors.info,
            onTap: () async {
              Navigator.pop(context);
              // Request photo library permission first
              final hasPermission =
                  await PermissionHelper.requestPhotoLibraryPermission(context);
              if (hasPermission && context.mounted) {
                _pickImage(ImageSource.gallery);
              }
            },
          ).enterList(1),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final c = context.colors;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.outline,
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
                AppSpacing.vSm,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add Child',
                        style: context.text.headlineSmall,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                  ],
                ),
                Text(
                  'Enter your child\'s details below',
                  style: context.text.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                AppSpacing.vXl,

                // Profile Photo
                Center(
                  child: GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Stack(
                      children: [
                        AnimatedSwitcher(
                          duration: AppDuration.medium,
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: Container(
                            key: ValueKey(_selectedImage?.path),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: c.brandSoft,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.brand.withValues(alpha: 0.3),
                                width: 2,
                              ),
                              image: _selectedImage != null
                                  ? DecorationImage(
                                      image: FileImage(
                                        File(_selectedImage!.path),
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _selectedImage == null
                                ? Icon(
                                    Icons.add_a_photo_rounded,
                                    color: c.brand,
                                    size: 40,
                                  )
                                : null,
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
                              border: Border.all(
                                color: context.scheme.surface,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).pop(),
                ),
                AppSpacing.vXs,
                Center(
                  child: Text(
                    _selectedImage != null
                        ? 'Change Photo'
                        : 'Add Photo (Optional)',
                    style: context.text.labelMedium?.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                ),
                AppSpacing.vXl,

                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g. John Doe',
                  prefixIcon: Icons.person_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter child\'s name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                ).enterList(0),
                AppSpacing.vMd,
                AppTextField(
                  controller: _classController,
                  label: 'Class/Grade (Optional)',
                  hint: 'e.g. Class 4 West',
                  prefixIcon: Icons.school_rounded,
                ).enterList(1),
                AppSpacing.vMd,
                _buildDropdown(
                  label: 'School *',
                  hint: 'Select School',
                  icon: Icons.account_balance_rounded,
                  value: _selectedSchool,
                  items: _getSchoolsFromRoutes(provider.routes),
                  emptyNote: 'No schools available. Please check your routes.',
                  onChanged: (value) => setState(() {
                    _selectedSchool = value;
                    // Reset route when school changes (routes may be school-specific)
                    _selectedRoute = null;
                  }),
                  validatorMessage: 'Please select a school',
                ).enterList(2),
                AppSpacing.vMd,
                _buildDropdown(
                  label: 'Route (Pickup Location) *',
                  hint: 'Select Route',
                  icon: Icons.route_rounded,
                  value: _selectedRoute,
                  items: _getRouteNames(provider.routes),
                  emptyNote: 'No routes available.',
                  onChanged: (value) => setState(() => _selectedRoute = value),
                  validatorMessage: 'Please select a route',
                ).enterList(3),
                AppSpacing.vXxl,
                AppButton(
                  label: 'Add Child',
                  icon: Icons.person_add_rounded,
                  loading: _isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required String emptyNote,
    required ValueChanged<String?> onChanged,
    required String validatorMessage,
  }) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.titleSmall),
        AppSpacing.vXs,
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: value,
          isExpanded: true,
          decoration: InputDecoration(prefixIcon: Icon(icon, color: c.brand)),
          hint: Text(hint),
          borderRadius: AppRadius.brMd,
          icon: Icon(Icons.expand_more_rounded, color: c.brand),
          items: [
            for (final item in items)
              DropdownMenuItem<String>(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
          validator: (v) => v == null || v.isEmpty ? validatorMessage : null,
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              emptyNote,
              style: context.text.labelSmall?.copyWith(color: c.warning),
            ),
          ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<AppProvider>();

    String? photoUrl;

    // Upload image if selected
    if (_selectedImage != null) {
      // Show loading for image upload
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: GlassPanel(
              child: CircularProgressIndicator(color: context.colors.brand),
            ),
          ),
        );
      }

      // For new students, we need to create the student first, then upload the image
      // This is a simplified approach - in production, you might want to handle this differently
    }

    // Get logged-in guardian's phone number
    final authProvider = context.read<AuthProvider>();
    final guardianPhone = authProvider.userPhone;

    // Create student using guardian API
    // Required fields: fullname, schoolname, route (pickup location)
    final student = await provider.addChildAPI(
      fullname: _nameController.text.trim(),
      schoolname: _selectedSchool,
      classname: _classController.text.trim().isEmpty
          ? null
          : _classController.text.trim(),
      route: _selectedRoute,
      pickupLocation: _selectedRoute, // Using route as pickup location
      photo: photoUrl,
      guardianPhoneNumber: guardianPhone,
    );

    // Upload image after student is created (if image was selected)
    if (student != null && _selectedImage != null && mounted) {
      await provider.uploadStudentImage(
        studentId: student.id,
        imagePath: _selectedImage!.path,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
    }

    setState(() => _isLoading = false);

    if (student != null && mounted) {
      Navigator.pop(context);
      AppSnackbar.success(context, '${student.name} added successfully!');
    }
  }
}
