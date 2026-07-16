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
  });

  // ---------------------------------------------------------------------------
  // Type-safe enum accessors (Hive fields remain raw Strings — no migration needed)
  // ---------------------------------------------------------------------------

  InstallmentStatus get statusEnum => InstallmentStatus.fromRaw(status);
  set statusEnum(InstallmentStatus s) => status = s.raw;

  LenderType get lenderEnum => LenderType.fromRaw(lender);
  set lenderEnum(LenderType l) => lender = l.raw;
}
