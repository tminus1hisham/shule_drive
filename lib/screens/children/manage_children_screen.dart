import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permission_helper.dart';
import '../../widgets/main_scaffold.dart';

class ManageChildrenScreen extends StatefulWidget {
  const ManageChildrenScreen({super.key});

  @override
  State<ManageChildrenScreen> createState() => _ManageChildrenScreenState();
}

class _ManageChildrenScreenState extends State<ManageChildrenScreen> {
  int _currentIndex = 3;

  @override
  void initState() {
    super.initState();
    // Fetch children when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().fetchGuardianStudents();
    });
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
      onBottomNavTap: (index) {
        setState(() => _currentIndex = index);
        if (index == 0) {
          Navigator.pushReplacementNamed(context, '/landing');
        }
      },
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChildDialog(context),
        backgroundColor: const Color(0xFF6B9B5B),
        child: const Icon(Icons.add),
      ),
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
        child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
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
                backgroundColor: const Color(0xFF6B9B5B),
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
              color: provider.textMutedColor.withValues(alpha: 128),
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

  Widget _buildChildCard(
    BuildContext context,
    AppProvider provider,
    api.Student child,
  ) {
    return Dismissible(
      key: Key(child.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
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
                  backgroundColor: Colors.red,
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
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(
          context,
          '/child-profile',
          arguments: {'childId': child.id},
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: provider.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 13),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Profile Image with placeholder
              GestureDetector(
                onTap: () => _showImagePickerOptions(context, child),
                child: Stack(
                  children: [
                    _buildProfileImage(child.photo, provider),
                    // Edit icon overlay
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B9B5B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: provider.cardColor,
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
              const SizedBox(width: 16),
              // Child Info: fullName, schoolName, route
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    Text(
                      child.name.isNotEmpty ? child.name : 'Unknown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: provider.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // School Name
                    Text(
                      child.schoolName ?? 'No School',
                      style: TextStyle(
                        fontSize: 13,
                        color: provider.textMutedColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Route
                    Row(
                      children: [
                        Icon(
                          Icons.route,
                          size: 12,
                          color: const Color(0xFF6B9B5B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            child.route ?? 'No Route Assigned',
                            style: TextStyle(
                              fontSize: 12,
                              color: child.route != null
                                  ? const Color(0xFF6B9B5B)
                                  : provider.textMutedColor,
                              fontWeight: child.route != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Phone icon - shows guardian phone on tap
              if (child.guardianPhone != null &&
                  child.guardianPhone!.isNotEmpty)
                GestureDetector(
                  onTap: () => _showGuardianPhone(context, child),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B9B5B).withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Color(0xFF6B9B5B),
                      size: 20,
                    ),
                  ),
                )
              else
                const SizedBox(width: 40),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: provider.textMutedColor),
            ],
          ),
        ),
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
        color: const Color(0xFF6B9B5B).withAlpha(50),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Color(0xFF6B9B5B), size: 32),
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
              color: const Color(0xFF6B9B5B).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9B5B)),
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
                color: Colors.grey.shade300,
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
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6B9B5B).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: Color(0xFF6B9B5B)),
                  const SizedBox(width: 12),
                  Text(
                    child.guardianPhone!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B9B5B),
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
                onPressed: () {
                  // TODO: Implement phone call functionality
                  // url_launcher can be used: launchUrl(Uri.parse('tel:${child.guardianPhone}'))
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Calling ${child.guardianPhone}...'),
                      backgroundColor: const Color(0xFF6B9B5B),
                    ),
                  );
                },
                icon: const Icon(Icons.call),
                label: const Text('Call Guardian'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
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
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B9B5B).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF6B9B5B)),
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: Text(
                  'Use camera to take a photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
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
                    color: const Color(0xFF2196F3).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF2196F3),
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                  ),
                ),
                subtitle: Text(
                  'Select a photo from your gallery',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
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
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: Text(
                    'Delete current profile photo',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
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
          child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
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
            backgroundColor: const Color(0xFF6B9B5B),
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
            backgroundColor: const Color(0xFF6B9B5B),
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
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                  color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B9B5B).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF6B9B5B)),
                ),
                title: Text(
                  'Take Photo',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
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
                    color: const Color(0xFF2196F3).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF2196F3),
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
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
                            color: const Color(0xFF6B9B5B).withAlpha(30),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF6B9B5B).withAlpha(50),
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
                                  color: Color(0xFF6B9B5B),
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
                              color: const Color(0xFF6B9B5B),
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
                      backgroundColor: const Color(0xFF6B9B5B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: const Color(
                        0xFF6B9B5B,
                      ).withValues(alpha: 128),
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
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedSchool,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.account_balance,
                color: Color(0xFF6B9B5B),
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
                color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              fontSize: 15,
            ),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6B9B5B)),
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
                ? const Color(0xFF2C2C2C)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRoute,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.route, color: Color(0xFF6B9B5B)),
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
                color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            dropdownColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
            style: TextStyle(
              color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
              fontSize: 15,
            ),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6B9B5B)),
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
        color: isDarkMode ? Colors.white : const Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6B9B5B)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: isDarkMode
            ? const Color(0xFF2C2C2C)
            : const Color(0xFFF5F5F5),
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
            child: CircularProgressIndicator(color: Color(0xFF6B9B5B)),
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
