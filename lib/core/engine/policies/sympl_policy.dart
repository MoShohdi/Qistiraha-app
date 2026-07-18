import 'package:qistiraha/features/consumer/models/installment.dart';
import '../penalty_engine.dart';
import 'late_fee_policy.dart';

/// Sympl late fee policy:
/// - Flat EGP 25 per full calendar month elapsed since the due date
/// - No acceleration clause
class SymplPolicy implements LateFeePolicy {
  const SymplPolicy();

  @override
  PenaltyResult calculatePenalty(
    Installment inst,
    DateTime now,
    int daysLate,
    int uncappedMissedMonths,
    int remainingInstallments,
  ) {
    // penalizableMonths = full calendar months that have COMPLETED since the due date
    // (uncappedMissedMonths already equals calculateCalendarMonthsPassed with the floor-1 guard)
    double totalPenalty = uncappedMissedMonths * 25.0;
    return PenaltyResult(lateFee: totalPenalty, isAccelerated: false);
  }
}
