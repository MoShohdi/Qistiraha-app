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

  int get monthsPerPayment {
    switch (paymentFrequency) {
      case 'Quarterly': return 3;
      case 'Semi-Annually': return 6;
      case 'Annually': return 12;
      case 'Monthly':
      default: return 1;
    }
  }

  int get totalPayments => totalMonths ~/ monthsPerPayment;
  int get paidPayments => paidMonths ~/ monthsPerPayment;
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
  'Other / Custom'
];
