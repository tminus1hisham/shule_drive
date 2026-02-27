import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// RouteGuard - Protects routes by checking authentication
/// Redirects to login if user is not authenticated
class RouteGuard extends StatelessWidget {
  final Widget child;
  final List<UserRole>? allowedRoles;

  const RouteGuard({
    super.key,
    required this.child,
    this.allowedRoles,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while checking auth state
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6B9B5B),
              ),
            ),
          );
        }

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
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6B9B5B),
              ),
            ),
          );
        }

        // Check role-based access if specified
        if (allowedRoles != null && !allowedRoles!.contains(authProvider.userRole)) {
          return _AccessDeniedScreen(
            onBack: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/dashboard',
                (route) => false,
              );
            },
          );
        }

        // User is authenticated (and has correct role if specified)
        return child;
      },
    );
  }
}

/// Access Denied Screen
class _AccessDeniedScreen extends StatelessWidget {
  final VoidCallback onBack;

  const _AccessDeniedScreen({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block,
                  size: 64,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You don\'t have permission to access this feature.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B9B5B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
