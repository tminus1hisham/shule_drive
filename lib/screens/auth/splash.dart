import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// Optimized Splash Screen - Renders immediately to prevent blank screen
/// between native splash and Flutter UI
class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => SplashState();
}

class SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
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
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Start animation immediately in next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {
    // Splash screen no longer handles navigation.
    // AuthWrapper in main.dart now handles routing.
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize. Please restart the app.';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold here - parent SplashWithTransition provides it
    // This ensures immediate rendering without layout delay
    return Container(
      color: const Color(0xFFF5F5F0), // Match native splash background
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    'images/logo.png',
                    width: 180,
                    height: 180,
                  ),
                ),
                const SizedBox(height: 48),
                // Loading indicator or status
                if (_errorMessage == null)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1FA971),
                      ),
                    ),
                  ),
                if (_errorMessage != null) ...[
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
                      });
                      _checkAuthState();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Global key to control splash screen from outside
final GlobalKey<SplashState> splashKey = GlobalKey<SplashState>();
