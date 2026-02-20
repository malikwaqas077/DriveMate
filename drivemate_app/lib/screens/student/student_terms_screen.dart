import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/terms.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class StudentTermsScreen extends StatefulWidget {
  const StudentTermsScreen({
    super.key,
    required this.profile,
    required this.terms,
  });

  final UserProfile profile;
  final Terms terms;

  @override
  State<StudentTermsScreen> createState() => _StudentTermsScreenState();
}

class _StudentTermsScreenState extends State<StudentTermsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  bool _saving = false;
  bool _hasScrolledToEnd = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Check after first frame in case content is short enough to not scroll
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIfAlreadyAtEnd());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkIfAlreadyAtEnd() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent <= 0) {
      // Content fits on screen, no scrolling needed
      setState(() => _hasScrolledToEnd = true);
    }
  }

  void _onScroll() {
    if (_hasScrolledToEnd) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 20) {
      setState(() => _hasScrolledToEnd = true);
    }
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      await _firestoreService.updateUserProfile(widget.profile.id, {
        'acceptedTermsVersion': widget.terms.version,
        'acceptedTermsAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept terms: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _decline() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Decline terms?'),
          content: const Text(
            'You must accept the terms to use DriveMate.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await _authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.terms.text,
                  style: const TextStyle(height: 1.5),
                ),
              ),
            ),
            // Scroll hint when not yet scrolled to end
            if (!_hasScrolledToEnd)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: colorScheme.primaryContainer.withOpacity(0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Please read and scroll to the end',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _decline,
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving || !_hasScrolledToEnd ? null : _accept,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
