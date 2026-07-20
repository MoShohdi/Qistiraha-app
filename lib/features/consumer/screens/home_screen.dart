import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:qistiraha/features/auth/models/user_account.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/engine/penalty_engine.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'package:qistiraha/core/engine/affordability_engine.dart';
import 'package:qistiraha/core/utils/card_entrance_animation.dart';
import 'add_installment_screen.dart';
import 'installment_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _sortBy = 'urgency';

  // --- What-If Simulator state ---
  final _whatIfCostController = TextEditingController();
  final _whatIfDownPaymentController = TextEditingController();
  final _whatIfMonthsController = TextEditingController();
  SimulatedOutlook? _simulatedOutlook;

  @override
  void initState() {
    super.initState();
    _whatIfCostController.addListener(_runSimulation);
    _whatIfDownPaymentController.addListener(_runSimulation);
    _whatIfMonthsController.addListener(_runSimulation);
  }

  void _runSimulation() {
    final double? cost = double.tryParse(_whatIfCostController.text);
    final int? months = int.tryParse(_whatIfMonthsController.text);
    final double downPayment =
        double.tryParse(_whatIfDownPaymentController.text) ?? 0.0;
    if (cost == null || months == null || months <= 0) {
      setState(() => _simulatedOutlook = null);
      return;
    }
    final box = HiveService.getUserBox();
    if (box.isEmpty) return;
    final user = box.values.first;
    final outlook = AffordabilityEngine.simulatePurchase(
      itemCost: cost,
      months: months,
      downPayment: downPayment,
      existing: user.installments?.toList() ?? [],
      monthlyIncome: user.monthlyIncome,
      salaryDay: user.salaryDay,
    );
    setState(() => _simulatedOutlook = outlook);
  }

  @override
  void dispose() {
    _whatIfCostController.dispose();
    _whatIfDownPaymentController.dispose();
    _whatIfMonthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'Qistiraha',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.fast_forward, color: Colors.black),
                tooltip: 'Skip 1 Day',
                onPressed: () {
                  setState(() {
                    TimeService.skipDays += 1;
                  });
                },
              ),
              if (TimeService.skipDays > 0)
                IconButton(
                  icon: const Icon(Icons.restore, color: Colors.deepPurple),
                  tooltip: 'Reset Time',
                  onPressed: () {
                    setState(() {
                      TimeService.skipDays = 0;
                    });
                  },
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: HiveService.getUserBox().listenable(),
        builder: (context, Box<UserAccount> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("No User Data Found"));
          }

          UserAccount user = box.values.first;

          return ValueListenableBuilder(
            valueListenable: HiveService.getInstallmentBox().listenable(),
            builder: (context, Box<Installment> installmentBox, _) {
              double totalPaymentThisMonth =
                  AffordabilityEngine.calculateTotalMonthlyPayment(user);
              double totalOutstanding =
                  AffordabilityEngine.calculateTotalOutstandingDebt(user);
              AffordabilityStatus status = AffordabilityEngine.calculateStatus(
                user,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user.name}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMMEEEEd().format(TimeService.now()),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Here is your financial overview.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Builder(
                      builder: (context) {
                        List<Installment> activeInstallments =
                            (user.installments?.toList() ?? <Installment>[])
                                .where(
                                  (inst) =>
                                      inst.paidMonths < inst.totalMonths &&
                                      inst.statusEnum != InstallmentStatus.paid,
                                )
                                .toList();

                        int activeCount = activeInstallments.length;

                        return _buildKPICards(
                          totalPaymentThisMonth,
                          totalOutstanding,
                          status,
                          activeCount,
                          "Across all your active installments",
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildSandboxCard(user),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Obligations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            DropdownButton<String>(
                              value: _sortBy,
                              underline: const SizedBox(),
                              icon: const Icon(
                                Icons.sort,
                                color: Colors.black,
                                size: 20,
                              ),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'name',
                                  child: Text('Name'),
                                ),
                                DropdownMenuItem(
                                  value: 'total debt',
                                  child: Text('Total Debt'),
                                ),
                                DropdownMenuItem(
                                  value: 'installment debt',
                                  child: Text('Installment Debt'),
                                ),
                                DropdownMenuItem(
                                  value: 'installment duration',
                                  child: Text('Duration'),
                                ),
                                DropdownMenuItem(
                                  value: 'urgency',
                                  child: Text('Urgency'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _sortBy = val;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.add, size: 20),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddInstallmentScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Short-Term Obligations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDebtFreeSubCard(
                      user,
                      isLongTerm: false,
                      titlePrefix: 'Retail Debt-Free',
                    ),
                    _buildUrgentWarning(user, false),
                    const SizedBox(height: 16),
                    _buildInstallmentsList(user.installments, false),
                    const SizedBox(height: 32),
                    const Text(
                      'Long-Term Assets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDebtFreeSubCard(
                      user,
                      isLongTerm: true,
                      titlePrefix: 'Asset Payoff Target',
                    ),
                    _buildUrgentWarning(user, true),
                    const SizedBox(height: 16),
                    _buildInstallmentsList(user.installments, true),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildKPICards(
    double monthPayment,
    double outstanding,
    AffordabilityStatus status,
    int activeCount,
    String nextInstallmentSubtitle,
  ) {
    Color statusColor;
    switch (status) {
      case AffordabilityStatus.green:
        statusColor = Colors.green;
        break;
      case AffordabilityStatus.yellow:
        statusColor = Colors.amber;
        break;
      case AffordabilityStatus.red:
        statusColor = Colors.red;
        break;
    }

    final currencyFormatter = NumberFormat.currency(
      symbol: 'EGP ',
      decimalDigits: 0,
    );
    return CardPopIn(
      id: 'home-kpi-cards',
      builder: (context, animate) => AnimatedSize(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutQuart,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total payment this month',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ).popInIf(animate, 0),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormatter.format(monthPayment),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ).popInIf(animate, 1),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          nextInstallmentSubtitle,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ).popInIf(animate, 2),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Outstanding Debt',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ).popInIf(animate, 0),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormatter.format(outstanding),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ).popInIf(animate, 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 16,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Across $activeCount active installments',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ).popInIf(animate, 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Debt-Free Milestone Card
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // Urgent Warning Helper
  // ---------------------------------------------------------------------------
  Widget _buildUrgentWarning(UserAccount user, bool isLongTerm) {
    List<Installment> activeInstallments =
        (user.installments?.toList() ?? <Installment>[])
            .where(
              (inst) =>
                  inst.paidMonths < inst.totalMonths &&
                  inst.statusEnum != InstallmentStatus.paid &&
                  inst.isLongTerm == isLongTerm,
            )
            .toList();

    if (activeInstallments.isEmpty) return const SizedBox.shrink();

    activeInstallments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    Installment nextInst = activeInstallments.first;

    PenaltyResult pr = PenaltyEngine.calculateLateFees(nextInst);
    final currencyFormatter = NumberFormat.currency(
      symbol: 'EGP ',
      decimalDigits: 0,
    );

    DateTime now = TimeService.now();
    DateTime justDate = DateTime(now.year, now.month, now.day);
    DateTime dueDateJustDate = DateTime(
      nextInst.dueDate.year,
      nextInst.dueDate.month,
      nextInst.dueDate.day,
    );

    int daysLate = justDate.difference(dueDateJustDate).inDays;
    int daysUntilDue = dueDateJustDate.difference(justDate).inDays;

    double displayAmountDue;
    if (pr.isAccelerated) {
      displayAmountDue =
          ((nextInst.totalMonths - nextInst.paidMonths) *
              nextInst.monthlyPayment) +
          pr.lateFee;
    } else if (pr.lateFee > 0 || daysLate > 0) {
      displayAmountDue =
          (nextInst.monthlyPayment *
              PenaltyEngine.calculateMissedMonths(nextInst)) +
          pr.lateFee;
    } else {
      displayAmountDue = nextInst.monthlyPayment;
    }

    String amountStr = currencyFormatter.format(displayAmountDue);
    String itemDetails = "${nextInst.provider} (${nextInst.itemDescription})";

    String warningText = '';
    Color bgColor = Colors.transparent;
    Color textColor = Colors.transparent;
    IconData iconData = Icons.warning;

    if (pr.isAccelerated) {
      warningText =
          '🚨 DEFAULT: Entire balance of $amountStr is due for $itemDetails!';
      bgColor = const Color(0xFFFFF0F0);
      textColor = Colors.red[800]!;
      iconData = Icons.error_outline;
    } else if (daysLate > 0) {
      warningText =
          '🚨 Payment is late. Please contact your lender for late fees details.';
      bgColor = const Color(0xFFFFF0F0);
      textColor = Colors.red[800]!;
      iconData = Icons.warning_amber_rounded;
    } else if (daysUntilDue >= 0 && daysUntilDue <= 3) {
      String timeStr = (daysUntilDue == 0) ? "Today" : "in $daysUntilDue days";
      warningText = '⚠️ Due $timeStr for $itemDetails! Pay $amountStr';
      bgColor = const Color(0xFFFFFBE6);
      textColor = Colors.orange[800]!;
      iconData = Icons.access_time_rounded;
    } else {
      return const SizedBox.shrink(); // Only show if urgent
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconData, color: textColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                warningText,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtFreeSubCard(
    UserAccount user, {
    required bool isLongTerm,
    required String titlePrefix,
  }) {
    final List<Installment> active = (user.installments?.toList() ?? [])
        .where(
          (i) =>
              i.statusEnum != InstallmentStatus.paid &&
              i.isLongTerm == isLongTerm,
        )
        .toList();

    final DateTime debtFreeDate = AffordabilityEngine.getAbsoluteDebtFreeDate(
      active,
    );
    final DateTime now = TimeService.now();
    final bool isDebtFree = active.isEmpty;

    String title;
    String subtitle;
    Color bgColor;
    Color textColor;

    if (isDebtFree) {
      title =
          '🎉 No active ${isLongTerm ? 'long-term assets' : 'retail debt'}!';
      subtitle =
          'All ${isLongTerm ? 'assets' : 'retail items'} are fully paid. Keep it up!';
      bgColor = const Color(0xFFF0FAF0);
      textColor = Colors.green[800]!;
    } else {
      final String formatted = DateFormat('MMMM yyyy').format(debtFreeDate);
      final int totalMonths =
          ((debtFreeDate.year - now.year) * 12) +
          debtFreeDate.month -
          now.month;
      final String timeAway = totalMonths <= 0
          ? 'this month'
          : '$totalMonths month${totalMonths == 1 ? '' : 's'} away';
      title = '🏁 $titlePrefix in $formatted';
      subtitle =
          'You will finish all ${isLongTerm ? 'assets' : 'retail installments'} in $formatted ($timeAway).';
      bgColor = const Color(0xFFF0F4FF);
      textColor = const Color(0xFF1E3A8A);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: textColor.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // What-If Sandbox Simulator Card
  // ---------------------------------------------------------------------------
  Widget _buildSandboxCard(UserAccount user) {
    final format = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final SimulatedOutlook? outlook = _simulatedOutlook;

    return CardPopIn(
      id: 'checkout-advisor-card',
      builder: (context, animate) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calculate_outlined,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checkout Advisor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Plan a hypothetical purchase',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ).popInIf(animate, 0),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Item Cost',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _whatIfCostController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0.0',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
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
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Down Pmt',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _whatIfDownPaymentController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '0.0',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
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
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Months',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _whatIfMonthsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '12',
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
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
                            borderSide: const BorderSide(
                              color: Color(0xFF6366F1),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (outlook != null) ...[
              Builder(
                builder: (context) {
                  Color bgColor;
                  Color borderColor;
                  Color iconColor;
                  IconData iconData;
                  String titleText;
                  String adviceText;

                  switch (outlook.riskTier) {
                    case RiskTier.safe:
                      bgColor = const Color(0xFFF0FAF0);
                      borderColor = Colors.green.withValues(alpha: 0.25);
                      iconColor = Colors.green[700]!;
                      iconData = Icons.check_circle_outline;
                      titleText = 'Affordable';
                      adviceText =
                          'You\'ll still have EGP ${format.format(outlook.newSafeBuffer)} available every month. Debt finishes in ${DateFormat('MMM yyyy').format(outlook.newDebtFreeDate)}.';
                      break;
                    case RiskTier.stretch:
                      bgColor = const Color(0xFFFFF7E6);
                      borderColor = Colors.orange.withValues(alpha: 0.25);
                      iconColor = Colors.orange[800]!;
                      iconData = Icons.warning_amber_rounded;
                      titleText = 'Possible, but tight';
                      adviceText =
                          'This consumes ${(outlook.foir * 100).toStringAsFixed(0)}% of your income. You\'ll only have EGP ${format.format(outlook.newSafeBuffer)} left.';
                      break;
                    case RiskTier.danger:
                      bgColor = const Color(0xFFFFF5F5);
                      borderColor = Colors.red.withValues(alpha: 0.25);
                      iconColor = Colors.red[700]!;
                      iconData = Icons.error_outline;
                      titleText = 'Not Recommended';
                      adviceText =
                          'This pushes your obligations to ${(outlook.foir * 100).toStringAsFixed(0)}% of your income, exceeding safe limits.';
                      break;
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(iconData, color: iconColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  titleText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: iconColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              adviceText,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[800],
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _resultRow(
                              'Monthly obligations',
                              format.format(outlook.newMonthlyObligation),
                              outlook.riskTier == RiskTier.danger
                                  ? Colors.red[700]!
                                  : Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ] else ...[
              const SizedBox(height: 16),
              Text(
                'Enter an item cost and number of months above to simulate how a new purchase would affect your budget.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInstallmentsList(
    HiveList<Installment>? installments,
    bool isLongTerm,
  ) {
    if (installments == null || installments.isEmpty) {
      return const Text(
        "No active installments",
        style: TextStyle(color: Colors.grey),
      );
    }

    // Filter active installments
    final activeList = installments
        .where(
          (inst) =>
              inst.statusEnum != InstallmentStatus.paid &&
              inst.isLongTerm == isLongTerm,
        )
        .toList();

    if (activeList.isEmpty) {
      return const Text(
        "No active installments",
        style: TextStyle(color: Colors.grey),
      );
    }

    // Sort based on selection
    activeList.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.merchantName.toLowerCase().compareTo(
            b.merchantName.toLowerCase(),
          );
        case 'total debt':
          double debtA =
              ((a.totalMonths - a.paidMonths) * a.monthlyPayment) +
              PenaltyEngine.calculateLateFees(a).lateFee;
          double debtB =
              ((b.totalMonths - b.paidMonths) * b.monthlyPayment) +
              PenaltyEngine.calculateLateFees(b).lateFee;
          return debtB.compareTo(debtA);
        case 'installment debt':
          return b.monthlyPayment.compareTo(a.monthlyPayment);
        case 'installment duration':
          return b.totalMonths.compareTo(a.totalMonths);
        case 'urgency':
        default:
          return a.dueDate.compareTo(b.dueDate);
      }
    });

    final currencyFormatter = NumberFormat.currency(
      symbol: 'EGP ',
      decimalDigits: 0,
    );

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activeList.length,
      itemBuilder: (context, index) {
        var inst = activeList[index];

        DateTime now = TimeService.now();
        DateTime justDate = DateTime(now.year, now.month, now.day);
        DateTime dueDateJustDate = DateTime(
          inst.dueDate.year,
          inst.dueDate.month,
          inst.dueDate.day,
        );
        int daysToDue = dueDateJustDate.difference(justDate).inDays;

        bool isOverdue =
            inst.statusEnum != InstallmentStatus.paid && daysToDue < 0;

        PenaltyResult penaltyResult = PenaltyEngine.calculateLateFees(inst);
        bool isAccelerated = penaltyResult.isAccelerated;
        int remainingPeriods = inst.totalPayments - inst.paidPayments;

        double displayAmountDue;

        // --- Header: total accumulated debt (what the user owes in full) ---
        int periodsOwed;
        if (!isOverdue) {
          periodsOwed = 1; // upcoming or on-time: show current active period
        } else {
          periodsOwed = PenaltyEngine.calculateUncappedMissedPeriods(inst);
          if (periodsOwed > remainingPeriods) {
            periodsOwed = remainingPeriods; // cap at remaining
          }
        }

        if (isAccelerated) {
          displayAmountDue = (remainingPeriods * inst.monthlyPayment);
        } else {
          displayAmountDue = (inst.monthlyPayment * periodsOwed);
        }

        // --- Button: immediate transaction cost (1 period for informal, arrears for commercial) ---
        int regularPeriodsToPay = PenaltyEngine.calculateActualPeriodsToPay(
          inst,
        );
        if (inst.paidPayments + regularPeriodsToPay > inst.totalPayments) {
          regularPeriodsToPay = inst.totalPayments - inst.paidPayments;
        }
        double regularTransactionCost =
            (inst.monthlyPayment * regularPeriodsToPay);

        int fullPeriodsToPay = inst.totalPayments - inst.paidPayments;
        double fullTransactionCost = (inst.monthlyPayment * fullPeriodsToPay);

        int visualRedSegments = 0;
        if (isOverdue) {
          visualRedSegments = PenaltyEngine.calculateUncappedMissedPeriods(
            inst,
          );
        }
        visualRedSegments = visualRedSegments > remainingPeriods
            ? remainingPeriods
            : visualRedSegments;

        String dueText;
        if (isAccelerated) {
          dueText = '⚠️ DEFAULT STATUS: ENTIRE BALANCE DUE';
        } else {
          dueText = TimeService.formatDueDate(daysToDue);
        }

        return CardPopIn(
          id: inst.id,
          builder: (context, animate) => AnimatedSize(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutQuart,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        InstallmentDetailsScreen(installment: inst),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOverdue ? Colors.red : Colors.grey[200]!,
                    width: isOverdue ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Tier 0: store name (animates first) ──────
                              Text(
                                inst.merchantName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ).popInIf(animate, 0),
                              // ── Tier 1: lender chip & details ────────────
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (inst.provider != 'Other / Custom')
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${inst.provider} Details',
                                        style: TextStyle(
                                          color: Colors.blue[800],
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (inst.itemDescription.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        inst.itemDescription,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isOverdue)
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.red,
                                          size: 16,
                                        ),
                                      if (isOverdue) const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          isOverdue
                                              ? 'Overdue by ${-daysToDue} days • Please contact your lender for late fees details.'
                                              : dueText,
                                          style: TextStyle(
                                            color: isOverdue
                                                ? Colors.red[700]
                                                : Colors.grey[700],
                                            fontSize: 13,
                                            fontWeight: isOverdue
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          softWrap: isOverdue,
                                          overflow: isOverdue
                                              ? TextOverflow.visible
                                              : TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ).popInIf(animate, 1),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Crossed out old price is removed since there are no calculated late fees.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  currencyFormatter.format(displayAmountDue),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isOverdue
                                        ? Colors.red
                                        : Colors.black,
                                  ),
                                ),
                              ).popInIf(animate, 0),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Tier 2: progress bar (200ms later) ──────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${inst.paidPayments} of ${inst.totalPayments} paid',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (inst.totalPayments <= 20)
                          Row(
                            children: List.generate(inst.totalPayments, (
                              index,
                            ) {
                              int paidSegments = inst.paidPayments;
                              int totalSegments = inst.totalPayments;
                              int redSegments = 0;

                              if (isAccelerated) {
                                redSegments = totalSegments - paidSegments;
                              } else {
                                redSegments = visualRedSegments;
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
                              value: inst.totalPayments > 0
                                  ? inst.paidPayments / inst.totalPayments
                                  : 0.0,
                              backgroundColor: Colors.grey[200],
                              color: Theme.of(context).primaryColor,
                              minHeight: 8,
                            ),
                          ),
                      ],
                    ).popInIf(animate, 2),
                    if (inst.statusEnum != InstallmentStatus.paid) ...[
                      const SizedBox(height: 16),
                      // ── Tier 2: pay button (same 200ms tier as progress) ──
                      (() {
                        Future<void> pay(int periodsToPay) async {
                          if (inst.paidPayments < inst.totalPayments) {
                            double evenlyDistributedPenalty = 0.0;

                            for (int i = 0; i < periodsToPay; i++) {
                              inst.pastPayments = List.from(inst.pastPayments)
                                ..add(
                                  inst.monthlyPayment +
                                      evenlyDistributedPenalty,
                                );
                            }

                            int monthsToAdvance =
                                periodsToPay * inst.monthsPerPayment;
                            inst.paidMonths += monthsToAdvance;
                            inst.dueDate = DateTime(
                              inst.dueDate.year,
                              inst.dueDate.month + monthsToAdvance,
                              inst.dueDate.day,
                            );

                            if (inst.paidPayments >= inst.totalPayments) {
                              inst.statusEnum = InstallmentStatus.paid;
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Installment fully paid! Moved to History tab. 🎉',
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else if (inst.statusEnum ==
                                    InstallmentStatus.overdue &&
                                inst.dueDate.isAfter(TimeService.now())) {
                              inst.statusEnum = InstallmentStatus.active;
                            }
                            inst.lastPaidAt =
                                TimeService.now(); // stamp payment time for billing cycle tracking
                            await inst.save();
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
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
                                              : 'Mark ${inst.paymentFrequency == 'Monthly'
                                                    ? 'Month'
                                                    : inst.paymentFrequency == 'Quarterly'
                                                    ? 'Quarter'
                                                    : inst.paymentFrequency == 'Semi-Annually'
                                                    ? 'Half-Year'
                                                    : 'Year'} as Paid\n',
                                        ),
                                        TextSpan(
                                          text:
                                              '(${currencyFormatter.format(regularTransactionCost)})',
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => pay(fullPeriodsToPay),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
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
                                        const TextSpan(
                                          text: 'Settle Full Debt\n',
                                        ),
                                        TextSpan(
                                          text:
                                              '(${currencyFormatter.format(fullTransactionCost)})',
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
                                          : 'Mark ${inst.paymentFrequency == 'Monthly'
                                                ? 'Month'
                                                : inst.paymentFrequency == 'Quarterly'
                                                ? 'Quarter'
                                                : inst.paymentFrequency == 'Semi-Annually'
                                                ? 'Half-Year'
                                                : 'Year'} as Paid\n',
                                    ),
                                    TextSpan(
                                      text:
                                          '(${currencyFormatter.format(regularTransactionCost)})',
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
                      })().popInIf(animate, 2),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
