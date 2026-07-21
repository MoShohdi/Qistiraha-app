import 'package:flutter/material.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';
import 'package:qistiraha/features/consumer/screens/consumer_dashboard_desktop.dart';
import 'package:qistiraha/features/merchant/screens/merchant_dashboard_desktop.dart';
import '../models/user_role.dart';
import '../widgets/role_toggle.dart';
import 'signup_screen.dart';

const _kBrandDark = Color(0xFF5A75AD);
const _kBg = Color(0xFFF8F9FA);

/// Desktop/web split-screen login — replaces the mobile Welcome→Login
/// two-step flow with a single modern page: a branded panel on the left,
/// the sign-in form in a clean white card on the right. Reached directly
/// from boot via `ResponsiveLayout` when not logged in, so a successful
/// sign-in goes straight to the desktop dashboards (no need to re-check
/// screen width — we're already on desktop by construction).
class LoginScreenDesktop extends StatefulWidget {
  const LoginScreenDesktop({super.key});

  @override
  State<LoginScreenDesktop> createState() => _LoginScreenDesktopState();
}

class _LoginScreenDesktopState extends State<LoginScreenDesktop> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  UserRole _selectedRole = UserRole.consumer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    final success = await AuthService.signInWithEmail(
      _emailController.text,
      _passwordController.text,
      role: _selectedRole,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => _selectedRole == UserRole.merchant
              ? const MerchantDashboardDesktop()
              : const ConsumerDashboardDesktop(),
        ),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please check your credentials.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _BrandPanel()),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome back',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Secure access to your Qistiraha installments',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        RoleToggle(
          selected: _selectedRole,
          onChanged: (role) => setState(() => _selectedRole = role),
        ),
        const SizedBox(height: 24),
        const Text(
          'Email or Phone Number',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            hintText: 'name@example.com',
            prefixIcon: const Icon(Icons.person_outline),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Password',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                'Forgot Password?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscureText,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 50,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Login',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: Colors.grey),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  );
                },
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kBrandDark, Color(0xFF1E2337)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Qistiraha',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Secure access to your installments and cash flow health.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.75), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
