import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_view.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late final TabController _tabController;
  late final PageController _pageController;

  final _signInEmail = TextEditingController();
  final _signInPassword = TextEditingController();

  final _signUpName = TextEditingController();
  final _signUpEmail = TextEditingController();
  final _signUpPassword = TextEditingController();

  String _role = 'instructor';
  bool _busy = false;
  bool _obscureSignInPassword = true;
  bool _obscureSignUpPassword = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pageController = PageController();
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pageController.dispose();
    _signInEmail.dispose();
    _signInPassword.dispose();
    _signUpName.dispose();
    _signUpEmail.dispose();
    _signUpPassword.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_signInEmail.text.trim().isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    if (_signInPassword.text.isEmpty) {
      _showError('Please enter your password');
      return;
    }
    setState(() => _busy = true);
    try {
      await _authService.signIn(
        email: _signInEmail.text.trim(),
        password: _signInPassword.text,
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Sign in failed');
    } catch (e) {
      _showError('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (_signUpName.text.trim().isEmpty) {
      _showError('Please enter your full name');
      return;
    }
    if (_signUpEmail.text.trim().isEmpty) {
      _showError('Please enter your email address');
      return;
    }
    if (_signUpPassword.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    setState(() => _busy = true);
    try {
      final credential = await _authService.signUp(
        email: _signUpEmail.text.trim(),
        password: _signUpPassword.text,
      );
      final user = credential.user;
      if (user != null) {
        final profile = UserProfile(
          id: user.uid,
          role: _role,
          name: _signUpName.text.trim(),
          email: user.email ?? _signUpEmail.text.trim(),
        );
        await _firestoreService.createUserProfile(profile);
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Sign up failed');
    } catch (e) {
      _showError('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D7377),
              Color(0xFF14919B),
              Color(0xFF1A6B6E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header section
              _buildHeader(),
              const SizedBox(height: 24),
              // Main content card
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      // Tab bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildTabBar(),
                      ),
                      // Form content
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _currentPage = index);
                            _tabController.animateTo(index);
                          },
                          children: [
                            _buildSignIn(),
                            _buildSignUp(),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Welcome to',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'DriveMate',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your driving school with ease',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppTheme.neutral100,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Sign In',
              isSelected: _currentPage == 0,
              onTap: () {
                _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                );
              },
            ),
          ),
          Expanded(
            child: _buildTabButton(
              label: 'Sign Up',
              isSelected: _currentPage == 1,
              onTap: () {
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.neutral500,
          ),
        ),
      ),
    );
  }

  Widget _buildSignIn() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email field
          _buildLabel('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: _signInEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
            decoration: _buildInputDecoration(
              hintText: 'you@example.com',
              prefixIcon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 20),
          // Password field
          _buildLabel('Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _signInPassword,
            obscureText: _obscureSignInPassword,
            textInputAction: TextInputAction.done,
            enabled: !_busy,
            onSubmitted: (_) => _handleSignIn(),
            decoration: _buildInputDecoration(
              hintText: 'Enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignInPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.neutral500,
                ),
                onPressed: () {
                  setState(() {
                    _obscureSignInPassword = !_obscureSignInPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Sign In Button
          _buildPrimaryButton(
            label: 'Sign In',
            onPressed: _busy ? null : _handleSignIn,
            isLoading: _busy,
          ),
          const SizedBox(height: 20),
          // Footer
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                'Forgot your password?',
                style: TextStyle(
                  color: AppTheme.neutral600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUp() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name field
          _buildLabel('Full Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _signUpName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
            decoration: _buildInputDecoration(
              hintText: 'John Doe',
              prefixIcon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 20),
          // Email field
          _buildLabel('Email'),
          const SizedBox(height: 8),
          TextField(
            controller: _signUpEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
            decoration: _buildInputDecoration(
              hintText: 'you@example.com',
              prefixIcon: Icons.email_outlined,
            ),
          ),
          const SizedBox(height: 20),
          // Password field
          _buildLabel('Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _signUpPassword,
            obscureText: _obscureSignUpPassword,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
            decoration: _buildInputDecoration(
              hintText: 'Create a password',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignUpPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppTheme.neutral500,
                ),
                onPressed: () {
                  setState(() {
                    _obscureSignUpPassword = !_obscureSignUpPassword;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Role selector
          _buildLabel('I am a...'),
          const SizedBox(height: 12),
          _buildRoleSelector(),
          const SizedBox(height: 32),
          // Sign Up Button
          _buildPrimaryButton(
            label: 'Create Account',
            onPressed: _busy ? null : _handleSignUp,
            isLoading: _busy,
          ),
          const SizedBox(height: 16),
          // Terms
          Text(
            'By signing up, you agree to our Terms of Service and Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.neutral700,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: AppTheme.neutral400),
      prefixIcon: Icon(prefixIcon, color: AppTheme.neutral500),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.neutral100,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.neutral200, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.neutral200, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.primary, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppTheme.neutral200, width: 1),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildRoleOption(
            label: 'Instructor',
            value: 'instructor',
            icon: Icons.school_outlined,
            description: 'Teach driving lessons',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRoleOption(
            label: 'Student',
            value: 'student',
            icon: Icons.person_outline_rounded,
            description: 'Learn to drive',
          ),
        ),
      ],
    );
  }

  Widget _buildRoleOption({
    required String label,
    required String value,
    required IconData icon,
    required String description,
  }) {
    final isSelected = _role == value;
    return GestureDetector(
      onTap: _busy ? null : () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.08) : AppTheme.neutral50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.15)
                    : AppTheme.neutral200,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.primary : AppTheme.neutral500,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primary : AppTheme.neutral700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.neutral500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const LoadingIndicator(
                size: 22,
                strokeWidth: 2.5,
                color: Colors.white,
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}
