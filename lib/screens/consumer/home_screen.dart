import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/hive_service.dart';
import '../../models/user_account.dart';
import '../../models/installment.dart';
import '../../services/time_service.dart';
import '../../engine/penalty_engine.dart';
import '../../models/enums.dart';
import '../../engine/affordability_engine.dart';
import 'add_installment_screen.dart';
import 'installment_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _sortBy = 'urgency';

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
              AffordabilityStatus status =
                  AffordabilityEngine.calculateStatus(user);

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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                Builder(
                  builder: (context) {
                    List<Installment> activeInstallments = (user.installments?.toList() ?? <Installment>[])
                        .where((inst) => inst.paidMonths < inst.totalMonths && inst.statusEnum != InstallmentStatus.paid)
                        .toList();
                        
                    int activeCount = activeInstallments.length;
      
                    String nextInstallmentSubtitle = 'No active installments';
                    if (activeInstallments.isNotEmpty) {
                      activeInstallments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
                      Installment nextInst = activeInstallments.first;
                      
                      PenaltyResult pr = PenaltyEngine.calculateLateFees(nextInst);
                      final currencyFormatter = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
                      
                      DateTime now = TimeService.now();
                      DateTime justDate = DateTime(now.year, now.month, now.day);
                      DateTime dueDateJustDate = DateTime(nextInst.dueDate.year, nextInst.dueDate.month, nextInst.dueDate.day);
                      
                      int daysLate = justDate.difference(dueDateJustDate).inDays;
                      int daysUntilDue = dueDateJustDate.difference(justDate).inDays;

                      double displayAmountDue;
                      if (pr.isAccelerated) {
                        displayAmountDue = ((nextInst.totalMonths - nextInst.paidMonths) * nextInst.monthlyPayment) + pr.lateFee;
                      } else if (pr.lateFee > 0 || daysLate > 0) {
                        displayAmountDue = (nextInst.monthlyPayment * PenaltyEngine.calculateMissedMonths(nextInst)) + pr.lateFee;
                      } else {
                        displayAmountDue = nextInst.monthlyPayment;
                      }
                      
                      String amountStr = currencyFormatter.format(displayAmountDue);
                      String formattedDate = DateFormat.MMMd().format(nextInst.dueDate);
                      String itemDetails = "${nextInst.lender} (${nextInst.itemDescription})";

                      if (pr.isAccelerated) {
                        nextInstallmentSubtitle = '🚨 DEFAULT: Entire balance of $amountStr is due for $itemDetails!';
                      } else if (daysLate > 0) {
                        nextInstallmentSubtitle = '🚨 Overdue since $formattedDate on $itemDetails! Pay $amountStr';
                      } else if (daysUntilDue >= 0 && daysUntilDue <= 3) {
                        String timeStr = (daysUntilDue == 0) ? "Today" : "in $daysUntilDue days";
                        nextInstallmentSubtitle = '⚠️ Due $timeStr for $itemDetails! Pay $amountStr';
                      } else {
                        nextInstallmentSubtitle = '📅 Due on $formattedDate for $itemDetails - $amountStr';
                      }
                    }
                    return _buildKPICards(totalPaymentThisMonth, totalOutstanding, status, activeCount, nextInstallmentSubtitle);
                  }
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Installments',
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
                          icon: const Icon(Icons.sort, color: Colors.black, size: 20),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 'name', child: Text('Name')),
                            DropdownMenuItem(value: 'total debt', child: Text('Total Debt')),
                            DropdownMenuItem(value: 'installment debt', child: Text('Installment Debt')),
                            DropdownMenuItem(value: 'installment duration', child: Text('Duration')),
                            DropdownMenuItem(value: 'urgency', child: Text('Urgency')),
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
                                MaterialPageRoute(builder: (context) => const AddInstallmentScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInstallmentsList(user.installments),
              ],
            ),
          );
            },
          );
        },
      ),
    );
  }

  Widget _buildKPICards(double monthPayment, double outstanding, AffordabilityStatus status, int activeCount, String nextInstallmentSubtitle) {
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

    final currencyFormatter = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
    return AnimatedSize(
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
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormatter.format(monthPayment),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        nextInstallmentSubtitle,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
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
                ),
                const SizedBox(height: 8),
                Text(
                  currencyFormatter.format(outstanding),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Across $activeCount active installments',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallmentsList(HiveList<Installment>? installments) {
    if (installments == null || installments.isEmpty) {
      return const Text("No active installments");
    }

    // Filter active installments
    final activeList = installments.where((inst) => inst.statusEnum != InstallmentStatus.paid).toList();

    if (activeList.isEmpty) {
      return const Text("No active installments");
    }

    // Sort based on selection
    activeList.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a.merchantName.toLowerCase().compareTo(b.merchantName.toLowerCase());
        case 'total debt':
          double debtA = ((a.totalMonths - a.paidMonths) * a.monthlyPayment) + PenaltyEngine.calculateLateFees(a).lateFee;
          double debtB = ((b.totalMonths - b.paidMonths) * b.monthlyPayment) + PenaltyEngine.calculateLateFees(b).lateFee;
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

    final currencyFormatter = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activeList.length,
      itemBuilder: (context, index) {
        var inst = activeList[index];
        
        DateTime now = TimeService.now();
        DateTime justDate = DateTime(now.year, now.month, now.day);
        DateTime dueDateJustDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
        int daysToDue = dueDateJustDate.difference(justDate).inDays;

        bool isOverdue = inst.statusEnum != InstallmentStatus.paid && daysToDue < 0;
        PenaltyResult penaltyResult = PenaltyEngine.calculateLateFees(inst);
        double lateFee = penaltyResult.lateFee;
        bool isAccelerated = penaltyResult.isAccelerated;
        int remaining = inst.totalMonths - inst.paidMonths;
        
        double displayAmountDue;

        // --- Header: total accumulated debt (what the user owes in full) ---
        int monthsOwed;
        if (!isOverdue) {
          monthsOwed = 1; // upcoming or on-time: show current active month
        } else {
          // +1 because calculateCalendarMonthsPassed counts COMPLETED months;
          // the current in-progress late month is also owed.
          monthsOwed = PenaltyEngine.calculateCalendarMonthsPassed(dueDateJustDate, justDate) + 1;
          if (monthsOwed > remaining) monthsOwed = remaining; // cap at remaining
        }

        if (isAccelerated) {
          displayAmountDue = ((inst.totalMonths - inst.paidMonths) * inst.monthlyPayment) + lateFee;
        } else {
          displayAmountDue = (inst.monthlyPayment * monthsOwed) + lateFee;
        }

        // --- Button: immediate transaction cost (1 month for informal, arrears for commercial) ---
        int regularMonthsToPay = PenaltyEngine.calculateActualMonthsToPay(inst);
        if (inst.paidMonths + regularMonthsToPay > inst.totalMonths) {
          regularMonthsToPay = inst.totalMonths - inst.paidMonths;
        }
        double regularTransactionCost = (inst.monthlyPayment * regularMonthsToPay) + lateFee;

        int fullMonthsToPay = inst.totalMonths - inst.paidMonths;
        double fullTransactionCost = (inst.monthlyPayment * fullMonthsToPay) + lateFee;

        // For visual progress bar: strictly missed calendar months (no grace bundling)
        int missedMonths = 0;
        if (isOverdue) {
          missedMonths = PenaltyEngine.calculateCalendarMonthsPassed(dueDateJustDate, justDate);
          if (missedMonths == 0) missedMonths = 1;
          missedMonths = missedMonths > remaining ? remaining : missedMonths;
        }

        int visualRedSegments = 0;
        if (isOverdue) {
          visualRedSegments = PenaltyEngine.calculateCalendarMonthsPassed(dueDateJustDate, justDate) + 1;
        }
        visualRedSegments = visualRedSegments > remaining ? remaining : visualRedSegments;

        
        String dueText;
        if (isAccelerated) {
          dueText = '⚠️ DEFAULT STATUS: ENTIRE BALANCE DUE';
        } else if (isOverdue) {
          dueText = 'Late by ${-daysToDue} days';
        } else if (daysToDue == 0) {
          dueText = 'Due today';
        } else {
          dueText = 'Due in $daysToDue days';
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutQuart,
          child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InstallmentDetailsScreen(installment: inst),
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
                        Row(
                          children: [
                            Text(
                              inst.merchantName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (inst.lenderEnum != LenderType.standard)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${inst.lender} Rule',
                                  style: TextStyle(color: Colors.blue[800], fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
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
                          children: [
                            if (isOverdue)
                              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                            if (isOverdue)
                              const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                dueText,
                                style: TextStyle(
                                  color: isOverdue ? Colors.red : Colors.grey[700],
                                  fontSize: 13,
                                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (lateFee > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.money_off, color: Colors.redAccent, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '+ EGP ${lateFee.toStringAsFixed(0)} Late Fee (${inst.lender})',
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (lateFee > 0 && !isAccelerated)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currencyFormatter.format(inst.monthlyPayment * PenaltyEngine.calculateMissedMonths(inst)),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            currencyFormatter.format(displayAmountDue),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: lateFee > 0 || isOverdue ? Colors.red : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  Text(
                    '${inst.paidMonths} of ${inst.totalMonths} paid',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(inst.totalMonths, (index) {
                  int paidSegments = inst.paidMonths;
                  int totalSegments = inst.totalMonths;
                  int redSegments = 0;

                  if (isAccelerated) {
                    redSegments = totalSegments - paidSegments;
                  } else {
                    redSegments = visualRedSegments;
                  }

                  Color segmentColor;
                  if (index < paidSegments) {
                    segmentColor = Colors.black;
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
              ),
              if (inst.statusEnum != InstallmentStatus.paid) ...[
                const SizedBox(height: 16),
                (() {
                  Future<void> pay(int monthsToPay) async {
                    if (inst.paidMonths < inst.totalMonths) {
                      double evenlyDistributedPenalty = lateFee / monthsToPay;

                      for (int i = 0; i < monthsToPay; i++) {
                        inst.pastPayments = List.from(inst.pastPayments)..add(inst.monthlyPayment + evenlyDistributedPenalty);
                      }
                      
                      inst.paidMonths += monthsToPay;
                      inst.dueDate = DateTime(inst.dueDate.year, inst.dueDate.month + monthsToPay, inst.dueDate.day);
                      
                      if (inst.paidMonths >= inst.totalMonths) {
                        inst.statusEnum = InstallmentStatus.paid;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Installment fully paid! Moved to History tab. 🎉'),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else if (inst.statusEnum == InstallmentStatus.overdue && inst.dueDate.isAfter(TimeService.now())) {
                        inst.statusEnum = InstallmentStatus.active;
                      }
                      await inst.save();
                    }
                  }

                  if (isAccelerated) {
                    return Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pay(regularMonthsToPay),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    text: regularMonthsToPay > 1
                                        ? 'Pay $regularMonthsToPay Months Arrears\n'
                                        : 'Mark Month as Paid\n',
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => pay(fullMonthsToPay),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                        onPressed: () => pay(regularMonthsToPay),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                                text: regularMonthsToPay > 1
                                    ? 'Pay $regularMonthsToPay Months Arrears\n'
                                    : 'Mark Month as Paid\n',
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
        ),
      ),
    );
  },
);
  }
}
