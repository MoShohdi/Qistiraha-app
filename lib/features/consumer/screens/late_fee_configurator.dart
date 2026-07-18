import 'package:flutter/material.dart';
import 'package:qistiraha/features/consumer/models/late_fee_rule.dart';
import 'package:qistiraha/core/services/hive_service.dart';

class LateFeeConfiguratorScreen extends StatefulWidget {
  const LateFeeConfiguratorScreen({super.key});

  @override
  State<LateFeeConfiguratorScreen> createState() => _LateFeeConfiguratorScreenState();
}

class _LateFeeConfiguratorScreenState extends State<LateFeeConfiguratorScreen> {
  FeeType _selectedType = FeeType.fixed;
  final _fixedAmountController = TextEditingController(text: '100.00');
  final _percentageController = TextEditingController();

  void _saveRule() async {
    final box = HiveService.getLateFeeBox();
    final rule = LateFeeRule(
      vendorName: 'Default Rule', // Can be customized per vendor later
      feeType: _selectedType,
      fixedAmount: double.tryParse(_fixedAmountController.text) ?? 0.0,
      percentage: double.tryParse(_percentageController.text) ?? 0.0,
    );
    await box.add(rule);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Late Fee Rule Saved!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _fixedAmountController.dispose();
    _percentageController.dispose();
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
          'Late Fee Rules',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(true),
                const SizedBox(width: 8),
                _buildDot(false),
                const SizedBox(width: 8),
                _buildDot(false),
                const SizedBox(width: 8),
                _buildDot(false),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'How is your penalty calculated?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a rule type to define how late fees are applied to overdue installments.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            
            _buildRuleOption(
              FeeType.fixed,
              'A Fixed Fee (EGP)',
              'e.g., A simple one-time fee of 150 EGP.',
              _selectedType == FeeType.fixed ? _buildFixedInput() : null,
            ),
            const SizedBox(height: 16),
            _buildRuleOption(
              FeeType.percentage,
              'A Percentage Fee (%)',
              'e.g., A fee of 5% on your installment.',
              _selectedType == FeeType.percentage ? _buildPercentageInput() : null,
            ),
            const SizedBox(height: 16),
            _buildRuleOption(
              FeeType.mixed,
              'A Mix (Fixed + Percentage)',
              'e.g., A 20 EGP fee + 2% of the installment.',
              _selectedType == FeeType.mixed ? _buildMixedInput() : null,
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveRule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E65F3), // Bright blue
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('Next Step', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(bool active) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF2E65F3) : Colors.grey[300],
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildRuleOption(FeeType type, String title, String description, Widget? extraContent) {
    bool isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF2E65F3) : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? const Color(0xFF2E65F3) : Colors.grey[400],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (extraContent != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 40.0), // Align with text
                child: extraContent,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFixedInput() {
    return _buildInputRow('EGP', _fixedAmountController);
  }

  Widget _buildPercentageInput() {
    return _buildInputRow('%', _percentageController);
  }

  Widget _buildMixedInput() {
    return Column(
      children: [
        _buildInputRow('EGP', _fixedAmountController),
        const SizedBox(height: 8),
        _buildInputRow('%', _percentageController),
      ],
    );
  }

  Widget _buildInputRow(String prefix, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Text(prefix, style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
