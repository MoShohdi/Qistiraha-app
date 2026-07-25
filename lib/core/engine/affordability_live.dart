import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/core/services/time_service.dart';

// Reuse the existing result types so migrated dashboards keep referencing the
// same enums/classes they already import — only the data source changes.
import 'affordability_engine.dart'
    show AffordabilityStatus, RiskTier, DateRange, SimulatedOutlook;

export 'affordability_engine.dart'
    show AffordabilityStatus, RiskTier, DateRange, SimulatedOutlook;

/// Penalty-free Affordability Engine that runs entirely off live Supabase
/// rows ([InstallmentRow]) instead of the Hive `UserAccount`/`Installment`
/// model. Behaviourally identical to the old [AffordabilityEngine] EXCEPT
/// that every late-fee / acceleration term has been removed — Qistiraha no
/// longer tracks penalties, so obligations are just the base period amounts.
///
/// This is the engine the dashboards call after the stream cutover:
/// ```dart
/// StreamBuilder<List<InstallmentRow>>(
///   stream: DatabaseService.consumerInstallments(),
///   builder: (_, snap) {
///     final rows = snap.data ?? const [];
///     final monthly = LiveAffordabilityEngine.totalMonthlyPayment(rows);
///     ...
///   },
/// )
/// ```
class LiveAffordabilityEngine {
  static const double _safeThresholdFraction = 0.50;

  static bool _isOpen(InstallmentRow r) => !r.isCompleted && !r.isCancelled;

  // -------------------------------------------------------------------------
  // Headline figures
  // -------------------------------------------------------------------------

  static AffordabilityStatus status(
    List<InstallmentRow> rows,
    double monthlyIncome,
  ) {
    if (rows.isEmpty || monthlyIncome <= 0) return AffordabilityStatus.green;
    final ratio = totalMonthlyPayment(rows) / monthlyIncome;
    if (ratio < 0.3) return AffordabilityStatus.green;
    if (ratio < 0.5) return AffordabilityStatus.yellow;
    return AffordabilityStatus.red;
  }

  /// This month's obligation: the normalized monthly drain of every open plan
  /// whose payment lands in (or is past due within) the current month. No
  /// penalty term — an overdue plan simply still owes its base amount.
  static double totalMonthlyPayment(List<InstallmentRow> rows) {
    final now = TimeService.now();
    double total = 0.0;
    for (final r in rows) {
      if (!_isOpen(r)) continue;
      final dueThisMonth =
          r.dueDate.year == now.year && r.dueDate.month == now.month;
      if (r.isOverdue || dueThisMonth) {
        total += r.monthlyDrain;
      }
    }
    return total;
  }

  static double totalOutstandingDebt(List<InstallmentRow> rows) {
    double total = 0.0;
    for (final r in rows) {
      if (!_isOpen(r)) continue;
      final remainingMonths = r.totalMonths - r.paidMonths;
      if (remainingMonths > 0) total += remainingMonths * r.monthlyDrain;
    }
    return total;
  }

  /// Furthest projected last-payment date across all open plans → the
  /// absolute debt-free date. Returns now when nothing is open.
  static DateTime absoluteDebtFreeDate(List<InstallmentRow> rows) {
    final now = TimeService.now();
    DateTime latest = now;
    for (final r in rows) {
      if (!_isOpen(r)) continue;
      final remaining = r.totalMonths - r.paidMonths;
      if (remaining <= 0) continue;
      final last = DateTime(
        r.dueDate.year,
        r.dueDate.month + (remaining - 1),
        r.dueDate.day,
      );
      if (last.isAfter(latest)) latest = last;
    }
    return latest;
  }

  // -------------------------------------------------------------------------
  // Billing cycle + Safe-to-Spend
  // -------------------------------------------------------------------------

  /// Current financial month: starts on [salaryDay], ends the day before
  /// [salaryDay] of the following month.
  static DateRange currentBillingCycle(int salaryDay, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (today.day >= salaryDay) {
      final start = DateTime(today.year, today.month, salaryDay);
      final end = DateTime(today.year, today.month + 1, salaryDay)
          .subtract(const Duration(days: 1));
      return DateRange(start: start, end: end);
    } else {
      final start = DateTime(today.year, today.month - 1, salaryDay);
      final end = DateTime(today.year, today.month, salaryDay)
          .subtract(const Duration(days: 1));
      return DateRange(start: start, end: end);
    }
  }

  /// Amount owed this cycle: open plans due within the window, plus anything
  /// overdue. Base amounts only.
  static double owedInCycle(List<InstallmentRow> rows, DateRange cycle) {
    final now = TimeService.now();
    final today = DateTime(now.year, now.month, now.day);
    double total = 0.0;
    for (final r in rows) {
      if (!_isOpen(r)) continue;
      final due = DateTime(r.dueDate.year, r.dueDate.month, r.dueDate.day);
      final inCycle = !due.isBefore(cycle.start) && !due.isAfter(cycle.end);
      final overdue = due.isBefore(today);
      if (inCycle || overdue) total += r.monthlyDrain;
    }
    return total;
  }

  /// Amount already paid within the cycle, anchored on [InstallmentRow.lastPaidAt]
  /// so it survives the due-date roll-forward after a payment is recorded.
  static double paidInCycle(List<InstallmentRow> rows, DateRange cycle) {
    double total = 0.0;
    for (final r in rows) {
      final paidAt = r.lastPaidAt;
      if (paidAt == null) continue;
      final inWindow =
          !paidAt.isBefore(cycle.start) && !paidAt.isAfter(cycle.end);
      if (inWindow) total += r.monthlyDrain;
    }
    return total;
  }

  static double safeToSpend(
    List<InstallmentRow> rows,
    double monthlyIncome,
    int salaryDay,
  ) {
    final cycle = currentBillingCycle(salaryDay, TimeService.now());
    return monthlyIncome -
        owedInCycle(rows, cycle) -
        paidInCycle(rows, cycle);
  }

  static double remainingSafeBuffer(
    List<InstallmentRow> rows,
    double monthlyIncome,
    int salaryDay,
  ) {
    final cycle = currentBillingCycle(salaryDay, TimeService.now());
    return (monthlyIncome * _safeThresholdFraction) - owedInCycle(rows, cycle);
  }

  // -------------------------------------------------------------------------
  // What-if purchase simulation (FOIR), penalty-free
  // -------------------------------------------------------------------------

  static SimulatedOutlook simulatePurchase({
    required double itemCost,
    required int months,
    required double downPayment,
    required List<InstallmentRow> existing,
    required double monthlyIncome,
    required int salaryDay,
  }) {
    final now = TimeService.now();
    final hypotheticalMonthly =
        months > 0 ? (itemCost - downPayment) / months : 0.0;

    final currentObligations = existing
        .where(_isOpen)
        .fold(0.0, (sum, r) => sum + r.monthlyDrain);

    final newMonthlyObligation = currentObligations + hypotheticalMonthly;
    final newSafeBuffer =
        (monthlyIncome - currentObligations) - hypotheticalMonthly;
    final foir =
        monthlyIncome > 0 ? newMonthlyObligation / monthlyIncome : 0.0;

    final RiskTier tier;
    if (foir <= 0.35) {
      tier = RiskTier.safe;
    } else if (foir <= 0.50) {
      tier = RiskTier.stretch;
    } else {
      tier = RiskTier.danger;
    }

    final existingDebtFree = absoluteDebtFreeDate(existing);
    final hypotheticalEnd = DateTime(now.year, now.month + months, now.day);
    final newDebtFreeDate = hypotheticalEnd.isAfter(existingDebtFree)
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
