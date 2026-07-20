import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:qistiraha/features/auth/models/user_account.dart';
import 'package:qistiraha/features/auth/models/business_account.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'hive_service.dart';
import 'time_service.dart';

class MockDataService {
  static Future<void> populateMockData() async {
    final userBox = HiveService.getUserBox();
    final businessBox = HiveService.getBusinessBox();
    final installmentBox = HiveService.getInstallmentBox();
    // Clear data to enforce the new mock data structure
    await userBox.clear();
    await businessBox.clear();
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
      provider: 'B. TECH (Minicash)',
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
      provider: 'Contact Financial Holding',
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
      provider: 'valU',
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
      provider: 'Sympl',
    );

    var inst5 = Installment(
      id: uuid.v4(),
      amount: 600000.0,
      merchantName: 'Toyota',
      itemDescription: 'Corolla 2024',
      dueDate: TimeService.now().add(const Duration(days: 15)),
      totalMonths: 60,
      paidMonths: 5,
      status: 'Active',
      monthlyPayment: 10000.0,
      category: 'Automotive',
      isLongTerm: true,
      paymentFrequency: 'Monthly',
      provider: 'QNB (Qatar National Bank Egypt)',
    );

    var inst6 = Installment(
      id: uuid.v4(),
      amount: 3000000.0,
      merchantName: 'Palm Hills',
      itemDescription: 'Villa Down Payment',
      dueDate: TimeService.now().add(const Duration(days: 20)),
      totalMonths: 60, // 5 years
      paidMonths: 12, // 1 year
      status: 'Active',
      monthlyPayment: 37500.0, // Per quarter
      category: 'Real Estate',
      isLongTerm: true,
      paymentFrequency: 'Quarterly',
      provider: 'Housing & Development Bank (HDB)',
    );

    await installmentBox.addAll([inst1, inst2, inst3, inst4, inst5, inst6]);

    // Create user
    var user = UserAccount(
      name: 'Mo',
      monthlyIncome: 5000.0,
      // We will link the installments
    );

    await userBox.add(user);

    // Link installments to user
    user.installments = HiveList(
      installmentBox,
      objects: [inst1, inst2, inst3, inst4, inst5, inst6],
    );
    await user.save();

    // Create Merchant Mock Data
    var bInst1 = Installment(
      id: uuid.v4(),
      amount: 12000,
      merchantName: 'B.TECH',
      itemDescription: 'Samsung Refrigerator',
      dueDate: TimeService.now().add(const Duration(days: 10)),
      totalMonths: 12,
      paidMonths: 4,
      status: InstallmentStatus.active.raw,
      monthlyPayment: 1000,
      downPayment: 0,
      interestRate: 0,
      category: 'Electronics',
      isLongTerm: true,
      paymentFrequency: 'Monthly',
      lender: 'Valu',
      provider: 'Valu',
    );
    
    var bInst2 = Installment(
      id: uuid.v4(),
      amount: 4500,
      merchantName: 'B.TECH',
      itemDescription: 'Microwave Oven',
      dueDate: TimeService.now().subtract(const Duration(days: 2)),
      totalMonths: 6,
      paidMonths: 2,
      status: InstallmentStatus.overdue.raw,
      monthlyPayment: 750,
      downPayment: 0,
      interestRate: 0,
      category: 'Electronics',
      isLongTerm: false,
      paymentFrequency: 'Monthly',
      lender: 'Sympl',
      provider: 'Sympl',
    );

    var bInst3 = Installment(
      id: uuid.v4(),
      amount: 8000,
      merchantName: 'B.TECH',
      itemDescription: 'Smart TV 55"',
      dueDate: TimeService.now().add(const Duration(days: 20)),
      totalMonths: 24,
      paidMonths: 24,
      status: InstallmentStatus.paid.raw,
      monthlyPayment: 333.33,
      downPayment: 0,
      interestRate: 0,
      category: 'Electronics',
      isLongTerm: true,
      paymentFrequency: 'Monthly',
      lender: 'AMAN Holding',
      provider: 'AMAN Holding',
    );

    await installmentBox.addAll([bInst1, bInst2, bInst3]);

    var business = BusinessAccount(
      id: uuid.v4(),
      businessName: 'B.TECH',
      category: 'Electronics & Home Appliances',
    );
    await businessBox.add(business);

    business.sentQists = HiveList(
      installmentBox,
      objects: [bInst1, bInst2, bInst3],
    );
    await business.save();
  }
}
