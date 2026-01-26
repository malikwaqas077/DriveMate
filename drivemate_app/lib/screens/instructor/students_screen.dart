import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';
import 'student_detail_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  String _statusFilter = 'all';

  static const List<String> _statusOptions = [
    'active',
    'inactive',
    'passed',
  ];

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.success;
      case 'inactive':
        return AppTheme.neutral500;
      case 'passed':
        return AppTheme.info;
      default:
        return AppTheme.neutral500;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.successLight;
      case 'inactive':
        return AppTheme.neutral200;
      case 'passed':
        return AppTheme.infoLight;
      default:
        return AppTheme.neutral200;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.check_circle_outline;
      case 'inactive':
        return Icons.pause_circle_outline;
      case 'passed':
        return Icons.emoji_events_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Student>>(
      stream: _firestoreService.streamStudents(
        widget.instructor.id,
        status: _statusFilter,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading students...');
        }
        final students = snapshot.data ?? [];
        return Scaffold(
          backgroundColor: AppTheme.neutral50,
          body: Column(
            children: [
              _buildStatusFilters(),
              Expanded(
                child: students.isEmpty
                    ? EmptyView(
                        message: 'No students yet',
                        subtitle: 'Add your first student to get started',
                        type: EmptyViewType.students,
                        actionLabel: 'Add Student',
                        onAction: () => _showAddStudent(context),
                      )
                    : _buildStudentsList(students),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddStudent(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Student'),
          ),
        );
      },
    );
  }

  Widget _buildStatusFilters() {
    final chips = <String>['all', ..._statusOptions];
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((status) {
            final selected = _statusFilter == status;
            final label = status[0].toUpperCase() + status.substring(1);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  setState(() => _statusFilter = status);
                },
                avatar: status != 'all'
                    ? Icon(
                        _getStatusIcon(status),
                        size: 18,
                        color: selected ? AppTheme.primary : AppTheme.neutral500,
                      )
                    : null,
                showCheckmark: false,
                backgroundColor: Colors.white,
                selectedColor: AppTheme.primary.withOpacity(0.12),
                side: BorderSide(
                  color: selected ? AppTheme.primary : AppTheme.neutral200,
                  width: 1,
                ),
                labelStyle: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.neutral600,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStudentsList(List<Student> students) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return _buildStudentCard(student);
      },
    );
  }

  Widget _buildStudentCard(Student student) {
    final balanceColor = student.balanceHours < 0
        ? AppTheme.error
        : student.balanceHours > 0
            ? AppTheme.success
            : AppTheme.neutral500;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(
                studentId: student.id,
                studentName: student.name,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(student.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.neutral900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusBackgroundColor(student.status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              student.status[0].toUpperCase() +
                                  student.status.substring(1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(student.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Balance
                          Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: balanceColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${student.balanceHours.toStringAsFixed(1)}h',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: balanceColor,
                            ),
                          ),
                          if (student.hourlyRate != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.payments_outlined,
                              size: 14,
                              color: AppTheme.neutral500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '£${student.hourlyRate!.toStringAsFixed(0)}/h',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.neutral600,
                              ),
                            ),
                          ],
                          if (student.phone != null && student.phone!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: AppTheme.neutral500,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppTheme.neutral500,
                  ),
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditStudent(context, student);
                    } else if (value == 'delete') {
                      _confirmDeleteStudent(context, student);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20, color: AppTheme.neutral600),
                          const SizedBox(width: 12),
                          const Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.error),
                          const SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: AppTheme.error)),
                        ],
                      ),
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _showAddStudent(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final rateController = TextEditingController();
    final phoneController = TextEditingController();
    final licenceController = TextEditingController();
    final amountPaidController = TextEditingController();
    final hoursPaidController = TextEditingController();
    String status = 'active';
    bool createLogin = true;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.neutral200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Student',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.neutral900,
                                ),
                              ),
                              Text(
                                'Create a new student profile',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.neutral500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Only minimal information is required. Student can complete their profile after logging in.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildFormLabel('Required Information'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email *',
                              prefixIcon: Icon(Icons.email_outlined),
                              helperText: 'Required if creating student login',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 24),
                          _buildFormLabel('Optional Information (can be added later)'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number (optional)',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: licenceController,
                            decoration: const InputDecoration(
                              labelText: 'Licence Number (optional)',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: rateController,
                            decoration: const InputDecoration(
                              labelText: 'Hourly Rate (£) (optional)',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: _statusOptions
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getStatusIcon(value),
                                          size: 18,
                                          color: _getStatusColor(value),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(value[0].toUpperCase() + value.substring(1)),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => status = value);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildFormLabel('Initial Payment (optional)'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: amountPaidController,
                                  decoration: const InputDecoration(
                                    labelText: 'Amount (£)',
                                    prefixIcon: Icon(Icons.currency_pound),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: hoursPaidController,
                                  decoration: const InputDecoration(
                                    labelText: 'Hours',
                                    prefixIcon: Icon(Icons.schedule_outlined),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildFormLabel('Student Login'),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.neutral50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                SwitchListTile(
                                  value: createLogin,
                                  title: const Text('Create student app login'),
                                  subtitle: const Text('Allow student to track lessons'),
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: saving
                                      ? null
                                      : (value) => setDialogState(() => createLogin = value),
                                ),
                                if (createLogin) ...[
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: passwordController,
                                    decoration: const InputDecoration(
                                      labelText: 'Temporary Password',
                                      prefixIcon: Icon(Icons.lock_outline),
                                    ),
                                    obscureText: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppTheme.neutral200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () => _saveStudent(
                                      context,
                                      setDialogState,
                                      nameController: nameController,
                                      emailController: emailController,
                                      passwordController: passwordController,
                                      rateController: rateController,
                                      phoneController: phoneController,
                                      licenceController: licenceController,
                                      amountPaidController: amountPaidController,
                                      hoursPaidController: hoursPaidController,
                                      status: status,
                                      createLogin: createLogin,
                                      saving: saving,
                                      setSaving: (val) => setDialogState(() => saving = val),
                                    ),
                            child: saving
                                ? const LoadingIndicator(size: 20, color: Colors.white)
                                : const Text('Save Student'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFormLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.neutral700,
      ),
    );
  }

  Future<void> _saveStudent(
    BuildContext context,
    StateSetter setDialogState, {
    required TextEditingController nameController,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required TextEditingController rateController,
    required TextEditingController phoneController,
    required TextEditingController licenceController,
    required TextEditingController amountPaidController,
    required TextEditingController hoursPaidController,
    required String status,
    required bool createLogin,
    required bool saving,
    required Function(bool) setSaving,
  }) async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (name.isEmpty) {
      _showSnack(context, 'Name is required.');
      return;
    }
    if (createLogin) {
      if (email.isEmpty) {
        _showSnack(context, 'Email is required to create student login.');
        return;
      }
      if (password.isEmpty) {
        _showSnack(context, 'Temporary password is required.');
        return;
      }
    }
    setSaving(true);
    final rateText = rateController.text.trim();
    final rate = rateText.isEmpty ? null : double.tryParse(rateText);
    if (rateText.isNotEmpty && rate == null) {
      _showSnack(context, 'Please enter a valid hourly rate.');
      setSaving(false);
      return;
    }
    final amountPaid = double.tryParse(amountPaidController.text) ?? 0;
    final hoursPaid = double.tryParse(hoursPaidController.text) ?? 0;
    if (amountPaid > 0 && hoursPaid <= 0) {
      _showSnack(context, 'Please enter hours for the amount paid.');
      setSaving(false);
      return;
    }
    final student = Student(
      id: '',
      instructorId: widget.instructor.id,
      name: name,
      schoolId: widget.instructor.schoolId,
      email: email.isEmpty ? null : email,
      phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      licenseNumber: licenceController.text.trim().isEmpty ? null : licenceController.text.trim(),
      hourlyRate: rate,
      balanceHours: 0,
      status: status,
    );
    String? studentId;
    try {
      studentId = await _firestoreService.addStudent(student);
    } catch (error) {
      _showSnack(context, 'Failed to add student: $error');
      setSaving(false);
      return;
    }
    if (studentId != null && hoursPaid > 0) {
      try {
        final payment = Payment(
          id: '',
          instructorId: widget.instructor.id,
          studentId: studentId,
          schoolId: widget.instructor.schoolId,
          amount: amountPaid,
          currency: 'GBP',
          method: 'cash',
          paidTo: 'instructor',
          hoursPurchased: hoursPaid,
          createdAt: DateTime.now(),
        );
        await _firestoreService.addPayment(payment: payment, studentId: studentId);
      } catch (error) {
        _showSnack(context, 'Student added, but payment failed: $error');
      }
    }
    String? loginEmail;
    String? loginPassword;
    String? loginError;
    if (createLogin && studentId != null) {
      try {
        final credential = await _authService.createStudentLogin(email: email, password: password);
        final user = credential.user;
        if (user != null) {
          final profile = UserProfile(
            id: user.uid,
            role: 'student',
            name: name,
            email: email,
            studentId: studentId,
          );
          await _firestoreService.createUserProfile(profile);
          loginEmail = email;
          loginPassword = password;
        }
      } catch (error) {
        loginError = error.toString();
      }
    }
    if (context.mounted) {
      Navigator.pop(context);
    }
    if (context.mounted && loginEmail != null && loginPassword != null) {
      _showLoginDetails(context, loginEmail, loginPassword);
    } else if (context.mounted && loginError != null) {
      _showSnack(context, 'Student added, but login failed: $loginError');
    }
  }

  Future<void> _showEditStudent(BuildContext context, Student student) async {
    final nameController = TextEditingController(text: student.name);
    final emailController = TextEditingController(text: student.email ?? '');
    final rateController = TextEditingController(text: student.hourlyRate?.toStringAsFixed(2) ?? '');
    final phoneController = TextEditingController(text: student.phone ?? '');
    final licenceController = TextEditingController(text: student.licenseNumber ?? '');
    String status = student.status;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.neutral200)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              _getInitials(student.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit Student',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.neutral900,
                                ),
                              ),
                              Text(
                                student.name,
                                style: const TextStyle(fontSize: 13, color: AppTheme.neutral500),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
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
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: licenceController,
                            decoration: const InputDecoration(
                              labelText: 'Licence Number',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: rateController,
                            decoration: const InputDecoration(
                              labelText: 'Hourly Rate (£)',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              prefixIcon: Icon(Icons.flag_outlined),
                            ),
                            items: _statusOptions
                                .map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Row(
                                      children: [
                                        Icon(
                                          _getStatusIcon(value),
                                          size: 18,
                                          color: _getStatusColor(value),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(value[0].toUpperCase() + value.substring(1)),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => status = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppTheme.neutral200)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    final name = nameController.text.trim();
                                    if (name.isEmpty) {
                                      _showSnack(context, 'Name is required.');
                                      return;
                                    }
                                    setDialogState(() => saving = true);
                                    try {
                                      final rateText = rateController.text.trim();
                                      final parsedRate = rateText.isEmpty ? null : double.tryParse(rateText);
                                      if (rateText.isNotEmpty && parsedRate == null) {
                                        _showSnack(context, 'Please enter a valid hourly rate.');
                                        setDialogState(() => saving = false);
                                        return;
                                      }
                                      await _firestoreService.updateStudent(student.id, {
                                        'name': name,
                                        'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                                        'licenseNumber': licenceController.text.trim().isEmpty ? null : licenceController.text.trim(),
                                        'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                                        'hourlyRate': parsedRate,
                                        'status': status,
                                      });
                                    } catch (error) {
                                      _showSnack(context, 'Failed to update student: $error');
                                      setDialogState(() => saving = false);
                                      return;
                                    }
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                            child: saving
                                ? const LoadingIndicator(size: 20, color: Colors.white)
                                : const Text('Save Changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteStudent(BuildContext context, Student student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 22),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Text('Delete student?')),
            ],
          ),
          content: Text('This will permanently remove ${student.name} and all their data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;
    try {
      await _firestoreService.deleteStudent(student.id);
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, 'Failed to delete student: $error');
      }
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLoginDetails(BuildContext context, String email, String password) {
    final shareMessage = 'Your DriveMate login details:\nEmail: $email\nPassword: $password';
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Text('Login Created')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.neutral50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 16, color: AppTheme.neutral500),
                        const SizedBox(width: 8),
                        Text(email, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 16, color: AppTheme.neutral500),
                        const SizedBox(width: 8),
                        Text(password, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Share these details with the student so they can access their lessons.',
                style: TextStyle(fontSize: 13, color: AppTheme.neutral600),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: shareMessage));
                if (context.mounted) {
                  _showSnack(context, 'Login details copied');
                }
              },
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('Copy'),
            ),
            TextButton.icon(
              onPressed: () => Share.share(shareMessage, subject: 'DriveMate login details'),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }
}
