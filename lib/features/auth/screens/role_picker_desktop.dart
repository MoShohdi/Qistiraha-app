import 'package:flutter/material.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../widgets/role_toggle.dart';
import '../../../main.dart';

const _kBg = Color(0xFFF8F9FA);

/// Desktop/web rendition of [RolePickerScreen] — same [RoleToggle],
/// [AuthService.completeRole] call, and destination routing, laid out as a
/// single centered card rather than a full split-panel page: this is a
/// brief interstitial step, not a marketing moment.
class RolePickerDesktopScreen extends StatefulWidget {
  const RolePickerDesktopScreen({super.key});

  @override
  State<RolePickerDesktopScreen> createState() =>
      _RolePickerDesktopScreenState();
}

class _RolePickerDesktopScreenState extends State<RolePickerDesktopScreen> {
  UserRole _selected = UserRole.consumer;
  bool _isLoading = false;

  Future<void> _confirm() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.completeRole(_selected);
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        showDesktopSnackBar(
          context,
          message: 'Could not save your choice. Please try again.',
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => destinationScreen(
          _selected == UserRole.merchant
              ? AuthDestination.merchantHome
              : AuthDestination.consumerHome,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'One last thing',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'How will you be using Qistiraha?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 28),
                RoleToggle(
                  selected: _selected,
                  onChanged: (role) => setState(() => _selected = role),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 50,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _confirm,
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
                              'Continue',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
