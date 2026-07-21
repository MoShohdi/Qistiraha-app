import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import '../controllers/add_installment_controller.dart';
import '../models/installment.dart';

const _kBrand = Color(0xFF99AFD7);
const _kBg = Color(0xFFF8F9FA);

/// Desktop/web rendition of the Add Installment flow — same controllers,
/// state variables and [AddInstallmentController] persistence logic as
/// [AddInstallmentScreen] (the mobile screen, untouched), laid out for a
/// wide viewport instead: a constrained, centered form card with a
/// horizontal breadcrumb stepper up top and a standard desktop action row
/// (Cancel/Back left, Next Step right) directly beneath the fields, instead
/// of the mobile full-width fields, linear progress bar and floating
/// bottom button.
class AddInstallmentDesktopScreen extends StatelessWidget {
  const AddInstallmentDesktopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        body: Column(
          children: [
            const _DesktopHeader(),
            Expanded(
              child: TabBarView(
                children: [
                  _InstallmentDesktopForm(isLongTerm: false),
                  _InstallmentDesktopForm(isLongTerm: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text(
                'Back',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
            ),
          ),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.grey[300],
          ),
          const Text(
            'Add Installment',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _buildTypeToggle(),
        ],
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      width: 340,
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.black87,
        unselectedLabelColor: Colors.grey[600],
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'Everyday'),
          Tab(text: 'Long-Term Assets'),
        ],
      ),
    );
  }
}

enum _StepState { done, active, upcoming }

class _StepNode extends StatelessWidget {
  final int index;
  final String label;
  final _StepState state;
  const _StepNode({
    required this.index,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final bool done = state == _StepState.done;
    final bool active = state == _StepState.active;
    final Color ringColor = done || active ? _kBrand : Colors.grey[300]!;
    final Color textColor = done || active ? Colors.black87 : Colors.grey[500]!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done ? _kBrand : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: ringColor, width: active ? 2 : 1),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: active ? _kBrand : Colors.grey[500],
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _InstallmentDesktopForm extends StatefulWidget {
  final bool isLongTerm;
  const _InstallmentDesktopForm({required this.isLongTerm});

  @override
  State<_InstallmentDesktopForm> createState() =>
      _InstallmentDesktopFormState();
}

class _InstallmentDesktopFormState extends State<_InstallmentDesktopForm> {
  final _controller = const AddInstallmentController();
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _itemDescController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _installmentsController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _interestRateController = TextEditingController();
  final _dueDateController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedCategory;
  String _selectedFrequency = 'Monthly';
  String? _selectedProvider;
  double _calculatedMonthly = 0.0;

  bool _isLegacy = false;
  bool _isLate = false;
  final _paidPeriodsController = TextEditingController();
  final _missedPeriodsController = TextEditingController();

  int _currentStep = 0;
  int? _selectedPresetMonths;
  bool _showCustomMonths = false;

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

  @override
  void initState() {
    super.initState();
    _totalAmountController.addListener(_calculateMonthly);
    _installmentsController.addListener(_calculateMonthly);
    _downPaymentController.addListener(_calculateMonthly);
    _interestRateController.addListener(_calculateMonthly);

    // Smart default: 30 days from now
    _selectedDate = TimeService.now().add(const Duration(days: 30));
    _dueDateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
  }

  void _calculateMonthly() {
    double total = double.tryParse(_totalAmountController.text) ?? 0.0;
    double down = double.tryParse(_downPaymentController.text) ?? 0.0;
    int months = int.tryParse(_installmentsController.text) ?? 0;
    double interest = double.tryParse(_interestRateController.text) ?? 0.0;

    setState(() {
      _calculatedMonthly = _controller.calculateMonthly(
        totalAmount: total,
        downPayment: down,
        totalMonths: months,
        interestRatePercent: interest,
      );
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
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

  void _saveInstallment() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      try {
        int mMultiplier = 1;
        if (widget.isLongTerm) {
          switch (_selectedFrequency) {
            case 'Quarterly':
              mMultiplier = 3;
              break;
            case 'Semi-Annually':
              mMultiplier = 6;
              break;
            case 'Annually':
              mMultiplier = 12;
              break;
          }
        }

        int paidPeriods = int.tryParse(_paidPeriodsController.text) ?? 0;
        int calculatedPaidMonths = _isLegacy ? (paidPeriods * mMultiplier) : 0;

        await _controller.saveInstallment(
          storeName: _storeNameController.text.isNotEmpty
              ? _storeNameController.text
              : (_selectedProvider ?? 'Unknown Store'),
          itemDescription: _itemDescController.text,
          totalAmount: double.parse(_totalAmountController.text),
          totalMonths: int.parse(_installmentsController.text),
          monthlyPayment: _calculatedMonthly,
          dueDate: _selectedDate!,
          downPayment: double.tryParse(_downPaymentController.text) ?? 0.0,
          interestRate: double.tryParse(_interestRateController.text) ?? 0.0,
          category: _selectedCategory ?? 'Other',
          isLongTerm: widget.isLongTerm,
          paymentFrequency: widget.isLongTerm ? _selectedFrequency : 'Monthly',
          provider: _selectedProvider ?? 'Other / Custom',
          paidMonths: calculatedPaidMonths,
        );

        if (mounted) {
          showDesktopSnackBar(
            context,
            message: 'Installment added successfully!',
            backgroundColor: Colors.green,
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          showDesktopSnackBar(
            context,
            message: 'Error saving installment: $e',
            backgroundColor: Colors.red,
          );
        }
      }
    } else if (_selectedDate == null) {
      showDesktopSnackBar(
        context,
        message: 'Please select a first payment due date',
        backgroundColor: Colors.red,
      );
    }
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

  void _nextStep() {
    if (_currentStep == 0) {
      if (_selectedProvider == null ||
          _itemDescController.text.isEmpty ||
          _storeNameController.text.isEmpty) {
        showDesktopSnackBar(
          context,
          message: 'Please fill all required fields in Step 1.',
          backgroundColor: Colors.red,
        );
        return;
      }
    } else if (_currentStep == 1) {
      if (_totalAmountController.text.isEmpty ||
          _installmentsController.text.isEmpty) {
        showDesktopSnackBar(
          context,
          message: 'Please fill all required fields in Step 2.',
          backgroundColor: Colors.red,
        );
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _saveInstallment();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _showProviderSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = kEgyptianProviders
                .where(
                  (p) => p.toLowerCase().contains(searchQuery.toLowerCase()),
                )
                .toList();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 480,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select Provider',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search providers...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) =>
                            setModalState(() => searchQuery = val),
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final provider = filtered[index];
                            return MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: ListTile(
                                title: Text(provider),
                                onTap: () {
                                  setState(() => _selectedProvider = provider);
                                  Navigator.pop(dialogContext);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepper(),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: IndexedStack(
                          index: _currentStep,
                          children: [
                            _buildStep1(),
                            _buildStep2(),
                            _buildStep3(),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: Colors.grey[200]),
                      _buildActionRow(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    const steps = ['New Plan', 'Item', 'Finance', 'Finalize'];
    final activeIndex = _currentStep + 1;

    return Row(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepNode(
            index: i + 1,
            label: steps[i],
            state: i < activeIndex
                ? _StepState.done
                : i == activeIndex
                ? _StepState.active
                : _StepState.upcoming,
          ),
          if (i != steps.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i < activeIndex ? _kBrand : Colors.grey[300],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TextButton(
              onPressed: _currentStep > 0
                  ? _prevStep
                  : () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: Text(_currentStep > 0 ? 'Back' : 'Cancel'),
            ),
          ),
          const Spacer(),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _currentStep == 2 ? 'Add Installment' : 'Next Step',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Item & Provider',
          'Tell us where this installment is from.',
        ),
        const SizedBox(height: 24),
        _buildLabel('Store / Merchant Name'),
        _buildTextField(
          _storeNameController,
          'e.g., B.TECH',
          suffixIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 20),
        _buildLabel('Provider / Institution'),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showProviderSearchDialog(context),
            child: AbsorbPointer(
              child: TextFormField(
                controller: TextEditingController(text: _selectedProvider),
                decoration: _fieldDecoration(
                  hint: 'Select provider',
                  suffixIcon: Icons.expand_more,
                ),
                validator: (val) =>
                    _selectedProvider == null ? 'Required field' : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildLabel('Item Description'),
        _buildTextField(_itemDescController, 'e.g., 55" 4K Smart TV'),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle('Financials', 'Set the total cost and repayment schedule.'),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Total Amount'),
                  _buildTextField(
                    _totalAmountController,
                    '0.00',
                    suffixText: 'EGP',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Down Payment'),
                  _buildTextField(
                    _downPaymentController,
                    '0.00',
                    suffixText: 'EGP',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildLabel(
          widget.isLongTerm && _selectedFrequency != 'Monthly'
              ? 'Installments (Payments)'
              : 'Installments (Months)',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._monthPresets.map(
              (months) => _presetChip(
                '$months Months',
                selected: _selectedPresetMonths == months && !_showCustomMonths,
                onTap: () {
                  setState(() {
                    _selectedPresetMonths = months;
                    _showCustomMonths = false;
                    _installmentsController.text = months.toString();
                  });
                },
              ),
            ),
            _presetChip(
              'Custom',
              selected: _showCustomMonths,
              onTap: () {
                setState(() {
                  _selectedPresetMonths = null;
                  _showCustomMonths = true;
                  _installmentsController.text = '';
                });
              },
            ),
          ],
        ),
        if (_showCustomMonths) ...[
          const SizedBox(height: 16),
          _buildTextField(
            _installmentsController,
            'e.g., 18',
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 20),
        _buildLabel('Interest Rate (Optional)'),
        _buildTextField(
          _interestRateController,
          '0',
          suffixText: '%',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _kBrand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBrand.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Payment',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                'EGP ${_calculatedMonthly.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    List<String> currentCategories = widget.isLongTerm
        ? _longTermCategories
        : _everydayCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepTitle(
          'Details & Dates',
          'Final details before we save this plan.',
        ),
        const SizedBox(height: 24),
        if (widget.isLongTerm) ...[
          _buildLabel('Payment Frequency'),
          DropdownButtonFormField<String>(
            value: _selectedFrequency,
            decoration: _fieldDecoration(),
            items: _frequencies
                .map((freq) => DropdownMenuItem(value: freq, child: Text(freq)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedFrequency = val);
            },
          ),
          const SizedBox(height: 20),
        ],
        _buildLabel('Category'),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          hint: Text(
            'Select a category',
            style: TextStyle(color: Colors.grey[400]),
          ),
          decoration: _fieldDecoration(),
          items: currentCategories
              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
              .toList(),
          onChanged: (val) => setState(() => _selectedCategory = val),
          validator: (val) => val == null ? 'Required field' : null,
        ),
        const SizedBox(height: 20),
        _buildLabel(_isLate ? 'Oldest Missed Due Date' : 'Next Due Date'),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _selectDate(context),
            child: AbsorbPointer(
              child: _buildTextField(
                _dueDateController,
                'dd/mm/yyyy',
                suffixIcon: Icons.calendar_today_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _togglableRow(
          title: 'I have already started paying this off',
          value: _isLegacy,
          activeColor: _kBrand,
          onChanged: (val) => setState(() => _isLegacy = val),
        ),
        if (_isLegacy) ...[
          const SizedBox(height: 12),
          _buildLabel('How many payments have you already made?'),
          _buildTextField(
            _paidPeriodsController,
            'e.g., 10',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          _togglableRow(
            title: 'I am currently behind on payments',
            value: _isLate,
            activeColor: Colors.red,
            onChanged: (val) => setState(() => _isLate = val),
          ),
          if (_isLate) ...[
            const SizedBox(height: 12),
            _buildLabel('How many payments are you late on?'),
            _buildTextField(
              _missedPeriodsController,
              'e.g., 2',
              keyboardType: TextInputType.number,
            ),
          ],
        ],
      ],
    );
  }

  Widget _togglableRow({
    required String title,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
        ),
        Switch(value: value, activeColor: activeColor, onChanged: onChanged),
      ],
    );
  }

  Widget _presetChip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _kBrand : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? _kBrand : Colors.grey[300]!),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    String? hint,
    IconData? suffixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400]),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _kBrand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: Colors.grey, size: 20)
          : null,
      suffixText: suffixText,
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    IconData? suffixIcon,
    String? suffixText,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _fieldDecoration(
        hint: hint,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
      ),
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
  }
}
