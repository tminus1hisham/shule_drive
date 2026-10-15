import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme_extension.dart';
import 'ui/ui.dart';

/// RouteGuard - Protects routes by checking authentication
/// Redirects to login if user is not authenticated
class RouteGuard extends StatelessWidget {
  final Widget child;
  final List<UserRole>? allowedRoles;

  const RouteGuard({super.key, required this.child, this.allowedRoles});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while checking auth state
        if (authProvider.isLoading) return const _Loading();

        // Not authenticated - redirect to login
        if (!authProvider.isAuthenticated) {
          // Use post-frame callback to navigate after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          });

          // Show loading while redirecting
          return const _Loading();
        }

        // Check role-based access if specified
        if (allowedRoles != null &&
            !allowedRoles!.contains(authProvider.userRole)) {
          return Scaffold(
            body: EmptyState(
              icon: Icons.block_rounded,
              iconColor: context.colors.error,
              title: 'Access Denied',
              message: 'You don\'t have permission to access this feature.',
              actionLabel: 'Go to Home',
              onAction: () => Navigator.pushNamedAndRemoveUntil(
                context,
                '/dashboard',
                (route) => false,
              ),
            ),
          );
        }

        // User is authenticated (and has correct role if specified)
        return child;
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: CircularProgressIndicator(color: context.colors.brand)),
  );
}
