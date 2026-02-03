import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Role Guard - Restricts access based on user role
/// Usage: Wrap any widget that should only be visible to certain roles
class RoleGuard extends StatelessWidget {
  final Widget child;
  final List<UserRole> allowedRoles;
  final Widget? fallback;

  const RoleGuard({
    super.key,
    required this.child,
    required this.allowedRoles,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userRole = authProvider.userRole;

    if (allowedRoles.contains(userRole)) {
      return child;
    }

    return fallback ?? const SizedBox.shrink();
  }
}

/// Driver Only - Only visible to drivers
class DriverOnly extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const DriverOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const [UserRole.driver],
      child: child,
      fallback: fallback,
    );
  }
}

/// Guardian Only - Only visible to guardians
class GuardianOnly extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const GuardianOnly({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const [UserRole.guardian],
      child: child,
      fallback: fallback,
    );
  }
}

/// Role-Based Navigation
/// Prevents navigation to unauthorized screens
class RoleBasedNavigator {
  static Future<T?> pushNamed<T>(
    BuildContext context,
    String routeName, {
    List<UserRole>? allowedRoles,
    Object? arguments,
  }) async {
    if (allowedRoles != null) {
      final authProvider = context.read<AuthProvider>();
      if (!allowedRoles.contains(authProvider.userRole)) {
        _showAccessDenied(context);
        return null;
      }
    }
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  static Future<T?> pushReplacementNamed<T, TO>(
    BuildContext context,
    String routeName, {
    List<UserRole>? allowedRoles,
    Object? arguments,
  }) async {
    if (allowedRoles != null) {
      final authProvider = context.read<AuthProvider>();
      if (!allowedRoles.contains(authProvider.userRole)) {
        _showAccessDenied(context);
        return null;
      }
    }
    return Navigator.pushReplacementNamed<T, TO>(
      context,
      routeName,
      arguments: arguments,
    );
  }

  static void _showAccessDenied(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Access denied. You don\'t have permission to access this feature.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Role-Based Route
/// Use in route definitions to enforce role access
class RoleBasedRoute<T> extends MaterialPageRoute<T> {
  final List<UserRole> allowedRoles;

  RoleBasedRoute({
    required super.builder,
    required this.allowedRoles,
    super.settings,
  });

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final authProvider = context.read<AuthProvider>();
    
    if (!allowedRoles.contains(authProvider.userRole)) {
      // Return access denied screen instead
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        const _AccessDeniedScreen(),
      );
    }

    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.block,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
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
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Role Badge - Displays current user role
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final role = authProvider.userRole;

    Color badgeColor;
    switch (role) {
      case UserRole.driver:
        badgeColor = Colors.blue;
        break;
      case UserRole.guardian:
        badgeColor = Colors.green;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        role.displayName.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}
