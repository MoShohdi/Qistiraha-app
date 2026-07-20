import 'package:flutter/material.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:flutter/services.dart';

class IncomeEditBottomSheet extends StatefulWidget {
  const IncomeEditBottomSheet({super.key});

  @override
  State<IncomeEditBottomSheet> createState() => _IncomeEditBottomSheetState();
}

class _IncomeEditBottomSheetState extends State<IncomeEditBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _incomeController;
  late double _salaryDay;

  @override
  void initState() {
    super.initState();
    final user = HiveService.getUserBox().values.first;
    _incomeController = TextEditingController(
      text: user.monthlyIncome.toStringAsFixed(0),
    );
    _salaryDay = user.salaryDay.toDouble();
  }

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      final user = HiveService.getUserBox().values.first;
      user.monthlyIncome = double.parse(_incomeController.text);
      user.salaryDay = _salaryDay.toInt();
      await user.save();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Income & Salary Configuration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _incomeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Monthly Income (EGP)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your monthly income';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Salary Deposit Day',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _salaryDay,
                    min: 1,
                    max: 31,
                    divisions: 30,
                    label: _salaryDay.round().toString(),
                    onChanged: (value) {
                      setState(() {
                        _salaryDay = value;
                      });
                    },
                  ),
                ),
                Text(
                  'Day ${_salaryDay.round()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _saveData,
                child: const Text(
                  'Save Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
