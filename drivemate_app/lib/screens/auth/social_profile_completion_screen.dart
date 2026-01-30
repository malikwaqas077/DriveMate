import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Shown after Google/Apple sign-in when the user has no Firestore profile yet.
/// Collects school name and phone so we have them for the instructor profile.
class SocialProfileCompletionScreen extends StatefulWidget {
  const SocialProfileCompletionScreen({
    super.key,
    required this.uid,
    required this.email,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? displayName;

  /// Create from Firebase User (e.g. after Google/Apple sign-in).
  factory SocialProfileCompletionScreen.fromUser(User user) {
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (user.email ?? 'User');
    return SocialProfileCompletionScreen(
      uid: user.uid,
      email: user.email ?? '',
      displayName: name,
    );
  }

  @override
  State<SocialProfileCompletionScreen> createState() =>
      _SocialProfileCompletionScreenState();
}

class _SocialProfileCompletionScreenState
    extends State<SocialProfileCompletionScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _saving = false;

  String get _defaultSchoolName {
    final name = _nameController.text.trim();
    return name.isEmpty ? 'My School' : '$name School';
  }

  @override
  void initState() {
    super.initState();
    final displayName = widget.displayName ?? widget.email.split('@').first;
    _nameController.text = displayName;
    _schoolNameController.text = displayName.isEmpty ? 'My School' : '$displayName School';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Please enter your name.');
      return;
    }
    final schoolName = _schoolNameController.text.trim().isEmpty
        ? _defaultSchoolName
        : _schoolNameController.text.trim();
    final phone = _phoneController.text.trim();
    setState(() => _saving = true);
    try {
      final profile = UserProfile(
        id: widget.uid,
        role: 'instructor',
        name: name,
        email: widget.email.isEmpty ? '${widget.uid}@social.drivemate.local' : widget.email,
        phone: phone.isEmpty ? null : phone,
      );
      await _firestoreService.createUserProfile(profile);
      await _firestoreService.ensurePersonalSchool(
        instructor: profile,
        schoolName: schoolName,
      );
      if (mounted) _showSnack('Profile saved.');
    } catch (e) {
      if (mounted) _showSnack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Complete your profile',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your school name and phone so we can set up your instructor account.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Full name',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                enabled: !_saving,
                decoration: InputDecoration(
                  hintText: 'John Doe',
                  border: const OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Email',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                readOnly: true,
                controller: TextEditingController(text: widget.email),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'School name',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _schoolNameController,
                textCapitalization: TextCapitalization.words,
                enabled: !_saving,
                decoration: const InputDecoration(
                  hintText: 'e.g. ABC Driving School',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Phone (optional)',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_saving,
                decoration: const InputDecoration(
                  hintText: 'e.g. +44 7700 900000',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
