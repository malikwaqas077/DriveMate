import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/lesson.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'active';
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        status: null, // Get all students for counts
      ),
      builder: (context, allStudentsSnapshot) {
        // Get filtered students for display
        return StreamBuilder<List<Student>>(
          stream: _firestoreService.streamStudents(
            widget.instructor.id,
            status: _statusFilter,
          ),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading students...');
            }
            final students = studentsSnapshot.data ?? [];
            final allStudents = allStudentsSnapshot.data ?? [];

            // Get payments and lessons to compute credit per student
            return StreamBuilder<List<Payment>>(
              stream: _firestoreService.streamPaymentsForInstructor(widget.instructor.id),
              builder: (context, paymentsSnapshot) {
                return StreamBuilder<List<Lesson>>(
                  stream: _firestoreService.streamLessonsForInstructor(widget.instructor.id),
                  builder: (context, lessonsSnapshot) {
                    final payments = paymentsSnapshot.data ?? [];
                    final lessons = lessonsSnapshot.data ?? [];
                    final now = DateTime.now();

                    // Compute available credit per student (paid - completed only, not upcoming)
                    final creditMap = <String, double>{};
                    for (final s in students) {
                      final totalPaid = payments
                          .where((p) => p.studentId == s.id)
                          .fold<double>(0, (t, p) => t + p.hoursPurchased);
                      final completedHours = lessons
                          .where((l) => l.studentId == s.id && !l.startAt.isAfter(now))
                          .fold<double>(0, (t, l) => t + l.durationHours);
                      creditMap[s.id] = totalPaid - completedHours;
                    }

                    final statusCounts = <String, int>{
                      'all': allStudents.length,
                      'active': allStudents.where((s) => s.status == 'active').length,
                      'inactive': allStudents.where((s) => s.status == 'inactive').length,
                      'passed': allStudents.where((s) => s.status == 'passed').length,
                    };

                    // Feature 2.2: Filter students by search query
                    final filteredStudents = _searchQuery.isEmpty
                        ? students
                        : students.where((s) {
                            final query = _searchQuery.toLowerCase();
                            return s.name.toLowerCase().contains(query) ||
                                (s.phone ?? '').toLowerCase().contains(query) ||
                                (s.email ?? '').toLowerCase().contains(query);
                          }).toList();

                    return Scaffold(
                      body: Column(
                        children: [
                          // Feature 2.2: Search bar
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search students...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() => _searchQuery = value.trim());
                              },
                            ),
                          ),
                          _buildStatusFilters(statusCounts),
                          Expanded(
                            child: filteredStudents.isEmpty
                                ? EmptyView(
                                    message: _searchQuery.isNotEmpty
                                        ? 'No students match "$_searchQuery"'
                                        : 'No students yet',
                                    subtitle: _searchQuery.isNotEmpty
                                        ? 'Try a different search'
                                        : 'Add your first student to get started',
                                    type: EmptyViewType.students,
                                    actionLabel: _searchQuery.isEmpty ? 'Add Student' : null,
                                    onAction: _searchQuery.isEmpty ? () => _showAddStudent(context) : null,
                                  )
                                : _buildStudentsList(filteredStudents, creditMap),
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
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatusFilters(Map<String, int> statusCounts) {
    final colorScheme = Theme.of(context).colorScheme;
    final chips = <String>['all', ..._statusOptions];
    return Container(
      color: colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((status) {
            final selected = _statusFilter == status;
            final label = status[0].toUpperCase() + status.substring(1);
            final count = statusCounts[status] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('$label ($count)'),
                selected: selected,
                onSelected: (_) {
                  setState(() => _statusFilter = status);
                },
                avatar: status != 'all'
                    ? Icon(
                        _getStatusIcon(status),
                        size: 18,
                        color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                      )
                    : null,
                showCheckmark: false,
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                side: BorderSide(
                  color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                  width: 1,
                ),
                labelStyle: TextStyle(
                  color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
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

  Widget _buildStudentsList(
    List<Student> students,
    Map<String, double> creditMap,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        final availableCredit = creditMap[student.id] ?? 0.0;
        return _buildStudentCard(student, availableCredit);
      },
    );
  }

  Widget _buildStudentCard(Student student, double availableCredit) {
    final colorScheme = Theme.of(context).colorScheme;
    final balanceColor = availableCredit < 0
        ? AppTheme.error
        : availableCredit > 0
            ? AppTheme.success
            : colorScheme.onSurfaceVariant;

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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(
                studentId: student.id,
                studentName: student.name,
                instructorId: widget.instructor.id,
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
                    gradient: context.primaryGradient,
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
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Status badge - always on the left
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
                          const SizedBox(width: 12),
                          // Balance
                          Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: balanceColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${availableCredit.toStringAsFixed(1)}h',
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
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '£${student.hourlyRate!.toStringAsFixed(0)}/h',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (student.phone != null && student.phone!.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions
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
                          Icon(Icons.edit_outlined, size: 20, color: colorScheme.onSurfaceVariant),
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
    final addressController = TextEditingController();
    final amountPaidController = TextEditingController();
    final hoursPaidController = TextEditingController();
    String status = 'active';
    String paymentMethod = 'cash';
    String paidTo = 'instructor';
    bool createLogin = true;
    bool saving = false;
    bool optionalExpanded = false;
    bool initialPaymentExpanded = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_add_outlined,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Student',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Create a new student profile',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
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
                            controller: phoneController,
                            decoration: InputDecoration(
                              labelText: createLogin ? 'Phone Number *' : 'Phone Number (optional)',
                              prefixIcon: const Icon(Icons.phone_outlined),
                              helperText: createLogin ? 'Required for student login' : null,
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 24),
                          _buildExpandableSection(
                            context,
                            title: 'Optional Information',
                            subtitle: 'Email, address, licence, rate, status',
                            expanded: optionalExpanded,
                            onExpandedChanged: (v) => setDialogState(() => optionalExpanded = v),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email (optional)',
                                    prefixIcon: Icon(Icons.email_outlined),
                                    helperText: 'Student can add email later',
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Address (optional)',
                                    prefixIcon: Icon(Icons.location_on_outlined),
                                    helperText: 'For navigation to pickup',
                                  ),
                                  maxLines: 2,
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildExpandableSection(
                            context,
                            title: 'Initial Payment (optional)',
                            subtitle: 'Record payment when adding student',
                            expanded: initialPaymentExpanded,
                            onExpandedChanged: (v) => setDialogState(() => initialPaymentExpanded = v),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                const SizedBox(height: 16),
                                Text(
                                  'Payment Method',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildPaymentMethodChip('cash', 'Cash', Icons.payments_outlined, paymentMethod,
                                        (v) => setDialogState(() => paymentMethod = v)),
                                    _buildPaymentMethodChip('bank_transfer', 'Bank', Icons.account_balance_outlined, paymentMethod,
                                        (v) => setDialogState(() => paymentMethod = v)),
                                    _buildPaymentMethodChip('card', 'Card', Icons.credit_card_outlined, paymentMethod,
                                        (v) => setDialogState(() => paymentMethod = v)),
                                    _buildPaymentMethodChip('other', 'Other', Icons.receipt_outlined, paymentMethod,
                                        (v) => setDialogState(() => paymentMethod = v)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Paid To',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPaidToChip(
                                        context,
                                        'instructor',
                                        'Instructor',
                                        Icons.person_outline,
                                        paidTo,
                                        (v) => setDialogState(() => paidTo = v),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildPaidToChip(
                                        context,
                                        'school',
                                        'School',
                                        Icons.business_outlined,
                                        paidTo,
                                        (v) => setDialogState(() => paidTo = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildFormLabel('Student Login'),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.infoLight.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.info),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'A 6-digit password will be automatically generated and shown after creating the student.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.info,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
                      color: colorScheme.surface,
                      border: Border(
                        top: BorderSide(color: colorScheme.outlineVariant),
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
                                      addressController: addressController,
                                      amountPaidController: amountPaidController,
                                      hoursPaidController: hoursPaidController,
                                      status: status,
                                      paymentMethod: paymentMethod,
                                      paidTo: paidTo,
                                      createLogin: createLogin,
                                      saving: saving,
                                      setSaving: (val) => setDialogState(() => saving = val),
                                    ),
                            child: saving
                                ? LoadingIndicator(size: 20, color: colorScheme.onPrimary)
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
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildExpandableSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool expanded,
    required ValueChanged<bool> onExpandedChanged,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: onExpandedChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Icon(Icons.expand_more, color: colorScheme.onSurfaceVariant, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip(
    String value,
    String label,
    IconData icon,
    String current,
    ValueChanged<String> onSelect,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.15) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppTheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidToChip(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    String current,
    ValueChanged<String> onSelect,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.15) : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isSelected ? AppTheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : colorScheme.onSurface,
              ),
            ),
          ],
        ),
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
    required TextEditingController addressController,
    required TextEditingController amountPaidController,
    required TextEditingController hoursPaidController,
    required String status,
    required String paymentMethod,
    required String paidTo,
    required bool createLogin,
    required bool saving,
    required Function(bool) setSaving,
  }) async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    var phone = phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    
    // Normalize phone number: ensure it starts with + if it doesn't already
    if (phone.isNotEmpty && !phone.startsWith('+')) {
      // If it starts with 0, replace with country code (assuming UK, but could be made configurable)
      if (phone.startsWith('0')) {
        phone = '+44${phone.substring(1)}';
      } else {
        // Otherwise, assume it's missing the + prefix
        phone = '+$phone';
      }
    }
    
    if (name.isEmpty) {
      _showSnack(context, 'Name is required.');
      return;
    }
    if (createLogin) {
      if (phone.isEmpty) {
        _showSnack(context, 'Phone number is required to create student login.');
        return;
      }
    }
    // Auto-generate 6-digit password for student login
    final password = createLogin ? AuthService.generateRandomPassword() : '';
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
      address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
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
          method: paymentMethod,
          paidTo: paidTo,
          hoursPurchased: hoursPaid,
          createdAt: DateTime.now(),
        );
        await _firestoreService.addPayment(payment: payment, studentId: studentId);
      } catch (error) {
        _showSnack(context, 'Student added, but payment failed: $error');
      }
    }
    String? loginPhone;
    String? loginPassword;
    String? loginError;
    String? loginWarning;
    if (createLogin && studentId != null) {
      try {
        final credential = await _authService.createStudentLogin(
          phone: phone,
          email: email.isEmpty ? null : email,
          password: password,
        );
        final user = credential.user;
        if (user != null) {
          // Check if user profile already exists
          final existingProfile = await _firestoreService.getUserProfile(user.uid);
          if (existingProfile == null) {
            // Create new profile
            final profile = UserProfile(
              id: user.uid,
              role: 'student',
              name: name,
              email: email.isEmpty ? AuthService.phoneToEmail(phone) : email,
              phone: phone,
              password: password, // Store password for instructor access
              studentId: studentId,
            );
            await _firestoreService.createUserProfile(profile);
          } else {
            // Profile already exists - update studentId if needed
            if (existingProfile.studentId != studentId) {
              await _firestoreService.updateUserProfile(user.uid, {
                'studentId': studentId,
              });
            }
            loginWarning = 'Login account already exists for this phone number';
          }
          loginPhone = phone;
          loginPassword = password;
        }
      } on FirebaseAuthException catch (e) {
        // Handle email-already-in-use - this means Auth account exists
        if (e.code == 'email-already-in-use') {
          // Check if there's an existing user profile linked to this student
          final existingProfile = await _firestoreService.getUserProfileByStudentId(studentId);
          
          if (existingProfile == null) {
            // No profile exists - this is an orphaned Auth account from a deleted student
            // We can't update the password or get the UID from client SDK
            // The student was added successfully, but login creation failed
            // Solution: Implement Cloud Function (see docs/firebase-auth-cleanup-cloud-function.md)
            // OR manually delete the Auth account from Firebase Console:
            // Authentication → Users → Find by email (+447727377256@drivemate.local) → Delete
            loginWarning = 'Student added successfully. A login account exists for this phone number from a previously deleted student. To create login with new password, delete the old Auth account from Firebase Console (Authentication → Users) or implement the Cloud Function.';
          } else {
            // Profile exists - account is already linked to this student
            loginWarning = 'Student added successfully. Login account already exists for this phone number.';
            loginPhone = phone;
            loginPassword = password;
          }
        } else {
          loginError = e.message ?? e.toString();
        }
      } catch (error) {
        loginError = error.toString();
      }
    }
    if (context.mounted) {
      Navigator.pop(context);
    }
    if (context.mounted && loginPhone != null && loginPassword != null) {
      if (loginWarning != null) {
        // Show warning first, then login details
        _showSnack(context, loginWarning, isError: false);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            _showLoginDetails(context, loginPhone!, loginPassword!);
          }
        });
      } else {
        _showLoginDetails(context, loginPhone, loginPassword);
      }
    } else if (context.mounted && loginWarning != null) {
      _showSnack(context, loginWarning, isError: false);
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
    final addressController = TextEditingController(text: student.address ?? '');
    String status = student.status;
    bool saving = false;
    bool optionalExpanded = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: context.primaryGradient,
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
                              Text(
                                'Edit Student',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                student.name,
                                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
                          const SizedBox(height: 24),
                          _buildExpandableSection(
                            context,
                            title: 'Optional Information',
                            subtitle: 'Email, address, licence, rate, status',
                            expanded: optionalExpanded,
                            onExpandedChanged: (v) => setDialogState(() => optionalExpanded = v),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: addressController,
                                  decoration: const InputDecoration(
                                    labelText: 'Address (optional)',
                                    prefixIcon: Icon(Icons.location_on_outlined),
                                  ),
                                  maxLines: 2,
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
                        ],
                      ),
                    ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
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
                                        'address': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
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
                                ? LoadingIndicator(size: 20, color: colorScheme.onPrimary)
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
      if (context.mounted) {
        _showSnack(
          context,
          'Student deleted successfully',
          isError: false,
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showSnack(context, 'Failed to delete student: $error');
      }
    }
  }

  void _showSnack(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? AppTheme.error : AppTheme.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLoginDetails(BuildContext context, String phone, String password) {
    final shareMessage = 'Your DriveMate login details:\nPhone Number: $phone\nPassword: $password';
    showDialog<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
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
              Expanded(child: Text('Login Created', style: TextStyle(color: colorScheme.onSurface))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            phone,
                            style: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(password, style: TextStyle(fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Share these details with the student so they can access their lessons.',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
