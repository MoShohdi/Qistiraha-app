import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/hive_service.dart';
import '../../models/user_account.dart';
import '../../services/time_service.dart';
import '../../engine/affordability_engine.dart';
import '../../engine/penalty_engine.dart';
import '../../models/enums.dart';
import '../../widgets/income_edit_bottom_sheet.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: const Text(
          'Qist List Insights',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
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
          Map<String, double> categoryTotals = {};
          double totalDebt = 0;
          for (var inst in installments) {
            if (inst.statusEnum != InstallmentStatus.paid) {
              double remaining = (inst.totalMonths - inst.paidMonths) * inst.monthlyPayment;
              categoryTotals[inst.category] = (categoryTotals[inst.category] ?? 0) + remaining;
              totalDebt += remaining;
            }
          }

          List<PieChartSectionData> pieSections = [];
          List<Widget> legendItems = [];
          
          List<Color> colors = [Colors.blue, Colors.purple, Colors.redAccent, Colors.green];
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
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(category, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Text('${percentage.toStringAsFixed(0)}%'),
                  ],
                ),
              ),
            );
            cIdx++;
          });

          // Dynamic forecast for 6 months
          List<BarChartGroupData> barGroups = [];
          DateTime now = TimeService.now();
          List<String> months = ['Now'];
          for (int i = 1; i < 6; i++) {
            DateTime mDate = DateTime(now.year, now.month + i, 1);
            months.add(DateFormat('MMM').format(mDate));
          }

          Color colorDefault = Colors.red;
          Color colorDueNow = const Color(0xFF2E65F3);
          Color colorFuture = Colors.grey[300]!;

          double maxForecast = 0;

          for (int i = 0; i < 6; i++) {
            double currentY = 0;
            List<BarChartRodStackItem> stackItems = [];
            
            for (var inst in installments) {
              if (inst.statusEnum != InstallmentStatus.paid) {
                PenaltyResult pr = PenaltyEngine.calculateLateFees(inst);
                int remaining = inst.totalMonths - inst.paidMonths;

                if (i == 0) {
                  // The "Now" pillar
                  DateTime justDate = DateTime(now.year, now.month, now.day);
                  DateTime dueDateJustDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
                  int daysLate = justDate.difference(dueDateJustDate).inDays;

                  double amountToAdd = 0;
                  Color segColor = colorDueNow;

                  if (daysLate > 0 || pr.isAccelerated) {
                    segColor = colorDefault;
                    if (pr.isAccelerated) {
                      amountToAdd = (remaining * inst.monthlyPayment) + pr.lateFee;
                    } else {
                      amountToAdd = (inst.monthlyPayment * PenaltyEngine.calculateMissedMonths(inst)) + pr.lateFee;
                    }
                  } else if (inst.dueDate.year == now.year && inst.dueDate.month == now.month) {
                    segColor = colorDueNow;
                    amountToAdd = inst.monthlyPayment;
                  }

                  if (amountToAdd > 0) {
                    stackItems.add(BarChartRodStackItem(currentY, currentY + amountToAdd, segColor));
                    currentY += amountToAdd;
                  }
                } else {
                  // Future forecast
                  if (!pr.isAccelerated) {
                    DateTime targetMonth = DateTime(now.year, now.month + i, 1);
                    int targetAbsolute = (targetMonth.year * 12) + targetMonth.month;
                    int dueAbsolute = (inst.dueDate.year * 12) + inst.dueDate.month;
                    int maturityAbsolute = dueAbsolute + remaining - 1;

                    // Only add the base payment if the target month falls within the loan's lifespan
                    if (targetAbsolute >= dueAbsolute && targetAbsolute <= maturityAbsolute) {
                      double amount = inst.monthlyPayment;
                      stackItems.add(BarChartRodStackItem(currentY, currentY + amount, colorFuture));
                      currentY += amount;
                    }
                  }
                }
              }
            }
            
            if (currentY > maxForecast) maxForecast = currentY;

            barGroups.add(
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: currentY,
                    width: 32,
                    borderRadius: BorderRadius.circular(6),
                    rodStackItems: stackItems,
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
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
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
                
                // Income Benchmarking Section
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
                              Text('Cash Flow Health', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('This month\'s income vs obligations', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => const IncomeEditBottomSheet(),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 24),
                      Builder(
                        builder: (context) {
                          double totalPayments = AffordabilityEngine.calculateTotalMonthlyPayment(user);
                          double income = user.monthlyIncome;
                          double available = income - totalPayments;
                          double percentage = income > 0 ? (totalPayments / income) : 0;
                          
                          Color barColor = Colors.green;
                          if (percentage > 0.8) {
                            barColor = Colors.red;
                          } else if (percentage > 0.5) {
                            barColor = Colors.orange;
                          }

                          var format = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Available Cash', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      Text(format.format(available), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Total Income', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      Text(format.format(income), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              LinearProgressIndicator(
                                value: percentage,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                minHeight: 8,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${(percentage * 100).toStringAsFixed(0)}% Consumed', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text('${format.format(totalPayments)} Payments', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              )
                            ],
                          );
                        }
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
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
                            children: const [
                              Text('Monthly Payments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Your upcoming year', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.bar_chart, color: Colors.blue),
                          )
                        ],
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 200,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: maxForecast > 0 ? maxForecast * 1.2 : 100,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  Map<String, double> sums = {};
                                  for (var item in rod.rodStackItems) {
                                    String status = 'Payment';
                                    if (item.color == Colors.red) {
                                      status = 'Overdue/Default';
                                    } else if (item.color == const Color(0xFF2E65F3)) {
                                      status = 'Current Due';
                                    } else {
                                      status = 'Scheduled';
                                    }
                                    
                                    sums[status] = (sums[status] ?? 0) + (item.toY - item.fromY);
                                  }
                                  
                                  String tooltipText = '';
                                  sums.forEach((key, val) {
                                      tooltipText += '$key: ${val.toStringAsFixed(0)}\n';
                                  });
                                  
                                  if (tooltipText.isNotEmpty) {
                                    tooltipText = tooltipText.substring(0, tooltipText.length - 1);
                                  } else {
                                    tooltipText = rod.toY.toStringAsFixed(0);
                                  }
                                  return BarTooltipItem(
                                    tooltipText,
                                    const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    if (value.toInt() >= months.length) return const SizedBox.shrink();
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        months[value.toInt()],
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
                                  reservedSize: 40,
                                  getTitlesWidget: (double value, TitleMeta meta) {
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        value.toInt().toString(),
                                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                                      ),
                                    );
                                  },
                                )
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: maxForecast > 0 ? (maxForecast / 4).ceilToDouble() : 50,
                              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: barGroups,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        children: barLegendItems,
                      ),
                      const SizedBox(height: 24),
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
                            Expanded(child: Text('Your payment forecast is dynamically calculated from your active installments.', style: TextStyle(color: Colors.black54, fontSize: 12))),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Donut Chart Section
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
                              Text('Debt by Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Based on your active installments', style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.pie_chart_outline, color: Colors.blue),
                          )
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
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
                      Column(
                        children: legendItems,
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
