import 'package:hive/hive.dart';
import 'installment.dart';

part 'business_account.g.dart';

@HiveType(typeId: 2)
class BusinessAccount extends HiveObject {
  @HiveField(0)
  String businessName;

  @HiveField(1)
  String category;

  @HiveField(2)
  HiveList<Installment>? sentQists;

  BusinessAccount({
    required this.businessName,
    required this.category,
    this.sentQists,
  });
}
