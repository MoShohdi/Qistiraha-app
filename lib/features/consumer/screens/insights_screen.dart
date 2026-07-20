import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:qistiraha/features/auth/models/user_account.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/engine/affordability_engine.dart';
import 'package:qistiraha/core/engine/penalty_engine.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import '../../../widgets/income_edit_bottom_sheet.dart';

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
      body: ValueListenableBuilder(
        valueListenable: HiveService.getUserBox().listenable(),
        builder: (context, Box<UserAccount> box, _) {
          if (box.isEmpty || box.values.first.installments == null) {
            return const Center(child: Text("No Data for Insights"));
          }

          UserAccount user = box.values.first;
          var installments = user.installments!;

          // Calculate category distribution
          Map<String, double> shortTermTotals = {};
          Map<String, double> longTermTotals = {};
          double shortTermDebt = 0;
          double longTermDebt = 0;

          for (var inst in installments) {
            if (inst.statusEnum != InstallmentStatus.paid) {
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

          List<BarChartGroupData> barGroups = [];
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

          Color colorDefault = Colors.red;
          Color colorDueNow = const Color(0xFF2E65F3);
          Color colorFuture = Colors.grey[300]!;

          List<double> buckets = List.filled(numBuckets, 0.0);
          List<List<BarChartRodStackItem>> stackItemsByMonth = List.generate(
            numBuckets,
            (_) => [],
          );

          for (var inst in installments) {
            if (inst.statusEnum != InstallmentStatus.paid) {
              PenaltyResult pr = PenaltyEngine.calculateLateFees(inst);

              if (pr.isAccelerated) {
                int remaining = inst.totalPayments - inst.paidPayments;
                double amount = (remaining * inst.monthlyPayment) + pr.lateFee;
                if (amount > 0) {
                  stackItemsByMonth[0].add(
                    BarChartRodStackItem(
                      buckets[0],
                      buckets[0] + amount,
                      colorDefault,
                    ),
                  );
                  buckets[0] += amount;
                }
              } else {
                int missed = PenaltyEngine.calculateUncappedMissedPeriods(inst);
                if (missed > 0) {
                  double amount = (missed * inst.monthlyPayment) + pr.lateFee;
                  stackItemsByMonth[0].add(
                    BarChartRodStackItem(
                      buckets[0],
                      buckets[0] + amount,
                      colorDefault,
                    ),
                  );
                  buckets[0] += amount;
                }

                int paymentsAdded = 0;
                int remainingPayments = inst.totalPayments - inst.paidPayments;
                DateTime projectedDate = inst.dueDate;

                // If we missed payments, the next future payment is shifted forward
                if (missed > 0) {
                  int monthsToAdvance = missed * inst.monthsPerPayment;
                  projectedDate = DateTime(
                    projectedDate.year,
                    projectedDate.month + monthsToAdvance,
                    projectedDate.day,
                  );
                }

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
                    if (monthsDiff == 0 && missed == 0) {
                      stackItemsByMonth[bucketIndex].add(
                        BarChartRodStackItem(
                          buckets[bucketIndex],
                          buckets[bucketIndex] + inst.monthlyPayment,
                          colorDueNow,
                        ),
                      );
                      buckets[bucketIndex] += inst.monthlyPayment;
                    } else if (monthsDiff > 0) {
                      stackItemsByMonth[bucketIndex].add(
                        BarChartRodStackItem(
                          buckets[bucketIndex],
                          buckets[bucketIndex] + inst.monthlyPayment,
                          colorFuture,
                        ),
                      );
                      buckets[bucketIndex] += inst.monthlyPayment;
                    }
                  }

                  projectedDate = DateTime(
                    projectedDate.year,
                    projectedDate.month + inst.monthsPerPayment,
                    projectedDate.day,
                  );
                  paymentsAdded++;
                }
              }
            }
          }

          final double maxBucket = buckets.isEmpty
              ? 0.0
              : buckets.reduce((curr, next) => curr > next ? curr : next);
          final double chartMaxY = maxBucket > 0 ? maxBucket * 1.2 : 10000;

          for (int i = 0; i < numBuckets; i++) {
            barGroups.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: buckets[i],
                    width: 32,
                    borderRadius: BorderRadius.circular(6),
                    rodStackItems: stackItemsByMonth[i],
                    color: Colors.transparent, // stack items provide colors
                  ),
                ],
              ),
            );
          }

          Widget buildLegendItem(Color color, String text) {
            return Padding(
              padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            );
          }

          List<Widget> barLegendItems = [
            buildLegendItem(colorDefault, 'Arrears / Default'),
            buildLegendItem(colorDueNow, 'Due Now'),
            buildLegendItem(colorFuture, 'Future Forecast'),
          ];

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
                _buildAdvisorCard(user, installments.toList()),

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
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) =>
                                    const IncomeEditBottomSheet(),
                              );
                            },
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
                      ),
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          final DateTime now = TimeService.now();
                          final DateRange cycle =
                              AffordabilityEngine.getCurrentBillingCycle(
                                user.salaryDay,
                                now,
                              );
                          final double owed =
                              AffordabilityEngine.getOwedInCycle(
                                installments.toList(),
                                cycle,
                              );
                          final double paid =
                              AffordabilityEngine.getPaidInCycle(
                                installments.toList(),
                                cycle,
                              );
                          final double totalCommitted = owed + paid;
                          final double income = user.monthlyIncome;
                          final double available =
                              AffordabilityEngine.calculateSafeToSpend(
                                installments.toList(),
                                income,
                                user.salaryDay,
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
                                    crossAxisAlignment: CrossAxisAlignment.end,
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
                          );
                        },
                      ),
                    ],
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _chartFilter == 'All'
                                    ? 'All Payments'
                                    : 'Grouped $_chartFilter',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _chartFilter == 'All'
                                    ? 'Your upcoming half-year'
                                    : 'Your upcoming projected timeline',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
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
                              Icons.bar_chart,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: chartMaxY,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                      Map<String, double> sums = {};
                                      for (var item in rod.rodStackItems) {
                                        String status = 'Payment';
                                        if (item.color == Colors.red) {
                                          status = 'Overdue/Default';
                                        } else if (item.color ==
                                            const Color(0xFF2E65F3)) {
                                          status = 'Current Due';
                                        } else {
                                          status = 'Scheduled';
                                        }

                                        sums[status] =
                                            (sums[status] ?? 0) +
                                            (item.toY - item.fromY);
                                      }

                                      String tooltipText = '';
                                      sums.forEach((key, val) {
                                        tooltipText +=
                                            '$key: ${val.toStringAsFixed(0)}\n';
                                      });

                                      if (tooltipText.isNotEmpty) {
                                        tooltipText = tooltipText.substring(
                                          0,
                                          tooltipText.length - 1,
                                        );
                                      } else {
                                        tooltipText = rod.toY.toStringAsFixed(
                                          0,
                                        );
                                      }
                                      return BarTooltipItem(
                                        tooltipText,
                                        const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget:
                                      (double value, TitleMeta meta) {
                                        if (value.toInt() >= labels.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return SideTitleWidget(
                                          axisSide: meta.axisSide,
                                          child: Text(
                                            labels[value.toInt()],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.normal,
                                              fontSize: 12,
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 44,
                                  interval: chartMaxY / 5,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    String text;
                                    if (value == 0) {
                                      text = '0';
                                    } else if (value >= 1000000) {
                                      text =
                                          '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
                                    } else if (value >= 1000) {
                                      text =
                                          '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
                                    } else {
                                      text = value.toStringAsFixed(0);
                                    }
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        text,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: chartMaxY / 5,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.grey[200],
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: barGroups,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(children: barLegendItems),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.black54,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your payment forecast is dynamically calculated from your active installments.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
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

    return Container(
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
                child: const Icon(Icons.pie_chart_outline, color: Colors.blue),
              ),
            ],
          ),
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
          ),
          const SizedBox(height: 32),
          Column(children: legendItems),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Affordability Advisor card
  // ---------------------------------------------------------------------------
  Widget _buildAdvisorCard(UserAccount user, List<Installment> installments) {
    final format = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    final DateTime now = TimeService.now();
    final DateRange cycle = AffordabilityEngine.getCurrentBillingCycle(
      user.salaryDay,
      now,
    );

    // Real-time safe-to-spend (resets on incomeDepositDay automatically)
    final double safeToSpend = AffordabilityEngine.calculateSafeToSpend(
      installments,
      user.monthlyIncome,
      user.salaryDay,
    );

    // Breakdown for the detail line
    final double owed = AffordabilityEngine.getOwedInCycle(installments, cycle);
    final double paid = AffordabilityEngine.getPaidInCycle(installments, cycle);
    final double usedPct = user.monthlyIncome > 0
        ? ((owed + paid) / user.monthlyIncome) * 100
        : 0;

    // ── Tier evaluation (drives both color and copywriting) ────────────────
    final double pct = user.monthlyIncome > 0
        ? (owed + paid) / user.monthlyIncome
        : 0.0;
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 28),
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
            ),
          ),
        ],
      ),
    );
  }
}
