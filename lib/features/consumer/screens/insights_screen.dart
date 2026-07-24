import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/engine/affordability_live.dart';
import '../../../widgets/branded_bar_chart_card.dart';
import 'package:qistiraha/core/utils/card_entrance_animation.dart';

// ---------------------------------------------------------------------------
// Budget Status helper — evaluated once, consumed by both cards
// ---------------------------------------------------------------------------

class _BudgetStatus {
  final String label; // e.g. "Safe-to-Spend"
  final Color tierColor; // dominant accent color
  final Color bgColor; // light tint for card backgrounds
  final String tierName; // e.g. "Optimized"

  const _BudgetStatus({
    required this.label,
    required this.tierColor,
    required this.bgColor,
    required this.tierName,
  });
}

/// Pure function — no state, fully testable.
/// [pct] is the raw ratio (0.0 – 1.0+), NOT a percentage.
_BudgetStatus _getBudgetStatus(double pct) {
  if (pct <= 0.30) {
    return const _BudgetStatus(
      label: 'Safe-to-Spend',
      tierColor: Color(0xFF2ECC71),
      bgColor: Color(0xFFF0FDF4),
      tierName: 'Optimized',
    );
  } else if (pct <= 0.50) {
    return const _BudgetStatus(
      label: 'Watch-Your-Spend',
      tierColor: Color(0xFFE67E22),
      bgColor: Color(0xFFFFF8F0),
      tierName: 'Mindful',
    );
  } else {
    return const _BudgetStatus(
      label: 'Limit-Your-Spend',
      tierColor: Color(0xFFE74C3C),
      bgColor: Color(0xFFFFF0F0),
      tierName: 'Critical',
    );
  }
}

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _chartFilter = 'All';

  double _income = 0;
  int _salaryDay = 1;
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await DatabaseService.profileFinance();
    if (!mounted) return;
    setState(() {
      _income = p.monthlyIncome;
      _salaryDay = p.salaryDay;
      _profileLoaded = true;
    });
  }

  Future<void> _editIncome() async {
    final controller = TextEditingController(
      text: _income > 0 ? _income.toStringAsFixed(0) : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monthly Income'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(prefixText: 'EGP ', hintText: '0'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await DatabaseService.updateIncome(result, salaryDay: _salaryDay);
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: const Text(
          'Qist List Insights',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<InstallmentRow>>(
        stream: DatabaseService.consumerInstallments(),
        builder: (context, snapshot) {
          if (!_profileLoaded ||
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final installments = snapshot.data ?? const <InstallmentRow>[];
          if (installments.isEmpty) {
            return const Center(child: Text("No Data for Insights"));
          }

          // Calculate category distribution
          Map<String, double> shortTermTotals = {};
          Map<String, double> longTermTotals = {};
          double shortTermDebt = 0;
          double longTermDebt = 0;

          for (var inst in installments) {
            if (!inst.isCompleted) {
              double drain = inst.monthlyPayment;
              if (inst.paymentFrequency == 'Quarterly') {
                drain /= 3;
              } else if (inst.paymentFrequency == 'Annually') {
                drain /= 12;
              } else if (inst.paymentFrequency == 'Semi-Annually') {
                drain /= 6;
              }

              if (inst.isLongTerm) {
                longTermTotals[inst.category] =
                    (longTermTotals[inst.category] ?? 0) + drain;
                longTermDebt += drain;
              } else {
                shortTermTotals[inst.category] =
                    (shortTermTotals[inst.category] ?? 0) + drain;
                shortTermDebt += drain;
              }
            }
          }

          // Dynamic scaling logic
          int stepSize = 1;
          int numBuckets = 6;

          if (_chartFilter == 'Quarterly') {
            stepSize = 3;
            numBuckets = 4;
          } else if (_chartFilter == 'Semi-Annually') {
            stepSize = 6;
            numBuckets = 4;
          } else if (_chartFilter == 'Annually') {
            stepSize = 12;
            numBuckets = 4;
          }

          DateTime now = TimeService.now();
          List<String> labels = [];

          for (int i = 0; i < numBuckets; i++) {
            if (i == 0 && _chartFilter == 'All') {
              labels.add('Now');
            } else {
              DateTime mDate = DateTime(
                now.year,
                now.month + (i * stepSize),
                1,
              );
              if (_chartFilter == 'Annually') {
                labels.add(DateFormat('yyyy').format(mDate));
              } else if (_chartFilter == 'Quarterly' ||
                  _chartFilter == 'Semi-Annually') {
                DateTime endDate = DateTime(
                  now.year,
                  now.month + (i * stepSize) + stepSize - 1,
                  1,
                );
                String startStr = DateFormat('MMM').format(mDate);
                String endStr = DateFormat('MMM').format(endDate);
                labels.add('$startStr-$endStr');
              } else {
                labels.add(DateFormat('MMM').format(mDate));
              }
            }
          }

          List<double> buckets = List.filled(numBuckets, 0.0);

          for (var inst in installments) {
            if (inst.isCompleted) continue;

            // No penalties/acceleration: simply project each remaining
            // payment forward from its due date by the plan's frequency step.
            int paymentsAdded = 0;
            int remainingPayments = inst.totalPayments - inst.paidPayments;
            DateTime projectedDate = inst.dueDate;

            while (paymentsAdded < remainingPayments) {
              int monthsDiff =
                  ((projectedDate.year - now.year) * 12) +
                  projectedDate.month -
                  now.month;

              int bucketIndex = monthsDiff ~/ stepSize;
              if (bucketIndex >= numBuckets) {
                break; // Past our dynamic window
              }

              if (bucketIndex >= 0) {
                buckets[bucketIndex] += inst.monthlyPayment;
              }

              projectedDate = DateTime(
                projectedDate.year,
                projectedDate.month + inst.monthsPerPayment,
                projectedDate.day,
              );
              paymentsAdded++;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Review your payment forecasts and debt distribution.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 24),

                // ── Affordability Advisor Card ─────────────────────────────
                _buildAdvisorCard(installments),

                const SizedBox(height: 24),
                CardPopIn(
                  id: 'cash-flow-health-card',
                  builder: (context, animate) => Container(
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
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Cash Flow Health',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'This month\'s income vs obligations',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: _editIncome,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ).popInIf(animate, 0),
                        const SizedBox(height: 24),
                        Builder(
                          builder: (context) {
                            final DateTime now = TimeService.now();
                            final DateRange cycle =
                                LiveAffordabilityEngine.currentBillingCycle(
                                  _salaryDay,
                                  now,
                                );
                            final double owed =
                                LiveAffordabilityEngine.owedInCycle(
                                  installments,
                                  cycle,
                                );
                            final double paid =
                                LiveAffordabilityEngine.paidInCycle(
                                  installments,
                                  cycle,
                                );
                            final double totalCommitted = owed + paid;
                            final double income = _income;
                            final double available =
                                LiveAffordabilityEngine.safeToSpend(
                                  installments,
                                  income,
                                  _salaryDay,
                                );
                            final double percentage = income > 0
                                ? (totalCommitted / income)
                                : 0;

                            // ── Tier evaluation ─────────────────────────────
                            final _BudgetStatus status = _getBudgetStatus(
                              percentage,
                            );
                            final Color barColor = status.tierColor;

                            final format = NumberFormat.currency(
                              symbol: 'EGP ',
                              decimalDigits: 0,
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Available Cash',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          format.format(available),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Total Income',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          format.format(income),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage.clamp(0.0, 1.0),
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      barColor,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${status.tierName} · ${(percentage * 100).toStringAsFixed(0)}% Consumed',
                                      style: TextStyle(
                                        color: barColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${format.format(totalCommitted)} Committed',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ).popInIf(animate, 1);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Quarterly', 'Semi-Annually', 'Annually']
                        .map((filter) {
                          final isSelected = _chartFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(
                                filter,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                setState(() {
                                  _chartFilter = filter;
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: const Color(0xFF6366F1),
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : Colors.grey[300]!,
                                ),
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // Bar Chart Section
                BrandedBarChartCard(
                  title: _chartFilter == 'All'
                      ? 'All Payments'
                      : 'Grouped $_chartFilter',
                  subtitle: _chartFilter == 'All'
                      ? 'Your upcoming half-year'
                      : 'Your upcoming projected timeline',
                  buckets: buckets,
                  labels: labels,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: Colors.black54),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your payment forecast is dynamically calculated from your active installments.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Donut Chart Sections
                if (shortTermTotals.isNotEmpty) ...[
                  _buildDonutChart(
                    'Retail Cash Flow',
                    'Based on active short-term obligations',
                    shortTermTotals,
                    shortTermDebt,
                  ),
                  const SizedBox(height: 24),
                ],
                if (longTermTotals.isNotEmpty) ...[
                  _buildDonutChart(
                    'Asset Cash Flow',
                    'Based on active long-term assets',
                    longTermTotals,
                    longTermDebt,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Donut Chart Widget Helper
  // ---------------------------------------------------------------------------
  Widget _buildDonutChart(
    String title,
    String subtitle,
    Map<String, double> categoryTotals,
    double totalDebt,
  ) {
    List<PieChartSectionData> pieSections = [];
    List<Widget> legendItems = [];

    List<Color> colors = [
      Colors.blue,
      Colors.purple,
      Colors.redAccent,
      Colors.green,
      Colors.orange,
    ];
    int cIdx = 0;

    categoryTotals.forEach((category, amount) {
      double percentage = (amount / totalDebt) * 100;
      Color color = colors[cIdx % colors.length];
      pieSections.add(
        PieChartSectionData(
          color: color,
          value: percentage,
          title: '',
          radius: 40,
        ),
      );

      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text('${percentage.toStringAsFixed(0)}%'),
            ],
          ),
        ),
      );
      cIdx++;
    });

    return CardPopIn(
      id: 'donut-chart-$title',
      builder: (context, animate) => Container(
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
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pie_chart_outline,
                    color: Colors.blue,
                  ),
                ),
              ],
            ).popInIf(animate, 0),
            const SizedBox(height: 32),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 60,
                      sections: pieSections,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${categoryTotals.keys.length}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Categories',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ).popInIf(animate, 1),
            const SizedBox(height: 32),
            Column(children: legendItems).popInIf(animate, 2),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Affordability Advisor card
  // ---------------------------------------------------------------------------
  Widget _buildAdvisorCard(List<InstallmentRow> installments) {
    final format = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final DateTime now = TimeService.now();
    final DateRange cycle = LiveAffordabilityEngine.currentBillingCycle(
      _salaryDay,
      now,
    );

    // Real-time safe-to-spend (resets on incomeDepositDay automatically)
    final double safeToSpend = LiveAffordabilityEngine.safeToSpend(
      installments,
      _income,
      _salaryDay,
    );

    // Breakdown for the detail line
    final double owed = LiveAffordabilityEngine.owedInCycle(
      installments,
      cycle,
    );
    final double paid = LiveAffordabilityEngine.paidInCycle(
      installments,
      cycle,
    );
    final double usedPct = _income > 0 ? ((owed + paid) / _income) * 100 : 0;

    // ── Tier evaluation (drives both color and copywriting) ────────────────
    final double pct = _income > 0 ? (owed + paid) / _income : 0.0;
    final _BudgetStatus status = _getBudgetStatus(pct);

    // Emergency override: if safeToSpend goes negative, escalate to critical
    final bool isOverBudget = safeToSpend < 0;
    final Color accentColor = isOverBudget
        ? const Color(0xFFE74C3C)
        : status.tierColor;
    final Color cardBg = isOverBudget
        ? const Color(0xFFFFF0F0)
        : status.bgColor;
    final IconData icon = isOverBudget
        ? Icons.warning_amber_rounded
        : Icons.account_balance_wallet_outlined;

    final String cycleLabel =
        '${DateFormat.MMMd().format(cycle.start)} – ${DateFormat.MMMd().format(cycle.end)}';

    final String headline;
    final String detail;

    if (isOverBudget) {
      headline =
          '🚨 Over Budget by ${format.format(safeToSpend.abs())} this cycle!';
      detail =
          'Cycle: $cycleLabel\n'
          '${format.format(owed)} still owed  •  ${format.format(paid)} already paid\n'
          'Your installment obligations exceed your income for this cycle. Avoid new purchases.';
    } else {
      headline =
          '💳 ${status.label}: ${format.format(safeToSpend)} remaining this cycle';
      detail =
          'Cycle: $cycleLabel  ·  ${status.tierName}\n'
          '${format.format(owed)} still owed  •  ${format.format(paid)} already paid\n'
          '${usedPct.toStringAsFixed(0)}% of your income is committed to installments.';
    }

    return CardPopIn(
      id: 'advisor-card',
      builder: (context, animate) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 28).popInIf(animate, 0),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                ],
              ).popInIf(animate, 1),
            ),
          ],
        ),
      ),
    );
  }
}
