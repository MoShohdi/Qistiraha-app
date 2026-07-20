import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:qistiraha/features/auth/models/business_account.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'hive_service.dart';
import 'time_service.dart';

/// Seeds a demo [BusinessAccount] with a handful of customer installments so
/// the Merchant Dashboard has data to show in the beta build.
///
/// Unlike [MockDataService.populateMockData], this is additive: it never
/// clears the consumer's boxes, since a single local Hive database on this
/// device may hold both a consumer identity and a merchant identity during
/// the beta (dev-bypass only).
class MockMerchantDataService {
  static Future<BusinessAccount> populateMockData() async {
    final businessBox = HiveService.getBusinessBox();

    if (businessBox.isNotEmpty) {
      final existingBusiness = businessBox.values.first;
      final installmentBox = HiveService.getInstallmentBox();
      final hasInstallments = installmentBox.values.any((i) => i.merchantId == existingBusiness.id);
      if (hasInstallments) {
        return existingBusiness;
      }
      // If the business exists but installments were wiped by another service,
      // clear it so we can cleanly recreate both.
      await businessBox.clear();
    }

    const uuid = Uuid();
    final installmentBox = HiveService.getInstallmentBox();
    final businessId = uuid.v4();

    final business = BusinessAccount(
      businessName: 'Nour Boutique',
      category: 'Fashion',
      id: businessId,
    );
    await businessBox.add(business);

    final sentInstallments = <Installment>[
      Installment(
        id: uuid.v4(),
        amount: 1800.0,
        merchantName: business.businessName,
        itemDescription: 'Winter Abaya Set',
        dueDate: TimeService.now().add(const Duration(days: 5)),
        totalMonths: 3,
        paidMonths: 1,
        status: InstallmentStatus.active.raw,
        monthlyPayment: 600.0,
        category: 'Fashion',
        merchantId: businessId,
        customerName: 'Rana Adel',
        customerPhone: '+201001234567',
      ),
      Installment(
        id: uuid.v4(),
        amount: 2400.0,
        merchantName: business.businessName,
        itemDescription: 'Custom Tailored Suit',
        dueDate: TimeService.now().subtract(const Duration(days: 4)),
        totalMonths: 4,
        paidMonths: 1,
        status: InstallmentStatus.overdue.raw,
        monthlyPayment: 600.0,
        category: 'Fashion',
        merchantId: businessId,
        customerName: 'Kareem Hassan',
        customerPhone: '+201009876543',
      ),
      Installment(
        id: uuid.v4(),
        amount: 900.0,
        merchantName: business.businessName,
        itemDescription: 'Evening Dress',
        dueDate: TimeService.now().add(const Duration(days: 20)),
        totalMonths: 3,
        paidMonths: 3,
        status: InstallmentStatus.paid.raw,
        monthlyPayment: 300.0,
        category: 'Fashion',
        merchantId: businessId,
        customerName: 'Rana Adel',
        customerPhone: '+201001234567',
      ),
      Installment(
        id: uuid.v4(),
        amount: 1500.0,
        merchantName: business.businessName,
        itemDescription: 'Wedding Guest Outfit',
        dueDate: TimeService.now().add(const Duration(days: 12)),
        totalMonths: 5,
        paidMonths: 0,
        status: InstallmentStatus.active.raw,
        monthlyPayment: 300.0,
        category: 'Fashion',
        merchantId: businessId,
        customerName: 'Salma Tarek',
        customerPhone: '+201112223344',
      ),
    ];

    await installmentBox.addAll(sentInstallments);
    business.sentQists = HiveList(installmentBox, objects: sentInstallments);
    await business.save();

    return business;
  }
}
