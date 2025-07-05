// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts if you use it for text
import 'login_screen.dart'; // Import your LoginScreen

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Duration of the animation
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn, // Controls how the fade animation progresses
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack, // Controls how the scale animation progresses
      ),
    );

    _controller.forward(); // Start the animation

    // Navigate to LoginScreen after animation completes + a short delay
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () { // Additional delay after animation
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // You can apply a consistent background color or gradient if needed
    final Color splashBackgroundColor = Colors.white; // Or a color from your theme

    return Scaffold(
      backgroundColor: splashBackgroundColor, // Set your desired background color
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logoart.png', // Path to your logo image
                  width: 200, // Adjust size as needed
                  height: 200, // Adjust size as needed
                ),
                const SizedBox(height: 20),
                Text(
                  'Anna Parcha -jaha anna waha parcha', // Your app name or a catchy phrase
                  style: GoogleFonts.poppins( // Use Google Fonts if available
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87, // Adjust text color for splash screen
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}