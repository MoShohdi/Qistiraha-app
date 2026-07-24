import 'package:flutter/material.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';
import '../widgets/google_sign_in_button.dart';

const _kBrandDark = Color(0xFF5A75AD);
const _kBg = Color(0xFFF8F9FA);

/// Desktop/web split-screen "Create Account" — the sibling of
/// [LoginScreenDesktop]. A branded gradient panel on the left, a constrained
/// (max 440px) form card on the right, so fields never stretch edge-to-edge
/// across a wide monitor. Same Supabase sign-up + Google logic as the mobile
/// [SignupScreen]; the root `onAuthStateChange` listener handles routing once
/// a session exists (new users land on the Role Picker).
class SignupScreenDesktop extends StatefulWidget {
  const SignupScreenDesktop({super.key});

  @override
  State<SignupScreenDesktop> createState() => _SignupScreenDesktopState();
}

class _SignupScreenDesktopState extends State<SignupScreenDesktop> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _obscure = true;

  bool get _busy => _isEmailLoading || _isGoogleLoading;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_passwordController.text != _confirmController.text) {
      showDesktopSnackBar(context, message: 'Passwords do not match.');
      return;
    }
    setState(() => _isEmailLoading = true);

    final error = await AuthService.signUpWithEmail(
      _nameController.text,
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() => _isEmailLoading = false);
      showDesktopSnackBar(context, message: error);
      return;
    }
    if (!AuthService.hasActiveSession) {
      // Email confirmation required by the project settings — no live session
      // for the listener to react to yet.
      setState(() => _isEmailLoading = false);
      showDesktopSnackBar(
        context,
        message: 'Check your email to confirm your account, then sign in.',
      );
      return;
    }
    // Session live — leave the spinner; the root listener routes to the Role
    // Picker (new users have no role yet).
  }

  Future<void> _handleGoogle() async {
    setState(() => _isGoogleLoading = true);
    bool launched = false;
    try {
      launched = await AuthService.signInWithGoogle();
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (!launched) {
      showDesktopSnackBar(
        context,
        message: 'Could not start Google sign-in. Please try again.',
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
                  constraints: const BoxConstraints(maxWidth: 440),
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
          'Create your account',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Track your installments and cash-flow health in one place.',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        _label('Full Name'),
        const SizedBox(height: 8),
        _field(
          controller: _nameController,
          hint: 'John Doe',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 20),
        _label('Email Address'),
        const SizedBox(height: 8),
        _field(
          controller: _emailController,
          hint: 'name@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        _label('Password'),
        const SizedBox(height: 8),
        _field(
          controller: _passwordController,
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: _obscure,
          suffix: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _label('Confirm Password'),
        const SizedBox(height: 8),
        _field(
          controller: _confirmController,
          hint: '••••••••',
          icon: Icons.lock_outline,
          obscure: _obscure,
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 50,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: ElevatedButton(
              onPressed: _busy ? null : _handleSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isEmailLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const AuthDivider(),
        const SizedBox(height: 24),
        GoogleSignInButton(
          onPressed: _busy ? null : _handleGoogle,
          isLoading: _isGoogleLoading,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Already have an account?',
              style: TextStyle(color: Colors.grey),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: !_busy,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
                'Join Qistiraha',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Every installment, due date, and cash-flow signal — organized, and always in sync.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
