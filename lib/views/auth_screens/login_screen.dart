// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../../services/auth_services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await _auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found for this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email format';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!EmailValidator.validate(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('LOGIN'),
                ),
              ),
              TextButton(
                onPressed: () => _showResetDialog(context),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Create new account'),
              ),
              const SizedBox(height: 30),
              const Text('OR', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              IconButton(
                icon: Image.asset('assets/images/google.jpeg', height: 40),
                onPressed: () async {
                  setState(() => _isLoading = true);
                  try {
                    final user = await _auth.signInWithGoogle();
                    if (!mounted) return;

                    setState(() => _isLoading = false);

                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Google login failed')),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(hintText: 'Your email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (emailController.text.isEmpty ||
                  !EmailValidator.validate(emailController.text)) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email')),
                );
                return;
              }

              try {
                // First check if email exists
                final methods = await FirebaseAuth.instance
                    .fetchSignInMethodsForEmail(emailController.text.trim());

                if (methods.isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No account found with this email'),
                    ),
                  );
                  return;
                }

                await _auth.sendPasswordResetEmail(emailController.text.trim());
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reset email sent! Check your inbox.'),
                  ),
                );
                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}
