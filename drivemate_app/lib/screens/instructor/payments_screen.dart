import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/payment.dart';
import '../../models/student.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';

class PaymentsScreen extends StatelessWidget {
  PaymentsScreen({super.key, required this.instructor});

  final UserProfile instructor;
  final FirestoreService _firestoreService = FirestoreService();

  final _currency = 'GBP';

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank_transfer':
        return Icons.account_balance_outlined;
      case 'card':
        return Icons.credit_card_outlined;
      case 'other':
        return Icons.receipt_outlined;
      default:
        // Custom payment methods use the default icon
        return Icons.payments_outlined;
    }
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'cash':
        return AppTheme.success;
      case 'bank_transfer':
        return AppTheme.info;
      case 'card':
        return const Color(0xFF8B5CF6);
      case 'other':
        return AppTheme.neutral500;
      default:
        // Custom payment methods use primary color
        return AppTheme.primary;
    }
  }

  Color _getMethodBackgroundColor(String method) {
    switch (method) {
      case 'cash':
        return AppTheme.successLight;
      case 'bank_transfer':
        return AppTheme.infoLight;
      case 'card':
        return const Color(0xFFEDE9FE);
      case 'other':
        return AppTheme.neutral100;
      default:
        // Custom payment methods use primary light color
        return AppTheme.primaryLight;
    }
  }

  String _getMethodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'card':
        return 'Card';
      case 'other':
        return 'Other';
      default:
        // Check if it's a custom payment method
        final customMethods = instructor.instructorSettings?.customPaymentMethods ?? [];
        try {
          final customMethod = customMethods.firstWhere((m) => m.id == method);
          return customMethod.label;
        } catch (_) {
          return method.replaceAll('_', ' ').isNotEmpty
              ? method.replaceAll('_', ' ')
              : 'Other';
        }
    }
  }

  List<Map<String, dynamic>> _getAllPaymentMethods() {
    final builtInMethods = [
      {'id': 'cash', 'label': 'Cash', 'icon': Icons.payments_outlined},
      {'id': 'bank_transfer', 'label': 'Bank', 'icon': Icons.account_balance_outlined},
      {'id': 'card', 'label': 'Card', 'icon': Icons.credit_card_outlined},
      {'id': 'other', 'label': 'Other', 'icon': Icons.receipt_outlined},
    ];
    
    final customMethods = instructor.instructorSettings?.customPaymentMethods ?? [];
    final customMethodList = customMethods.map((m) => {
      'id': m.id,
      'label': m.label,
      'icon': Icons.payments_outlined,
    }).toList();
    
    return [...builtInMethods, ...customMethodList];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Student>>(
      stream: _firestoreService.streamStudents(instructor.id),
      builder: (context, studentsSnapshot) {
        if (studentsSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading payments...');
        }
        final students = studentsSnapshot.data ?? [];
        final studentMap = {
          for (final student in students) student.id: student.name,
        };
        final schoolId = instructor.schoolId;
        return StreamBuilder<List<Payment>>(
          stream: _firestoreService.streamPaymentsForInstructor(instructor.id),
          builder: (context, paymentsSnapshot) {
            if (paymentsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(message: 'Loading payments...');
            }
            final payments = paymentsSnapshot.data ?? [];

            // Calculate summary
            final totalAmount = payments.fold<double>(0, (sum, p) => sum + p.amount);
            final totalHours = payments.fold<double>(0, (sum, p) => sum + p.hoursPurchased);

            return Scaffold(
              body: Column(
                children: [
                  // Summary Card
                  _buildSummaryCard(context, totalAmount, totalHours, payments.length),
                  // Payments List
                  Expanded(
                    child: payments.isEmpty
                        ? EmptyView(
                            message: 'No payments yet',
                            subtitle: 'Record your first payment to get started',
                            type: EmptyViewType.payments,
                            actionLabel: 'Add Payment',
                            onAction: students.isEmpty
                                ? null
                                : () => _showAddPayment(context, students, schoolId),
                          )
                        : _buildPaymentsList(context, payments, studentMap, students, schoolId),
                  ),
                ],
              ),
              floatingActionButton: students.isEmpty
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: () => _showAddPayment(context, students, schoolId),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Payment'),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    double totalAmount,
    double totalHours,
    int count,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Revenue',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '£${totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  icon: Icons.schedule_outlined,
                  label: 'Hours',
                  value: '${totalHours.toStringAsFixed(1)}h',
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withOpacity(0.3),
                ),
                _buildSummaryItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transactions',
                  value: count.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentsList(
    BuildContext context,
    List<Payment> payments,
    Map<String, String> studentMap,
    List<Student> students,
    String? schoolId,
  ) {
    // Group payments by date
    final groupedPayments = <String, List<Payment>>{};
    for (final payment in payments) {
      final dateKey = DateFormat('yyyy-MM-dd').format(payment.createdAt);
      groupedPayments.putIfAbsent(dateKey, () => []).add(payment);
    }

    final sortedKeys = groupedPayments.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final dayPayments = groupedPayments[dateKey]!;
        final date = DateTime.parse(dateKey);
        final isToday = _isToday(date);
        final isYesterday = _isYesterday(date);

        String dateLabel;
        if (isToday) {
          dateLabel = 'Today';
        } else if (isYesterday) {
          dateLabel = 'Yesterday';
        } else {
          dateLabel = DateFormat('EEEE, d MMMM').format(date);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.neutral500,
                ),
              ),
            ),
            ...dayPayments.map((payment) => _buildPaymentCard(
                  context,
                  payment,
                  studentMap,
                  students,
                  schoolId,
                )),
          ],
        );
      },
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }

  Widget _buildPaymentCard(
    BuildContext context,
    Payment payment,
    Map<String, String> studentMap,
    List<Student> students,
    String? schoolId,
  ) {
    final name = studentMap[payment.studentId] ?? 'Student';
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEditPayment(context, payment),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Method icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getMethodBackgroundColor(payment.method),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getMethodIcon(payment.method),
                    color: _getMethodColor(payment.method),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getMethodBackgroundColor(payment.method),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getMethodLabel(payment.method),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getMethodColor(payment.method),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            payment.paidTo == 'school'
                                ? Icons.business_outlined
                                : Icons.person_outline,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            payment.paidTo == 'school' ? 'School' : 'Instructor',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '£${payment.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${payment.hoursPurchased.toStringAsFixed(1)}h',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: colorScheme.onSurfaceVariant, size: 20),
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditPayment(context, payment);
                    } else if (value == 'delete') {
                      _confirmDeletePayment(context, payment);
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

  Future<void> _showAddPayment(
    BuildContext context,
    List<Student> students,
    String? schoolId,
  ) async {
    Student selectedStudent = students.first;
    final amountController = TextEditingController();
    final hoursController = TextEditingController();
    String method = 'cash';
    String paidTo = 'instructor';
    bool saving = false;
    final customMethods = List<CustomPaymentMethod>.from(
      instructor.instructorSettings?.customPaymentMethods ?? [],
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colorScheme = Theme.of(context).colorScheme;
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
                            color: AppTheme.successLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add_card_rounded, color: AppTheme.success),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Payment',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Record a new payment',
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
                          Text(
                            'Student',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Student>(
                            value: selectedStudent,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: students
                                .map(
                                  (student) => DropdownMenuItem(
                                    value: student,
                                    child: Text(student.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedStudent = value);
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Amount (£)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: amountController,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.currency_pound),
                                        hintText: '0.00',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Hours',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: hoursController,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.schedule_outlined),
                                        hintText: '0',
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Payment Method',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildMethodChip('cash', 'Cash', Icons.payments_outlined, method,
                                  (val) => setDialogState(() => method = val)),
                              _buildMethodChip('bank_transfer', 'Bank', Icons.account_balance_outlined, method,
                                  (val) => setDialogState(() => method = val)),
                              _buildMethodChip('card', 'Card', Icons.credit_card_outlined, method,
                                  (val) => setDialogState(() => method = val)),
                              _buildMethodChip('other', 'Other', Icons.receipt_outlined, method,
                                  (val) => setDialogState(() => method = val)),
                              ...customMethods.map((m) => _buildMethodChip(
                                m.id, m.label, Icons.payments_outlined, method,
                                (val) => setDialogState(() => method = val),
                              )),
                              _buildAddNewPaymentMethodChip(
                                context,
                                colorScheme,
                                customMethods,
                                instructor,
                                setDialogState,
                                (newId) => method = newId,
                                _firestoreService,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Paid To',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaidToOption(
                                  'instructor',
                                  'Instructor',
                                  Icons.person_outline,
                                  paidTo,
                                  (val) => setDialogState(() => paidTo = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaidToOption(
                                  'school',
                                  'School',
                                  Icons.business_outlined,
                                  paidTo,
                                  (val) => setDialogState(() => paidTo = val),
                                ),
                              ),
                            ],
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
                                    final amount = double.tryParse(amountController.text) ?? 0;
                                    final hours = double.tryParse(hoursController.text) ?? 0;
                                    setDialogState(() => saving = true);
                                    final payment = Payment(
                                      id: '',
                                      instructorId: instructor.id,
                                      studentId: selectedStudent.id,
                                      schoolId: schoolId,
                                      amount: amount,
                                      currency: _currency,
                                      method: method,
                                      paidTo: paidTo,
                                      hoursPurchased: hours,
                                      createdAt: DateTime.now(),
                                    );
                                    await _firestoreService.addPayment(
                                      payment: payment,
                                      studentId: selectedStudent.id,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                    }
                                  },
                            child: saving
                                ? LoadingIndicator(size: 20, color: colorScheme.onPrimary)
                                : const Text('Save Payment'),
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

  Widget _buildMethodChip(
    String value,
    String label,
    IconData icon,
    String current,
    Function(String) onSelect,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _getMethodBackgroundColor(value) : AppTheme.neutral50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _getMethodColor(value) : AppTheme.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? _getMethodColor(value) : AppTheme.neutral500,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? _getMethodColor(value) : AppTheme.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewPaymentMethodChip(
    BuildContext context,
    ColorScheme colorScheme,
    List<CustomPaymentMethod> customMethods,
    UserProfile instructor,
    StateSetter setDialogState,
    void Function(String newId) onAdded,
    FirestoreService firestoreService,
  ) {
    return GestureDetector(
      onTap: () async {
        final labelController = TextEditingController();
        final label = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('New payment method'),
            content: TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: 'Method name',
                hintText: 'e.g. PayPal, Venmo',
              ),
              autofocus: true,
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, labelController.text.trim()),
                child: const Text('Add'),
              ),
            ],
          ),
        );
        if (label == null || label.isEmpty) return;
        final id = label.toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (id.isEmpty) return;
        if (customMethods.any((m) => m.id == id)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This payment method already exists')),
            );
          }
          return;
        }
        customMethods.add(CustomPaymentMethod(id: id, label: label));
        final current = instructor.instructorSettings;
        final newSettings = InstructorSettings(
          cancellationRules: current?.cancellationRules,
          reminderHoursBefore: current?.reminderHoursBefore,
          notificationSettings: current?.notificationSettings,
          defaultNavigationApp: current?.defaultNavigationApp,
          lessonColors: current?.lessonColors,
          defaultCalendarView: current?.defaultCalendarView,
          customPaymentMethods: customMethods,
          customLessonTypes: current?.customLessonTypes,
        );
        await firestoreService.updateUserProfile(instructor.id, {'instructorSettings': newSettings.toMap()});
        onAdded(id);
        setDialogState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colorScheme.outline, width: 1.5, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Add new',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaidToOption(
    String value,
    String label,
    IconData icon,
    String current,
    Function(String) onSelect,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
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
            Icon(
              icon,
              color: isSelected ? AppTheme.primary : AppTheme.neutral500,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPayment(BuildContext context, Payment payment) async {
    final amountController = TextEditingController(text: payment.amount.toStringAsFixed(2));
    final hoursController = TextEditingController(text: payment.hoursPurchased.toStringAsFixed(1));
    String method = payment.method;
    String paidTo = payment.paidTo;
    bool saving = false;
    final customMethods = List<CustomPaymentMethod>.from(
      instructor.instructorSettings?.customPaymentMethods ?? [],
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
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
                            color: _getMethodBackgroundColor(payment.method),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _getMethodIcon(payment.method),
                            color: _getMethodColor(payment.method),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Payment',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Update payment details',
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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: amountController,
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
                                  controller: hoursController,
                                  decoration: const InputDecoration(
                                    labelText: 'Hours',
                                    prefixIcon: Icon(Icons.schedule_outlined),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Payment Method',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.neutral700),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildMethodChip('cash', 'Cash', Icons.payments_outlined, method,
                                  (val) => setDialogState(() => method = val)),
                              _buildMethodChip('bank_transfer', 'Bank', Icons.account_balance_outlined, method,
                                  (val) => setDialogState(() => method = val)),
                              _buildMethodChip('card', 'Card', Icons.credit_card_outlined, method,
                                  (val) => setDialogState(() => method = val)),
                              _buildMethodChip('other', 'Other', Icons.receipt_outlined, method,
                                  (val) => setDialogState(() => method = val)),
                              ...customMethods.map((m) => _buildMethodChip(
                                m.id, m.label, Icons.payments_outlined, method,
                                (val) => setDialogState(() => method = val),
                              )),
                              _buildAddNewPaymentMethodChip(
                                context,
                                colorScheme,
                                customMethods,
                                instructor,
                                setDialogState,
                                (newId) => method = newId,
                                _firestoreService,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Paid To',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.neutral700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaidToOption(
                                  'instructor',
                                  'Instructor',
                                  Icons.person_outline,
                                  paidTo,
                                  (val) => setDialogState(() => paidTo = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPaidToOption(
                                  'school',
                                  'School',
                                  Icons.business_outlined,
                                  paidTo,
                                  (val) => setDialogState(() => paidTo = val),
                                ),
                              ),
                            ],
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
                                    final amount = double.tryParse(amountController.text) ?? 0;
                                    final hours = double.tryParse(hoursController.text) ?? 0;
                                    setDialogState(() => saving = true);
                                    final updated = Payment(
                                      id: payment.id,
                                      instructorId: payment.instructorId,
                                      studentId: payment.studentId,
                                      schoolId: payment.schoolId,
                                      amount: amount,
                                      currency: payment.currency,
                                      method: method,
                                      paidTo: paidTo,
                                      hoursPurchased: hours,
                                      createdAt: payment.createdAt,
                                    );
                                    await _firestoreService.updatePayment(
                                      payment: updated,
                                      previousHours: payment.hoursPurchased,
                                    );
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

  Future<void> _confirmDeletePayment(BuildContext context, Payment payment) async {
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
                decoration: BoxDecoration(color: AppTheme.errorLight, shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 22),
              ),
              const SizedBox(width: 16),
              const Expanded(child: Text('Delete payment?')),
            ],
          ),
          content: const Text('This will remove the payment and restore hours to the student balance.'),
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
    if (confirm == true) {
      await _firestoreService.deletePayment(payment);
    }
  }
}
