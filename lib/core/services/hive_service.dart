import 'package:hive_flutter/hive_flutter.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/auth/models/user_account.dart';
import 'package:qistiraha/features/auth/models/business_account.dart';
import 'package:qistiraha/features/consumer/models/late_fee_rule.dart';

class HiveService {
  static const String userBoxName = 'userBox';
  static const String businessBoxName = 'businessBox';
  static const String installmentBoxName = 'installmentBox';
  static const String lateFeeBoxName = 'lateFeeBox';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(InstallmentAdapter());
    Hive.registerAdapter(UserAccountAdapter());
    Hive.registerAdapter(BusinessAccountAdapter());
    Hive.registerAdapter(LateFeeRuleAdapter());
    Hive.registerAdapter(FeeTypeAdapter());

    // Open Boxes
    await Hive.openBox<UserAccount>(userBoxName);
    await Hive.openBox<BusinessAccount>(businessBoxName);
    await Hive.openBox<Installment>(installmentBoxName);
    await Hive.openBox<LateFeeRule>(lateFeeBoxName);
  }

  static Box<UserAccount> getUserBox() => Hive.box<UserAccount>(userBoxName);
  static Box<BusinessAccount> getBusinessBox() =>
      Hive.box<BusinessAccount>(businessBoxName);
  static Box<Installment> getInstallmentBox() =>
      Hive.box<Installment>(installmentBoxName);
  static Box<LateFeeRule> getLateFeeBox() =>
      Hive.box<LateFeeRule>(lateFeeBoxName);
}
