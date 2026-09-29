import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/main_scaffold.dart';

import '../../theme/app_colors.dart';
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  String _completePhoneNumber = '';
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final userData = context.read<AuthProvider>().userData;
    _nameController = TextEditingController(text: userData['name']);
    _phoneController = TextEditingController(text: userData['phone']);
    _emailController = TextEditingController(text: userData['email'] ?? '');
    _completePhoneNumber = userData['phone'] ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (kDebugMode) {
        print('📷 Picking image from: $source');
      }

      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (kDebugMode) {
        print('📷 Picked file: ${pickedFile?.path}');
      }

      if (pickedFile != null) {
        // Check if file exists
        final file = File(pickedFile.path);
        final exists = await file.exists();
        final size = exists ? await file.length() : 0;
        
        if (kDebugMode) {
          print('📷 File exists: $exists, Size: $size bytes');
        }

        if (!exists) {
          if (mounted) _showError('Selected file does not exist');
          return;
        }

        if (mounted) {
          setState(() {
            _selectedImage = file;
          });
        }
        
        // Small delay to ensure setState completes before upload
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Automatically upload after selection
        // Use a separate method to avoid mounted issues
        if (mounted) {
          await _uploadProfilePicture();
        } else {
          if (kDebugMode) print('⚠️ Widget not mounted after picking image');
        }
      } else {
        if (kDebugMode) print('❌ No file picked');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Error picking image: $e');
        print(stackTrace);
      }
      if (mounted) _showError('Failed to pick image: $e');
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_selectedImage == null) {
      if (kDebugMode) print('❌ No image selected');
      return;
    }

    // Store file path locally in case widget gets unmounted
    final imagePath = _selectedImage!.path;
    
    // Verify file still exists before uploading
    final exists = await _selectedImage!.exists();
    if (!exists) {
      if (kDebugMode) print('❌ Selected file no longer exists');
      if (mounted) {
        _showError('Selected file no longer exists. Please try again.');
        setState(() => _selectedImage = null);
      }
      return;
    }

    if (kDebugMode) {
      print('📤 Starting upload from screen...');
      print('  Image path: $imagePath');
      print('  File size: ${await _selectedImage!.length()} bytes');
    }

    // Store context reference before async operations
    final currentContext = context;
    final authProvider = currentContext.read<AuthProvider>();

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppPalette.emerald),
        ),
      );
    }

    String? imageUrl;
    String? errorMsg;
    
    try {
      imageUrl = await authProvider.updateProfilePicture(imagePath);

      if (kDebugMode) {
        print('📤 Upload result: $imageUrl');
      }
    } catch (e, stackTrace) {
      errorMsg = e.toString();
      if (kDebugMode) {
        print('❌ Exception during upload: $e');
        print(stackTrace);
      }
    }

    // Wait a moment for widget to remount if it was unmounted
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) {
      if (kDebugMode) print('⚠️ Widget not mounted after upload attempt');
      return;
    }
    
    // Close loading dialog
    Navigator.pop(context);

    if (imageUrl != null && imageUrl.isNotEmpty) {
      _showSuccess('Profile picture updated successfully');
      setState(() {
        _selectedImage = null; // Clear selected image
      });
    } else {
      errorMsg ??= authProvider.errorMessage ?? 'Failed to upload profile picture';
      if (kDebugMode) print('❌ Upload failed: $errorMsg');
      _showError(errorMsg);
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
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
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
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Please enter your name');
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.updateUserProfile(
      name: _nameController.text.trim(),
      phone: _completePhoneNumber.isNotEmpty ? _completePhoneNumber : null,
      email: _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success) {
      _showSuccess('Profile updated successfully');
      Navigator.pop(context);
    } else {
      _showError(authProvider.errorMessage ?? 'Failed to update profile');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppPalette.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;

    return MainScaffold(
      title: 'Edit Profile',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card with Avatar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Avatar with tap to change
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Stack(
                      children: [
                        _buildAvatar(userData['avatar']),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppPalette.emerald,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: provider.cardColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userData['name'] ?? 'User',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: provider.textColor,
                    ),
                  ),
                  Text(
                    userData['role']?.toString().toUpperCase() ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.textMutedColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _showImagePickerOptions,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Change Photo'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.emerald,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Form Fields
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: provider.cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    'Full Name',
                    _nameController,
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildPhoneField(),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Email',
                    _emailController,
                    Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Changes Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: authProvider.isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: const Color(
                    0xFF6B9B5B,
                  ).withValues(alpha: 0.5),
                ),
                child: authProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build avatar widget with proper image handling
  Widget _buildAvatar(String? avatarUrl) {
    // If we have a selected image file, show it
    if (_selectedImage != null) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: FileImage(_selectedImage!),
        backgroundColor: AppPalette.outlineLight,
      );
    }

    // If we have a valid network URL, show it
    if (avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      return CircleAvatar(
        radius: 50,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: AppPalette.outlineLight,
        onBackgroundImageError: (e, s) {
          // Fallback to placeholder on error
          if (kDebugMode) print('⚠️ Failed to load avatar: $e');
        },
      );
    }

    // Default placeholder
    return CircleAvatar(
      radius: 50,
      backgroundColor: AppPalette.emerald.withAlpha(50),
      child: const Icon(Icons.person, size: 50, color: AppPalette.emerald),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    final provider = context.watch<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: provider.textMutedColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: provider.textColor),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: provider.textMutedColor),
            filled: true,
            fillColor: provider.isDarkMode
                ? AppPalette.textSecondaryLight
                : AppPalette.surfaceSubtleLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    final provider = context.watch<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: provider.textMutedColor,
          ),
        ),
        const SizedBox(height: 8),
        IntlPhoneField(
          controller: _phoneController,
          decoration: InputDecoration(
            hintText: '712 345 678',
            hintStyle: TextStyle(color: AppPalette.textMutedLight),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: provider.isDarkMode
                ? AppPalette.textSecondaryLight
                : AppPalette.surfaceSubtleLight,
          ),
          style: TextStyle(color: provider.textColor),
          dropdownTextStyle: TextStyle(color: provider.textColor),
          initialCountryCode: 'KE',
          disableLengthCheck: true,
          onChanged: (phone) {
            _completePhoneNumber = phone.completeNumber;
          },
        ),
      ],
    );
  }
}
