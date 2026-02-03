import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
  final _signUpSchoolName = TextEditingController();

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
    _signUpSchoolName.dispose();
    super.dispose();
  }

  bool _isPhoneNumber(String input) {
    final trimmed = input.trim();
    // Check if it starts with + and contains mostly digits
    if (trimmed.startsWith('+')) {
      final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
      return digitsOnly.length >= 7; // Minimum phone number length
    }
    // Check if it's all digits (without +)
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.length >= 7 && trimmed.length <= 15;
  }

  Future<void> _handleSignIn() async {
    final identifier = _signInEmail.text.trim();
    if (identifier.isEmpty) {
      _showError('Please enter your email address or phone number');
      return;
    }
    if (_signInPassword.text.isEmpty) {
      _showError('Please enter your password');
      return;
    }
    setState(() => _busy = true);
    try {
      // Auto-detect if input is phone number or email
      if (_isPhoneNumber(identifier)) {
        await _authService.signInWithPhone(
          phone: identifier,
          password: _signInPassword.text,
        );
      } else {
        await _authService.signIn(
          email: identifier,
          password: _signInPassword.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Sign in failed');
    } catch (e) {
      _showError('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSignInWithGoogle() async {
    setState(() => _busy = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential?.user == null) return; // User cancelled
      await _ensureProfileForSocialUser(credential!.user!);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Google sign in failed');
    } catch (e) {
      _showError(e.toString().contains('id token') ? e.toString() : 'Google sign in failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSignInWithApple() async {
    setState(() => _busy = true);
    try {
      final credential = await _authService.signInWithApple();
      if (credential?.user == null) return;
      await _ensureProfileForSocialUser(credential!.user!);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Apple sign in failed');
    } catch (e) {
      _showError('Apple sign in failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// For new Google/Apple sign-in users: do not create profile here.
  /// AuthGate will show SocialProfileCompletionScreen so they can enter school name and phone.
  Future<void> _ensureProfileForSocialUser(User user) async {
    final existing = await _firestoreService.getUserProfile(user.uid);
    if (existing != null) return;
    // New social user: leave profile null so AuthGate shows SocialProfileCompletionScreen
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
        
        // Create school with provided name or default
        final schoolName = _signUpSchoolName.text.trim();
        final finalSchoolName = schoolName.isEmpty 
            ? '${_signUpName.text.trim()} School'
            : schoolName;
        await _firestoreService.ensurePersonalSchool(
          instructor: profile,
          schoolName: finalSchoolName,
        );
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
    final primary = Theme.of(context).colorScheme.primary;
    final headerGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(primary, Colors.black, 0.3) ?? primary,
        primary,
        Color.lerp(primary, Colors.black, 0.15) ?? primary,
      ],
    );
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: headerGradient,
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
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
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
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.08),
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
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
          // Email/Phone field
          _buildLabel('Email or Phone Number'),
          const SizedBox(height: 8),
          TextField(
            controller: _signInEmail,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            enabled: !_busy,
            decoration: _buildInputDecoration(
              context,
              hintText: 'you@example.com or +1234567890',
              prefixIcon: Icons.person_outline_rounded,
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
              context,
              hintText: 'Enter your password',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignInPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          Text(
            'Added by your school or instructor? Use email/phone and password above.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildSocialDivider(),
          const SizedBox(height: 20),
          _buildSocialSignInButtons(),
          const SizedBox(height: 20),
          // Footer
          Center(
            child: TextButton(
              onPressed: () {},
              child: Text(
                'Forgot your password?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialDivider() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or continue with',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }

  bool get _isAppleSignInAvailable {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Widget _buildSocialSignInButtons() {
    return _isAppleSignInAvailable
        ? Row(
            children: [
              Expanded(
                child: _buildOutlinedSocialButton(
                  icon: Icons.g_mobiledata_rounded,
                  label: 'Google',
                  onPressed: _busy ? null : _handleSignInWithGoogle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutlinedSocialButton(
                  icon: Icons.apple_rounded,
                  label: 'Apple',
                  onPressed: _busy ? null : _handleSignInWithApple,
                ),
              ),
            ],
          )
        : _buildOutlinedSocialButton(
            icon: Icons.g_mobiledata_rounded,
            label: 'Continue with Google',
            onPressed: _busy ? null : _handleSignInWithGoogle,
          );
  }

  Widget _buildOutlinedSocialButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: colorScheme.outlineVariant),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: colorScheme.onSurface),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
              context,
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
              context,
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
              context,
              hintText: 'Create a password',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureSignUpPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
          // School Name field (optional)
          Row(
            children: [
              _buildLabel('School Name'),
              const SizedBox(width: 8),
              Text(
                '(Optional)',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _signUpSchoolName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            enabled: !_busy,
            decoration: _buildInputDecoration(
              context,
              hintText: 'e.g., ABC Driving School',
              prefixIcon: Icons.school_outlined,
            ).copyWith(
              helperText: 'Leave empty to use "[Your Name] School"',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 32),
          // Sign Up Button
          _buildPrimaryButton(
            label: 'Create Account',
            onPressed: _busy ? null : _handleSignUp,
            isLoading: _busy,
          ),
          const SizedBox(height: 24),
          _buildSocialDivider(),
          const SizedBox(height: 20),
          _buildSocialSignInButtons(),
          const SizedBox(height: 16),
          // Terms
          Text(
            'By signing up, you agree to our Terms of Service and Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      prefixIcon: Icon(prefixIcon, color: colorScheme.onSurfaceVariant),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? LoadingIndicator(
                size: 22,
                strokeWidth: 2.5,
                color: colorScheme.onPrimary,
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
