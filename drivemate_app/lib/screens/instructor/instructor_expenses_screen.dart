import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';
import '../owner/add_expense_screen.dart';

class InstructorExpensesScreen extends StatelessWidget {
  const InstructorExpensesScreen({super.key, required this.instructor});

  final UserProfile instructor;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final schoolId = instructor.schoolId ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('My Expenses')),
      body: StreamBuilder<List<Expense>>(
        stream: firestoreService.streamExpensesForInstructor(instructor.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading expenses...');
          }
          final expenses = snapshot.data ?? [];

          if (expenses.isEmpty) {
            return EmptyView(
              message: 'No expenses yet',
              subtitle: 'Tap + to record your first expense',
              type: EmptyViewType.expenses,
              actionLabel: 'Add Expense',
              onAction: schoolId.isEmpty
                  ? null
                  : () => _addExpense(context, schoolId),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            itemBuilder: (context, index) =>
                _buildExpenseCard(context, expenses[index], schoolId, firestoreService),
          );
        },
      ),
      floatingActionButton: schoolId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addExpense(context, schoolId),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Expense'),
            ),
    );
  }

  void _addExpense(BuildContext context, String schoolId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          schoolId: schoolId,
          instructorId: instructor.id,
        ),
      ),
    );
  }

  Widget _buildExpenseCard(
    BuildContext context,
    Expense expense,
    String schoolId,
    FirestoreService firestoreService,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: const Text('Delete expense?'),
            content: Text('Delete "${expense.description}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await firestoreService.deleteExpense(expense.id);
                  if (context.mounted) Navigator.pop(context, true);
                },
                style:
                    FilledButton.styleFrom(backgroundColor: AppTheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddExpenseScreen(
                    schoolId: schoolId,
                    instructorId: instructor.id,
                    expense: expense,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Expense.categoryIcon(expense.category),
                      color: AppTheme.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${Expense.categoryLabel(expense.category)} · ${DateFormat('d MMM yyyy').format(expense.date)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-£${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
