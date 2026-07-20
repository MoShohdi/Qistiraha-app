import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/engine/penalty_engine.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'package:lottie/lottie.dart';

class InstallmentDetailsScreen extends StatefulWidget {
  final Installment installment;

  const InstallmentDetailsScreen({super.key, required this.installment});

  @override
  State<InstallmentDetailsScreen> createState() => _InstallmentDetailsScreenState();
}

class _InstallmentDetailsScreenState extends State<InstallmentDetailsScreen> {
  final currencyFormatter = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);
  bool _isByDate = true;
  DateTime? _desiredPayoffDate;
  double _newMonthlyPayment = 0.0;
  int _calculatedMonthsToPayoff = 0;

  void _applyNewPlan() async {
    widget.installment.monthlyPayment = _newMonthlyPayment;
    widget.installment.totalMonths = widget.installment.paidMonths + _calculatedMonthsToPayoff;
    await widget.installment.save(); // Save to Hive

    setState(() {
      _newMonthlyPayment = 0.0;
      _desiredPayoffDate = null;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Installment plan updated successfully')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Installment'),
        content: const Text('Are you sure you want to delete this installment? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final userBox = HiveService.getUserBox();
      if (userBox.isNotEmpty) {
        var user = userBox.values.first;
        user.installments?.remove(widget.installment);
        await user.save();
      }
      
      await widget.installment.delete();
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DeleteAnimationScreen()),
        );
      }
    }
  }

  void _calculateEarlyPayoff() {
    if (_desiredPayoffDate == null) return;
    
    int remainingMonths = widget.installment.totalMonths - widget.installment.paidMonths;
    double remainingDebt = remainingMonths * widget.installment.monthlyPayment;
    
    // Calculate months between now and desired payoff date
    int monthsToPayoff = (_desiredPayoffDate!.year - TimeService.now().year) * 12 + 
                         _desiredPayoffDate!.month - TimeService.now().month;
                         
    if (monthsToPayoff <= 0) monthsToPayoff = 1;
    
    setState(() {
      _newMonthlyPayment = remainingDebt / monthsToPayoff;
      _calculatedMonthsToPayoff = monthsToPayoff;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: TimeService.now().add(const Duration(days: 30)),
      firstDate: TimeService.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _desiredPayoffDate) {
      setState(() {
        _desiredPayoffDate = picked;
      });
    }
  }

  Future<void> _pickWarrantyImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        widget.installment.warrantyImagePath = image.path;
        await widget.installment.save();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Add Warranty Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickWarrantyImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickWarrantyImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int remainingMonths = widget.installment.totalMonths - widget.installment.paidMonths;
    double remainingDebt = remainingMonths * widget.installment.monthlyPayment;
    PenaltyResult penaltyResult = PenaltyEngine.calculateLateFees(widget.installment);
    remainingDebt += penaltyResult.lateFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.installment.merchantName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.black),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildAmountCard('TOTAL AMOUNT', widget.installment.amount),
            const SizedBox(height: 16),
            _buildRemainingDebtCard(remainingDebt),
            const SizedBox(height: 16),
            _buildDebtPaidCard(),
            const SizedBox(height: 16),
            _buildMonthlyPaymentCard(penaltyResult),
            const SizedBox(height: 16),
            _buildWarrantyCard(),
            const SizedBox(height: 24),
            _buildPaymentHistory(),
            const SizedBox(height: 24),
            if (widget.installment.statusEnum != InstallmentStatus.paid) ...[
              _buildEarlyPayoffCalculator(),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Delete Installment', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(String label, double amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(amount),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingDebtCard(double remainingDebt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REMAINING DEBT',
            style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(remainingDebt),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
          ),
          const SizedBox(height: 16),
          if (widget.installment.totalPayments <= 20)
            Row(
              children: List.generate(widget.installment.totalPayments, (index) {
                int paidSegments = widget.installment.paidPayments;
                int totalSegments = widget.installment.totalPayments;
                int redSegments = 0;

                PenaltyResult pr = PenaltyEngine.calculateLateFees(widget.installment);
                if (pr.isAccelerated) {
                  redSegments = totalSegments - paidSegments;
                } else {
                  redSegments = PenaltyEngine.calculateUncappedMissedPeriods(widget.installment);
                  if (redSegments > (totalSegments - paidSegments)) {
                    redSegments = totalSegments - paidSegments;
                  }
                }

                Color segmentColor;
                if (index < paidSegments) {
                  segmentColor = Theme.of(context).primaryColor;
                } else if (index < paidSegments + redSegments) {
                  segmentColor = Colors.red;
                } else {
                  segmentColor = Colors.grey[200]!;
                }

                return Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: index == totalSegments - 1 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: segmentColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: widget.installment.totalPayments > 0 ? widget.installment.paidPayments / widget.installment.totalPayments : 0.0,
                backgroundColor: Colors.grey[200],
                color: Theme.of(context).primaryColor,
                minHeight: 8,
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${widget.installment.paidPayments} of ${widget.installment.totalPayments} paid',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtPaidCard() {
    double totalPaid = widget.installment.pastPayments.fold(0.0, (sum, p) => sum + p);
    double totalPenalty = widget.installment.pastPayments.fold(0.0, (sum, p) {
      return sum + (p > widget.installment.monthlyPayment ? (p - widget.installment.monthlyPayment) : 0.0);
    });
    double totalRegular = totalPaid - totalPenalty;
    
    // Fallback if no pastPayments stored (for legacy test data)
    if (totalPaid == 0 && widget.installment.paidMonths > 0) {
      totalPaid = widget.installment.paidMonths * widget.installment.monthlyPayment;
      totalRegular = totalPaid;
    }

    double maxTotal = totalPaid;
    double regularRatio = maxTotal > 0 ? totalRegular / maxTotal : 0;
    double penaltyRatio = maxTotal > 0 ? totalPenalty / maxTotal : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEBT PAID',
            style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormatter.format(totalPaid),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (regularRatio > 0)
                    Expanded(
                      flex: (regularRatio * 1000).toInt(),
                      child: Container(color: Colors.blueGrey[800]),
                    ),
                  if (penaltyRatio > 0)
                    Expanded(
                      flex: (penaltyRatio * 1000).toInt(),
                      child: Container(color: Colors.redAccent),
                    ),
                  if (regularRatio == 0 && penaltyRatio == 0)
                    Expanded(
                      child: Container(color: Colors.grey[200]),
                    )
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (penaltyRatio > 0)
                Text(
                  'Includes ${currencyFormatter.format(totalPenalty)} penalties',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              if (penaltyRatio == 0)
                const SizedBox(),
              Text(
                '${widget.installment.paidPayments} of ${widget.installment.totalPayments} paid',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyPaymentCard(PenaltyResult penaltyResult) {
    double lateFee = penaltyResult.lateFee;
    bool isAccelerated = penaltyResult.isAccelerated;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAccelerated ? Colors.red : Colors.grey[200]!, width: isAccelerated ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAccelerated) ...[
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ DEFAULT STATUS: ENTIRE BALANCE DUE',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Text(
                'MONTHLY PAYMENT',
                style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2337),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('FIXED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 8),
          if (lateFee > 0 && !isAccelerated)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormatter.format(widget.installment.monthlyPayment * PenaltyEngine.calculateMissedMonths(widget.installment)),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormatter.format(
                isAccelerated 
                  ? ((widget.installment.totalPayments - widget.installment.paidPayments) * widget.installment.monthlyPayment)
                  : widget.installment.statusEnum == InstallmentStatus.overdue
                    ? (widget.installment.monthlyPayment * PenaltyEngine.calculateUncappedMissedPeriods(widget.installment))
                    : widget.installment.monthlyPayment
              ),
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: widget.installment.statusEnum == InstallmentStatus.overdue ? Colors.red : Colors.black,
              ),
            ),
          ),
          if (widget.installment.statusEnum == InstallmentStatus.overdue)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Please contact your lender for late fees details.',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Due ${widget.installment.dueDate.day}th of every month',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          if (widget.installment.statusEnum != InstallmentStatus.paid) ...[
            const SizedBox(height: 20),
            (() {
              int regularPeriodsToPay = PenaltyEngine.calculateActualPeriodsToPay(widget.installment);
              if (widget.installment.paidPayments + regularPeriodsToPay > widget.installment.totalPayments) {
                regularPeriodsToPay = widget.installment.totalPayments - widget.installment.paidPayments;
              }
              double regularTransactionCost = (widget.installment.monthlyPayment * regularPeriodsToPay) + lateFee;

              int fullPeriodsToPay = widget.installment.totalPayments - widget.installment.paidPayments;
              double fullTransactionCost = (widget.installment.monthlyPayment * fullPeriodsToPay) + lateFee;

              Future<void> pay(int periodsToPay) async {
                if (widget.installment.paidPayments < widget.installment.totalPayments) {
                  double evenlyDistributedPenalty = lateFee / periodsToPay;
                  for (int i = 0; i < periodsToPay; i++) {
                    widget.installment.pastPayments = List.from(widget.installment.pastPayments)..add(widget.installment.monthlyPayment + evenlyDistributedPenalty);
                  }
                  
                  int monthsToAdvance = periodsToPay * widget.installment.monthsPerPayment;
                  widget.installment.paidMonths += monthsToAdvance;
                  widget.installment.dueDate = DateTime(widget.installment.dueDate.year, widget.installment.dueDate.month + monthsToAdvance, widget.installment.dueDate.day);
                  
                  if (widget.installment.paidPayments >= widget.installment.totalPayments) {
                    widget.installment.statusEnum = InstallmentStatus.paid;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Installment fully paid! Moved to History tab. 🎉'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.pop(context); // Go back to home to see the animation/result
                    }
                  } else if (widget.installment.statusEnum == InstallmentStatus.overdue && widget.installment.dueDate.isAfter(TimeService.now())) {
                    widget.installment.statusEnum = InstallmentStatus.active;
                  }
                  widget.installment.lastPaidAt = TimeService.now(); // stamp payment time for billing cycle tracking
                  await widget.installment.save();
                  setState(() {});
                }
              }

              if (isAccelerated) {
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => pay(regularPeriodsToPay),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            children: [
                              TextSpan(
                                text: regularPeriodsToPay > 1
                                    ? 'Pay $regularPeriodsToPay Arrears\n'
                                    : 'Mark ${widget.installment.paymentFrequency == 'Monthly' ? 'Month' : widget.installment.paymentFrequency == 'Quarterly' ? 'Quarter' : widget.installment.paymentFrequency == 'Semi-Annually' ? 'Half-Year' : 'Year'} as Paid\n',
                              ),
                              TextSpan(
                                text: '(${currencyFormatter.format(regularTransactionCost)})',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => pay(fullPeriodsToPay),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            children: [
                              const TextSpan(text: 'Settle Full Debt\n'),
                              TextSpan(
                                text: '(${currencyFormatter.format(fullTransactionCost)})',
                                style: TextStyle(
                                  color: Colors.red.shade100,
                                  fontWeight: FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => pay(regularPeriodsToPay),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                                text: regularPeriodsToPay > 1
                                    ? 'Pay $regularPeriodsToPay Arrears\n'
                                    : 'Mark ${widget.installment.paymentFrequency == 'Monthly' ? 'Month' : widget.installment.paymentFrequency == 'Quarterly' ? 'Quarter' : widget.installment.paymentFrequency == 'Semi-Annually' ? 'Half-Year' : 'Year'} as Paid\n',
                          ),
                          TextSpan(
                            text: '(${currencyFormatter.format(regularTransactionCost)})',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            })(),
          ],
        ],
      ),
    );
  }

  Widget _buildWarrantyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WARRANTY & RECEIPT',
            style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          if (widget.installment.warrantyImagePath == null)
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.camera_alt_outlined, color: Colors.grey[500], size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to add warranty photo',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.installment.warrantyImagePath!),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Document Saved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    insetPadding: const EdgeInsets.all(16),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.file(File(widget.installment.warrantyImagePath!)),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.fullscreen, size: 16, color: Colors.black),
                              label: const Text('View', style: TextStyle(color: Colors.black, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                bool? confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Remove Warranty Document'),
                                    content: const Text('Are you sure you want to remove this image? This action cannot be undone.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  widget.installment.warrantyImagePath = null;
                                  await widget.installment.save();
                                  setState(() {});
                                }
                              },
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    List<Widget> historyItems = [];
    
    // Add upcoming payment
    if (widget.installment.paidMonths < widget.installment.totalMonths) {
      double upcomingAmount = widget.installment.monthlyPayment;
      PenaltyResult pr = PenaltyEngine.calculateLateFees(widget.installment);
      double lateFee = pr.lateFee;
      upcomingAmount += lateFee;
      
      historyItems.add(_buildHistoryItem(
        'Payment ${widget.installment.paidMonths + 1}',
        widget.installment.dueDate,
        upcomingAmount,
        lateFee > 0 ? 'LATE' : 'UPCOMING',
        lateFee > 0 ? Colors.red[50]! : Colors.grey[200]!,
        lateFee > 0 ? Colors.red : Colors.black,
        lateFee > 0 ? Icons.warning_amber_rounded : Icons.access_time
      ));
      if (widget.installment.paidMonths > 0) {
        historyItems.add(const SizedBox(height: 16));
      }
    }

    // Add past payments from newest to oldest
    for (int i = widget.installment.paidMonths - 1; i >= 0; i--) {
      double amount = widget.installment.monthlyPayment;
      if (i < widget.installment.pastPayments.length) {
        amount = widget.installment.pastPayments[i];
      }
      
      DateTime pastDate = widget.installment.dueDate.subtract(Duration(days: 30 * (widget.installment.paidMonths - i)));
      bool wasLate = amount > widget.installment.monthlyPayment;

      historyItems.add(_buildHistoryItem(
        'Payment ${i + 1}',
        pastDate,
        amount,
        wasLate ? 'PAID (LATE)' : 'PAID',
        wasLate ? Colors.red[50]! : Colors.green[50]!,
        wasLate ? Colors.red : Colors.green,
        wasLate ? Icons.warning_rounded : Icons.check_circle
      ));
      
      if (i > 0) {
        historyItems.add(const SizedBox(height: 16));
      }
    }

    if (historyItems.isEmpty) {
      historyItems.add(const Text("No payment history"));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Payment History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('View All', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          ...historyItems,
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String title, DateTime date, double amount, String status, Color statusBg, Color statusText, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.black54),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Due: ${DateFormat('dd/MM/yyyy').format(date)}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currencyFormatter.format(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status, style: TextStyle(color: statusText, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarlyPayoffCalculator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Early Payoff Calculator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Simulate early settlement terms.', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isByDate = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _isByDate ? Colors.white : Colors.grey[100],
                      border: Border.all(color: _isByDate ? Colors.grey[300]! : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text('By Date', style: TextStyle(fontWeight: _isByDate ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isByDate = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !_isByDate ? Colors.white : Colors.grey[100],
                      border: Border.all(color: !_isByDate ? Colors.grey[300]! : Colors.transparent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text('By Amount', style: TextStyle(fontWeight: !_isByDate ? FontWeight.bold : FontWeight.normal)),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          if (_isByDate) ...[
            const Text('Desired Payoff Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _desiredPayoffDate != null ? DateFormat('dd/MM/yyyy').format(_desiredPayoffDate!) : 'dd/mm/yyyy',
                      style: TextStyle(color: _desiredPayoffDate != null ? Colors.black : Colors.grey[400]),
                    ),
                    const Icon(Icons.calendar_today, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _calculateEarlyPayoff,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Calculate New Payment', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (_newMonthlyPayment > 0) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
                        children: [
                          const TextSpan(text: 'To pay off by '),
                          TextSpan(text: DateFormat('dd/MM/yyyy').format(_desiredPayoffDate!), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: ', your new monthly payment will be '),
                          TextSpan(text: currencyFormatter.format(_newMonthlyPayment), style: const TextStyle(fontWeight: FontWeight.bold)),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _applyNewPlan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E65F3), // Match brand blue
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Apply to Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              )
            ]
          ] else ...[
            const Center(child: Text("By Amount simulation is coming soon."))
          ]
        ],
      ),
    );
  }
}

class DeleteAnimationScreen extends StatelessWidget {
  const DeleteAnimationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animations/delete_files.json',
          repeat: false,
          onLoaded: (composition) {
            Future.delayed(composition.duration, () {
              if (context.mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            });
          },
        ),
      ),
    );
  }
}
