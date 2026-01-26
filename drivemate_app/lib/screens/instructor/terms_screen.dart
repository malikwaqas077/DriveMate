import 'package:flutter/material.dart';

import '../../models/terms.dart';
import '../../services/firestore_service.dart';
import '../../widgets/loading_view.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({
    super.key,
    required this.schoolId,
    required this.canEdit,
  });

  final String schoolId;
  final bool canEdit;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;
  bool _dirty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!widget.canEdit) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _showSnack('Please enter the terms and conditions.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _firestoreService.saveSchoolTerms(
        schoolId: widget.schoolId,
        text: text,
      );
      _dirty = false;
      if (mounted) {
        _showSnack('Terms updated.');
      }
    } catch (error) {
      _showSnack('Failed to save terms: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: SafeArea(
        child: StreamBuilder<Terms?>(
          stream: _firestoreService.streamTermsForSchool(widget.schoolId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading terms...');
            }
            final terms = snapshot.data;
            if (!_dirty) {
              _controller.text = terms?.text ?? '';
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Terms & Conditions',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      if (terms != null)
                        Text(
                          'v${terms.version}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                  if (terms?.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Last updated: ${terms!.updatedAt!.toLocal()}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      readOnly: !widget.canEdit,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'Enter the terms students must accept before using the app.',
                      ),
                      onChanged: widget.canEdit ? (_) => _dirty = true : null,
                    ),
                  ),
                  if (widget.canEdit) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save terms'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
