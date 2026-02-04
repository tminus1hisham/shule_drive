import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../api/api.dart' as api;
import '../../providers/app_provider.dart';
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
        child: CircularProgressIndicator(
          color: Color(0xFF6B9B5B),
        ),
      );
    }

    // Show error
    if (errorMessage != null && children.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: provider.textMutedColor,
            ),
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
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
              ),
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
              style: TextStyle(
                fontSize: 14,
                color: provider.textMutedColor,
              ),
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
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${child.name} removed')),
          );
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
              GestureDetector(
                onTap: () => _showImagePickerOptions(context, child),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: child.photo != null
                          ? NetworkImage(child.photo!)
                          : null,
                      backgroundColor: const Color(0xFF6B9B5B).withAlpha(50),
                      child: child.photo == null
                          ? const Icon(
                              Icons.person,
                              color: Color(0xFF6B9B5B),
                              size: 32,
                            )
                          : null,
                    ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: provider.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      child.schoolName ?? 'No School',
                      style: TextStyle(
                        fontSize: 13,
                        color: provider.textMutedColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      child.className,
                      style: TextStyle(
                        fontSize: 12,
                        color: provider.textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: provider.textMutedColor,
              ),
            ],
          ),
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
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF6B9B5B),
                  ),
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
                  final hasPermission = await PermissionHelper.requestCameraPermission(context);
                  if (hasPermission && context.mounted) {
                    await _pickAndUploadImage(context, child, ImageSource.camera);
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
                  final hasPermission = await PermissionHelper.requestPhotoLibraryPermission(context);
                  if (hasPermission && context.mounted) {
                    await _pickAndUploadImage(context, child, ImageSource.gallery);
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
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to upload photo. Please try again.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _removeStudentImage(BuildContext context, api.Student child) async {
    try {
      final provider = context.read<AppProvider>();
      await provider.updateChildAPI(
        studentId: child.id,
        photo: null,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${child.name}\'s photo removed'),
            backgroundColor: const Color(0xFF6B9B5B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}

/// Add Child Form with Validation
class AddChildForm extends StatefulWidget {
  const AddChildForm({super.key});

  @override
  State<AddChildForm> createState() => _AddChildFormState();
}

class _AddChildFormState extends State<AddChildForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _classController = TextEditingController();
  final _schoolController = TextEditingController();
  final _pickupController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  bool _isLoading = false;
  XFile? _selectedImage;

  @override
  void dispose() {
    _nameController.dispose();
    _classController.dispose();
    _schoolController.dispose();
    _pickupController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
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
                  child: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF6B9B5B),
                  ),
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
                  final hasPermission = await PermissionHelper.requestCameraPermission(context);
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
                  final hasPermission = await PermissionHelper.requestPhotoLibraryPermission(context);
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
                      icon: Icon(
                        Icons.close,
                        color: provider.textMutedColor,
                      ),
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
                                    image: FileImage(File(_selectedImage!.path)),
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
                    _selectedImage != null ? 'Change Photo' : 'Add Photo (Optional)',
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

                // Class Field
                _buildTextField(
                  controller: _classController,
                  label: 'Class/Grade',
                  hint: 'e.g. Class 4 West',
                  icon: Icons.school,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter class or grade';
                    }
                    return null;
                  },
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // School Field
                _buildTextField(
                  controller: _schoolController,
                  label: 'School (Optional)',
                  hint: 'e.g. Ozone Valley Day School',
                  icon: Icons.account_balance,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // Pickup Location Field
                _buildTextField(
                  controller: _pickupController,
                  label: 'Pickup Location (Optional)',
                  hint: 'e.g. Home Address',
                  icon: Icons.location_on,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),

                // Emergency Contact Section
                Text(
                  'Emergency Contact (Optional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: provider.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emergencyContactController,
                  label: 'Contact Name',
                  hint: 'e.g. Jane Doe',
                  icon: Icons.contact_phone,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emergencyPhoneController,
                  label: 'Contact Phone',
                  hint: 'e.g. +254 712 345 678',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Simple phone validation
                      final phoneRegex = RegExp(r'^[+\d\s\-\(\)]{10,}$');
                      if (!phoneRegex.hasMatch(value)) {
                        return 'Please enter a valid phone number';
                      }
                    }
                    return null;
                  },
                  isDarkMode: isDarkMode,
                ),
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
                      disabledBackgroundColor:
                          const Color(0xFF6B9B5B).withValues(alpha: 128),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
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
        fillColor: isDarkMode ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

    final student = await provider.addChildAPI(
      name: _nameController.text.trim(),
      className: _classController.text.trim(),
      schoolId: _schoolController.text.trim().isEmpty
          ? null
          : _schoolController.text.trim(),
      photo: photoUrl,
      pickupLocation: _pickupController.text.trim().isEmpty
          ? null
          : _pickupController.text.trim(),
      emergencyContact: _emergencyContactController.text.trim().isEmpty
          ? null
          : _emergencyContactController.text.trim(),
      emergencyPhone: _emergencyPhoneController.text.trim().isEmpty
          ? null
          : _emergencyPhoneController.text.trim(),
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
