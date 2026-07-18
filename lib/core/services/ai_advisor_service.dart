import 'package:google_generative_ai/google_generative_ai.dart';
import 'hive_service.dart';
import 'package:qistiraha/features/auth/models/user_account.dart';

class AIAdvisorService {
  // Note: Replace with your actual API key, or define it via --dart-define=GEMINI_API_KEY=your_key
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_API_KEY_HERE');
  late final GenerativeModel _model;

  AIAdvisorService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: _apiKey,
    );
  }

  Future<String> askAdvisor(String userPrompt) async {
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      return "Hello! I am your AI financial advisor. Please add your Gemini API key to use my full capabilities.";
    }

    try {
      final userBox = HiveService.getUserBox();
      if (userBox.isEmpty) {
        return "I couldn't find your financial data to advise you on.";
      }
      
      UserAccount user = userBox.values.first;
      String financialContext = _buildFinancialContext(user);
      
      String fullPrompt = "You are an AI financial advisor named Qistiraha AI. "
          "Here is the user's financial context:\n$financialContext\n\n"
          "The user asks: $userPrompt\n"
          "Provide a concise, helpful, and professional financial advice.";
          
      final content = [Content.text(fullPrompt)];
      final response = await _model.generateContent(content);
      
      return response.text ?? "I'm sorry, I couldn't generate a response at this time.";
    } catch (e) {
      return "An error occurred while connecting to the AI advisor: $e";
    }
  }

  String _buildFinancialContext(UserAccount user) {
    double totalIncome = user.monthlyIncome;
    double totalDebt = 0;
    double monthlyPayments = 0;
    
    if (user.installments != null) {
      for (var inst in user.installments!) {
        if (inst.status != 'Paid') {
          totalDebt += (inst.totalMonths - inst.paidMonths) * inst.monthlyPayment;
          monthlyPayments += inst.monthlyPayment;
        }
      }
    }
    
    return "User: ${user.name}\n"
           "Monthly Income: $totalIncome EGP\n"
           "Total Outstanding Debt: $totalDebt EGP\n"
           "Total Monthly Installment Payments: $monthlyPayments EGP\n"
           "Remaining Budget: ${totalIncome - monthlyPayments} EGP";
  }
}
