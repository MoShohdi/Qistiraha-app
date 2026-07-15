import 'dart:math';
import '../models/installment.dart';
import '../services/time_service.dart';

class PenaltyResult {
  final double lateFee;
  final bool isAccelerated;

  PenaltyResult({required this.lateFee, required this.isAccelerated});
}

class PenaltyEngine {
  static int calculateCalendarMonthsPassed(DateTime dueDate, DateTime now) {
    int months = (now.year - dueDate.year) * 12 + (now.month - dueDate.month);
    // If the current day of the month hasn't reached the due date's day, subtract 1
    if (now.day < dueDate.day) {
      months--;
    }
    return months < 0 ? 0 : months;
  }

  static int calculateUncappedMissedMonths(Installment inst) {
    if (inst.status == 'Paid') return 0;
    
    DateTime now = TimeService.now();
    DateTime justDate = DateTime(now.year, now.month, now.day);
    DateTime dueDateJustDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
    
    int daysLate = justDate.difference(dueDateJustDate).inDays;
    if (daysLate <= 0) return 0;
    
    // True calendar math (e.g. if you are 5 days late, months passed is 0, but you are in 1 billing cycle of arrears)
    return calculateCalendarMonthsPassed(dueDateJustDate, justDate) + 1;
  }

  static int calculateMissedMonths(Installment inst) {
    int calculatedArrears = calculateUncappedMissedMonths(inst);
    int remainingInstallments = inst.totalMonths - inst.paidMonths;
    return min(calculatedArrears, remainingInstallments);
  }

  static PenaltyResult calculateLateFees(Installment inst) {
    if (inst.status == 'Paid') return PenaltyResult(lateFee: 0.0, isAccelerated: false);
    
    DateTime now = TimeService.now();
    DateTime justDate = DateTime(now.year, now.month, now.day);
    DateTime dueDateJustDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
    
    int daysLate = justDate.difference(dueDateJustDate).inDays;
    if (daysLate <= 0) return PenaltyResult(lateFee: 0.0, isAccelerated: false);

    int uncappedMissedMonths = calculateUncappedMissedMonths(inst);
    if (uncappedMissedMonths < 1) uncappedMissedMonths = 1;
    
    int remainingInstallments = inst.totalMonths - inst.paidMonths;

    double totalLateFee = 0.0;
    bool isAccelerated = false;

    // Acceleration Check
    if (uncappedMissedMonths >= 2) {
      if (['Valu', 'Shahry', 'TRU', 'MiniCash', 'B.Tech'].contains(inst.lender)) {
        isAccelerated = true;
      }
    }

    if (isAccelerated) {
        int remainingMonths = inst.totalMonths - inst.paidMonths;
        double entireRemainingPrincipal = remainingMonths * inst.monthlyPayment;
        
        switch (inst.lender) {
            case 'Valu':
                totalLateFee = entireRemainingPrincipal * 0.10;
                break;
            case 'Shahry':
            case 'TRU':
                totalLateFee = entireRemainingPrincipal * 0.15;
                break;
            case 'MiniCash':
            case 'B.Tech':
                double fee = entireRemainingPrincipal * 0.06;
                totalLateFee = fee < 60.0 ? 60.0 : fee;
                break;
            default:
                break;
        }
        return PenaltyResult(lateFee: totalLateFee, isAccelerated: true);
    }

    if (inst.lender == 'SYMPL') {
        int penalizableMonths = calculateCalendarMonthsPassed(dueDateJustDate, justDate);
        double totalPenalty = penalizableMonths * 25.0;
        return PenaltyResult(lateFee: totalPenalty, isAccelerated: false);
    }

    // Normal Cumulative Loop
    for (int i = 1; i <= uncappedMissedMonths; i++) {
        double feeForThisMonth = 0.0;
        int actualMonthsToPay = min(i, remainingInstallments);

        switch (inst.lender) {
            case 'Valu':
                if (daysLate > 5) {
                    feeForThisMonth = (actualMonthsToPay * inst.monthlyPayment) * 0.10;
                }
                break;
            case 'Shahry':
            case 'TRU':
                if (daysLate > 5) {
                    feeForThisMonth = (actualMonthsToPay * inst.monthlyPayment) * 0.15;
                }
                break;
            case 'MiniCash':
            case 'B.Tech':
                if (daysLate > 5) {
                    double penalty = (actualMonthsToPay * inst.monthlyPayment) * 0.06;
                    feeForThisMonth = penalty < 60.0 ? 60.0 : penalty;
                }
                break;
            case 'CIB':
                if (daysLate > 0) {
                    feeForThisMonth = 150.0 + ((actualMonthsToPay * inst.monthlyPayment) * 0.0399);
                }
                break;
            default:
                break;
        }
        totalLateFee += feeForThisMonth;
    }
    
    return PenaltyResult(lateFee: totalLateFee, isAccelerated: isAccelerated);
  }
}
