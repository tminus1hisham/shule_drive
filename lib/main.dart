import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'api/api_client.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_reset_otp_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/main/home_screen.dart';
import 'screens/main/landing_screen.dart';
import 'screens/main/start_trip_screen.dart';
import 'screens/main/select_students_screen.dart';
import 'screens/main/active_trip_screen.dart';
import 'screens/main/students_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/profile/terms_service_screen.dart';
import 'screens/profile/privacy_policy_screen.dart';
import 'screens/info/about_screen.dart';
import 'screens/info/contact_screen.dart';
import 'screens/trips/trips_screen.dart';
import 'screens/trips/trip_details_screen.dart';
import 'screens/routes/routes_list_screen.dart';
import 'screens/children/manage_children_screen.dart';
import 'screens/children/child_profile_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/user_list_screen.dart';
import 'screens/notifications/notifications_screen.dart';

import 'services/token_storage.dart';
import 'widgets/route_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize token storage (for web: shared_preferences, for mobile: secure_storage)
  await TokenStorage().init();
  
  // Initialize API client (loads saved tokens)
  await ApiClient().init();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ShuleDriveApp());
}

class ShuleDriveApp extends StatelessWidget {
  const ShuleDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            title: 'ShuleDrive',
            debugShowCheckedModeBanner: false,
            themeMode: appProvider.themeMode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const AuthWrapper(),
            routes: {
              // Public routes (no auth required)
              '/login': (context) => const LoginScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/verify-reset-otp': (context) => const VerifyResetOtpScreen(),
              '/reset-password': (context) => const ResetPasswordScreen(),
              
              // Protected routes - require authentication
              '/landing': (context) => const RouteGuard(
                child: LandingScreen(),
              ),
              '/home': (context) => const RouteGuard(
                child: HomeScreen(),
              ),
              
              // Driver-only routes
              '/start-trip': (context) => const RouteGuard(
                allowedRoles: [UserRole.driver],
                child: StartTripScreen(),
              ),
              '/select-students': (context) => const RouteGuard(
                allowedRoles: [UserRole.driver],
                child: SelectStudentsScreen(),
              ),
              '/active-trip': (context) => const RouteGuard(
                allowedRoles: [UserRole.driver],
                child: ActiveTripScreen(),
              ),
              
              // Shared routes - any authenticated user
              '/students-list': (context) => const RouteGuard(
                child: StudentsListScreen(),
              ),
              '/profile': (context) => const RouteGuard(
                child: ProfileScreen(),
              ),
              '/edit-profile': (context) => const RouteGuard(
                child: EditProfileScreen(),
              ),
              '/change-password': (context) => const RouteGuard(
                child: ChangePasswordScreen(),
              ),
              '/terms': (context) => const RouteGuard(
                child: TermsServiceScreen(),
              ),
              '/privacy': (context) => const RouteGuard(
                child: PrivacyPolicyScreen(),
              ),
              '/about': (context) => const RouteGuard(
                child: AboutScreen(),
              ),
              '/contact': (context) => const RouteGuard(
                child: ContactScreen(),
              ),
              '/trips': (context) => const RouteGuard(
                child: TripsScreen(),
              ),
              '/routes': (context) => const RouteGuard(
                child: RoutesListScreen(),
              ),
              '/trip-details': (context) => const RouteGuard(
                child: TripDetailsScreen(),
              ),
              
              // Notifications
              '/notifications': (context) => const RouteGuard(
                child: NotificationsScreen(),
              ),
              
              // Guardian routes
              '/manage-children': (context) => const RouteGuard(
                allowedRoles: [UserRole.guardian],
                child: ManageChildrenScreen(),
              ),
              '/child-profile': (context) => const RouteGuard(
                allowedRoles: [UserRole.guardian],
                child: ChildProfileScreen(),
              ),
              
              // Chat (all authenticated roles)
              '/chat': (context) => const RouteGuard(
                child: ChatListScreen(),
              ),
              '/chat-users': (context) => const RouteGuard(
                child: UserListScreen(),
              ),
              '/chat-detail': (context) {
                final args = ModalRoute.of(context)!.settings.arguments 
                    as Map<String, dynamic>?;
                return RouteGuard(
                  child: ChatScreen(
                    receiverId: args?['receiverId'] as String?,
                    receiverName: args?['receiverName'] as String?,
                    receiverAvatar: args?['receiverAvatar'] as String?,
                  ),
                );
              },
            },
          );
        },
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: const Color(0xFF6B9B5B),
      scaffoldBackgroundColor: const Color(0xFFF5F5F0),
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6B9B5B),
        secondary: Color(0xFF6B9B5B),
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A1A1A),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F5F0),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B9B5B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF6B9B5B),
      scaffoldBackgroundColor: const Color(0xFF121212),
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6B9B5B),
        secondary: Color(0xFF6B9B5B),
        surface: Color(0xFF1E1E1E),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6B9B5B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

/// Authentication Wrapper - Handles auth state and redirects accordingly
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading while initializing
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6B9B5B),
              ),
            ),
          );
        }

        // If authenticated, show screen based on role
        if (authProvider.isAuthenticated) {
          // Drivers see LandingScreen (with trip features)
          // Guardians see HomeScreen (simplified view)
          if (authProvider.isDriver) {
            return const LandingScreen();
          } else {
            return const HomeScreen();
          }
        }

        // Not authenticated, show login
        return const LoginScreen();
      },
    );
  }
}


