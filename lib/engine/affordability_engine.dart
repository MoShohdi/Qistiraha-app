import '../models/user_account.dart';
import '../services/time_service.dart';
import 'penalty_engine.dart';


enum AffordabilityStatus { green, yellow, red }

class AffordabilityEngine {
  static AffordabilityStatus calculateStatus(UserAccount user) {
    if (user.installments == null || user.installments!.isEmpty) {
      return AffordabilityStatus.green;
    }

    double totalMonthlyPayments = calculateTotalMonthlyPayment(user);

    double ratio = totalMonthlyPayments / user.monthlyIncome;

    if (ratio < 0.3) {
      return AffordabilityStatus.green;
    } else if (ratio < 0.5) {
      return AffordabilityStatus.yellow;
    } else {
      return AffordabilityStatus.red;
    }
  }

  static double calculateTotalMonthlyPayment(UserAccount user) {
    if (user.installments == null || user.installments!.isEmpty) return 0.0;
    
    DateTime now = TimeService.now();
    DateTime justDate = DateTime(now.year, now.month, now.day);
    
    double total = 0.0;
    for (var inst in user.installments!) {
      if (inst.status != 'Paid') {
        PenaltyResult pr = PenaltyEngine.calculateLateFees(inst);
        DateTime dueDateJustDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
        int daysLate = justDate.difference(dueDateJustDate).inDays;

        if (daysLate > 0 || pr.isAccelerated) {
          double displayAmountDue;
          if (pr.isAccelerated) {
            displayAmountDue = ((inst.totalMonths - inst.paidMonths) * inst.monthlyPayment) + pr.lateFee;
          } else {
            displayAmountDue = (inst.monthlyPayment * PenaltyEngine.calculateMissedMonths(inst)) + pr.lateFee;
          }
          total += displayAmountDue;
        } else if (inst.dueDate.year == now.year && inst.dueDate.month == now.month) {
          total += inst.monthlyPayment;
        }
      }
    }
    return total;
  }

  static double calculateTotalOutstandingDebt(UserAccount user) {
    if (user.installments == null || user.installments!.isEmpty) return 0.0;

    double total = 0.0;
    for (var inst in user.installments!) {
      if (inst.status != 'Paid') {
        int remainingMonths = inst.totalMonths - inst.paidMonths;
        total += remainingMonths * inst.monthlyPayment;
        total += PenaltyEngine.calculateLateFees(inst).lateFee;
      }
    }
    return total;
  }
}
