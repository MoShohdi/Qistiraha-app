import 'package:hive/hive.dart';
import '../../consumer/models/installment.dart';

part 'business_account.g.dart';

@HiveType(typeId: 2)
class BusinessAccount extends HiveObject {
  @HiveField(0)
  String businessName;

  @HiveField(1)
  String category;

  @HiveField(2)
  HiveList<Installment>? sentQists;

  /// Stable identifier (uuid) used to attribute [Installment.merchantId] to
  /// this merchant, independent of the Hive box key.
  @HiveField(3, defaultValue: '')
  String id;

  BusinessAccount({
    required this.businessName,
    required this.category,
    this.sentQists,
    this.id = '',
  });
}
