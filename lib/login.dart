import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/services/auth_service.dart';
import 'package:test/widgets/forgot_password_screen.dart';

class LoginPage extends StatefulWidget {
  final ThemeProvider themeProvider;
  const LoginPage({Key? key, required this.themeProvider}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  String? _errorText;
  int _tabIndex = 0; // 0 = Sign In, 1 = Sign Up
  final AuthService _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    _emailCtrl.text = prefs.getString('email') ?? '';
    _pwCtrl.text = prefs.getString('password') ?? '';
  }

  Future<void> _saveCreds(String email, String pw) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email);
    await prefs.setString('password', pw);
  }

  bool get _isDark => widget.themeProvider.isDarkMode;
  Color get _primary => _isDark ? const Color.fromARGB(255, 191, 148, 135) : const Color.fromARGB(255, 191, 148, 135);
  Color get _bg => _isDark ? Colors.black : Colors.white;

  Future<void> _signIn() async {
    setState(() => _errorText = null);
    try {
      final cred = await _auth.signInWithEmailPassword(
          _emailCtrl.text.trim(), _pwCtrl.text);
      await _saveCreds(_emailCtrl.text.trim(), _pwCtrl.text);
      Navigator.pushReplacementNamed(context, '/splash2',
          arguments: cred.user!.uid);
    } catch (_) {
      setState(() => _errorText = 'Invalid email or password');
    }
  }

  Future<void> _signUp() async {
    setState(() => _errorText = null);
    final pw = _pwCtrl.text, cpw = _confirmPwCtrl.text;
    final strong = RegExp(r'^(?=.*[0-9])(?=.*[^A-Za-z0-9]).{7,}$');
    if (!strong.hasMatch(pw)) {
      setState(() => _errorText =
          'Password: ≥7 chars, include number & special character');
      return;
    }
    if (pw != cpw) {
      setState(() => _errorText = 'Passwords do not match');
      return;
    }
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: _emailCtrl.text.trim(), password: pw);
      await _saveCreds(_emailCtrl.text.trim(), pw);
      Navigator.pushReplacementNamed(context, '/splash2',
          arguments: cred.user!.uid);
    } catch (_) {
      setState(() => _errorText = 'Sign up failed');
    }
  }

  Future<void> _google() async {
    try {
      final userCred = await _auth.signInWithGoogle();
      if (userCred != null) {
        await _saveCreds(userCred.user!.email ?? '', '');
        Navigator.pushReplacementNamed(context, '/splash2',
            arguments: userCred.user!.uid);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,  // allow resize for keyboard
      backgroundColor: _bg,
      body: DefaultTabController(
        length: 2,
        initialIndex: _tabIndex,
        child: Column(
          children: [
            // Top half: logo
            Expanded(
              flex: 2,
              child: Center(
                child: Image.asset(
                  'assets/capy_boba.png',
                  width: 140,
                  height: 140,
                  color: _isDark ? Colors.white70 : null,
                  colorBlendMode:
                      _isDark ? BlendMode.modulate : BlendMode.dst,
                ),
              ),
            ),

            // Bottom half: tabs + forms
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    TabBar(
                      onTap: (i) => setState(() => _tabIndex = i),
                      indicatorColor: _primary,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 4,
                      labelColor: _primary,
                      unselectedLabelColor:
                          _isDark ? Colors.white54 : Colors.black54,
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Sign Up'),
                      ],
                    ),
                    if (_errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _errorText!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Expanded(
                      child: TabBarView(
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // Sign In Form wrapped for keyboard
                          SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 32,
                              right: 32,
                              top: 24,
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom + 24,
                            ),
                            child: _buildForm(isSignIn: true),
                          ),

                          // Sign Up Form wrapped for keyboard
                          SingleChildScrollView(
                            padding: EdgeInsets.only(
                              left: 32,
                              right: 32,
                              top: 24,
                              bottom:
                                  MediaQuery.of(context).viewInsets.bottom + 24,
                            ),
                            child: _buildForm(isSignIn: false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm({required bool isSignIn}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _lineField(_emailCtrl, 'Email', false),
        const SizedBox(height: 16),
        _lineField(_pwCtrl, 'Password', true,
            helper: isSignIn ? null : '≥7 chars, 1 number & special'),
        const SizedBox(height: 16),
        if (!isSignIn)
          _lineField(_confirmPwCtrl, 'Confirm Password', true),
        if (isSignIn)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen())),
              child: Text('Forgot Password?', style: TextStyle(color: _primary)),
            ),
          ),
        const SizedBox(height: 24),
        _actionButton(
          isSignIn ? 'Sign In' : 'Create Account',
          isSignIn ? _signIn : _signUp,
        ),
        const SizedBox(height: 12),
        _actionButton(
          'Continue with Google',
          _google,
          icon: 'assets/google_logo.png',
        ),
      ],
    );
  }

  Widget _lineField(TextEditingController c, String hint, bool obscure,
      {String? helper}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        helperText: helper,
        border: InputBorder.none,
      ),
      style: TextStyle(color: _isDark ? Colors.white : Colors.black),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap, {String? icon}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: icon == null
            ? Text(label,
                style: const TextStyle(fontSize: 16, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(icon, height: 24),
                  const SizedBox(width: 8),
                  Text(label,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white)),
                ],
              ),
      ),
    );
  }
}
