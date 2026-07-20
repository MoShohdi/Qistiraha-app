import 'dart:math';
import 'package:qistiraha/features/consumer/models/installment.dart';
import '../penalty_engine.dart';
import 'late_fee_policy.dart';

/// MiniCash / B.Tech late fee policy (identical rules, shared implementation):
/// - 5-day grace period
/// - Rate: 6% of missed principal, minimum EGP 60
/// - Acceleration at 2+ missed months: 6% of entire remaining principal (min EGP 60)
class MiniCashBtechPolicy implements LateFeePolicy {
  const MiniCashBtechPolicy();

  @override
  PenaltyResult calculatePenalty(
    Installment inst,
    DateTime now,
    int daysLate,
    int uncappedMissedMonths,
    int remainingInstallments,
  ) {
    // Acceleration clause
    if (uncappedMissedMonths >= 2) {
      double entireRemainingPrincipal =
          remainingInstallments * inst.monthlyPayment;
      double fee = entireRemainingPrincipal * 0.06;
      return PenaltyResult(
        lateFee: fee < 60.0 ? 60.0 : fee,
        isAccelerated: true,
      );
    }

    // Pre-acceleration: cumulative loop
    double totalLateFee = 0.0;
    if (daysLate > 5) {
      for (int i = 1; i <= uncappedMissedMonths; i++) {
        int actualMonths = min(i, remainingInstallments);
        double penalty = (actualMonths * inst.monthlyPayment) * 0.06;
        totalLateFee += penalty < 60.0 ? 60.0 : penalty;
      }
    }
    return PenaltyResult(lateFee: totalLateFee, isAccelerated: false);
  }
}
