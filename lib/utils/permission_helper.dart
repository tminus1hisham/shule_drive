import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/ui/ui.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class for handling app permissions
class PermissionHelper {
  /// Request camera permission
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showSettingsDialog(
          context,
          title: 'Camera Permission Required',
          message: 'Please enable camera access in settings to take photos.',
        );
      }
      return false;
    } else {
      if (context.mounted) {
        _showPermissionDeniedSnackBar(
          context,
          'Camera permission is required to take photos.',
        );
      }
      return false;
    }
  }

  /// Request photo library/gallery permission
  static Future<bool> requestPhotoLibraryPermission(
    BuildContext context,
  ) async {
    PermissionStatus status;

    if (Platform.isIOS) {
      status = await Permission.photos.request();
    } else {
      // For Android, check storage permission
      if (Platform.version.contains('33') || Platform.version.contains('13')) {
        // Android 13+ uses READ_MEDIA_IMAGES
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    }

    if (status.isGranted || status.isLimited) {
      return true;
    } else if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showSettingsDialog(
          context,
          title: 'Photo Library Permission Required',
          message:
              'Please enable photo library access in settings to select photos.',
        );
      }
      return false;
    } else {
      if (context.mounted) {
        _showPermissionDeniedSnackBar(
          context,
          'Photo library permission is required to select photos.',
        );
      }
      return false;
    }
  }

  /// Check if camera permission is granted
  static Future<bool> isCameraGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if photo library permission is granted
  static Future<bool> isPhotoLibraryGranted() async {
    final status = await Permission.photos.status;
    return status.isGranted || status.isLimited;
  }

  /// Show settings dialog for permanently denied permissions
  static Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show snackbar for denied permissions
  static void _showPermissionDeniedSnackBar(
    BuildContext context,
    String message,
  ) {
    AppSnackbar.error(context, message);
  }
}
