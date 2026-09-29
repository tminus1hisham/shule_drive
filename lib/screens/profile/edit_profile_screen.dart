import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/main_scaffold.dart';
import '../../widgets/ui/ui.dart';

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

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();

    // Show loading
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
      errorMsg ??=
          authProvider.errorMessage ?? 'Failed to upload profile picture';
      if (kDebugMode) print('❌ Upload failed: $errorMsg');
      _showError(errorMsg);
    }
  }

  void _showImagePickerOptions() {
    showAppBottomSheet<void>(
      context: context,
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
            onTap: () {
              Navigator.pop(sheet);
              _pickImage(ImageSource.camera);
            },
          ).enterList(0),
          AppListTile(
            icon: Icons.photo_library_rounded,
            title: 'Choose from Gallery',
            iconColor: sheet.colors.info,
            onTap: () {
              Navigator.pop(sheet);
              _pickImage(ImageSource.gallery);
            },
          ).enterList(1),
        ],
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

  void _showError(String message) => AppSnackbar.error(context, message);

  void _showSuccess(String message) => AppSnackbar.success(context, message);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authProvider = context.watch<AuthProvider>();
    final userData = authProvider.userData;

    return MainScaffold(
      title: 'Edit Profile',
      showBackButton: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackdrop()),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              GradientHeroCard(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: Stack(
                        children: [
                          // The freshly picked photo cross-fades in.
                          AnimatedSwitcher(
                            duration: AppDuration.slow,
                            child: KeyedSubtree(
                              key: ValueKey(_selectedImage?.path),
                              child: _buildAvatar(userData['avatar']),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: c.accent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).pop(),
                    AppSpacing.vMd,
                    Text(
                      userData['name'] ?? 'User',
                      style: context.text.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    AppSpacing.vXxs,
                    StatusPill(
                      label: userData['role']?.toString().toUpperCase() ?? '',
                      color: Colors.white,
                      showDot: false,
                      dense: true,
                    ),
                    AppSpacing.vSm,
                    AppButton(
                      label: 'Change Photo',
                      icon: Icons.camera_alt_rounded,
                      variant: AppButtonVariant.onBrand,
                      size: AppButtonSize.small,
                      expand: false,
                      onPressed: _showImagePickerOptions,
                    ),
                  ],
                ),
              ).enter(),
              AppSpacing.vMd,
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      label: 'Full Name',
                      controller: _nameController,
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                    ),
                    AppSpacing.vMd,
                    Text('Phone Number', style: context.text.titleSmall),
                    AppSpacing.vXs,
                    IntlPhoneField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: '712 345 678',
                      ),
                      style: context.text.bodyLarge,
                      dropdownTextStyle: context.text.bodyLarge,
                      initialCountryCode: 'KE',
                      disableLengthCheck: true,
                      onChanged: (phone) {
                        _completePhoneNumber = phone.completeNumber;
                      },
                    ),
                    AppSpacing.vXs,
                    AppTextField(
                      label: 'Email',
                      controller: _emailController,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ).enterList(1),
              AppSpacing.vXl,
              AppButton(
                label: 'Save Changes',
                icon: Icons.check_rounded,
                loading: authProvider.isLoading,
                onPressed: _saveProfile,
              ).enterList(2),
            ],
          ),
        ],
      ),
    );
  }

  /// Picked file first, then a valid network URL, else initials.
  Widget _buildAvatar(String? avatarUrl) {
    if (_selectedImage != null) {
      return Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          image: DecorationImage(
            image: FileImage(_selectedImage!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    final valid =
        avatarUrl != null &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));
    return AppAvatar(
      imageUrl: valid ? avatarUrl : null,
      name: context.read<AuthProvider>().userData['name']?.toString(),
      size: 100,
      borderColor: Colors.white,
    );
  }
}
