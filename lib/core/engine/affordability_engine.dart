import 'package:qistiraha/features/auth/models/user_account.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'package:qistiraha/core/services/time_service.dart';

// ---------------------------------------------------------------------------
// Data holders
// ---------------------------------------------------------------------------

/// A simple start/end date range for a custom billing cycle.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange({required this.start, required this.end});
}

enum RiskTier { safe, stretch, danger }

/// The result of a hypothetical purchase simulation.
class SimulatedOutlook {
  /// Combined monthly obligation (existing + hypothetical new payment).
  final double newMonthlyObligation;

  /// How much "safe buffer" (income - obligations) would remain.
  final double newSafeBuffer;

  /// The new absolute debt-free date after adding the hypothetical installment.
  final DateTime newDebtFreeDate;

  /// The calculated FOIR tier for this purchase.
  final RiskTier riskTier;

  /// The calculated FOIR (Fixed Obligation to Income Ratio).
  final double foir;

  const SimulatedOutlook({
    required this.newMonthlyObligation,
    required this.newSafeBuffer,
    required this.newDebtFreeDate,
    required this.riskTier,
    required this.foir,
  });
}

// ---------------------------------------------------------------------------
// Core engine
// ---------------------------------------------------------------------------

enum AffordabilityStatus { green, yellow, red }

class AffordabilityEngine {
  static const double _safeThresholdFraction = 0.50; // 50 % of income

  // -------------------------------------------------------------------------
  // Existing public methods (unchanged signatures)
  // -------------------------------------------------------------------------

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

  static double _getMonthlyDrain(Installment inst) {
    double drain = inst.monthlyPayment;
    if (inst.paymentFrequency == 'Quarterly') {
      drain /= 3;
    } else if (inst.paymentFrequency == 'Annually') {
      drain /= 12;
    } else if (inst.paymentFrequency == 'Semi-Annually') {
      drain /= 6;
    }
    return drain;
  }

  static double calculateTotalMonthlyPayment(UserAccount user) {
    if (user.installments == null || user.installments!.isEmpty) return 0.0;

    DateTime now = TimeService.now();
    DateTime justDate = DateTime(now.year, now.month, now.day);

    double total = 0.0;
    for (var inst in user.installments!) {
      if (inst.statusEnum == InstallmentStatus.paid) continue;
      DateTime dueDateJustDate = DateTime(
        inst.dueDate.year,
        inst.dueDate.month,
        inst.dueDate.day,
      );
      int daysLate = justDate.difference(dueDateJustDate).inDays;
      bool dueThisMonth =
          inst.dueDate.year == now.year && inst.dueDate.month == now.month;

      // No late fees / acceleration: a plan simply owes its base monthly
      // drain when it is due this month or already past due.
      if (daysLate > 0 || dueThisMonth) {
        total += _getMonthlyDrain(inst);
      }
    }
    return total;
  }

  static double calculateTotalOutstandingDebt(UserAccount user) {
    if (user.installments == null || user.installments!.isEmpty) return 0.0;

    double total = 0.0;
    for (var inst in user.installments!) {
      if (inst.statusEnum != InstallmentStatus.paid) {
        int remainingMonths = inst.totalMonths - inst.paidMonths;
        total += remainingMonths * inst.monthlyPayment;
      }
    }
    return total;
  }

  // -------------------------------------------------------------------------
  // New planning methods
  // -------------------------------------------------------------------------

  /// Returns the exact start and end of the user's current financial month.
  ///
  /// The cycle starts on [salaryDay] of each month and ends the day before
  /// [salaryDay] of the following month.
  ///
  /// Example: salaryDay = 22, today = July 15
  ///   → today < 22, so cycle started June 22 and ends July 21.
  /// Example: salaryDay = 22, today = July 25
  ///   → today >= 22, so cycle started July 22 and ends August 21.
  static DateRange getCurrentBillingCycle(int salaryDay, DateTime now) {
    DateTime today = DateTime(now.year, now.month, now.day);

    DateTime cycleStart;
    DateTime cycleEnd;

    if (today.day >= salaryDay) {
      // We are in the second half — cycle started this month
      cycleStart = DateTime(today.year, today.month, salaryDay);
      // End = one day before salaryDay of next month
      DateTime nextMonthStart = DateTime(
        today.year,
        today.month + 1,
        salaryDay,
      );
      cycleEnd = nextMonthStart.subtract(const Duration(days: 1));
    } else {
      // We are in the first half — cycle started last month
      cycleStart = DateTime(today.year, today.month - 1, salaryDay);
      // End = one day before salaryDay of this month
      cycleEnd = DateTime(
        today.year,
        today.month,
        salaryDay,
      ).subtract(const Duration(days: 1));
    }

    return DateRange(start: cycleStart, end: cycleEnd);
  }

  /// Returns the furthest projected last-payment date across all active
  /// installments, representing when the user will be completely debt-free.
  ///
  /// For each installment: lastPaymentDate = dueDate + (remaining − 1) months.
  /// Returns [DateTime.now()] when there are no active installments.
  static DateTime getAbsoluteDebtFreeDate(List<Installment> installments) {
    DateTime now = TimeService.now();
    DateTime latest = now;

    for (var inst in installments) {
      if (inst.statusEnum != InstallmentStatus.paid) {
        int remaining = inst.totalMonths - inst.paidMonths;
        if (remaining <= 0) continue;

        // Project the month of the last payment
        int extraMonths = remaining - 1;
        DateTime lastPayment = DateTime(
          inst.dueDate.year,
          inst.dueDate.month + extraMonths,
          inst.dueDate.day,
        );

        if (lastPayment.isAfter(latest)) {
          latest = lastPayment;
        }
      }
    }

    return latest;
  }

  /// Sums all installment obligations whose due date falls within [cycle].
  /// Overdue installments (past due date) are always included.
  static double getObligationsInCycle(
    List<Installment> installments,
    DateRange cycle,
  ) {
    double total = 0.0;
    DateTime now = TimeService.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    for (var inst in installments) {
      if (inst.statusEnum == InstallmentStatus.paid) continue;

      DateTime dueJust = DateTime(
        inst.dueDate.year,
        inst.dueDate.month,
        inst.dueDate.day,
      );
      bool isDueInCycle =
          !dueJust.isBefore(cycle.start) && !dueJust.isAfter(cycle.end);
      bool isOverdue = dueJust.isBefore(today);

      if (isDueInCycle || isOverdue) {
        total += _getMonthlyDrain(inst);
      }
    }
    return total;
  }

  /// Returns the total of all installments that fall inside the current billing
  /// cycle and are still unpaid (owed but not yet marked paid).
  ///
  /// Used by [calculateSafeToSpend].
  static double getOwedInCycle(
    List<Installment> installments,
    DateRange cycle,
  ) {
    double total = 0.0;
    DateTime now = TimeService.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    for (var inst in installments) {
      if (inst.statusEnum == InstallmentStatus.paid) continue;

      DateTime dueJust = DateTime(
        inst.dueDate.year,
        inst.dueDate.month,
        inst.dueDate.day,
      );
      bool isDueInCycle =
          !dueJust.isBefore(cycle.start) && !dueJust.isAfter(cycle.end);
      bool isOverdue = dueJust.isBefore(today);

      if (isDueInCycle || isOverdue) {
        total += _getMonthlyDrain(inst);
      }
    }
    return total;
  }

  /// Returns how much the user has *already paid* toward installments during
  /// the current billing cycle, using the [lastPaidAt] payment timestamp.
  ///
  /// This is immune to the "dueDate shift" bug: when a payment is marked, the
  /// dueDate advances to the next month, but [lastPaidAt] remains anchored at
  /// the exact moment the user tapped pay — so it always stays within the
  /// cycle window where the payment actually occurred.
  static double getPaidInCycle(
    List<Installment> installments,
    DateRange cycle,
  ) {
    double total = 0.0;

    for (var inst in installments) {
      final DateTime? paidAt = inst.lastPaidAt;
      if (paidAt == null) continue;

      // Inclusive boundary: paidAt >= cycle.start && paidAt <= cycle.end
      final bool paidInWindow =
          !paidAt.isBefore(cycle.start) && !paidAt.isAfter(cycle.end);

      if (paidInWindow) {
        total += _getMonthlyDrain(inst);
      }
    }
    return total;
  }

  /// Real-time "Safe-to-Spend" for the current billing cycle.
  ///
  /// Formula: `income − amountStillOwedThisCycle − amountAlreadyPaidThisCycle`
  ///
  /// - `amountStillOwedThisCycle`: active installments whose due date falls in
  ///   the cycle window (or are overdue).
  /// - `amountAlreadyPaidThisCycle`: fully-paid installments whose due date
  ///   was inside the cycle.
  ///
  /// The result resets automatically when `getCurrentBillingCycle` rolls over
  /// on the user's `incomeDepositDay`.
  static double calculateSafeToSpend(
    List<Installment> installments,
    double monthlyIncome,
    int salaryDay,
  ) {
    DateTime now = TimeService.now();
    DateRange cycle = getCurrentBillingCycle(salaryDay, now);
    double owed = getOwedInCycle(installments, cycle);
    double paid = getPaidInCycle(installments, cycle);
    return monthlyIncome - owed - paid;
  }

  /// Returns how much "safe headroom" the user has left this billing cycle
  /// against the 50%-of-income threshold (legacy — used by status badge).
  static double getRemainingSafeBuffer(
    List<Installment> installments,
    double monthlyIncome,
    int salaryDay,
  ) {
    DateTime now = TimeService.now();
    DateRange cycle = getCurrentBillingCycle(salaryDay, now);
    double obligations = getObligationsInCycle(installments, cycle);
    double safeThreshold = monthlyIncome * _safeThresholdFraction;
    return safeThreshold - obligations;
  }

  /// Simulates adding a hypothetical purchase and returns how it changes the
  /// user's financial outlook.
  ///
  /// The threshold used is the user's **Discretionary Income**:
  ///   `discretionary = monthlyIncome − sum(all active monthly payments)`
  /// The hypothetical monthly payment is checked against this real available
  /// buffer, NOT the raw income.
  ///
  /// [itemCost]  — total price of the item
  /// [months]    — number of installment months
  /// [downPayment] — initial down payment
  /// [existing]  — current active installments
  /// [monthlyIncome] — user's monthly income
  /// [salaryDay] — user's custom income deposit day
  static SimulatedOutlook simulatePurchase({
    required double itemCost,
    required int months,
    required double downPayment,
    required List<Installment> existing,
    required double monthlyIncome,
    required int salaryDay,
  }) {
    DateTime now = TimeService.now();
    double hypotheticalMonthly = months > 0
        ? (itemCost - downPayment) / months
        : 0.0;

    // --- True Discretionary Income (FOIR) ---
    // Sum all active monthly payments (base installment amounts only, no penalties).
    double currentObligations = existing
        .where((i) => i.statusEnum != InstallmentStatus.paid)
        .fold(0.0, (sum, i) => sum + _getMonthlyDrain(i));
    double realAvailableBuffer = monthlyIncome - currentObligations;

    // The new payment eats into the discretionary buffer.
    double newSafeBuffer = realAvailableBuffer - hypotheticalMonthly;

    // New monthly obligation display value: existing obligations + new payment.
    double newMonthlyObligation = currentObligations + hypotheticalMonthly;

    // Calculate FOIR
    double foir = monthlyIncome > 0
        ? newMonthlyObligation / monthlyIncome
        : 0.0;

    RiskTier tier;
    if (foir <= 0.35) {
      tier = RiskTier.safe;
    } else if (foir <= 0.50) {
      tier = RiskTier.stretch;
    } else {
      tier = RiskTier.danger;
    }

    // Debt-free date: max(existing furthest, today + months)
    DateTime existingDebtFree = getAbsoluteDebtFreeDate(existing);
    DateTime hypotheticalEnd = DateTime(now.year, now.month + months, now.day);
    DateTime newDebtFreeDate = hypotheticalEnd.isAfter(existingDebtFree)
        ? hypotheticalEnd
        : existingDebtFree;

    return SimulatedOutlook(
      newMonthlyObligation: newMonthlyObligation,
      newSafeBuffer: newSafeBuffer,
      newDebtFreeDate: newDebtFreeDate,
      riskTier: tier,
      foir: foir,
    );
  }
}
