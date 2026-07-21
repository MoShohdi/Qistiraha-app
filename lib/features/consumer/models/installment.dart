import 'package:hive/hive.dart';
import 'enums.dart';

part 'installment.g.dart';

@HiveType(typeId: 0)
class Installment extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  double amount;

  @HiveField(2)
  String merchantName;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4)
  int totalMonths;

  @HiveField(5)
  int paidMonths;

  @HiveField(6)
  String status; // e.g., 'Active', 'Paid', 'Overdue'

  @HiveField(7)
  double monthlyPayment;

  @HiveField(8)
  String itemDescription;

  @HiveField(9)
  double downPayment;

  @HiveField(10)
  double interestRate;

  @HiveField(11)
  String category; // E.g., 'Electronics', 'Fashion', 'Home Essentials', 'Other'

  @HiveField(12, defaultValue: 'Other')
  String lender;

  @HiveField(13, defaultValue: [])
  List<double> pastPayments;

  @HiveField(14)
  String? warrantyImagePath;

  @HiveField(15)
  DateTime? lastPaidAt;

  @HiveField(16, defaultValue: false)
  bool isLongTerm;

  @HiveField(17, defaultValue: 'Monthly')
  String paymentFrequency;

  @HiveField(18, defaultValue: 'Other / Custom')
  String provider;

  /// Links this installment to a [BusinessAccount.id] when it originated from
  /// a merchant's Qist-Link (QR code or WhatsApp share). Null for
  /// installments the consumer entered manually.
  @HiveField(19)
  String? merchantId;

  /// The merchant's own label for who owes this installment (as entered on
  /// the "Generate Payment Link" screen). Used by the Merchant Dashboard.
  @HiveField(20)
  String? customerName;

  @HiveField(21)
  String? customerPhone;

  Installment({
    required this.id,
    required this.amount,
    required this.merchantName,
    required this.dueDate,
    required this.totalMonths,
    required this.paidMonths,
    required this.status,
    required this.monthlyPayment,
    this.itemDescription = '',
    this.downPayment = 0.0,
    this.interestRate = 0.0,
    this.category = 'Other',
    this.lender = 'Other',
    this.pastPayments = const [],
    this.warrantyImagePath,
    this.lastPaidAt,
    this.isLongTerm = false,
    this.paymentFrequency = 'Monthly',
    this.provider = 'Other / Custom',
    this.merchantId,
    this.customerName,
    this.customerPhone,
  });

  // ---------------------------------------------------------------------------
  // Type-safe enum accessors (Hive fields remain raw Strings — no migration needed)
  // ---------------------------------------------------------------------------

  InstallmentStatus get statusEnum => InstallmentStatus.fromRaw(status);
  set statusEnum(InstallmentStatus s) => status = s.raw;

  LenderType get lenderEnum => LenderType.fromRaw(lender);
  set lenderEnum(LenderType l) => lender = l.raw;

  // ---------------------------------------------------------------------------
  // Frequency math helpers
  // ---------------------------------------------------------------------------

  int get monthsPerPayment => monthsPerPaymentFor(paymentFrequency);

  int get totalPayments => totalMonths ~/ monthsPerPayment;
  int get paidPayments => paidMonths ~/ monthsPerPayment;

  /// The calendar due date of the payment-period sitting [periodsBack]
  /// periods before [dueDate] (which always points at the *next* unpaid
  /// period). Steps by whole months — `periodsBack * monthsPerPayment` — so
  /// quarterly/semi-annual/annual nodes land on real dates (Start + 6 months,
  /// etc.) instead of a 30-day-per-step approximation. Pass a negative value
  /// to step forward. Mirrors the month arithmetic used when advancing
  /// [dueDate] on payment, so past nodes line up with future ones.
  DateTime dueDateForPeriodsBack(int periodsBack) {
    final monthsBack = periodsBack * monthsPerPayment;
    return DateTime(dueDate.year, dueDate.month - monthsBack, dueDate.day);
  }

  /// Singular noun for one payment period — e.g. "Month", "Quarter",
  /// "Half-Year", "Year". Used in copy like "Mark this Quarter as Paid".
  String get periodNoun => periodNounFor(paymentFrequency);

  /// Unit noun for the "Installments (...)" entry field, matching
  /// [periodNoun] but pluralized — e.g. "Quarters", "Half-Years", "Years".
  String get periodNounPlural => periodNounPluralFor(paymentFrequency);

  /// Adjective label for a single payment chunk — e.g. "Quarterly Payment",
  /// "Semi-Annual Payment". The single source of truth anywhere the UI would
  /// otherwise hardcode "Monthly Payment".
  String get paymentFrequencyLabel =>
      paymentFrequencyLabelFor(paymentFrequency);

  /// Recurrence phrase for "Due on the Nth of ..." style copy — e.g.
  /// "every quarter", "every 6 months", "every year".
  String get paymentCadencePhrase => paymentCadencePhraseFor(paymentFrequency);

  // ---------------------------------------------------------------------------
  // Static frequency-string helpers — the single source of truth reused both
  // by the getters above (once an [Installment] exists) and by the Add
  // Installment data-entry flow (which only has the raw frequency string
  // typed/selected so far, before a real instance can be built).
  // ---------------------------------------------------------------------------

  static int monthsPerPaymentFor(String frequency) {
    switch (frequency) {
      case 'Quarterly':
        return 3;
      case 'Semi-Annually':
        return 6;
      case 'Annually':
        return 12;
      case 'Monthly':
      default:
        return 1;
    }
  }

  static String periodNounFor(String frequency) {
    switch (frequency) {
      case 'Quarterly':
        return 'Quarter';
      case 'Semi-Annually':
        return 'Half-Year';
      case 'Annually':
        return 'Year';
      case 'Monthly':
      default:
        return 'Month';
    }
  }

  static String periodNounPluralFor(String frequency) =>
      switch (periodNounFor(frequency)) {
        'Half-Year' => 'Half-Years',
        final noun => '${noun}s',
      };

  static String paymentFrequencyLabelFor(String frequency) {
    switch (frequency) {
      case 'Quarterly':
        return 'Quarterly Payment';
      case 'Semi-Annually':
        return 'Semi-Annual Payment';
      case 'Annually':
        return 'Annual Payment';
      case 'Monthly':
      default:
        return 'Monthly Payment';
    }
  }

  static String paymentCadencePhraseFor(String frequency) {
    switch (frequency) {
      case 'Quarterly':
        return 'every quarter';
      case 'Semi-Annually':
        return 'every 6 months';
      case 'Annually':
        return 'every year';
      case 'Monthly':
      default:
        return 'every month';
    }
  }
}

const List<String> kEgyptianProviders = [
  // Fintech & BNPL
  'Valu',
  'AMAN Holding',
  'Contact Financial Holding',
  'MNT-Halan',
  'Souhoola',
  'Premium Card',
  'Shahry',
  'Forsa',
  'Sympl',
  'Blnk',
  'Fawry',
  'OneBank',
  // Banks
  'National Bank of Egypt (NBE)',
  'Banque Misr',
  'Commercial International Bank (CIB)',
  'QNB Alahli',
  'Banque du Caire',
  'Arab African International Bank (AAIB)',
  'HSBC Egypt',
  'AlexBank',
  'Credit Agricole Egypt',
  'Abu Dhabi Islamic Bank (ADIB) Egypt',
  'Emirates NBD Egypt',
  'EG Bank',
  'Mashreq Bank Egypt',
  'saib Bank',
  'Housing and Development Bank (HDB)',
  // Fallback
  'Other / Custom',
];
