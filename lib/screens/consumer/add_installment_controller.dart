import 'package:uuid/uuid.dart';
import '../../models/installment.dart';
import '../../models/user_account.dart';
import '../../models/enums.dart';
import '../../services/hive_service.dart';

/// Business logic controller for the Add Installment flow.
///
/// Responsibilities:
///   - Monthly payment calculation (pure math, no Flutter dependencies)
///   - Form field validation logic
///   - Hive persistence (creating and linking the new [Installment])
///
/// The UI screen ([AddInstallmentScreen]) owns all widget state (text controllers,
/// form key, navigation) and calls into this controller for any non-UI work.
class AddInstallmentController {
  const AddInstallmentController();

  // ---------------------------------------------------------------------------
  // Calculation
  // ---------------------------------------------------------------------------

  /// Calculates the monthly installment payment given the loan parameters.
  /// Returns 0.0 if [totalMonths] is 0 or less.
  double calculateMonthly({
    required double totalAmount,
    required double downPayment,
    required int totalMonths,
    required double interestRatePercent,
  }) {
    if (totalMonths <= 0) return 0.0;
    double principal = totalAmount - downPayment;
    double totalWithInterest = principal * (1 + (interestRatePercent / 100));
    return totalWithInterest / totalMonths;
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? validatePositiveNumber(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null; // optional fields
    final n = double.tryParse(value);
    if (n == null) return '$fieldName must be a number';
    if (n < 0) return '$fieldName must be positive';
    return null;
  }

  String? validatePositiveInt(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    final n = int.tryParse(value);
    if (n == null || n <= 0) return '$fieldName must be a whole number greater than 0';
    return null;
  }

  String? validateDate(DateTime? date) {
    if (date == null) return 'Please select a due date';
    return null;
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Creates a new [Installment], persists it to Hive, and links it to the
  /// current [UserAccount]. Returns the saved [Installment] instance.
  Future<Installment> saveInstallment({
    required String storeName,
    required String itemDescription,
    required double totalAmount,
    required int totalMonths,
    required double monthlyPayment,
    required DateTime dueDate,
    required double downPayment,
    required double interestRate,
    required String category,
  }) async {
    final userBox = HiveService.getUserBox();
    if (userBox.isEmpty) {
      throw StateError('No user account found. Cannot save installment.');
    }

    UserAccount user = userBox.values.first;

    final newInstallment = Installment(
      id: const Uuid().v4(),
      amount: totalAmount,
      merchantName: storeName,
      itemDescription: itemDescription,
      dueDate: dueDate,
      totalMonths: totalMonths,
      paidMonths: 0,
      status: InstallmentStatus.active.raw,
      monthlyPayment: monthlyPayment,
      downPayment: downPayment,
      interestRate: interestRate,
      category: category,
    );

    final installmentBox = HiveService.getInstallmentBox();
    await installmentBox.add(newInstallment);

    user.installments?.add(newInstallment);
    await user.save();

    return newInstallment;
  }
}
