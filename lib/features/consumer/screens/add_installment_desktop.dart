import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/core/theme/app_theme.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import 'package:qistiraha/widgets/desktop/app_modal.dart';
import 'package:qistiraha/widgets/desktop/segmented_toggle.dart';
import '../controllers/add_installment_controller.dart';
import '../models/installment.dart';

/// Launches the desktop "Add Installment" flow as a constrained [AppModal]
/// (maxWidth 500) over the dashboard — no more full-screen wizard. Same
/// [AddInstallmentController] math and [DatabaseService.addSelfInstallment]
/// persistence as before; the mobile [AddInstallmentScreen] is untouched.
Future<void> showAddInstallmentModal(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => const _AddInstallmentModal(),
  );
}

class _AddInstallmentModal extends StatefulWidget {
  const _AddInstallmentModal();

  @override
  State<_AddInstallmentModal> createState() => _AddInstallmentModalState();
}

class _AddInstallmentModalState extends State<_AddInstallmentModal> {
  final _controller = const AddInstallmentController();
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _itemDescController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _installmentsController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _dueDateController = TextEditingController();
  final _paidPeriodsController = TextEditingController();
  final _missedPeriodsController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedCategory;
  String _selectedFrequency = 'Monthly';
  String? _selectedProvider;
  double _calculatedMonthly = 0.0;

  // Type of plan lives in state now (a top-of-modal toggle) instead of two
  // separate tab pages — so switching type preserves entered data.
  bool _isLongTerm = false;
  bool _isLegacy = false;
  bool _isLate = false;

  int _currentStep = 0; // 0 Item · 1 Finance · 2 Finalize
  int? _selectedPresetMonths;
  bool _showCustomMonths = false;
  bool _saving = false;

  static const List<int> _monthPresets = [3, 6, 12, 24];

  static const List<String> _everydayCategories = [
    'Electronics',
    'Home Appliances',
    'Furniture',
    'Fashion',
    'Education',
    'Medical & Clinics',
    'Automotive',
    'Travel',
    'Other',
  ];

  static const List<String> _longTermCategories = [
    'Real Estate',
    'Automotive',
    'Medical',
    'Business',
    'Other',
  ];

  static const List<String> _frequencies = [
    'Monthly',
    'Quarterly',
    'Semi-Annually',
    'Annually',
  ];

  static const List<String> _stepLabels = ['Item', 'Finance', 'Finalize'];

  @override
  void initState() {
    super.initState();
    _totalAmountController.addListener(_calculateMonthly);
    _installmentsController.addListener(_calculateMonthly);
    _downPaymentController.addListener(_calculateMonthly);
    _interestRateController.addListener(_calculateMonthly);

    _selectedDate = TimeService.now().add(const Duration(days: 30));
    _dueDateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _itemDescController.dispose();
    _totalAmountController.dispose();
    _installmentsController.dispose();
    _downPaymentController.dispose();
    _interestRateController.dispose();
    _dueDateController.dispose();
    _paidPeriodsController.dispose();
    _missedPeriodsController.dispose();
    super.dispose();
  }

  void _calculateMonthly() {
    setState(() {
      _calculatedMonthly = _controller.calculateMonthly(
        totalAmount: double.tryParse(_totalAmountController.text) ?? 0.0,
        downPayment: double.tryParse(_downPaymentController.text) ?? 0.0,
        totalMonths: int.tryParse(_installmentsController.text) ?? 0,
        interestRatePercent: double.tryParse(_interestRateController.text) ?? 0.0,
      );
    });
  }

  String get _stepSubtitle => switch (_currentStep) {
    0 => 'Where is this installment from?',
    1 => 'Set the total cost and repayment schedule.',
    _ => 'Final details before we save this plan.',
  };

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? TimeService.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dueDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedProvider == null ||
          _itemDescController.text.isEmpty ||
          _storeNameController.text.isEmpty) {
        _toast('Please fill all required fields in Step 1.', error: true);
        return;
      }
    } else if (_currentStep == 1) {
      if (_totalAmountController.text.isEmpty ||
          _installmentsController.text.isEmpty) {
        _toast('Please fill all required fields in Step 2.', error: true);
        return;
      }
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      if (_selectedDate == null) {
        _toast('Please select a first payment due date', error: true);
      }
      return;
    }
    setState(() => _saving = true);
    try {
      final mMultiplier = _isLongTerm
          ? Installment.monthsPerPaymentFor(_selectedFrequency)
          : 1;
      final paidPeriods = int.tryParse(_paidPeriodsController.text) ?? 0;
      final calculatedPaidMonths = _isLegacy ? (paidPeriods * mMultiplier) : 0;

      await DatabaseService.addSelfInstallment(
        merchantName: _storeNameController.text.isNotEmpty
            ? _storeNameController.text
            : (_selectedProvider ?? 'Unknown Store'),
        itemDescription: _itemDescController.text,
        totalAmount: double.parse(_totalAmountController.text),
        totalMonths: int.parse(_installmentsController.text) * mMultiplier,
        monthlyPayment: _calculatedMonthly,
        dueDate: _selectedDate!,
        downPayment: double.tryParse(_downPaymentController.text) ?? 0.0,
        interestRate: double.tryParse(_interestRateController.text) ?? 0.0,
        category: _selectedCategory ?? 'Other',
        isLongTerm: _isLongTerm,
        paymentFrequency: _isLongTerm ? _selectedFrequency : 'Monthly',
        provider: _selectedProvider ?? 'Other / Custom',
        paidMonths: calculatedPaidMonths,
      );
      if (mounted) {
        _toast('Installment added successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast('Error saving installment: $e', error: true);
      }
    }
  }

  void _toast(String message, {bool error = false}) {
    showDesktopSnackBar(
      context,
      message: message,
      backgroundColor: error ? AppColors.danger : AppColors.success,
    );
  }

  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AppModal(
      title: 'Add Installment',
      subtitle: _stepSubtitle,
      maxWidth: 500,
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : (_currentStep > 0 ? _prevStep : () => Navigator.pop(context)),
          child: Text(_currentStep > 0 ? 'Back' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _nextStep,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_currentStep == 2 ? 'Add Installment' : 'Next Step'),
        ),
      ],
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedToggle<bool>(
              value: _isLongTerm,
              onChanged: (v) => setState(() => _isLongTerm = v),
              options: const [
                ToggleOption(false, 'Everyday'),
                ToggleOption(true, 'Long-Term Asset'),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _Stepper(current: _currentStep, labels: _stepLabels),
            const SizedBox(height: AppSpacing.xl),
            IndexedStack(
              index: _currentStep,
              children: [_buildStep1(), _buildStep2(), _buildStep3()],
            ),
          ],
        ),
      ),
    );
  }

  // ── steps ──────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Store / Merchant Name'),
        _textField(
          _storeNameController,
          'e.g., B.TECH',
          suffixIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: AppSpacing.lg),
        _label('Provider / Institution'),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _showProviderSearchDialog,
            child: AbsorbPointer(
              child: TextFormField(
                controller: TextEditingController(text: _selectedProvider),
                decoration: _dec(
                  hint: 'Select provider',
                  suffixIcon: Icons.expand_more,
                ),
                validator: (_) =>
                    _selectedProvider == null ? 'Required field' : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _label('Item Description'),
        _textField(_itemDescController, 'e.g., 55" 4K Smart TV'),
      ],
    );
  }

  Widget _buildStep2() {
    final freq = _isLongTerm ? _selectedFrequency : 'Monthly';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isLongTerm) ...[
          _label('Payment Frequency'),
          DropdownButtonFormField<String>(
            value: _selectedFrequency,
            decoration: _dec(),
            items: _frequencies
                .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedFrequency = v);
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _label('Total Amount'),
        _textField(
          _totalAmountController,
          '0.00',
          suffixText: 'EGP',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.lg),
        _label('Installments (${Installment.periodNounPluralFor(freq)})'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final m in _monthPresets)
              _presetChip(
                '$m ${Installment.periodNounPluralFor(freq)}',
                selected: _selectedPresetMonths == m && !_showCustomMonths,
                onTap: () => setState(() {
                  _selectedPresetMonths = m;
                  _showCustomMonths = false;
                  _installmentsController.text = m.toString();
                }),
              ),
            _presetChip(
              'Custom',
              selected: _showCustomMonths,
              onTap: () => setState(() {
                _selectedPresetMonths = null;
                _showCustomMonths = true;
                _installmentsController.text = '';
              }),
            ),
          ],
        ),
        if (_showCustomMonths) ...[
          const SizedBox(height: AppSpacing.md),
          _textField(
            _installmentsController,
            'e.g., 18',
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _MonthlyPreview(
          label: Installment.paymentFrequencyLabelFor(freq),
          value: 'EGP ${_calculatedMonthly.toStringAsFixed(2)}',
        ),
        const SizedBox(height: AppSpacing.sm),
        AdvancedOptions(
          children: [
            _label('Down Payment'),
            _textField(
              _downPaymentController,
              '0.00',
              suffixText: 'EGP',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            _label('Interest Rate'),
            _textField(
              _interestRateController,
              '0',
              suffixText: '%',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final categories = _isLongTerm ? _longTermCategories : _everydayCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Category'),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          hint: const Text('Select a category'),
          decoration: _dec(),
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
          validator: (v) => v == null ? 'Required field' : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        _label(_isLate ? 'Oldest Missed Due Date' : 'Next Due Date'),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _selectDate,
            child: AbsorbPointer(
              child: _textField(
                _dueDateController,
                'dd/mm/yyyy',
                suffixIcon: Icons.calendar_today_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AdvancedOptions(
          label: 'Already paying this off?',
          children: [
            _toggleRow(
              'I have already started paying this off',
              _isLegacy,
              AppColors.accent,
              (v) => setState(() => _isLegacy = v),
            ),
            if (_isLegacy) ...[
              const SizedBox(height: AppSpacing.sm),
              _label('How many payments have you already made?'),
              _textField(
                _paidPeriodsController,
                'e.g., 10',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              _toggleRow(
                'I am currently behind on payments',
                _isLate,
                AppColors.danger,
                (v) => setState(() => _isLate = v),
              ),
              if (_isLate) ...[
                const SizedBox(height: AppSpacing.sm),
                _label('How many payments are you late on?'),
                _textField(
                  _missedPeriodsController,
                  'e.g., 2',
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }

  // ── provider search (nested dialog) ──────────────────────────────────────
  void _showProviderSearchDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = kEgyptianProviders
                .where((p) => p.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return AppModal(
              title: 'Select Provider',
              maxWidth: 420,
              scrollable: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: _dec(
                      hint: 'Search providers…',
                      prefixIcon: Icons.search,
                    ),
                    onChanged: (v) => setModalState(() => query = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ListTile(
                          title: Text(filtered[i]),
                          onTap: () {
                            setState(() => _selectedProvider = filtered[i]);
                            Navigator.pop(dialogContext);
                          },
                        ),
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
  }

  // ── small helpers ─────────────────────────────────────────────────────────
  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
        color: AppColors.textSecondary,
      ),
    ),
  );

  InputDecoration _dec({
    String? hint,
    IconData? suffixIcon,
    IconData? prefixIcon,
    String? suffixText,
  }) => InputDecoration(
    hintText: hint,
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, size: 20, color: AppColors.textTertiary)
        : null,
    suffixIcon: suffixIcon != null
        ? Icon(suffixIcon, size: 20, color: AppColors.textTertiary)
        : null,
    suffixText: suffixText,
  );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    IconData? suffixIcon,
    String? suffixText,
    TextInputType? keyboardType,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    decoration: _dec(hint: hint, suffixIcon: suffixIcon, suffixText: suffixText),
    validator: (value) {
      if (value == null || value.isEmpty) {
        if (controller != _downPaymentController &&
            controller != _interestRateController) {
          return 'Required field';
        }
      }
      return null;
    },
  );

  Widget _presetChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: AppRadii.smAll,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    ),
  );

  Widget _toggleRow(
    String title,
    bool value,
    Color activeColor,
    ValueChanged<bool> onChanged,
  ) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      Switch(value: value, activeColor: activeColor, onChanged: onChanged),
    ],
  );
}

/// Compact horizontal stepper for the modal — numbered nodes joined by
/// connector lines, in the design-system palette.
class _Stepper extends StatelessWidget {
  final int current;
  final List<String> labels;
  const _Stepper({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          _node(i),
          if (i != labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i < current ? AppColors.ink : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }

  Widget _node(int i) {
    final done = i < current;
    final active = i == current;
    final ring = done || active ? AppColors.ink : AppColors.border;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: done ? AppColors.ink : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: active ? 2 : 1),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 13, color: Colors.white)
              : Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: active ? AppColors.ink : AppColors.textTertiary,
                  ),
                ),
        ),
        const SizedBox(height: 5),
        Text(
          labels[i],
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: done || active
                ? AppColors.textPrimary
                : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// The soft-tinted "per-period payment" summary shown on the Finance step.
class _MonthlyPreview extends StatelessWidget {
  final String label;
  final String value;
  const _MonthlyPreview({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentWash,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.accentSoft.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
