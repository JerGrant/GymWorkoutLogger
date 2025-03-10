import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/sign_in_page.dart'; // Ensure this file exists
import 'screens/home_page.dart'; // Ensure HomePage exists
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'package:lottie/lottie.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Gym Workout Logger',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.currentTheme,
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => const SplashScreen(),
              '/': (context) => const SignInPage(),
              '/home': (context) => const HomePage(),
            },
          );
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _simulateProgress();
  }

  void _simulateProgress() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _progress += 0.033;
        if (_progress >= 1.0) {
          timer.cancel();
          Navigator.pushReplacementNamed(context, '/');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'lib/assets/BlueDumbbell.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 20),
            Text(
              'Gym Workout Logger',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Theme.of(context).dividerColor,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
