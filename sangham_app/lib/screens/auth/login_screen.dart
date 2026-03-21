import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../admin/admin_shell.dart';
import '../user/user_shell.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter phone and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(
      _phoneController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      final destination = auth.isAdmin ? const AdminShell() : const UserShell();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Login failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A5C3A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            // Logo & Title
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 36,
                color: Color(0xFF1A5C3A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The Digital Ledger',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sangham Management System',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            // Login Form
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F0),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A3C34),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Login to manage your Sangham',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Phone Field
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(Icons.phone,
                                color: Color(0xFF1A5C3A)),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFF1A5C3A), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Password Field
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock,
                                color: Color(0xFF1A5C3A)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFF1A5C3A), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        // Login Button
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            return SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: auth.isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A5C3A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 3,
                                ),
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Don't have an account? Sign Up",
                              style: TextStyle(
                                color: Color(0xFF1A5C3A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
