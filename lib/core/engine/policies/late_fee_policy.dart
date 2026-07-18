import 'package:qistiraha/features/consumer/models/installment.dart';
import '../penalty_engine.dart';

/// Abstract Strategy: all lender-specific policy classes must implement this.
abstract class LateFeePolicy {
  /// Calculate the penalty result for a given installment at [now].
  ///
  /// [daysLate]             — calendar days past the due date (already computed by engine)
  /// [uncappedMissedMonths] — raw calendar months elapsed since due (already computed)
  /// [remainingInstallments]— total months remaining on the plan
  PenaltyResult calculatePenalty(
    Installment inst,
    DateTime now,
    int daysLate,
    int uncappedMissedMonths,
    int remainingInstallments,
  );
}
