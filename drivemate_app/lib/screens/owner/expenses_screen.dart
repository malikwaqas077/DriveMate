import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/loading_view.dart';
import 'add_expense_screen.dart';
import 'csv_import_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.owner});

  final UserProfile owner;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final schoolId = widget.owner.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      return const Center(child: Text('School not set up.'));
    }

    return StreamBuilder<List<Expense>>(
      stream: _firestoreService.streamExpensesForSchool(schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(message: 'Loading expenses...');
        }
        final allExpenses = snapshot.data ?? [];

        // Filter by month
        final monthExpenses = allExpenses.where((e) {
          return e.date.month == _selectedMonth &&
              e.date.year == _selectedYear;
        }).toList();

        // Filter by category
        final filteredExpenses = _selectedCategory == null
            ? monthExpenses
            : monthExpenses
                .where((e) => e.category == _selectedCategory)
                .toList();

        final monthTotal =
            monthExpenses.fold<double>(0, (sum, e) => sum + e.amount);

        return Scaffold(
          body: Column(
            children: [
              // Month selector
              _buildMonthSelector(context),

              // Summary card
              _buildSummaryCard(context, monthTotal, monthExpenses.length),

              // Category filter chips
              _buildCategoryFilter(context, monthExpenses),

              // Expense list
              Expanded(
                child: filteredExpenses.isEmpty
                    ? EmptyView(
                        message: 'No expenses this month',
                        subtitle: 'Tap + to add an expense or import from CSV',
                        type: EmptyViewType.expenses,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: filteredExpenses.length,
                        itemBuilder: (context, index) {
                          return _buildExpenseCard(
                              context, filteredExpenses[index]);
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showFabOptions(context),
            child: const Icon(Icons.add_rounded),
          ),
        );
      },
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
            },
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy')
                  .format(DateTime(_selectedYear, _selectedMonth)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              final now = DateTime.now();
              if (_selectedYear < now.year ||
                  (_selectedYear == now.year &&
                      _selectedMonth < now.month)) {
                setState(() {
                  if (_selectedMonth == 12) {
                    _selectedMonth = 1;
                    _selectedYear++;
                  } else {
                    _selectedMonth++;
                  }
                });
              }
            },
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, double total, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.error,
            AppTheme.error.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.error.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Expenses',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '£${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'items',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(
      BuildContext context, List<Expense> monthExpenses) {
    // Get categories that have expenses this month
    final activeCategories = <String>{};
    for (final e in monthExpenses) {
      activeCategories.add(e.category);
    }

    if (activeCategories.isEmpty) return const SizedBox(height: 12);

    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(context, null, 'All', null),
          ...activeCategories.map((cat) => _buildFilterChip(
                context,
                cat,
                Expense.categoryLabel(cat),
                Expense.categoryIcon(cat),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String? category,
    String label,
    IconData? icon,
  ) {
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        onSelected: (_) {
          setState(() => _selectedCategory = isSelected ? null : category);
        },
      ),
    );
  }

  Widget _buildExpenseCard(BuildContext context, Expense expense) {
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
      confirmDismiss: (_) => _confirmDelete(context, expense),
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
            onTap: () => _editExpense(context, expense),
            onLongPress: () => _showExpenseMenu(context, expense),
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
                        Row(
                          children: [
                            Text(
                              DateFormat('d MMM').format(expense.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _methodLabel(expense.paymentMethod),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (expense.csvImportSource != null) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.file_download_outlined,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ],
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

  String _methodLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      case 'bank_transfer':
        return 'Bank';
      default:
        return method;
    }
  }

  Future<bool?> _confirmDelete(BuildContext context, Expense expense) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.error, size: 22),
            ),
            const SizedBox(width: 16),
            const Expanded(child: Text('Delete expense?')),
          ],
        ),
        content: Text('Delete "${expense.description}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _firestoreService.deleteExpense(expense.id);
              if (context.mounted) Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _editExpense(BuildContext context, Expense expense) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          schoolId: widget.owner.schoolId!,
          instructorId: expense.instructorId,
          expense: expense,
        ),
      ),
    );
  }

  void _showExpenseMenu(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editExpense(context, expense);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.error),
              title: const Text('Delete',
                  style: TextStyle(color: AppTheme.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await _confirmDelete(context, expense);
                if (confirm == true) {
                  // already deleted in confirmDelete
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFabOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_rounded, color: AppTheme.primary),
              ),
              title: const Text('Add Expense',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Manually add a new expense'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddExpenseScreen(
                      schoolId: widget.owner.schoolId!,
                      instructorId: widget.owner.id,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upload_file_rounded,
                    color: AppTheme.info),
              ),
              title: const Text('Import CSV',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Import expenses from TotalDrive'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CsvImportScreen(
                      schoolId: widget.owner.schoolId!,
                      instructorId: widget.owner.id,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
