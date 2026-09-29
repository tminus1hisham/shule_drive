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

import '../../theme/app_colors.dart';
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
  int _currentIndex = 3;
  
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

  void _handleNavigation(int index) {
    if (index == _currentIndex) return; // Already on this tab
    
    switch (index) {
      case 0:
        // Home/Landing
        Navigator.pushReplacementNamed(context, '/dashboard');
        break;
      case 1:
        // Chat
        Navigator.pushNamed(context, '/chat');
        break;
      case 2:
        // Notifications
        Navigator.pushNamed(context, '/notifications');
        break;
      case 3:
        // Settings/Profile
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final children = provider.apiStudents;
    final isLoading = provider.isLoading;
    final errorMessage = provider.errorMessage;

    return MainScaffold(
      title: 'My Children',
      showBackButton: true,
      showBottomNav: true,
      bottomNavIndex: _currentIndex,
      onBottomNavTap: _handleNavigation,
      floatingActionButton: _buildSpeedDialFab(provider),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchGuardianStudents(),
        child: _buildBody(context, provider, children, isLoading, errorMessage),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppProvider provider,
    List<api.Student> children,
    bool isLoading,
    String? errorMessage,
  ) {
    // Show loading
    if (isLoading && children.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppPalette.emerald),
      );
    }

    // Show error
    if (errorMessage != null && children.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: provider.textMutedColor),
            const SizedBox(height: 16),
            Text(
              'Error loading children',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(fontSize: 14, color: provider.textMutedColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => provider.fetchGuardianStudents(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.emerald,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (children.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.child_care,
              size: 80,
              color: provider.textMutedColor.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'No children added yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: provider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add your first child',
              style: TextStyle(fontSize: 14, color: provider.textMutedColor),
            ),
          ],
        ),
      );
    }

    // Show children list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: children.length,
      itemBuilder: (context, index) {
        final child = children[index];
        return _buildChildCard(context, provider, child);
      },
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

  /// Build Speed Dial FAB with expandable options
  Widget _buildSpeedDialFab(AppProvider provider) {
    // Ensure controller is initialized
    if (_fabController == null) {
      return FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppPalette.emerald,
        child: const Icon(Icons.add),
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Secondary option: Add Extended Guardian
        _speedDialOption(
          _isFabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      _toggleFab();
                      _showAddExtendedGuardianDialog(context, provider);
                    },
                    backgroundColor: AppPalette.emerald.withAlpha(230),
                    icon: const Icon(Icons.people_outline, size: 20),
                    label: const Text(
                      'Add Guardian',
                      style: TextStyle(fontSize: 13),
                    ),
                    heroTag: 'addGuardian',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Primary option: Add Child
        _speedDialOption(
          _isFabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      _toggleFab();
                      _showAddChildDialog(context);
                    },
                    backgroundColor: AppPalette.emerald,
                    icon: const Icon(Icons.person_add, size: 20),
                    label: const Text(
                      'Add Child',
                      style: TextStyle(fontSize: 13),
                    ),
                    heroTag: 'addChild',
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Main FAB - toggles the menu
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: AppPalette.emerald,
          child: AnimatedBuilder(
            animation: _fabController!,
            builder: (context, child) {
              return Transform.rotate(
                angle: AppCurves.easeInOut.transform(_fabController!.value) *
                    0.785398,
                child: const Icon(Icons.add, size: 28),
              );
            },
          ),
          heroTag: 'mainFab',
        ),
      ],
    );
  }

  Widget _buildChildCard(
    BuildContext context,
    AppProvider provider,
    api.Student child,
  ) {
    return Dismissible(
      key: Key(child.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.colors.error,
          borderRadius: AppRadius.brLg,
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Child?'),
            content: Text('Are you sure you want to remove ${child.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final success = await provider.deleteChildAPI(child.id);
        if (success && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${child.name} removed')));
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
          border: Border.all(color: context.colors.outline),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _showImagePickerOptions(context, child),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildProfileImage(child.photo, provider),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xxs),
                        decoration: BoxDecoration(
                          color: context.colors.brand,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.scheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
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
                        color: context.colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.vXs,
                    Row(
                      children: [
                        Icon(
                          Icons.route,
                          size: 14,
                          color: child.route != null
                              ? context.colors.brand
                              : context.colors.textMuted,
                        ),
                        AppSpacing.hXxs,
                        Expanded(
                          child: Text(
                            child.route ?? 'No route assigned',
                            style: context.text.labelMedium?.copyWith(
                              color: child.route != null
                                  ? context.colors.brand
                                  : context.colors.textMuted,
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
              if (child.guardianPhone != null &&
                  child.guardianPhone!.isNotEmpty)
                IconButton(
                  tooltip: 'Guardian contact',
                  onPressed: () => _showGuardianPhone(context, child),
                  icon: const Icon(Icons.phone_outlined, size: 20),
                  color: context.colors.brand,
                  style: IconButton.styleFrom(
                    backgroundColor: context.colors.brandSoft,
                  ),
                ),
              Icon(Icons.chevron_right, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Show dialog to add extended guardian
  void _showAddExtendedGuardianDialog(
    BuildContext context,
    AppProvider provider,
  ) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: provider.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppPalette.outlineLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  'Add Extended Guardian',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: provider.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add another guardian who can track and manage all your children',
                  style: TextStyle(
                    fontSize: 14,
                    color: provider.textMutedColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Name Field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter guardian name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppPalette.outlineLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppPalette.emerald),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Phone Field
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g., +254 712 345 678',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppPalette.outlineLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppPalette.emerald),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Relationship Field
                TextField(
                  controller: relationshipController,
                  decoration: InputDecoration(
                    labelText: 'Relationship (Optional)',
                    hintText: 'e.g., Father, Aunt, Uncle',
                    prefixIcon: const Icon(Icons.people_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppPalette.outlineLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppPalette.emerald),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Add Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
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
                    icon: const Icon(Icons.person_add),
                    label: const Text(
                      'Add Guardian',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.emerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: provider.textMutedColor,
                        fontSize: 15,
                      ),
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

  /// Add extended guardian (placeholder - connect to API as needed)
  void _addExtendedGuardian({
    required BuildContext context,
    required String name,
    required String phone,
    String? relationship,
  }) {
    // TODO: Connect to your API to add extended guardian
    // For now, show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Extended guardian "$name" added successfully'),
        backgroundColor: AppPalette.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Build profile image with placeholder
  Widget _buildProfileImage(String? photoUrl, AppProvider provider) {
    // Default placeholder widget
    Widget placeholder = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppPalette.emerald.withAlpha(50),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: AppPalette.emerald, size: 32),
    );

    if (photoUrl == null || photoUrl.isEmpty) {
      return ClipOval(child: placeholder);
    }

    return ClipOval(
      child: Image.network(
        photoUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppPalette.emerald.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppPalette.emerald),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return placeholder;
        },
      ),
    );
  }

  /// Show guardian phone number dialog
  void _showGuardianPhone(BuildContext context, api.Student child) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.outlineLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileImage(child.photo, context.read<AppProvider>()),
            const SizedBox(height: 16),
            Text(
              child.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Guardian Contact',
              style: TextStyle(fontSize: 14, color: AppPalette.textSecondaryLight),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppPalette.emerald.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: AppPalette.emerald),
                  const SizedBox(width: 12),
                  Text(
                    child.guardianPhone!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.emerald,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => _callGuardian(child.guardianPhone!),
                icon: const Icon(Icons.call),
                label: const Text('Call Guardian'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Call guardian using device's phone app
  Future<void> _callGuardian(String phone) async {
    if (kDebugMode) {
      print('📞 Attempting to call guardian: $phone');
    }

    // Clean up the phone number (remove spaces, dashes, parentheses, etc.)
    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    
    // Ensure phone starts with + for international format, or add country code if needed
    final formattedPhone = cleanPhone.startsWith('+') 
        ? cleanPhone 
        : (cleanPhone.startsWith('0') 
            ? '+254${cleanPhone.substring(1)}'  // Convert 0... to +254... for Kenya
            : (cleanPhone.startsWith('254') 
                ? '+$cleanPhone' 
                : '+254$cleanPhone'));
    
    // Create tel: URI
    final uri = Uri(scheme: 'tel', path: formattedPhone);
    
    if (kDebugMode) {
      print('📞 Formatted phone: $formattedPhone');
      print('📞 Launch URI: $uri');
    }
    
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open phone dialer. Please check your phone app.'),
              backgroundColor: AppPalette.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error launching phone dialer: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening dialer: $e'),
            backgroundColor: AppPalette.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
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
    final provider = context.read<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppPalette.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.emerald.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppPalette.emerald),
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  'Use camera to take a photo',
                  style: TextStyle(
                    color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // Request camera permission first
                  final hasPermission =
                      await PermissionHelper.requestCameraPermission(context);
                  if (hasPermission && context.mounted) {
                    await _pickAndUploadImage(
                      context,
                      child,
                      ImageSource.camera,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.info.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: AppPalette.info,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  'Select a photo from your gallery',
                  style: TextStyle(
                    color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // Request photo library permission first
                  final hasPermission =
                      await PermissionHelper.requestPhotoLibraryPermission(
                        context,
                      );
                  if (hasPermission && context.mounted) {
                    await _pickAndUploadImage(
                      context,
                      child,
                      ImageSource.gallery,
                    );
                  }
                },
              ),
              if (child.photo != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppPalette.error.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: AppPalette.error),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: AppPalette.error),
                  ),
                  subtitle: Text(
                    'Delete current profile photo',
                    style: TextStyle(
                      color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeStudentImage(context, child);
                  },
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
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
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppPalette.emerald),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child.name}\'s photo updated successfully'),
            backgroundColor: AppPalette.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to upload photo. Please try again.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child.name}\'s photo removed'),
            backgroundColor: AppPalette.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to remove photo'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
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
    final provider = context.read<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppPalette.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.emerald.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppPalette.emerald),
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // Request camera permission first
                  final hasPermission =
                      await PermissionHelper.requestCameraPermission(context);
                  if (hasPermission && context.mounted) {
                    _pickImage(ImageSource.camera);
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.info.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: AppPalette.info,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // Request photo library permission first
                  final hasPermission =
                      await PermissionHelper.requestPhotoLibraryPermission(
                        context,
                      );
                  if (hasPermission && context.mounted) {
                    _pickImage(ImageSource.gallery);
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDarkMode = provider.isDarkMode;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: provider.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Child',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: provider.textColor,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: provider.textMutedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your child\'s details below',
                  style: TextStyle(
                    fontSize: 14,
                    color: provider.textMutedColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Profile Photo
                Center(
                  child: GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppPalette.emerald.withAlpha(30),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppPalette.emerald.withAlpha(50),
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
                              ? const Icon(
                                  Icons.add_a_photo,
                                  color: AppPalette.emerald,
                                  size: 40,
                                )
                              : null,
                        ),
                        // Edit badge
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppPalette.emerald,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: provider.backgroundColor,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _selectedImage != null
                        ? 'Change Photo'
                        : 'Add Photo (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      color: provider.textMutedColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Name Field
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g. John Doe',
                  icon: Icons.person,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter child\'s name';
                    }
                    if (value.trim().length < 3) {
                      return 'Name must be at least 3 characters';
                    }
                    return null;
                  },
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // Class Field (Optional)
                _buildTextField(
                  controller: _classController,
                  label: 'Class/Grade (Optional)',
                  hint: 'e.g. Class 4 West',
                  icon: Icons.school,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // School Dropdown (Required)
                _buildSchoolDropdown(provider, isDarkMode),
                const SizedBox(height: 16),

                // Route/Pickup Location Dropdown (Required)
                _buildRouteDropdown(provider, isDarkMode),
                const SizedBox(height: 24),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.emerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: const Color(
                        0xFF6B9B5B,
                      ).withAlpha(128),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Add Child',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  /// Build School Dropdown
  Widget _buildSchoolDropdown(AppProvider provider, bool isDarkMode) {
    final schools = _getSchoolsFromRoutes(provider.routes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'School *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: provider.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppPalette.surfaceSubtleDark
                : AppPalette.surfaceSubtleLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedSchool,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.account_balance,
                color: AppPalette.emerald,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            hint: Text(
              'Select School',
              style: TextStyle(
                color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
              ),
            ),
            dropdownColor: isDarkMode ? AppPalette.surfaceSubtleDark : Colors.white,
            style: TextStyle(
              color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
              fontSize: 15,
            ),
            icon: const Icon(Icons.arrow_drop_down, color: AppPalette.emerald),
            items: schools.map((school) {
              return DropdownMenuItem<String>(
                value: school,
                child: Text(school, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSchool = value;
                // Reset route when school changes (optional - routes might be school-specific)
                _selectedRoute = null;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a school';
              }
              return null;
            },
          ),
        ),
        if (schools.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No schools available. Please check your routes.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
          ),
      ],
    );
  }

  /// Build Route/Pickup Location Dropdown
  Widget _buildRouteDropdown(AppProvider provider, bool isDarkMode) {
    final routes = _getRouteNames(provider.routes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Route (Pickup Location) *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: provider.textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppPalette.surfaceSubtleDark
                : AppPalette.surfaceSubtleLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRoute,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.route, color: AppPalette.emerald),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            hint: Text(
              'Select Route',
              style: TextStyle(
                color: isDarkMode ? AppPalette.textSecondaryDark : AppPalette.textSecondaryLight,
              ),
            ),
            dropdownColor: isDarkMode ? AppPalette.surfaceSubtleDark : Colors.white,
            style: TextStyle(
              color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
              fontSize: 15,
            ),
            icon: const Icon(Icons.arrow_drop_down, color: AppPalette.emerald),
            items: routes.map((route) {
              return DropdownMenuItem<String>(
                value: route,
                child: Text(route, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRoute = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select a route';
              }
              return null;
            },
          ),
        ),
        if (routes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No routes available.',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: isDarkMode ? AppPalette.textPrimaryDark : AppPalette.textPrimaryLight,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppPalette.emerald),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDarkMode
            ? AppPalette.surfaceSubtleDark
            : AppPalette.surfaceSubtleLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
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
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: AppPalette.emerald),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${student.name} added successfully!')),
      );
    }
  }
}
