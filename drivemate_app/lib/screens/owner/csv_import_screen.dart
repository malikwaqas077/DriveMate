import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({
    super.key,
    required this.schoolId,
    required this.instructorId,
  });

  final String schoolId;
  final String instructorId;

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  final _firestoreService = FirestoreService();

  // Phase: 0 = pick file, 1 = preview, 2 = importing/done
  int _phase = 0;
  String? _fileName;
  List<_ParsedRow> _parsedRows = [];
  Set<int> _selectedIndices = {};
  bool _importing = false;
  int? _importedCount;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String csvContent;

    if (file.bytes != null) {
      csvContent = String.fromCharCodes(file.bytes!);
    } else if (file.path != null) {
      csvContent = await File(file.path!).readAsString();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read file')),
        );
      }
      return;
    }

    _fileName = file.name;
    _parseCSV(csvContent);
  }

  void _parseCSV(String content) {
    final rows = const CsvToListConverter().convert(content);
    if (rows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV file is empty')),
        );
      }
      return;
    }

    // Find header row (first row)
    final headers =
        rows.first.map((h) => h.toString().trim().toLowerCase()).toList();

    // Map column indices case-insensitively
    final dateIdx = _findHeader(headers, ['transaction date', 'date']);
    final firstNameIdx = _findHeader(headers, ['first name', 'firstname']);
    final lastNameIdx = _findHeader(headers, ['last name', 'lastname']);
    final typeIdx = _findHeader(headers, ['transaction type', 'type']);
    final amountIdx =
        _findHeader(headers, ['transaction amount', 'amount']);
    final methodIdx = _findHeader(headers, ['payment method', 'method']);
    final statusIdx =
        _findHeader(headers, ['transaction status', 'status']);
    final notesIdx = _findHeader(headers, ['notes', 'description']);

    if (amountIdx == -1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('CSV missing required "Transaction Amount" column')),
        );
      }
      return;
    }

    final parsed = <_ParsedRow>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      String getCol(int idx) =>
          idx >= 0 && idx < row.length ? row[idx].toString().trim() : '';

      final status = getCol(statusIdx).toLowerCase();
      final type = getCol(typeIdx);
      final firstName = getCol(firstNameIdx);
      final lastName = getCol(lastNameIdx);
      final amountStr = getCol(amountIdx).replaceAll(RegExp(r'[£$,]'), '');
      final amount = double.tryParse(amountStr) ?? 0;
      final method = getCol(methodIdx);
      final notes = getCol(notesIdx);
      final dateStr = getCol(dateIdx);

      // Determine if this is an expense row
      // Expense indicators: status contains 'expense', 'debit', 'outgoing'
      // or type contains 'expense', 'cost', 'fuel', 'maintenance'
      final isExpense = _isExpenseRow(status, type);

      DateTime? date;
      // Try common date formats
      date = _tryParseDate(dateStr);

      parsed.add(_ParsedRow(
        rowIndex: i,
        firstName: firstName,
        lastName: lastName,
        type: type,
        amount: amount.abs(),
        method: method,
        status: status,
        notes: notes,
        date: date ?? DateTime.now(),
        isExpense: isExpense,
      ));
    }

    // Pre-select expense rows
    final selected = <int>{};
    for (var i = 0; i < parsed.length; i++) {
      if (parsed[i].isExpense) selected.add(i);
    }

    setState(() {
      _parsedRows = parsed;
      _selectedIndices = selected;
      _phase = 1;
    });
  }

  int _findHeader(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = headers.indexOf(candidate);
      if (idx != -1) return idx;
    }
    return -1;
  }

  bool _isExpenseRow(String status, String type) {
    final statusLower = status.toLowerCase();
    final typeLower = type.toLowerCase();
    final expenseKeywords = [
      'expense',
      'debit',
      'outgoing',
      'cost',
      'fuel',
      'maintenance',
      'repair',
      'insurance',
      'office',
      'marketing',
    ];
    for (final kw in expenseKeywords) {
      if (statusLower.contains(kw) || typeLower.contains(kw)) return true;
    }
    return false;
  }

  DateTime? _tryParseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    // Try dd/MM/yyyy
    try {
      return DateFormat('dd/MM/yyyy').parseStrict(dateStr);
    } catch (_) {}
    // Try yyyy-MM-dd
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(dateStr);
    } catch (_) {}
    // Try MM/dd/yyyy
    try {
      return DateFormat('MM/dd/yyyy').parseStrict(dateStr);
    } catch (_) {}
    // Try d/M/yyyy
    try {
      return DateFormat('d/M/yyyy').parseStrict(dateStr);
    } catch (_) {}
    return DateTime.tryParse(dateStr);
  }

  String _smartCategory(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('fuel') || lower.contains('petrol') || lower.contains('diesel')) {
      return 'fuel';
    }
    if (lower.contains('maintenance') ||
        lower.contains('repair') ||
        lower.contains('service') ||
        lower.contains('mot')) {
      return 'vehicle_maintenance';
    }
    if (lower.contains('insurance')) return 'insurance';
    if (lower.contains('office') || lower.contains('rent')) return 'office';
    if (lower.contains('market') || lower.contains('advert')) return 'marketing';
    if (lower.contains('training') || lower.contains('course')) return 'training';
    if (lower.contains('equipment') || lower.contains('supply')) return 'equipment';
    return 'other';
  }

  String _mapPaymentMethod(String method) {
    final lower = method.toLowerCase();
    if (lower.contains('cash')) return 'cash';
    if (lower.contains('card') || lower.contains('credit') || lower.contains('debit')) {
      return 'card';
    }
    if (lower.contains('bank') || lower.contains('transfer') || lower.contains('bacs')) {
      return 'bank_transfer';
    }
    return 'cash';
  }

  Future<void> _import() async {
    setState(() => _importing = true);

    final expenses = <Expense>[];
    for (final idx in _selectedIndices) {
      final row = _parsedRows[idx];
      final description = row.firstName.isNotEmpty || row.lastName.isNotEmpty
          ? '${row.firstName} ${row.lastName} - ${row.type}'.trim()
          : row.notes.isNotEmpty
              ? row.notes
              : row.type.isNotEmpty
                  ? row.type
                  : 'Imported expense';

      expenses.add(Expense(
        id: '',
        schoolId: widget.schoolId,
        instructorId: widget.instructorId,
        category: _smartCategory(row.type),
        description: description,
        amount: row.amount,
        currency: 'GBP',
        date: row.date,
        paymentMethod: _mapPaymentMethod(row.method),
        csvImportSource: 'TotalDrive CSV',
        notes: row.notes.isNotEmpty ? row.notes : null,
        createdAt: DateTime.now(),
      ));
    }

    try {
      final count = await _firestoreService.batchAddExpenses(expenses);
      setState(() {
        _importedCount = count;
        _phase = 2;
        _importing = false;
      });
    } catch (e) {
      setState(() => _importing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: _phase == 0
          ? _buildPickPhase()
          : _phase == 1
              ? _buildPreviewPhase()
              : _buildDonePhase(),
    );
  }

  Widget _buildPickPhase() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.infoLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                size: 48,
                color: AppTheme.info,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Import from TotalDrive',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a CSV file exported from TotalDrive to import expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Choose CSV File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewPhase() {
    final colorScheme = Theme.of(context).colorScheme;
    final expenseCount = _selectedIndices.length;
    final incomeCount = _parsedRows.length - expenseCount;

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.all(16),
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fileName ?? 'CSV File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$expenseCount expenses selected, $incomeCount income rows (will be skipped)',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Row list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _parsedRows.length,
            itemBuilder: (context, index) {
              final row = _parsedRows[index];
              final isSelected = _selectedIndices.contains(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIndices.add(index);
                      } else {
                        _selectedIndices.remove(index);
                      }
                    });
                  },
                  title: Text(
                    row.firstName.isNotEmpty || row.lastName.isNotEmpty
                        ? '${row.firstName} ${row.lastName}'.trim()
                        : row.type.isNotEmpty
                            ? row.type
                            : 'Row ${row.rowIndex}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${row.type} · ${DateFormat('d MMM yyyy').format(row.date)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  secondary: Text(
                    '£${row.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppTheme.error : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
        ),

        // Import button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _importing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _importing || _selectedIndices.isEmpty
                      ? null
                      : _import,
                  child: _importing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Import ${_selectedIndices.length} Expenses'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDonePhase() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppTheme.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Import Complete',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_importedCount expenses imported successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParsedRow {
  _ParsedRow({
    required this.rowIndex,
    required this.firstName,
    required this.lastName,
    required this.type,
    required this.amount,
    required this.method,
    required this.status,
    required this.notes,
    required this.date,
    required this.isExpense,
  });

  final int rowIndex;
  final String firstName;
  final String lastName;
  final String type;
  final double amount;
  final String method;
  final String status;
  final String notes;
  final DateTime date;
  final bool isExpense;
}
