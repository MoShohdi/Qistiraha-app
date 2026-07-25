import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:lottie/lottie.dart';
import 'package:qistiraha/core/utils/card_entrance_animation.dart';

class InstallmentDetailsScreen extends StatefulWidget {
  final InstallmentRow installment;

  const InstallmentDetailsScreen({super.key, required this.installment});

  @override
  State<InstallmentDetailsScreen> createState() =>
      _InstallmentDetailsScreenState();
}

class _InstallmentDetailsScreenState extends State<InstallmentDetailsScreen> {
  final currencyFormatter = NumberFormat.currency(
    symbol: 'EGP ',
    decimalDigits: 2,
  );
  // Held in state so mutations (payment, re-plan) can refresh it from Supabase.
  late InstallmentRow _inst = widget.installment;
  bool _isByDate = true;
  DateTime? _desiredPayoffDate;
  double _newMonthlyPayment = 0.0;
  int _calculatedMonthsToPayoff = 0;

  Future<void> _refresh() async {
    final updated = await DatabaseService.fetchInstallment(_inst.id);
    if (updated != null && mounted) setState(() => _inst = updated);
  }

  bool _uploadingReceipt = false;

  Future<void> _pickAndUploadReceipt(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
      if (image == null) return;
      setState(() => _uploadingReceipt = true);
      final bytes = await image.readAsBytes();
      await DatabaseService.uploadReceipt(_inst.id, bytes);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to upload receipt: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  void _showReceiptSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Add Receipt Photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadReceipt(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _removeReceipt() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Receipt'),
        content: const Text('Remove this receipt image? This cannot be undone.'),
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
    if (confirm != true) return;
    await DatabaseService.removeReceipt(_inst.id);
    await _refresh();
  }

  void _applyNewPlan() async {
    await DatabaseService.updatePlanTerms(
      _inst.id,
      monthlyPayment: _newMonthlyPayment,
      totalMonths: _inst.paidMonths + _calculatedMonthsToPayoff,
    );
    await _refresh();

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
        content: const Text(
          'Are you sure you want to delete this installment? This action cannot be undone.',
        ),
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
      await DatabaseService.deleteInstallment(_inst.id);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DeleteAnimationScreen(),
          ),
        );
      }
    }
  }

  void _calculateEarlyPayoff() {
    if (_desiredPayoffDate == null) return;

    final double remainingDebt = _inst.remaining; // totalAmount - paidAmount

    // Calculate months between now and desired payoff date
    int monthsToPayoff =
        (_desiredPayoffDate!.year - TimeService.now().year) * 12 +
        _desiredPayoffDate!.month -
        TimeService.now().month;

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

  @override
  Widget build(BuildContext context) {
    final double remainingDebt = _inst.remaining; // totalAmount - paidAmount

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
          _inst.merchantName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildAmountCard('TOTAL AMOUNT', _inst.totalAmount),
            const SizedBox(height: 16),
            _buildRemainingDebtCard(remainingDebt),
            const SizedBox(height: 16),
            _buildDebtPaidCard(),
            const SizedBox(height: 16),
            _buildMonthlyPaymentCard(),
            const SizedBox(height: 16),
            _buildReceiptCard(),
            const SizedBox(height: 24),
            _buildPaymentHistory(),
            const SizedBox(height: 24),
            if (!_inst.isCompleted) ...[
              _buildEarlyPayoffCalculator(),
              const SizedBox(height: 24),
            ],
            // A merchant-issued plan can only be cancelled by that merchant.
            // A self-added plan (merchant_id == the current user) is deletable
            // here.
            if (_inst.merchantId == DatabaseService.currentUserId)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _confirmDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Delete Installment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(String label, double amount) {
    return CardPopIn(
      id: 'details-amount-card-$label',
      builder: (context, animate) => Container(
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
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormatter.format(amount),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ],
        ).popInIf(animate, 0),
      ),
    );
  }

  Widget _buildRemainingDebtCard(double remainingDebt) {
    return CardPopIn(
      id: 'details-remaining-debt-card',
      builder: (context, animate) => Container(
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
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormatter.format(remainingDebt),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 16),
            if (_inst.totalPayments <= 20)
              Row(
                children: List.generate(_inst.totalPayments, (index) {
                  int paidSegments = _inst.paidPayments;
                  int totalSegments = _inst.totalPayments;

                  // No penalties: segments are simply paid vs. remaining.
                  Color segmentColor;
                  if (index < paidSegments) {
                    segmentColor = Theme.of(context).primaryColor;
                  } else {
                    segmentColor = Colors.grey[200]!;
                  }

                  return Expanded(
                    child: Container(
                      height: 8,
                      margin: EdgeInsets.only(
                        right: index == totalSegments - 1 ? 0 : 4,
                      ),
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
                  value: _inst.totalPayments > 0
                      ? _inst.paidPayments / _inst.totalPayments
                      : 0.0,
                  backgroundColor: Colors.grey[200],
                  color: Theme.of(context).primaryColor,
                  minHeight: 8,
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_inst.paidPayments} of ${_inst.totalPayments} paid',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ).popInIf(animate, 0),
      ),
    );
  }

  Widget _buildDebtPaidCard() {
    double totalPaid = _inst.pastPayments.fold(0.0, (sum, p) => sum + p);
    double totalPenalty = _inst.pastPayments.fold(0.0, (sum, p) {
      return sum +
          (p > _inst.monthlyPayment ? (p - _inst.monthlyPayment) : 0.0);
    });
    double totalRegular = totalPaid - totalPenalty;

    // Fallback if no pastPayments stored (for legacy test data)
    if (totalPaid == 0 && _inst.paidMonths > 0) {
      totalPaid = _inst.paidMonths * _inst.monthlyPayment;
      totalRegular = totalPaid;
    }

    double maxTotal = totalPaid;
    double regularRatio = maxTotal > 0 ? totalRegular / maxTotal : 0;
    double penaltyRatio = maxTotal > 0 ? totalPenalty / maxTotal : 0;

    return CardPopIn(
      id: 'details-debt-paid-card',
      builder: (context, animate) => Container(
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
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormatter.format(totalPaid),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[800],
              ),
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
                      Expanded(child: Container(color: Colors.grey[200])),
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
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (penaltyRatio == 0) const SizedBox(),
                Text(
                  '${_inst.paidPayments} of ${_inst.totalPayments} paid',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ).popInIf(animate, 0),
      ),
    );
  }

  Widget _buildMonthlyPaymentCard() {
    final bool isOverdue = _inst.isOverdue;

    return CardPopIn(
      id: 'details-monthly-payment-card',
      builder: (context, animate) => Container(
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
              children: [
                Text(
                  _inst.paymentFrequencyLabel.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2337),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'FIXED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                currencyFormatter.format(_inst.monthlyPayment),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isOverdue ? Colors.red : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Due ${_inst.dueDate.day}th of ${_inst.paymentCadencePhrase}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
            if (!_inst.isCompleted) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _markOnePeriodPaid,
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
                        TextSpan(text: 'Mark ${_inst.periodNoun} as Paid\n'),
                        TextSpan(
                          text:
                              '(${currencyFormatter.format(_inst.monthlyPayment)})',
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
            ],
          ],
        ).popInIf(animate, 0),
      ),
    );
  }

  /// Records a single on-time period payment. No penalties, no arrears
  /// bundling — one tap advances the plan by exactly one payment period.
  Future<void> _markOnePeriodPaid() async {
    if (_inst.paidPayments >= _inst.totalPayments) return;
    final wasLast = _inst.paidPayments + 1 >= _inst.totalPayments;

    try {
      await DatabaseService.recordPayment(_inst);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record payment.')),
        );
      }
      return;
    }

    if (wasLast) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Installment fully paid! Moved to History tab. 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
      return;
    }
    await _refresh();
  }

  Widget _buildReceiptCard() {
    final url = _inst.receiptImageUrl;
    return CardPopIn(
      id: 'details-receipt-card',
      builder: (context, animate) => Container(
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
              style: TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            if (_uploadingReceipt)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (url == null)
              GestureDetector(
                onTap: _showReceiptSourceDialog,
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
                      Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.grey[500],
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to add receipt photo',
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
                    child: Image.network(
                      url,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Receipt saved',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    insetPadding: const EdgeInsets.all(16),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Image.network(url),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black45,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.fullscreen,
                                  size: 16,
                                  color: Colors.black,
                                ),
                                label: const Text(
                                  'View',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _removeReceipt,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
        ).popInIf(animate, 0),
      ),
    );
  }

  Widget _buildPaymentHistory() {
    List<Widget> historyItems = [];
    final inst = _inst;

    // One node per payment PERIOD, not per month — a 12-month Semi-Annual
    // plan shows 2 nodes, not 12. Amounts are the per-period chunk stored in
    // [monthlyPayment] (or the exact recorded value in [pastPayments], which
    // is itself one entry per period), and dates step by whole frequency
    // chunks via [dueDateForPeriodsBack].

    // Add upcoming payment (next unpaid period). No late fee is ever added.
    if (inst.paidPayments < inst.totalPayments) {
      historyItems.add(
        _buildHistoryItem(
          'Payment ${inst.paidPayments + 1}',
          inst.dueDate,
          inst.monthlyPayment,
          'UPCOMING',
          Colors.grey[200]!,
          Colors.black,
          Icons.access_time,
        ),
      );
      if (inst.paidPayments > 0) {
        historyItems.add(const SizedBox(height: 16));
      }
    }

    // Add past periods from newest to oldest.
    for (int i = inst.paidPayments - 1; i >= 0; i--) {
      double amount = i < inst.pastPayments.length
          ? inst.pastPayments[i]
          : inst.monthlyPayment;

      DateTime pastDate = inst.dueDateForPeriodsBack(inst.paidPayments - i);
      bool wasLate = amount > inst.monthlyPayment;

      historyItems.add(
        _buildHistoryItem(
          'Payment ${i + 1}',
          pastDate,
          amount,
          wasLate ? 'PAID (LATE)' : 'PAID',
          wasLate ? Colors.red[50]! : Colors.green[50]!,
          wasLate ? Colors.red : Colors.green,
          wasLate ? Icons.warning_rounded : Icons.check_circle,
        ),
      );

      if (i > 0) {
        historyItems.add(const SizedBox(height: 16));
      }
    }

    if (historyItems.isEmpty) {
      historyItems.add(const Text("No payment history"));
    }

    return CardPopIn(
      id: 'details-payment-history-card',
      builder: (context, animate) => Container(
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ).popInIf(animate, 0),
            const SizedBox(height: 16),
            ...historyItems,
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
    String title,
    DateTime date,
    double amount,
    String status,
    Color statusBg,
    Color statusText,
    IconData icon,
  ) {
    return CardPopIn(
      id: 'details-history-item-$title',
      builder: (context, animate) => Container(
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
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due: ${DateFormat('dd/MM/yyyy').format(date)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormatter.format(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusText,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ).popInIf(animate, 0),
      ),
    );
  }

  Widget _buildEarlyPayoffCalculator() {
    return CardPopIn(
      id: 'details-early-payoff-card',
      builder: (context, animate) => Container(
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
              'Early Payoff Calculator',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Simulate early settlement terms.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
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
                        border: Border.all(
                          color: _isByDate
                              ? Colors.grey[300]!
                              : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'By Date',
                        style: TextStyle(
                          fontWeight: _isByDate
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
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
                        border: Border.all(
                          color: !_isByDate
                              ? Colors.grey[300]!
                              : Colors.transparent,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'By Amount',
                        style: TextStyle(
                          fontWeight: !_isByDate
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            if (_isByDate) ...[
              const Text(
                'Desired Payoff Date',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _desiredPayoffDate != null
                            ? DateFormat(
                                'dd/MM/yyyy',
                              ).format(_desiredPayoffDate!)
                            : 'dd/mm/yyyy',
                        style: TextStyle(
                          color: _desiredPayoffDate != null
                              ? Colors.black
                              : Colors.grey[400],
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                        size: 20,
                      ),
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
                  child: const Text(
                    'Calculate New Payment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'To pay off by '),
                            TextSpan(
                              text: DateFormat(
                                'dd/MM/yyyy',
                              ).format(_desiredPayoffDate!),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(
                              text: ', your new monthly payment will be ',
                            ),
                            TextSpan(
                              text: currencyFormatter.format(
                                _newMonthlyPayment,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                            backgroundColor: const Color(
                              0xFF2E65F3,
                            ), // Match brand blue
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Apply to Plan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              const Center(child: Text("By Amount simulation is coming soon.")),
            ],
          ],
        ).popInIf(animate, 0),
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
