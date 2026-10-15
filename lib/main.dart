import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/splash.dart';
import 'theme/app_spacing.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'api/api_client.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/tracking_provider.dart';
import 'providers/connectivity_provider.dart';
import 'widgets/main_scaffold.dart' show tabTracker;
import 'widgets/offline_gate.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_reset_otp_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/main/dashboard_screen.dart';
import 'screens/main/start_trip_screen.dart';
import 'screens/main/active_trip_screen.dart';
import 'screens/main/students_list_screen.dart';
import 'screens/driver/trip_selection_screen.dart';
import 'screens/driver/vehicle_selection_screen.dart';
import 'models/master_trip.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/change_password_screen.dart';
import 'screens/profile/terms_service_screen.dart';
import 'screens/profile/privacy_policy_screen.dart';
import 'screens/info/about_screen.dart';
import 'screens/info/contact_screen.dart';
import 'screens/trips/trips_screen.dart';
import 'screens/trips/trip_details_screen.dart';
import 'screens/trips/manage/manage_master_trips_screen.dart';
import 'screens/children/manage_children_screen.dart';
import 'screens/children/child_profile_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/user_list_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/tracking/osm_tracking_screen.dart';

import 'services/chat_service.dart';
import 'services/token_storage.dart';
import 'services/local_database_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_manager.dart';
import 'services/app_config.dart';
import 'widgets/route_guard.dart';
import 'theme/app_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ============================================================================
// APP ENTRY POINT
// ============================================================================

// Plain print() is in 300+ places and, like debugPrint, survives release
// builds; running the app in a zone that drops it keeps those logs off the
// device log (iOS Console / logcat) without touching every call site.
Future<void> main() => kReleaseMode
    ? runZoned(
        _main,
        zoneSpecification: ZoneSpecification(print: (_, _, _, _) {}),
      )
    : _main();

Future<void> _main() async {
  // debugPrint isn't stripped from release builds and logs carry phone
  // numbers, ids and server bodies; keep them off production logcat.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};

  // Ensure Flutter binding is initialized
  final binding = WidgetsFlutterBinding.ensureInitialized();

  // Initialize AppConfig (loads .env, dart-define, etc.)
  // This must happen before runApp()
  await AppConfig().initialize();

  // Allow bad SSL certificates only for local debug builds.
  if (kDebugMode) {
    HttpOverrides.global = _DevHttpOverrides();
  }

  // Schedule the actual initialization after the first frame is rendered
  binding.addPostFrameCallback((_) async {
    // Initialize critical services after first frame is shown
    await _initCriticalServices();

    // Start non-critical services in background
    _initNonCriticalServices();
  });

  // Run the app immediately - the splash screen background will be shown
  runApp(const ShuleDriveApp());
}

/// HTTP overrides for development to accept bad SSL certificates
/// This is needed for staging environments with self-signed certs
class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Accept all certificates in debug mode for staging
        if (kDebugMode) {
          return true;
        }
        return false;
      };
  }
}

/// Critical services that must be ready before showing UI
Future<void> _initCriticalServices() async {
  // Token storage (fast - shared prefs)
  await TokenStorage().init();

  // API client (loads saved tokens, fast)
  await ApiClient().init();
}

/// Non-critical services that can initialize in background
void _initNonCriticalServices() {
  // Skip on web
  if (kIsWeb) return;

  // Database - can be slow, do in background
  LocalDatabaseService().database
      .then((_) {
        if (kDebugMode) print('📦 Database initialized');
      })
      .catchError((e) {
        if (kDebugMode) print('⚠️ Database init error: $e');
      });

  // Notifications - can be slow
  NotificationService()
      .initialize(
        // Android guardians get Firebase push; everyone also gets MQTT.
        preferredBackend: Platform.isAndroid
            ? NotificationBackend.firebase
            : NotificationBackend.localOnly,
      )
      .then((_) {
        if (kDebugMode) print('🔔 Notifications initialized');
      })
      .catchError((e) {
        if (kDebugMode) print('⚠️ Notification init error: $e');
      });

  // Offline sync - lowest priority
  OfflineSyncManager()
      .initialize()
      .then((_) {
        if (kDebugMode) print('🔄 Offline sync initialized');
      })
      .catchError((e) {
        if (kDebugMode) print('⚠️ Offline sync init error: $e');
      });
}

// ============================================================================
// MAIN APP
// ============================================================================

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

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
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider()
            ..initialize().catchError((e) {
              if (kDebugMode) print('⚠️ Connectivity init error: $e');
            }),
        ),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            title: 'Transfa',
            debugShowCheckedModeBanner: false,
            themeMode: appProvider.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SplashWithTransition(),
            navigatorObservers: [routeObserver, tabTracker],
            onGenerateRoute: _buildPageRoute,
            // Status bar for screens without an AppBar (AppBars set their
            // own). iOS reads statusBarBrightness, Android the icon one.
            builder: (context, child) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: dark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: dark ? Brightness.dark : Brightness.light,
                ),
                child: OfflineGate(child: child!),
              );
            },
          );
        },
      ),
    );
  }
}

/// Splash screen wrapper that handles the transition to main content
class SplashWithTransition extends StatefulWidget {
  const SplashWithTransition({super.key});

  @override
  State<SplashWithTransition> createState() => _SplashWithTransitionState();
}

class _SplashWithTransitionState extends State<SplashWithTransition>
    with TickerProviderStateMixin {
  // Splash enters from right to center
  late AnimationController _splashEnterController;
  late Animation<Offset> _splashEnterAnimation;

  // Splash exits to bottom, Login enters from top
  late AnimationController _transitionController;
  late Animation<Offset> _splashExitAnimation;
  late Animation<Offset> _loginEnterAnimation;

  bool _showSplash = true;
  bool _showLogin = false;

  @override
  void initState() {
    super.initState();

    // Splash enter animation (right to center) - faster
    _splashEnterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _splashEnterAnimation =
        Tween<Offset>(
          begin: const Offset(1.0, 0), // Start from right
          end: Offset.zero, // End at center
        ).animate(
          CurvedAnimation(
            parent: _splashEnterController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Transition animation (splash down, login from top) - faster
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Splash slides down
    _splashExitAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, 1.0)).animate(
          CurvedAnimation(
            parent: _transitionController,
            curve: Curves.easeInOutCubic,
          ),
        );

    // Login slides from top
    _loginEnterAnimation =
        Tween<Offset>(
          begin: const Offset(0, -1.0), // Start from top
          end: Offset.zero, // End at center
        ).animate(
          CurvedAnimation(
            parent: _transitionController,
            curve: Curves.easeOutCubic,
          ),
        );

    _runSequence();
  }

  @override
  void dispose() {
    _splashEnterController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  Future<void> _runSequence() async {
    // Phase 1: Animate splash in from right
    await _splashEnterController.forward();

    // Phase 2: Initialize auth while splash is showing
    final authProvider = context.read<AuthProvider>();
    await authProvider.initialize();

    // Minimum time splash stays visible after entering (reduced)
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      setState(() {
        _showLogin = true; // Build login (hidden at first)
      });

      // Small delay to ensure login is built
      await Future.delayed(const Duration(milliseconds: 30));

      if (mounted) {
        // Phase 3: Transition - splash slides down, login slides from top
        await _transitionController.forward();
        setState(() => _showSplash = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Splash layer - slides in from right, then out to bottom
        if (_showSplash)
          SlideTransition(
            position: _splashEnterAnimation,
            child: SlideTransition(
              position: _splashExitAnimation,
              child: const Splash(),
            ),
          ),
        // Login layer - slides in from top
        if (_showLogin)
          SlideTransition(
            position: _loginEnterAnimation,
            child: const AuthWrapper(),
          ),
      ],
    );
  }
}

Route _buildPageRoute(RouteSettings settings) {
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
    case '/':
    case '/dashboard':
      page = const DashboardScreen();
      protected = true;
      break;
    case '/landing':
      page = const DashboardScreen();
      protected = true;
      break;
    case '/home':
      page = const DashboardScreen(); // Unified dashboard for all users
      protected = true;
      break;
    case '/start-trip':
      final args = settings.arguments as Map<String, dynamic>?;
      page = args?['masterTrip'] is MasterTrip
          ? const StartTripScreen()
          : const TripSelectionScreen();
      protected = true;
      allowedRoles = [UserRole.driver];
      break;
    case '/trip-selection':
      page = const TripSelectionScreen();
      protected = true;
      allowedRoles = [UserRole.driver];
      break;
    case '/vehicle-selection':
      final args = settings.arguments as Map<String, dynamic>?;
      page = VehicleSelectionScreen(
        masterTrip: args?['masterTrip'] as MasterTrip?,
      );
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
    case '/trip-details':
      page = const TripDetailsScreen();
      protected = true;
      break;
    case '/manage-master-trips':
      page = const ManageMasterTripsScreen();
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
      final receiverPhone = args?['receiverPhone'] as String?;
      // A trip group opened from the chat list (or after re-login) arrives
      // without the map's args; derive them so it stays a read-only-when-
      // ended group instead of a sendable "User" chat.
      final isGroup =
          receiverPhone != null && ChatService.isGroup(receiverPhone);
      page = ChatScreen(
        receiverPhone: receiverPhone,
        receiverName: args?['receiverName'] as String?,
        receiverAvatar: args?['receiverAvatar'] as String?,
        receiverRole: isGroup ? 'Group' : args?['receiverRole'] as String?,
        tripId:
            args?['tripId']?.toString() ??
            (isGroup ? receiverPhone.substring('trip_'.length) : null),
        isTripChat: (args?['isTripChat'] as bool? ?? false) || isGroup,
        memberPhones: (args?['memberPhones'] as List?)?.cast<String>(),
      );
      protected = true;
      break;
    case '/osm-tracking':
      final args = settings.arguments as Map<String, dynamic>?;
      page = OsmTrackingScreen(
        tripId: args?['tripId']?.toString(),
        busId: args?['busId'] as String?,
        routeId: args?['routeId'] as String?,
        preloadedData: args?['preloadedData'] as Map<String, dynamic>?,
      );
      protected = true;
      break;
    default:
      return PageRouteBuilder(
        settings: settings,
        pageBuilder: (context, a1, a2) =>
            const Scaffold(body: Center(child: Text('Page not found'))),
      );
  }

  if (protected) {
    page = RouteGuard(allowedRoles: allowedRoles, child: page);
  }

  // Tabs are siblings: a quick fade-through (the bottom bar stays planted as a
  // shared hero). Pushed screens are depth: they rise into place while the
  // screen underneath recedes slightly.
  if (isTabRoute) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, a1, a2) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppCurves.easeOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 180),
    );
  }

  // iOS users go back by swiping from the screen edge; only a
  // MaterialPageRoute (Cupertino transition from the theme) has that gesture.
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return MaterialPageRoute(settings: settings, builder: (_) => page);
  }

  return PageRouteBuilder(
    settings: settings,
    pageBuilder: (context, a1, a2) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final enter = CurvedAnimation(
        parent: animation,
        curve: AppCurves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      final recede = CurvedAnimation(
        parent: secondaryAnimation,
        curve: AppCurves.easeOut,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.96).animate(recede),
        child: FadeTransition(
          opacity: enter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(enter),
            child: child,
          ),
        ),
      );
    },
    transitionDuration: AppDuration.page,
    reverseTransitionDuration: const Duration(milliseconds: 220),
  );
}

/// AuthWrapper that handles authentication, onboarding flow
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();

    // Services init happens in background
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isAuthenticated && !kIsWeb) {
      _initializeServices(authProvider);
    }
  }

  /// Check if user has completed onboarding
  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_onboarding') ?? false;

    if (mounted) {
      setState(() {
        _hasSeenOnboarding = hasSeen;
      });
    }
  }

  void _initializeServices(AuthProvider authProvider) {
    // Welcome notification after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && authProvider.isAuthenticated) {
        _showWelcomeNotification(authProvider);
      }
    });
  }

  Future<void> _showWelcomeNotification(AuthProvider authProvider) async {
    if (kIsWeb) return;

    final userName = authProvider.userName;
    final role = authProvider.isDriver
        ? 'Driver'
        : authProvider.isGuardian
        ? 'Guardian'
        : 'User';

    final title = userName != null
        ? '👋 Welcome back, $userName!'
        : '👋 Welcome back!';

    final body =
        'Thank you for being a part of Transfa. '
        'Your $role dashboard is ready. Have a great day! 🚌';

    await NotificationService().showLocalNotification(
      title: title,
      body: body,
      channelId: 'trip_updates',
      importance: Importance.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Don't show anything until we've checked onboarding status
        // This prevents flashing the wrong screen
        if (_hasSeenOnboarding == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F5F0),
            body: SizedBox.shrink(),
          );
        }

        // User is authenticated -> Dashboard
        if (authProvider.isAuthenticated) {
          return const DashboardScreen();
        }

        // User not authenticated but hasn't seen onboarding -> Show Onboarding
        if (!_hasSeenOnboarding!) {
          return const OnboardingScreen();
        }

        // User not authenticated and has seen onboarding -> Login
        return const LoginScreen();
      },
    );
  }
}
