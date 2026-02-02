import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
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

void main() {
  runApp(const ShuleDriveApp());
}

class ShuleDriveApp extends StatelessWidget {
  const ShuleDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: MaterialApp(
        title: 'ShuleDrive',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF6B9B5B),
          scaffoldBackgroundColor: const Color(0xFFF5F5F0),
          fontFamily: 'Inter',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B9B5B),
            primary: const Color(0xFF6B9B5B),
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
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/otp': (context) => const OTPScreen(),
          '/landing': (context) => const LandingScreen(),
          '/home': (context) => const HomeScreen(),
          '/start-trip': (context) => const StartTripScreen(),
          '/select-students': (context) => const SelectStudentsScreen(),
          '/active-trip': (context) => const ActiveTripScreen(),
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
          '/manage-children': (context) => const ManageChildrenScreen(),
          '/child-profile': (context) => const ChildProfileScreen(),
        },
      ),
    );
  }
}
