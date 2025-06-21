// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cogni_loop/utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      if (_fullNameController.text.trim().isEmpty) {
        throw Exception('Full name is required');
      }
      if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
        throw Exception('Passwords do not match');
      }
      
      // Create user with email and password
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      // Store user data in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'email': userCredential.user?.email,
        'fullName': _fullNameController.text.trim(),
        'registrationDate': Timestamp.now(),
        'lastLogin': Timestamp.now(),
        'hasCompletedOnboarding': false,
        'role': 'user',
      });
      
      // Show success message and navigate to home
      _showSnackBar('Registration successful! Welcome to CogniLoop!', isError: false);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showSnackBar('Registration failed: $e');
    }
    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Store user data in Firestore if it's a new user
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'fullName': userCredential.user?.displayName,
          'registrationDate': Timestamp.now(),
          'lastLogin': Timestamp.now(),
          'hasCompletedOnboarding': false,
          'role': 'user',
        });
        _showSnackBar('New Google user data stored!', isError: false);
      }

      _showSnackBar('Signed in with Google successfully!', isError: false);
      Navigator.pushReplacementNamed(context, '/user_profile_setup');
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Failed to sign in with Google: ${e.message}');
    } catch (e) {
      _showSnackBar('An unexpected error occurred during Google Sign-In: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
        child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                // Logo at the top center
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 32),
                  child: SvgPicture.asset(
                    AppImages.logo,
                    height: 80,
              ),
                ),
              Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign up to get started',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
              ),
                const SizedBox(height: 32),
              TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email, color: AppColors.primary),
                    fillColor: AppColors.card,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: _fullNameController,
                decoration: InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person, color: AppColors.primary),
                    fillColor: AppColors.card,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, color: AppColors.primary),
                    fillColor: AppColors.card,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
                    fillColor: AppColors.card,
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Register'),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                    Expanded(child: Divider(color: AppColors.subtitle)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or', style: TextStyle(color: AppColors.subtitle)),
                  ),
                    Expanded(child: Divider(color: AppColors.subtitle)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                      side: const BorderSide(color: AppColors.subtitle),
                  ),
                  child: _isLoading
                        ? const CircularProgressIndicator(color: AppColors.primary)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Image.asset('assets/images/googlelogo.png', height: 24),
                            const SizedBox(width: 10),
                            Text(
                                'Sign up with Google',
                              style: TextStyle(
                                  color: AppColors.text,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?', style: Theme.of(context).textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      child: Text('Login', style: TextStyle(color: AppColors.primary)),
                      ),
                    ],
                  ),

              ],
              ),
          ),
        ),
      ),
    );
  }
} 