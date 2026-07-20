import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/time_service.dart';
import '../controllers/add_installment_controller.dart';
import '../models/installment.dart';

class AddInstallmentScreen extends StatelessWidget {
  const AddInstallmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF8F9FA),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Add Installment',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF99AFD7),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF99AFD7),
            tabs: [
              Tab(text: 'Everyday'),
              Tab(text: 'Long-Term Assets'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _InstallmentFormView(isLongTerm: false),
            _InstallmentFormView(isLongTerm: true),
          ],
        ),
      ),
    );
  }
}

class _InstallmentFormView extends StatefulWidget {
  final bool isLongTerm;
  const _InstallmentFormView({required this.isLongTerm});

  @override
  State<_InstallmentFormView> createState() => _InstallmentFormViewState();
}

class _InstallmentFormViewState extends State<_InstallmentFormView> {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Installment added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving installment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a first payment due date'),
          backgroundColor: Colors.red,
        ),
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
      // Validate Step 1
      if (_selectedProvider == null ||
          _itemDescController.text.isEmpty ||
          _storeNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required fields in Step 1.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // Validate Step 2
      if (_totalAmountController.text.isEmpty ||
          _installmentsController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all required fields in Step 2.'),
            backgroundColor: Colors.red,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildProgressBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 12.0,
            ),
            child: Form(
              key: _formKey,
              child: IndexedStack(
                index: _currentStep,
                children: [_buildStep1(), _buildStep2(), _buildStep3()],
              ),
            ),
          ),
        ),
        _buildBottomNav(),
      ],
    );
  }

  Widget _buildProgressBar() {
    double progress = 0.2;
    if (_currentStep == 1) progress = 0.5;
    if (_currentStep == 2) progress = 0.8;

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}% 🔥',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFF99AFD7),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNode(label: 'New Plan', isCompleted: true, isActive: false),
              _buildNode(
                label: 'Item',
                isCompleted: _currentStep > 0,
                isActive: _currentStep == 0,
              ),
              _buildNode(
                label: 'Finance',
                isCompleted: _currentStep > 1,
                isActive: _currentStep == 1,
              ),
              _buildNode(
                label: 'Finalize',
                isCompleted: false,
                isActive: _currentStep == 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNode({
    required String label,
    required bool isCompleted,
    required bool isActive,
  }) {
    Widget icon;
    if (isCompleted) {
      icon = const Icon(Icons.check, color: Colors.white, size: 14);
    } else if (isActive) {
      icon = Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
    } else {
      icon = const SizedBox();
    }

    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? const Color(0xFF99AFD7)
                : Colors.grey[300],
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? const Color(0xFF99AFD7) : Colors.transparent,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: icon,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF99AFD7) : Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showProviderSearchBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        String searchQuery = '';
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final filteredProviders = kEgyptianProviders
                  .where(
                    (p) => p.toLowerCase().contains(searchQuery.toLowerCase()),
                  )
                  .toList();

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search providers...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            searchQuery = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredProviders.length,
                        itemBuilder: (context, index) {
                          final provider = filteredProviders[index];
                          return ListTile(
                            title: Text(provider),
                            onTap: () {
                              setState(() {
                                _selectedProvider = provider;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 1: Item & Provider',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildLabel('Store / Merchant Name'),
        _buildTextField(
          _storeNameController,
          'e.g., B.TECH',
          suffixIcon: Icons.store,
        ),
        const SizedBox(height: 16),
        _buildLabel('Provider / Institution Name'),
        GestureDetector(
          onTap: () => _showProviderSearchBottomSheet(context),
          child: AbsorbPointer(
            child: TextFormField(
              controller: TextEditingController(text: _selectedProvider),
              decoration: InputDecoration(
                hintText: 'Select Provider',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                  borderSide: const BorderSide(color: Colors.blueAccent),
                ),
                suffixIcon: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey,
                ),
              ),
              validator: (val) =>
                  _selectedProvider == null ? 'Required field' : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabel('Item Description'),
        _buildTextField(_itemDescController, 'Enter item description'),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Step 2: Financials & Presets',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
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
            const SizedBox(width: 16),
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
        const SizedBox(height: 16),
        _buildLabel(
          widget.isLongTerm && _selectedFrequency != 'Monthly'
              ? 'Installments (Payments)'
              : 'Installments (Months)',
        ),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            ..._monthPresets.map(
              (months) => ChoiceChip(
                label: Text('$months Months'),
                selected: _selectedPresetMonths == months && !_showCustomMonths,
                selectedColor: const Color(0xFF99AFD7),
                labelStyle: TextStyle(
                  color: _selectedPresetMonths == months && !_showCustomMonths
                      ? Colors.white
                      : Colors.black,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPresetMonths = months;
                      _showCustomMonths = false;
                      _installmentsController.text = months.toString();
                    });
                  }
                },
              ),
            ),
            ChoiceChip(
              label: const Text('Custom'),
              selected: _showCustomMonths,
              selectedColor: const Color(0xFF99AFD7),
              labelStyle: TextStyle(
                color: _showCustomMonths ? Colors.white : Colors.black,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedPresetMonths = null;
                    _showCustomMonths = true;
                    _installmentsController.text = '';
                  });
                }
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
        const SizedBox(height: 16),
        _buildLabel('Interest rate (Optional)'),
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
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monthly Payment:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
        const Text(
          'Step 3: Details & Smart Dates',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (widget.isLongTerm) ...[
          _buildLabel('Payment Frequency'),
          DropdownButtonFormField<String>(
            value: _selectedFrequency,
            decoration: _dropdownDecoration(),
            items: _frequencies
                .map((freq) => DropdownMenuItem(value: freq, child: Text(freq)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedFrequency = val);
            },
          ),
          const SizedBox(height: 16),
        ],
        _buildLabel('Category'),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          hint: Text(
            'Select a category',
            style: TextStyle(color: Colors.grey[400]),
          ),
          decoration: _dropdownDecoration(),
          items: currentCategories
              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
              .toList(),
          onChanged: (val) => setState(() => _selectedCategory = val),
          validator: (val) => val == null ? 'Required field' : null,
        ),
        const SizedBox(height: 16),
        _buildLabel(_isLate ? 'Oldest Missed Due Date' : 'Next Due Date'),
        GestureDetector(
          onTap: () => _selectDate(context),
          child: AbsorbPointer(
            child: _buildTextField(
              _dueDateController,
              'dd/mm/yyyy',
              suffixIcon: Icons.calendar_today,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text(
            'I have already started paying this off',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          contentPadding: EdgeInsets.zero,
          activeColor: Colors.black,
          value: _isLegacy,
          onChanged: (val) => setState(() => _isLegacy = val),
        ),
        if (_isLegacy) ...[
          const SizedBox(height: 8),
          _buildLabel('How many payments have you already made?'),
          _buildTextField(
            _paidPeriodsController,
            'e.g., 10',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(
              'I am currently behind on payments',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: Colors.red,
            value: _isLate,
            onChanged: (val) => setState(() => _isLate = val),
          ),
          if (_isLate) ...[
            const SizedBox(height: 8),
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

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_currentStep > 0) ...[
                SizedBox(
                  width: 120,
                  child: OutlinedButton(
                    onPressed: _prevStep,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              SizedBox(
                width: _currentStep > 0 ? 200 : 336,
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentStep == 2 ? 'Add Installment' : 'Next',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
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
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
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
        borderSide: const BorderSide(color: Colors.blueAccent),
      ),
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
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
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
          borderSide: const BorderSide(color: Colors.blueAccent),
        ),
        suffixIcon: suffixIcon != null
            ? Icon(suffixIcon, color: Colors.grey)
            : null,
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
