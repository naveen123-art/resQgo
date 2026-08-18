import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import ' resqgo_auth_page.dart';
import 'resqgo_home_page.dart';
import 'service_provider_home_page.dart';


void main() {
  runApp(const ResQGoApp());
}

class ResQGoApp extends StatelessWidget {
  const ResQGoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQGo App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Fade-in animation
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();

    // Navigate after splash
    Timer(const Duration(seconds: 3), _checkLoginAndNavigate);
  }

  Future<void> _checkLoginAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('username');
    final accountType = prefs.getString('account_type');
    final savedLocation = prefs.getString('location') ?? '';

    Widget nextPage;

    if (savedUsername != null && savedUsername.isNotEmpty) {
      // Determine account type
      if (accountType == "service_provider") {
        nextPage = ServiceProviderHomePage(username: savedUsername);
      } else {
        nextPage = ResQGoHomePage(
          username: savedUsername,
          location: savedLocation,
          accountType: accountType ?? 'user',
        );
      }
    } else {
      nextPage = const ResQGoAuthPage();
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextPage,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Image.asset(
            'assets/my_logo.png',
            width: 200,
            height: 200,
          ),
        ),
      ),
    );
  }
} 
 