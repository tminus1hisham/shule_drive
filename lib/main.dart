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
            onGenerateRoute: (settings) {
              return _buildPageRoute(settings);
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
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
  /// Build page route with fast transitions
  Route _buildPageRoute(RouteSettings settings) {
    // Routes that are considered "tab switches" - use instant transition
    const tabRoutes = <String>{
      '/landing',
      '/home',
      '/chat',
      '/notifications',
      '/profile',
    };
    
    Widget page;
    bool protected = false;
    List<UserRole>? allowedRoles;
    bool isTabRoute = tabRoutes.contains(settings.name);

    switch (settings.name) {
      // Public routes
      case '/login':
        page = const LoginScreen();
        break;
      case '/forgot-password':
        page = const ForgotPasswordScreen();
        break;
      case '/verify-reset-otp':
        page = const VerifyResetOtpScreen();
        break;
      case '/reset-password':
        page = const ResetPasswordScreen();
        break;

      // Protected routes
      case '/landing':
        page = const LandingScreen();
        protected = true;
        break;
      case '/home':
        page = const HomeScreen();
        protected = true;
        break;
      case '/start-trip':
        page = const StartTripScreen();
        protected = true;
        allowedRoles = [UserRole.driver];
        break;
      case '/select-students':
        page = const SelectStudentsScreen();
        protected = true;
        allowedRoles = [UserRole.driver];
        break;
      case '/active-trip':
        page = const ActiveTripScreen();
        protected = true;
        allowedRoles = [UserRole.driver];
        break;
      case '/students-list':
        page = const StudentsListScreen();
        protected = true;
        break;
      case '/profile':
        page = const ProfileScreen();
        protected = true;
        break;
      case '/edit-profile':
        page = const EditProfileScreen();
        protected = true;
        break;
      case '/change-password':
        page = const ChangePasswordScreen();
        protected = true;
        break;
      case '/terms':
        page = const TermsServiceScreen();
        protected = true;
        break;
      case '/privacy':
        page = const PrivacyPolicyScreen();
        protected = true;
        break;
      case '/about':
        page = const AboutScreen();
        protected = true;
        break;
      case '/contact':
        page = const ContactScreen();
        protected = true;
        break;
      case '/trips':
        page = const TripsScreen();
        protected = true;
        break;
      case '/routes':
        page = const RoutesListScreen();
        protected = true;
        break;
      case '/trip-details':
        page = const TripDetailsScreen();
        protected = true;
        break;
      case '/notifications':
        page = const NotificationsScreen();
        protected = true;
        break;
      case '/manage-children':
        page = const ManageChildrenScreen();
        protected = true;
        allowedRoles = [UserRole.guardian];
        break;
      case '/child-profile':
        page = const ChildProfileScreen();
        protected = true;
        allowedRoles = [UserRole.guardian];
        break;
      case '/chat':
        page = const ChatListScreen();
        protected = true;
        break;
      case '/chat-users':
        page = const UserListScreen();
        protected = true;
        break;
      case '/chat-detail':
        final args = settings.arguments as Map<String, dynamic>?;
        page = ChatScreen(
          receiverId: args?['receiverId'] as String?,
          receiverName: args?['receiverName'] as String?,
          receiverAvatar: args?['receiverAvatar'] as String?,
        );
        protected = true;
        break;

      default:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, a1, a2) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }

    // Wrap with RouteGuard if protected
    if (protected) {
      page = RouteGuard(
        allowedRoles: allowedRoles,
        child: page,
      );
    }

    // Tab routes use instant transition for snappy switching
    if (isTabRoute) {
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, a1, a2) => page,
        transitionsBuilder: (ctx, anim, anim2, child) => child,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    // Other routes use fast fade transition
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, a1, a2) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    );
  }

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


