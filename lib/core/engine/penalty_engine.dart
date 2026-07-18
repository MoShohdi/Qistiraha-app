import 'dart:math';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'policies/late_fee_policy.dart';
import 'policies/valu_policy.dart';
import 'policies/shahry_tru_policy.dart';
import 'policies/mini_cash_btech_policy.dart';
import 'policies/sympl_policy.dart';
import 'policies/standard_policy.dart';

class PenaltyResult {
  final double lateFee;
  final bool isAccelerated;

  PenaltyResult({required this.lateFee, required this.isAccelerated});
}

class PenaltyEngine {
  // ---------------------------------------------------------------------------
  // Strategy map: lender string → policy instance (singletons, stateless)
  // ---------------------------------------------------------------------------
  static const LateFeePolicy _standardPolicy = StandardPolicy();

  static const Map<String, LateFeePolicy> _policyMap = {
    'Valu': ValuPolicy(),
    'Shahry': ShahryTruPolicy(),
    'TRU': ShahryTruPolicy(),
    'MiniCash': MiniCashBtechPolicy(),
    'B.Tech': MiniCashBtechPolicy(),
    'SYMPL': SymplPolicy(),
  };

  static LateFeePolicy _policyFor(Installment inst) {
    return _policyMap[inst.lender] ?? _standardPolicy;
  }

  // ---------------------------------------------------------------------------
  // Calendar math helpers
  // ---------------------------------------------------------------------------

  /// Returns the number of full calendar months between [dueDate] and [now].
  /// Does NOT add the +1 "current late month" — callers do that as needed.
  static int calculateCalendarMonthsPassed(DateTime dueDate, DateTime now) {
    int months = (now.year - dueDate.year) * 12 + (now.month - dueDate.month);
    if (now.day < dueDate.day) {
      months--;
    }
    return months < 0 ? 0 : months;
  }

  // ---------------------------------------------------------------------------
  // Missed months helpers
  // ---------------------------------------------------------------------------

  /// Raw missed months with no cap (used internally by policies and the engine).
  static int calculateUncappedMissedMonths(Installment inst) {
    if (inst.statusEnum == InstallmentStatus.paid) return 0;

    DateTime now = TimeService.now();
    DateTime justDate = DateTime(now.year, now.month, now.day);
    DateTime dueDateJustDate = DateTime(
      inst.dueDate.year,
      inst.dueDate.month,
      inst.dueDate.day,
    );

    int daysLate = justDate.difference(dueDateJustDate).inDays;
    if (daysLate <= 0) return 0;

    int calculatedArrears = calculateCalendarMonthsPassed(dueDateJustDate, justDate);
    if (daysLate > 0 && calculatedArrears == 0) {
      calculatedArrears = 1;
    }
    return calculatedArrears;
  }

  /// Missed months capped at the number of remaining installments.
  static int calculateMissedMonths(Installment inst) {
    int calculatedArrears = calculateUncappedMissedMonths(inst);
    int remainingInstallments = inst.totalMonths - inst.paidMonths;
    return min(calculatedArrears, remainingInstallments);
  }

  /// The number of months that will actually be transacted on button press.
  /// Informal loans always pay exactly 1 month at a time.
  /// Commercial/strict rules retain multi-month arrears bundling.
  static int calculateActualMonthsToPay(Installment inst) {
    if (inst.statusEnum == InstallmentStatus.paid) return 0;
    if (inst.lenderEnum == LenderType.standard) return 1;
    int missed = calculateMissedMonths(inst);
    return missed <= 0 ? 1 : missed;
  }

  // ---------------------------------------------------------------------------
  // Main entry point — delegates to the correct LateFeePolicy
  // ---------------------------------------------------------------------------

  static PenaltyResult calculateLateFees(Installment inst) {
    if (inst.statusEnum == InstallmentStatus.paid) {
      return PenaltyResult(lateFee: 0.0, isAccelerated: false);
    }

    DateTime now = TimeService.now();
    DateTime justDate = DateTime(now.year, now.month, now.day);
    DateTime dueDateJustDate = DateTime(
      inst.dueDate.year,
      inst.dueDate.month,
      inst.dueDate.day,
    );

    int daysLate = justDate.difference(dueDateJustDate).inDays;
    if (daysLate <= 0) return PenaltyResult(lateFee: 0.0, isAccelerated: false);

    int uncappedMissedMonths = calculateUncappedMissedMonths(inst);
    if (uncappedMissedMonths < 1) uncappedMissedMonths = 1;

    int remainingInstallments = inst.totalMonths - inst.paidMonths;

    final policy = _policyFor(inst);
    return policy.calculatePenalty(
      inst,
      now,
      daysLate,
      uncappedMissedMonths,
      remainingInstallments,
    );
  }
}
