import 'dart:typed_data' show Uint8List;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'receipt_image_stub.dart' if (dart.library.io) 'receipt_image_io.dart'
    as receipt_image;
import 'receipt_storage_stub.dart' if (dart.library.io) 'receipt_storage_io.dart'
    as receipt_storage;

import '../../models/expense.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({
    super.key,
    required this.schoolId,
    required this.instructorId,
    this.expense,
  });

  final String schoolId;
  final String instructorId;
  final Expense? expense;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestoreService = FirestoreService();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  String _category = 'fuel';
  DateTime _date = DateTime.now();
  String _paymentMethod = 'cash';
  String? _receiptLocalPath;
  Uint8List? _receiptBytes; // Used on web (no dart:io File)
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.expense!;
      _descriptionController.text = e.description;
      _amountController.text = e.amount.toStringAsFixed(2);
      _notesController.text = e.notes ?? '';
      _category = e.category;
      _date = e.date;
      _paymentMethod = e.paymentMethod;
      _receiptLocalPath = e.receiptLocalPath;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) return; // Camera picker limited on web
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (image != null) await _saveReceiptImage(image);
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (image != null) await _saveReceiptImage(image);
  }

  Future<void> _saveReceiptImage(XFile image) async {
    if (kIsWeb) {
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _receiptBytes = bytes);
      return;
    }
    final path = await receipt_storage.saveReceiptToFile(image);
    if (mounted && path != null) setState(() => _receiptLocalPath = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('[AddExpense] Form validation failed');
      return;
    }

    // Validate required IDs
    if (widget.schoolId.isEmpty || widget.instructorId.isEmpty) {
      debugPrint('[AddExpense] Missing schoolId or instructorId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Missing school or instructor information'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    debugPrint('[AddExpense] Starting save...');
    setState(() => _saving = true);

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;
      final notes = _notesController.text.trim();

      debugPrint('[AddExpense] schoolId: ${widget.schoolId}, instructorId: ${widget.instructorId}');
      debugPrint('[AddExpense] amount: $amount, description: ${_descriptionController.text.trim()}');

      if (_isEditing) {
        debugPrint('[AddExpense] Updating expense: ${widget.expense!.id}');
        await _firestoreService.updateExpense(widget.expense!.id, {
          'category': _category,
          'description': _descriptionController.text.trim(),
          'amount': amount,
          'date': Timestamp.fromDate(_date),
          'paymentMethod': _paymentMethod,
          if (_receiptLocalPath != null) 'receiptLocalPath': _receiptLocalPath,
          if (notes.isNotEmpty) 'notes': notes,
        });
        debugPrint('[AddExpense] Expense updated successfully');
      } else {
        final expense = Expense(
          id: '',
          schoolId: widget.schoolId,
          instructorId: widget.instructorId,
          category: _category,
          description: _descriptionController.text.trim(),
          amount: amount,
          currency: 'GBP',
          date: _date,
          paymentMethod: _paymentMethod,
          receiptLocalPath: _receiptLocalPath,
          notes: notes.isNotEmpty ? notes : null,
          createdAt: DateTime.now(),
        );
        debugPrint('[AddExpense] Adding expense to Firestore...');
        final expenseId = await _firestoreService.addExpense(expense);
        debugPrint('[AddExpense] Expense added successfully with ID: $expenseId');
      }

      if (mounted) {
        debugPrint('[AddExpense] Navigating back...');
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      debugPrint('[AddExpense] Error saving expense: $e');
      debugPrint('[AddExpense] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'Add Expense'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category
            Text(
              'Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: Expense.categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(Expense.categoryIcon(cat), size: 20),
                      const SizedBox(width: 10),
                      Text(Expense.categoryLabel(cat)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: 20),

            // Description
            Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'e.g. Fuel top-up at BP',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (val) =>
                  (val == null || val.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            // Amount
            Text(
              'Amount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixIcon: Icon(Icons.currency_pound),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                final amount = double.tryParse(val);
                if (amount == null || amount <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Date
            Text(
              'Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  DateFormat('d MMMM yyyy').format(_date),
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Method
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
                _buildMethodChip('cash', 'Cash', Icons.payments_outlined),
                _buildMethodChip('card', 'Card', Icons.credit_card_outlined),
                _buildMethodChip(
                    'bank_transfer', 'Bank Transfer', Icons.account_balance_outlined),
              ],
            ),
            const SizedBox(height: 20),

            // Notes
            Text(
              'Notes (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Additional notes...',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
              minLines: 1,
            ),
            const SizedBox(height: 24),

            // Receipt Image
            Text(
              'Receipt Image',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if ((kIsWeb ? _receiptBytes : _receiptLocalPath) != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: receipt_image.buildReceiptImage(
                  path: _receiptLocalPath,
                  bytes: _receiptBytes,
                  errorBuilder: () => Container(
                    height: 200,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _receiptLocalPath = null;
                  _receiptBytes = null;
                }),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (!kIsWeb)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Take Photo'),
                    ),
                  ),
                if (!kIsWeb) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(kIsWeb ? 'Choose File' : 'Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cloud Upload (Coming Soon)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cloud Upload',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 14, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        Text(
                          'Coming Soon',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            FilledButton(
              onPressed: _saving
                  ? null
                  : () {
                      debugPrint('[AddExpense] Button pressed');
                      _save();
                    },
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Add Expense'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.neutral50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.neutral200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primary : AppTheme.neutral500,
            ),
            const SizedBox(width: 8),
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
}
