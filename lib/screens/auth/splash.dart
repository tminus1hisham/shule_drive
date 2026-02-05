import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';
import '../main/dashboard_screen.dart';

/// Optimized Splash Screen - Shows immediately while app initializes in background
/// Uses the original logo image with improved startup performance
class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => SplashState();
}

class SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  bool _isCheckingAuth = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Set immersive mode for splash
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(2.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    // Start animation immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.initialize();

      // Minimum display time for splash (1 second for better UX)
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) return;

      if (authProvider.isAuthenticated) {
        _navigateTo(const DashboardScreen());
      } else {
        _navigateTo(const LoginScreen());
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize. Please restart the app.';
        _isCheckingAuth = false;
      });
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, -1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      body: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset:
                      _slideAnimation.value * MediaQuery.of(context).size.width,
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'images/logo.png',
                      width: 200,
                      height: 200,
                    ),
                  ),
                ),
                if (_isCheckingAuth) ...[
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF6B9B5B),
                      ),
                    ),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _isCheckingAuth = true;
                      });
                      _checkAuthState();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Global key to control splash screen from outside
final GlobalKey<SplashState> splashKey = GlobalKey<SplashState>();
