import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/access_request.dart';
import '../../models/school_instructor.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';
import 'owner_instructor_detail_screen.dart';

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
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: links.length,
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
                                    return StreamBuilder<List<Student>>(
                                      stream: _firestoreService.streamStudents(link.instructorId),
                                      builder: (context, studentsSnapshot) {
                                        final students = studentsSnapshot.data ?? [];
                                        final studentCount = students.length;
                                        return _InstructorCard(
                                          name: name,
                                          email: email,
                                          studentCount: studentCount,
                                          feeAmount: link.feeAmount,
                                          feeFrequency: link.feeFrequency,
                                          accessStatus: status,
                                          isOwner: isOwner,
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => OwnerInstructorDetailScreen(
                                                  owner: owner,
                                                  link: link,
                                                  instructorName: name,
                                                  accessStatus: status,
                                                ),
                                              ),
                                            );
                                          },
                                          onRequestAccess: isOwner ? null : () => _requestAccess(link.instructorId),
                                          onEditFee: isOwner ? null : () => _editFee(context, link),
                                        );
                                      },
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.person_add_outlined,
                            color: colorScheme.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add instructor',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create a new instructor account',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Required information',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              hintText: 'Instructor full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'instructor@example.com',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: passwordController,
                            decoration: const InputDecoration(
                              labelText: 'Temporary password',
                              hintText: 'Share with instructor to log in',
                              prefixIcon: Icon(Icons.lock_outline),
                              helperText: 'Instructor can change this after first login',
                            ),
                            obscureText: true,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Fee settings',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: feeController,
                            decoration: const InputDecoration(
                              labelText: 'Fee amount (£)',
                              hintText: '0.00',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: frequency,
                            decoration: const InputDecoration(
                              labelText: 'Fee frequency',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            style: const TextStyle(fontSize: 16),
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
                  ),
                  // Footer buttons
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
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
                                        setDialogState(() => saving = false);
                                        return;
                                      }
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: saving
                                  ? SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Text('Add instructor'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

class _InstructorCard extends StatelessWidget {
  const _InstructorCard({
    required this.name,
    required this.email,
    required this.studentCount,
    required this.feeAmount,
    required this.feeFrequency,
    required this.accessStatus,
    required this.isOwner,
    required this.onTap,
    this.onRequestAccess,
    this.onEditFee,
  });

  final String name;
  final String email;
  final int studentCount;
  final double feeAmount;
  final String feeFrequency;
  final String accessStatus;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback? onRequestAccess;
  final VoidCallback? onEditFee;

  Color _accessColor() {
    switch (accessStatus) {
      case 'approved':
        return AppTheme.success;
      case 'pending':
        return AppTheme.warning;
      default:
        return AppTheme.neutral500;
    }
  }

  Color _accessBgColor() {
    switch (accessStatus) {
      case 'approved':
        return AppTheme.successLight;
      case 'pending':
        return AppTheme.warningLight;
      default:
        return AppTheme.neutral200;
    }
  }

  String _getInitials(String n) {
    final parts = n.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final freqLabel = feeFrequency == 'week' ? 'week' : 'month';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: isOwner
                            ? context.primaryGradient
                            : LinearGradient(
                                colors: [
                                  AppTheme.primary.withOpacity(0.8),
                                  AppTheme.primaryLight.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _getInitials(name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              if (isOwner) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.email_outlined,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _InfoChip(
                                icon: Icons.people_outline_rounded,
                                label: '$studentCount students',
                              ),
                              _InfoChip(
                                icon: Icons.payments_outlined,
                                label: '£${feeAmount.toStringAsFixed(2)}/$freqLabel',
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _accessBgColor(),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _accessColor().withOpacity(0.4),
                                  ),
                                ),
                                child: Text(
                                  'Access: ${accessStatus == 'not requested' ? 'Not requested' : accessStatus}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _accessColor(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onRequestAccess != null || onEditFee != null)
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        position: PopupMenuPosition.under,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'request_access' && onRequestAccess != null) {
                            onRequestAccess!();
                          } else if (value == 'edit_fee' && onEditFee != null) {
                            onEditFee!();
                          }
                        },
                        itemBuilder: (context) => [
                          if (onRequestAccess != null)
                            const PopupMenuItem(
                              value: 'request_access',
                              child: Text('Request access'),
                            ),
                          if (onEditFee != null)
                            const PopupMenuItem(
                              value: 'edit_fee',
                              child: Text('Edit fee'),
                            ),
                        ],
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
