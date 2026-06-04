import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/responsive.dart';
import '../../models/refund_item.dart';
import '../../services/refund_storage_service.dart';

class AddRefundScreen extends StatefulWidget {
  const AddRefundScreen({super.key});

  @override
  State<AddRefundScreen> createState() => _AddRefundScreenState();
}

class _AddRefundScreenState extends State<AddRefundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderIdController = TextEditingController();
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customCategoryController = TextEditingController();
  RefundCategory? _presetCategory = RefundCategory.retail;
  bool _isOtherCategory = false;
  DateTime? _refundIssuedAt;
  String _currency = '₹';
  final RefundStorageService _storage = RefundStorageService();

  static const _currencies = ['₹', '\$', '€', '£', '¥'];

  @override
  void dispose() {
    _orderIdController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _refundIssuedAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _refundIssuedAt = picked);
  }

  /// Sanitize free-text input: strip control characters, collapse whitespace.
  static String _sanitize(String input) =>
      input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isOtherCategory && _customCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a category name or select a preset category'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final orderId = _sanitize(_orderIdController.text.trim());
    final merchant = _merchantController.text.trim().isNotEmpty
        ? _sanitize(_merchantController.text.trim())
        : 'Unknown Merchant';
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;

    // Use a safe ID that cannot contain path-traversal characters
    final safeOrderId = orderId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final id = 'manual_${safeOrderId}_${DateTime.now().millisecondsSinceEpoch}';
    final item = RefundItem(
      id: id,
      merchantName: merchant,
      amount: amount,
      status: RefundStatus.processing,
      source: RefundSource.email,
      currency: _currency,
      orderId: orderId,
      category: _isOtherCategory ? null : _presetCategory,
      categoryLabel: _isOtherCategory
          ? _sanitize(_customCategoryController.text.trim())
          : null,
      detectedAt: DateTime.now(),
      refundIssuedAt: _refundIssuedAt,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _sanitize(_descriptionController.text.trim()),
    );

    await _storage.mergeAndSave([item]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tracking order #$orderId'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Add Refund'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: context.hPad),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Track a refund by order ID',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the order or reference ID to start tracking.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 32),
                _buildCard(
                  context,
                  isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order / Reference ID',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _orderIdController,
                        maxLength: 64,
                        decoration: InputDecoration(
                          hintText: 'e.g. 8291 or RFND-920',
                          counterText: '',
                          prefixIcon: const Icon(Icons.tag, color: AppColors.primary, size: 22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.surfaceLight,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter order or reference ID';
                          }
                          if (v.trim().length > 64) return 'Too long (max 64 chars)';
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Merchant name',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _merchantController,
                        maxLength: 100,
                        decoration: InputDecoration(
                          hintText: 'e.g. Amazon.com',
                          counterText: '',
                          prefixIcon: const Icon(Icons.store_outlined, color: AppColors.primary, size: 22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.surfaceLight,
                        ),
                        validator: (v) {
                          if (v != null && v.trim().length > 100) return 'Too long (max 100 chars)';
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Refund amount',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      // Currency selector chips
                      Wrap(
                        spacing: 8,
                        children: _currencies.map((c) {
                          final selected = c == _currency;
                          return ChoiceChip(
                            label: Text(c,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : null,
                                )),
                            selected: selected,
                            onSelected: (_) => setState(() => _currency = c),
                            selectedColor: AppColors.primary,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : AppColors.surfaceLight,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              _currency,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.surfaceLight,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter amount';
                          }
                          final parsed = double.tryParse(v.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount greater than 0';
                          }
                          if (parsed > 9999999) {
                            return 'Amount is unreasonably large';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Date refund issued',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            hintText: 'Tap to pick date',
                            prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 22),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : AppColors.surfaceLight,
                          ),
                          child: Text(
                            _refundIssuedAt != null
                                ? '${_refundIssuedAt!.day}/${_refundIssuedAt!.month}/${_refundIssuedAt!.year}'
                                : 'Optional',
                            style: TextStyle(
                              color: _refundIssuedAt != null
                                  ? Theme.of(context).colorScheme.onSurface
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Description',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: 'Notes or details (optional)',
                          counterText: '',
                          alignLabelWithHint: true,
                          prefixIcon: const Icon(Icons.notes_outlined, color: AppColors.primary, size: 22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.surfaceLight,
                        ),
                        textInputAction: TextInputAction.newline,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Category',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...RefundCategory.values.map((c) {
                            final selected = !_isOtherCategory && _presetCategory == c;
                            return FilterChip(
                              label: Text(c.label),
                              selected: selected,
                              onSelected: (_) => setState(() {
                                _isOtherCategory = false;
                                _presetCategory = c;
                                _customCategoryController.clear();
                              }),
                              selectedColor: AppColors.primary,
                              checkmarkColor: AppColors.textPrimary,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.surfaceLight,
                            );
                          }),
                          FilterChip(
                            label: const Text('Other'),
                            selected: _isOtherCategory,
                            onSelected: (_) => setState(() {
                              _isOtherCategory = true;
                              _presetCategory = null;
                            }),
                            selectedColor: AppColors.primary,
                            checkmarkColor: AppColors.textPrimary,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : AppColors.surfaceLight,
                          ),
                        ],
                      ),
                      if (_isOtherCategory) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customCategoryController,
                          maxLength: 50,
                          decoration: InputDecoration(
                            hintText: 'Enter category (e.g. Books, Subscriptions)',
                            counterText: '',
                            prefixIcon: const Icon(Icons.label_outline, color: AppColors.primary, size: 22),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : AppColors.surfaceLight,
                          ),
                          validator: (v) {
                            if (_isOtherCategory && (v == null || v.trim().isEmpty)) {
                              return 'Enter a category name';
                            }
                            if (v != null && v.trim().length > 50) return 'Too long (max 50 chars)';
                            return null;
                          },
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    label: const Text('Start tracking'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
