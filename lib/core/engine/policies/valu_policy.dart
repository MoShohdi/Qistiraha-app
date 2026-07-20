import 'dart:math';
import 'package:qistiraha/features/consumer/models/installment.dart';
import '../penalty_engine.dart';
import 'late_fee_policy.dart';

/// Valu late fee policy:
/// - 5-day grace period
/// - Pre-acceleration: 10% of missed principal per missed month
/// - Acceleration at 2+ missed months: 10% of entire remaining principal (full balance due)
class ValuPolicy implements LateFeePolicy {
  const ValuPolicy();

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
      return PenaltyResult(
        lateFee: entireRemainingPrincipal * 0.10,
        isAccelerated: true,
      );
    }

    // Pre-acceleration: cumulative loop
    double totalLateFee = 0.0;
    if (daysLate > 5) {
      for (int i = 1; i <= uncappedMissedMonths; i++) {
        int actualMonths = min(i, remainingInstallments);
        totalLateFee += (actualMonths * inst.monthlyPayment) * 0.10;
      }
    }
    return PenaltyResult(lateFee: totalLateFee, isAccelerated: false);
  }
}
