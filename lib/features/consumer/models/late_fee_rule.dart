import 'package:hive/hive.dart';

part 'late_fee_rule.g.dart';

@HiveType(typeId: 3)
enum FeeType {
  @HiveField(0)
  fixed,
  @HiveField(1)
  percentage,
  @HiveField(2)
  mixed,
}

@HiveType(typeId: 4)
class LateFeeRule extends HiveObject {
  @HiveField(0)
  String vendorName;

  @HiveField(1)
  FeeType feeType;

  @HiveField(2)
  double fixedAmount;

  @HiveField(3)
  double percentage;

  LateFeeRule({
    required this.vendorName,
    required this.feeType,
    this.fixedAmount = 0.0,
    this.percentage = 0.0,
  });
}
