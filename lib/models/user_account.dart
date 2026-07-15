import 'package:hive/hive.dart';
import 'installment.dart';

part 'user_account.g.dart';

@HiveType(typeId: 1)
class UserAccount extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  double monthlyIncome;

  @HiveField(2)
  HiveList<Installment>? installments;

  @HiveField(3, defaultValue: 1)
  int salaryDay;

  UserAccount({
    required this.name,
    required this.monthlyIncome,
    this.installments,
    this.salaryDay = 1,
  });
}
