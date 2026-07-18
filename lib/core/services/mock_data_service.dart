import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:qistiraha/features/auth/models/user_account.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'hive_service.dart';
import 'time_service.dart';

class MockDataService {
  static Future<void> populateMockData() async {
    final userBox = HiveService.getUserBox();
    final installmentBox = HiveService.getInstallmentBox();
    // Clear data to enforce the new mock data structure
    await userBox.clear();
    await installmentBox.clear();

    var uuid = const Uuid();

    // Create some installments
    var inst1 = Installment(
      id: uuid.v4(),
      amount: 1200.0,
      merchantName: 'Tech Haven',
      itemDescription: 'Samsung Galaxy S24 Ultra',
      dueDate: TimeService.now().add(const Duration(days: 3)),
      totalMonths: 12,
      paidMonths: 4,
      status: 'Active',
      monthlyPayment: 100.0,
      category: 'Electronics',
    );

    var inst2 = Installment(
      id: uuid.v4(),
      amount: 400.0,
      merchantName: 'Home Essentials',
      itemDescription: 'Philips Air Fryer XXL',
      dueDate: TimeService.now().add(const Duration(days: 5)), 
      totalMonths: 4,
      paidMonths: 2,
      status: 'Active',
      monthlyPayment: 100.0,
      category: 'Home Essentials',
    );

    var inst3 = Installment(
      id: uuid.v4(),
      amount: 750.0,
      merchantName: 'Fashion Hub',
      itemDescription: 'Zara Winter Collection',
      dueDate: TimeService.now().add(const Duration(days: 10)),
      totalMonths: 5,
      paidMonths: 3,
      status: 'Active',
      monthlyPayment: 150.0,
      category: 'Fashion',
    );

    var inst4 = Installment(
      id: uuid.v4(),
      amount: 4000.0,
      merchantName: 'EGO',
      itemDescription: 'Dior Sauvage Parfum',
      dueDate: TimeService.now().subtract(const Duration(days: 1)),
      totalMonths: 10,
      paidMonths: 1,
      status: 'Overdue',
      monthlyPayment: 400.0,
      category: 'Fashion',
    );

    await installmentBox.addAll([inst1, inst2, inst3, inst4]);

    // Create user
    var user = UserAccount(
      name: 'Mo',
      monthlyIncome: 5000.0,
      // We will link the installments
    );

    await userBox.add(user);

    // Link installments to user
    user.installments = HiveList(installmentBox, objects: [inst1, inst2, inst3, inst4]);
    await user.save();
  }
}
