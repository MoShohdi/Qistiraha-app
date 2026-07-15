/// Strongly-typed enums for Installment model fields.
///
/// The Hive fields remain as raw [String] values for backwards compatibility
/// (Option A). These enums are exposed via computed getter/setters on
/// [Installment] so all call sites can use type-safe comparisons.
library;


enum InstallmentStatus {
  active,
  paid,
  overdue,
  defaulted;

  /// The raw string value stored in Hive.
  String get raw {
    switch (this) {
      case InstallmentStatus.active:
        return 'Active';
      case InstallmentStatus.paid:
        return 'Paid';
      case InstallmentStatus.overdue:
        return 'Overdue';
      case InstallmentStatus.defaulted:
        return 'Defaulted';
    }
  }

  static InstallmentStatus fromRaw(String s) {
    switch (s.toLowerCase()) {
      case 'paid':
        return InstallmentStatus.paid;
      case 'overdue':
        return InstallmentStatus.overdue;
      case 'defaulted':
        return InstallmentStatus.defaulted;
      default:
        return InstallmentStatus.active;
    }
  }
}

enum LenderType {
  valu,
  shahry,
  tru,
  miniCash,
  btech,
  sympl,
  cib,
  standard; // covers 'Other', 'None', empty

  /// The canonical string stored in Hive / displayed in the UI.
  String get raw {
    switch (this) {
      case LenderType.valu:
        return 'Valu';
      case LenderType.shahry:
        return 'Shahry';
      case LenderType.tru:
        return 'TRU';
      case LenderType.miniCash:
        return 'MiniCash';
      case LenderType.btech:
        return 'B.Tech';
      case LenderType.sympl:
        return 'SYMPL';
      case LenderType.cib:
        return 'CIB';
      case LenderType.standard:
        return 'Other';
    }
  }

  static LenderType fromRaw(String s) {
    switch (s.trim()) {
      case 'Valu':
        return LenderType.valu;
      case 'Shahry':
        return LenderType.shahry;
      case 'TRU':
        return LenderType.tru;
      case 'MiniCash':
        return LenderType.miniCash;
      case 'B.Tech':
        return LenderType.btech;
      case 'SYMPL':
        return LenderType.sympl;
      case 'CIB':
        return LenderType.cib;
      default:
        return LenderType.standard;
    }
  }
}
