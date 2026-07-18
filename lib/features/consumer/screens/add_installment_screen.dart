import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'lender_selection_screen.dart';
import '../controllers/add_installment_controller.dart';

class AddInstallmentScreen extends StatefulWidget {
  const AddInstallmentScreen({super.key});

  @override
  State<AddInstallmentScreen> createState() => _AddInstallmentScreenState();
}

class _AddInstallmentScreenState extends State<AddInstallmentScreen> {
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
  double _calculatedMonthly = 0.0;

  @override
  void initState() {
    super.initState();
    _totalAmountController.addListener(_calculateMonthly);
    _installmentsController.addListener(_calculateMonthly);
    _downPaymentController.addListener(_calculateMonthly);
    _interestRateController.addListener(_calculateMonthly);
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
      initialDate: TimeService.now(),
      firstDate: TimeService.now(),
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
        final newInstallment = await _controller.saveInstallment(
          storeName: _storeNameController.text,
          itemDescription: _itemDescController.text,
          totalAmount: double.parse(_totalAmountController.text),
          totalMonths: int.parse(_installmentsController.text),
          monthlyPayment: _calculatedMonthly,
          dueDate: _selectedDate!,
          downPayment: double.tryParse(_downPaymentController.text) ?? 0.0,
          interestRate: double.tryParse(_interestRateController.text) ?? 0.0,
          category: 'Other',
        );

        if (mounted) {
          bool? addRule = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Add Late Fee Rule?'),
              content: const Text('Would you like to assign a specific lender to this installment to automatically track real-world late fees and penalties?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No, skip for now', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  child: const Text('Yes, choose lender'),
                ),
              ],
            ),
          );

          if (addRule == true && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LenderSelectionScreen(installment: newInstallment),
              ),
            );
          } else if (mounted) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving installment: $e'), backgroundColor: Colors.red),
          );
        }
      }
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Placeholder for OCR
                  },
                  icon: const Icon(Icons.document_scanner, color: Colors.white),
                  label: const Text('Scan Document or Receipt'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2337), // Dark blue/black
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Store Name'),
                    _buildTextField(_storeNameController, 'Enter store name', suffixIcon: Icons.store),
                    const SizedBox(height: 16),
                    
                    _buildLabel('Item Description'),
                    _buildTextField(_itemDescController, 'Enter item description'),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Total Amount'),
                              _buildTextField(_totalAmountController, '0.00', suffixText: 'EGP', keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Installments'),
                              _buildTextField(_installmentsController, 'e.g., 12', keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Down Payment (Optional)'),
                              _buildTextField(_downPaymentController, '0.00', suffixText: 'EGP', keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Interest rate'),
                              _buildTextField(_interestRateController, '0', suffixText: '%', keyboardType: TextInputType.number),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _buildLabel('First Payment Due Date'),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: _buildTextField(_dueDateController, 'dd/mm/yyyy', suffixIcon: Icons.calendar_today),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                        const Text('Monthly Payment:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(
                          'EGP ${_calculatedMonthly.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Calculated based on total amount, installments, and down payment.',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveInstallment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add Installment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildTextField(TextEditingController controller, String hint, {IconData? suffixIcon, String? suffixText, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
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
        suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Colors.grey) : null,
        suffixText: suffixText,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          if (controller != _downPaymentController && controller != _interestRateController) {
            return 'Required field';
          }
        }
        return null;
      },
    );
  }
}
