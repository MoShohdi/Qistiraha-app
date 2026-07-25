import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';

/// Compatibility shim so the merchant surfaces — originally written against
/// the Hive `Installment` model — can consume Supabase [InstallmentRow]s with
/// minimal churn.
///
/// It re-exposes the handful of accessors the merchant UI branches on:
///   * [amount]         — legacy alias for [InstallmentRow.totalAmount].
///   * [customerPhone]  — always null; the account-based handshake carries no
///                        phone number (the consumer claims via their own
///                        auth account), so any phone-dependent UI simply
///                        renders nothing and degrades gracefully.
///   * [statusEnum]     — maps the new *derived* lifecycle
///                        (completed / overdue / everything-else) onto the old
///                        display enum the dashboards still switch on. Note the
///                        legacy `defaulted` state never occurs in the Supabase
///                        model, so those switch arms are simply dead.
extension MerchantInstallmentRowCompat on InstallmentRow {
  double get amount => totalAmount;

  String? get customerPhone => null;

  InstallmentStatus get statusEnum {
    if (isCompleted) return InstallmentStatus.paid;
    if (isOverdue) return InstallmentStatus.overdue;
    return InstallmentStatus.active;
  }
}
