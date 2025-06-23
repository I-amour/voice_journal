// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'views/auth_screens/login_screen.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'views/home_screen.dart'; 
import 'views/auth_screens/register_screen.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('Current directory: ${Directory.current.path}');
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Journal',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          return user == null ? const LoginScreen() : const HomeScreen();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}