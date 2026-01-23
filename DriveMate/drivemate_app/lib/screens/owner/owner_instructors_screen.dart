import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/access_request.dart';
import '../../models/school_instructor.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class OwnerInstructorsScreen extends StatelessWidget {
  OwnerInstructorsScreen({super.key, required this.owner});

  final UserProfile owner;
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final schoolId = owner.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return const Center(child: Text('School not set up.'));
    }
    return StreamBuilder<List<SchoolInstructor>>(
      stream: _firestoreService.streamSchoolInstructors(schoolId),
      builder: (context, linkSnapshot) {
        if (linkSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading instructors...');
        }
        final links = linkSnapshot.data ?? [];
        return StreamBuilder<List<AccessRequest>>(
          stream: _firestoreService.streamAccessRequestsForSchool(schoolId),
          builder: (context, accessSnapshot) {
            if (accessSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading access...');
            }
            final requests = accessSnapshot.data ?? [];
            final latestRequestByInstructor = <String, AccessRequest>{};
            for (final request in requests) {
              final existing = latestRequestByInstructor[request.instructorId];
              if (existing == null ||
                  (request.createdAt ?? DateTime(0))
                      .isAfter(existing.createdAt ?? DateTime(0))) {
                latestRequestByInstructor[request.instructorId] = request;
              }
            }
            return Scaffold(
              body: links.isEmpty
                  ? const EmptyView(message: 'No instructors yet.')
                  : ListView.separated(
                      itemCount: links.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final link = links[index];
                        final request =
                            latestRequestByInstructor[link.instructorId];
                        return FutureBuilder<UserProfile?>(
                          future:
                              _firestoreService.getUserProfile(link.instructorId),
                          builder: (context, profileSnapshot) {
                            final profile = profileSnapshot.data;
                            final name = profile?.name ?? 'Instructor';
                            final email = profile?.email ?? '';
                            final status = request?.status ?? 'not requested';
                            return ListTile(
                              title: Text(name),
                              subtitle: Text(
                                [
                                  if (email.isNotEmpty) email,
                                  'Fee: £${link.feeAmount.toStringAsFixed(2)} / ${link.feeFrequency}',
                                  'Access: $status',
                                ].join(' · '),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'request_access') {
                                    _requestAccess(link.instructorId);
                                  } else if (value == 'edit_fee') {
                                    _editFee(context, link);
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: 'request_access',
                                    child: Text('Request access'),
                                  ),
                                  PopupMenuItem(
                                    value: 'edit_fee',
                                    child: Text('Edit fee'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
              floatingActionButton: FloatingActionButton(
                onPressed: () => _showAddInstructor(context, schoolId),
                child: const Icon(Icons.add),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _requestAccess(String instructorId) {
    final schoolId = owner.schoolId ?? '';
    return _firestoreService.requestAccess(
      schoolId: schoolId,
      ownerId: owner.id,
      instructorId: instructorId,
    );
  }

  Future<void> _editFee(
    BuildContext context,
    SchoolInstructor link,
  ) async {
    final feeController =
        TextEditingController(text: link.feeAmount.toStringAsFixed(2));
    String frequency = link.feeFrequency;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit instructor fee'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: feeController,
                    decoration: const InputDecoration(labelText: 'Fee amount'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: frequency,
                    items: const [
                      DropdownMenuItem(value: 'week', child: Text('Weekly')),
                      DropdownMenuItem(value: 'month', child: Text('Monthly')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => frequency = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final fee = double.tryParse(feeController.text) ?? 0;
                          setDialogState(() => saving = true);
                          await _firestoreService.updateSchoolInstructorFee(
                            linkId: link.id,
                            feeAmount: fee,
                            feeFrequency: frequency,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddInstructor(
    BuildContext context,
    String schoolId,
  ) async {
    final parentContext = context;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final feeController = TextEditingController();
    String frequency = 'week';
    bool saving = false;
    String? loginEmail;
    String? loginPassword;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add instructor'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Temp password'),
                      obscureText: true,
                    ),
                    TextField(
                      controller: feeController,
                      decoration: const InputDecoration(labelText: 'Fee amount'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: frequency,
                      decoration: const InputDecoration(labelText: 'Fee frequency'),
                      items: const [
                        DropdownMenuItem(value: 'week', child: Text('Weekly')),
                        DropdownMenuItem(value: 'month', child: Text('Monthly')),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => frequency = value);
                              }
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          final password = passwordController.text;
                          if (name.isEmpty || email.isEmpty || password.isEmpty) {
                            _showSnack(context, 'All fields are required.');
                            return;
                          }
                          final feeAmount =
                              double.tryParse(feeController.text) ?? 0;
                          setDialogState(() => saving = true);
                          try {
                            final credential =
                                await _authService.createInstructorLogin(
                              email: email,
                              password: password,
                            );
                            final user = credential.user;
                            if (user != null) {
                              await _firestoreService.createUserProfile(
                                UserProfile(
                                  id: user.uid,
                                  role: 'instructor',
                                  name: name,
                                  email: email,
                                  schoolId: schoolId,
                                ),
                              );
                              await _firestoreService.addInstructorToSchool(
                                schoolId: schoolId,
                                instructorId: user.uid,
                                feeAmount: feeAmount,
                                feeFrequency: frequency,
                              );
                              loginEmail = email;
                              loginPassword = password;
                            }
                          } catch (error) {
                            _showSnack(
                              context,
                              'Failed to add instructor: $error',
                            );
                          } finally {
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
    if (loginEmail != null && loginPassword != null) {
      _showLoginDetails(parentContext, loginEmail!, loginPassword!);
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLoginDetails(
    BuildContext context,
    String email,
    String password,
  ) {
    final shareMessage =
        'Your DriveMate login details:\nEmail: $email\nPassword: $password';
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Instructor login created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: $email'),
              const SizedBox(height: 8),
              Text('Password: $password'),
              const SizedBox(height: 8),
              const Text('Share these details with the instructor.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: shareMessage));
                if (context.mounted) {
                  _showSnack(context, 'Login details copied.');
                }
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Share.share(
                shareMessage,
                subject: 'DriveMate login details',
              ),
              child: const Text('Share'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
