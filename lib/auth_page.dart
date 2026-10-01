import 'demo/demo_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'mainscreen.dart';
import 'name_input_dialog.dart';
import 'models/medication.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isSignUp = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool _authBusy = false;
  Future<void> _runAuth(Future<void> Function() operation) async {
    if (_authBusy) return;
    setState(() => _authBusy = true);
    try { await operation(); }
    catch (_) { if (mounted) _showError('Unable to complete this request. Check your connection and try again later.'); }
    finally { if (mounted) setState(() => _authBusy = false); }
  }
  Future<void> _signup() => _runAuth(_performSignup);
  Future<void> _login() => _runAuth(_performLogin);
  Future<void> _forgotPassword() => _runAuth(_performForgotPassword);

  Future<void> _performSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match!');
      return;
    }

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await credential.user!.sendEmailVerification();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() => _isSignUp = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Check your email to verify your account, then log in.'),
        ));
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(error.message ?? 'Could not create account.');
    }
  }

  Future<void> _performLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await credential.user?.reload();
      if (FirebaseAuth.instance.currentUser?.emailVerified != true) {
        await FirebaseAuth.instance.signOut();
        if (mounted) _showError('Verify your email using the link sent when you signed up, then log in.');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final existingOwner = prefs.getString('dosebuddy_local_owner_uid');
      if (existingOwner != null && existingOwner != uid) {
        await FirebaseAuth.instance.signOut();
        if (mounted) _showError('This device has another account\'s local data. Use the original account on this device.');
        return;
      }
      if (existingOwner == null && Hive.box<Medication>(DemoMode.boxName).isNotEmpty) {
        if (!mounted) return;
        final claim = await showDialog<bool>(context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Keep your existing DoseBuddy data?'),
            content: const Text('This device already has medication records. Attach them to the account you just signed into? Only continue if they are yours.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not mine')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keep my data')),
            ],
          ));
        if (claim != true) {
          await FirebaseAuth.instance.signOut();
          return;
        }
      }
      await prefs.setString('dosebuddy_local_owner_uid', uid);
      await prefs.setString('user_email', email);
      if (prefs.getString('user_last_name') == null && mounted) {
        await showDialog<String>(context: context, barrierDismissible: false,
          builder: (context) => const NameInputDialog());
      }
      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => const MainScreen()));
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(error.message ?? 'Could not sign in.');
    }
  }

  Future<void> _performForgotPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      _showError('Please enter your email address');
      return;
    }

    if (!_isValidEmail(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      if (mounted) _showError(error.message ?? 'Could not send reset email.');
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Password Reset'),
        content: Text('A password reset link has been sent to $email'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              //Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B67CA).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SvgPicture.asset(
                    'assets/images/pill_bottle_logo.svg',
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              //Title
              Text(
                _isSignUp ? 'Sign up' : 'Login',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B67CA),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                _isSignUp
                    ? 'Create an account to get started'
                    : 'Welcome back! Sign in to continue',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF718096),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              //Email field
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Email Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF5B67CA), width: 2),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              //Password field
              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF5B67CA), width: 2),
                  ),
                ),
              ),
              
              //Confirm Password field for sign up
              if (_isSignUp) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirm your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF5B67CA), width: 2),
                    ),
                  ),
                ),
              ],
              
              //Forgot Password for log in
              if (!_isSignUp) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _authBusy ? null : _forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF5B67CA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Sign Up / Login Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _authBusy ? null : (_isSignUp ? _signup : _login),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B67CA),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _isSignUp ? 'Sign up' : 'Login',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              //Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or ${_isSignUp ? 'Sign up' : 'Login'} with',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              
              const SizedBox(height: 24),
              
              //Login Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showError('Facebook login not yet implemented');
                      },
                      icon: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
                      label: const Text(
                        'Facebook',
                        style: TextStyle(color: Color(0xFF1877F2)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _showError('Google login not yet implemented');
                      },
                      icon: const Icon(Icons.g_mobiledata, color: Color(0xFFDB4437), size: 28),
                      label: const Text(
                        'Google',
                        style: TextStyle(color: Color(0xFFDB4437)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              //Toggle between Sign Up and Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? 'Already have an Account?'
                        : "Don't have an Account?",
                    style: const TextStyle(color: Color(0xFF718096)),
                  ),
                  TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _isSignUp ? 'Login' : 'Sign up',
                      style: const TextStyle(
                        color: Color(0xFF5B67CA),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
