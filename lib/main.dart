import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'api/api_client.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
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
import 'screens/children/manage_children_screen.dart';
import 'screens/children/child_profile_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/auth/splash.dart';
import 'widgets/role_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      ],
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: 'ShuleDrive',
            debugShowCheckedModeBanner: false,
            themeMode: provider.themeMode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const Splash(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/forgot-password': (context) => const ForgotPasswordScreen(),
              '/verify-reset-otp': (context) => const VerifyResetOtpScreen(),
              '/reset-password': (context) => const ResetPasswordScreen(),
              '/landing': (context) => const LandingScreen(),
              '/home': (context) => const HomeScreen(),
              // Driver-only routes
              '/start-trip': (context) => RoleGuard(
                allowedRoles: const [UserRole.driver],
                fallback: const _AccessDeniedFallback(),
                child: const StartTripScreen(),
              ),
              '/select-students': (context) => RoleGuard(
                allowedRoles: const [UserRole.driver],
                fallback: const _AccessDeniedFallback(),
                child: const SelectStudentsScreen(),
              ),
              '/active-trip': (context) => RoleGuard(
                allowedRoles: const [UserRole.driver],
                fallback: const _AccessDeniedFallback(),
                child: const ActiveTripScreen(),
              ),
              // Shared routes
              '/students-list': (context) => const StudentsListScreen(),
              '/profile': (context) => const ProfileScreen(),
              '/edit-profile': (context) => const EditProfileScreen(),
              '/change-password': (context) => const ChangePasswordScreen(),
              '/terms': (context) => const TermsServiceScreen(),
              '/privacy': (context) => const PrivacyPolicyScreen(),
              '/about': (context) => const AboutScreen(),
              '/contact': (context) => const ContactScreen(),
              '/trips': (context) => const TripsScreen(),
              '/trip-details': (context) => const TripDetailsScreen(),
              // Guardian routes
              '/manage-children': (context) => const ManageChildrenScreen(),
              '/child-profile': (context) => const ChildProfileScreen(),
              // Chat (all roles)
              '/chat': (context) => const ChatScreen(),
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

class _AccessDeniedFallback extends StatelessWidget {
  const _AccessDeniedFallback();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Access Denied',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('You don\'t have permission to access this feature.'),
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
