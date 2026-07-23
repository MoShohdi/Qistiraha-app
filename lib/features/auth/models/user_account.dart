import 'package:hive/hive.dart';
import '../../consumer/models/installment.dart';

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

  /// 'consumer' or 'merchant'. See [UserRole].
  @HiveField(4, defaultValue: 'consumer')
  String role;

  /// Set when [role] is 'merchant' — points to the linked [BusinessAccount.id].
  @HiveField(5)
  String? businessId;

  /// Supabase `auth.users.id` — links this local record to the
  /// authenticated identity that owns it. Null for any local data seeded
  /// before real auth existed.
  @HiveField(6)
  String? authUserId;

  @HiveField(7)
  String? email;

  UserAccount({
    required this.name,
    required this.monthlyIncome,
    this.installments,
    this.salaryDay = 1,
    this.role = 'consumer',
    this.businessId,
    this.authUserId,
    this.email,
  });
}
