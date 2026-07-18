import 'package:qistiraha/features/consumer/models/installment.dart';
import '../penalty_engine.dart';
import 'late_fee_policy.dart';

/// Standard (informal) late fee policy:
/// - No late fees apply
/// - No acceleration clause
/// - Used for lenders: 'Other', 'None', or empty string
class StandardPolicy implements LateFeePolicy {
  const StandardPolicy();

  @override
  PenaltyResult calculatePenalty(
    Installment inst,
    DateTime now,
    int daysLate,
    int uncappedMissedMonths,
    int remainingInstallments,
  ) {
    return PenaltyResult(lateFee: 0.0, isAccelerated: false);
  }
}
