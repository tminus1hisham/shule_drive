import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shule_drive/main.dart';
import 'package:shule_drive/providers/auth_provider.dart';
import 'package:shule_drive/widgets/route_guard.dart';

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider({
    required this.authenticated,
    required this.role,
    this.loading = false,
  });

  final bool authenticated;
  final bool loading;
  final UserRole role;

  @override
  bool get isAuthenticated => authenticated;

  @override
  bool get isLoading => loading;

  @override
  UserRole get userRole => role;
}

void main() {
  testWidgets('ShuleDriveApp builds the app shell', (tester) async {
    await tester.pumpWidget(const ShuleDriveApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('ShuleDrive'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('RouteGuard renders child for an authenticated allowed role', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuthProvider(
          authenticated: true,
          role: UserRole.driver,
        ),
        child: const MaterialApp(
          home: RouteGuard(
            allowedRoles: [UserRole.driver],
            child: Text('Driver content'),
          ),
        ),
      ),
    );

    expect(find.text('Driver content'), findsOneWidget);
  });

  testWidgets('RouteGuard blocks authenticated users with the wrong role', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: _FakeAuthProvider(
          authenticated: true,
          role: UserRole.guardian,
        ),
        child: const MaterialApp(
          home: RouteGuard(
            allowedRoles: [UserRole.driver],
            child: Text('Driver content'),
          ),
        ),
      ),
    );

    expect(find.text('Access Denied'), findsOneWidget);
    expect(find.text('Driver content'), findsNothing);
  });
}
