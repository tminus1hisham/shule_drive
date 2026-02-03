import 'package:flutter/material.dart';
import 'package:shule_drive/screens/auth/login_screen.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(
            2.0,
            0.0,
          ), // Start further off-screen to the right
          end: Offset.zero, // End at center
        ).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    // Start animation after a short delay to ensure widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });

    // Navigate to login after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LoginScreen(),
            transitionDuration: const Duration(
              milliseconds: 2500,
            ), // Slower transition
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, -1.0); // Start from top
                  const end = Offset.zero;
                  const curve = Curves.easeInOut;

                  var tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);

                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0), // Light theme background
      body: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Center(
            child: Transform.translate(
              offset: _slideAnimation.value * MediaQuery.of(context).size.width,
              child: Image.asset('images/logo.png', width: 200, height: 200),
            ),
          );
        },
      ),
    );
  }
}
