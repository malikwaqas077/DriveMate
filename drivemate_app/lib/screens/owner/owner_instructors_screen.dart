import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/access_request.dart';
import '../../models/school_instructor.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
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
            // Check if owner is already an instructor
            final ownerIsInstructor = links.any((link) => link.instructorId == owner.id);
            
            return Scaffold(
              body: links.isEmpty && !ownerIsInstructor
                  ? const EmptyView(message: 'No instructors yet.')
                  : Column(
                      children: [
                        // Show option to create instructor profile for owner if not already one
                        if (!ownerIsInstructor)
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.infoLight.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: AppTheme.info),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Create Instructor Profile',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.info,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Create a separate instructor account to teach lessons',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.info,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _showCreateOwnerInstructorProfile(context, schoolId),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Create'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.info,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // List of instructors
                        if (links.isNotEmpty)
                          Expanded(
                            child: ListView.separated(
                              itemCount: links.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final link = links[index];
                                final request =
                                    latestRequestByInstructor[link.instructorId];
                                final isOwner = link.instructorId == owner.id;
                                return FutureBuilder<UserProfile?>(
                                  future:
                                      _firestoreService.getUserProfile(link.instructorId),
                                  builder: (context, profileSnapshot) {
                                    final profile = profileSnapshot.data;
                                    final name = profile?.name ?? 'Instructor';
                                    final email = profile?.email ?? '';
                                    final status = request?.status ?? 'not requested';
                                    return ListTile(
                                      leading: isOwner
                                          ? Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: AppTheme.primary,
                                                size: 20,
                                              ),
                                            )
                                          : null,
                                      title: Row(
                                        children: [
                                          Text(name),
                                          if (isOwner)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primary.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'You',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      subtitle: Text(
                                        [
                                          if (email.isNotEmpty) email,
                                          'Fee: £${link.feeAmount.toStringAsFixed(2)} / ${link.feeFrequency}',
                                          'Access: $status',
                                        ].join(' · '),
                                      ),
                                      trailing: isOwner
                                          ? null
                                          : PopupMenuButton<String>(
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
                          ),
                      ],
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

  Future<void> _showCreateOwnerInstructorProfile(
    BuildContext context,
    String schoolId,
  ) async {
    final parentContext = context;
    final nameController = TextEditingController(text: owner.name);
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final feeController = TextEditingController(text: '0');
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
              title: const Text('Create Your Instructor Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.infoLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This will create a separate instructor account. You can log in with different credentials to teach lessons.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Your name for instructor profile',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        hintText: 'Different email for instructor login',
                        helperText: 'Must be different from your owner email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password *',
                        hintText: 'Create a password',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feeController,
                      decoration: const InputDecoration(
                        labelText: 'Fee amount',
                        helperText: 'Fee you pay to the school (can be 0)',
                      ),
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
                          
                          if (name.isEmpty) {
                            _showSnack(context, 'Name is required.');
                            return;
                          }
                          if (email.isEmpty || password.isEmpty) {
                            _showSnack(context, 'Email and password are required.');
                            return;
                          }
                          if (email == owner.email) {
                            _showSnack(context, 'Instructor email must be different from owner email.');
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
                              'Failed to create instructor profile: $error',
                            );
                            setDialogState(() => saving = false);
                            return;
                          }
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
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    if (loginEmail != null && loginPassword != null) {
      _showLoginDetails(parentContext, loginEmail!, loginPassword!, isOwner: true);
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
    String password, {
    bool isOwner = false,
  }) {
    final shareMessage =
        'Your DriveMate login details:\nEmail: $email\nPassword: $password';
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isOwner 
              ? 'Your Instructor Profile Created'
              : 'Instructor login created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.successLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email: $email',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Password: $password',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isOwner
                    ? 'You can now log out and sign in with these credentials to access your instructor profile and teach lessons.'
                    : 'Share these details with the instructor.',
                style: const TextStyle(fontSize: 13),
              ),
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
