import 'package:hive_flutter/hive_flutter.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/auth/models/user_account.dart';
import 'package:qistiraha/features/auth/models/business_account.dart';

class HiveService {
  static const String userBoxName = 'userBox';
  static const String businessBoxName = 'businessBox';
  static const String installmentBoxName = 'installmentBox';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(InstallmentAdapter());
    Hive.registerAdapter(UserAccountAdapter());
    Hive.registerAdapter(BusinessAccountAdapter());

    // Open Boxes
    await Hive.openBox<UserAccount>(userBoxName);
    await Hive.openBox<BusinessAccount>(businessBoxName);
    await Hive.openBox<Installment>(installmentBoxName);
  }

  static Box<UserAccount> getUserBox() => Hive.box<UserAccount>(userBoxName);
  static Box<BusinessAccount> getBusinessBox() =>
      Hive.box<BusinessAccount>(businessBoxName);
  static Box<Installment> getInstallmentBox() =>
      Hive.box<Installment>(installmentBoxName);
}
