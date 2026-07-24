import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';
import '../../../main.dart';

const _kBrand = Color(0xFF99AFD7);

/// Consumer end of the merchant→consumer handshake. Reached by opening a
/// `qistiraha://installment/<id>` link (QR scan or WhatsApp tap). Fetches
/// that Supabase row, shows a preview, and on confirm runs the RLS-guarded
/// claim (`consumer_id = auth.uid()`, status → `active`). Because both
/// dashboards subscribe to `DatabaseService` streams, the claim lands on the
/// merchant's screen and this consumer's screen in real time — no refresh.
class ClaimInstallmentScreen extends StatefulWidget {
  final String installmentId;
  const ClaimInstallmentScreen({super.key, required this.installmentId});

  @override
  State<ClaimInstallmentScreen> createState() => _ClaimInstallmentScreenState();
}

class _ClaimInstallmentScreenState extends State<ClaimInstallmentScreen> {
  final _currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);

  bool _loading = true;
  bool _claiming = false;
  String? _error;
  InstallmentRow? _row;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await DatabaseService.fetchInstallment(widget.installmentId);
      if (!mounted) return;
      setState(() {
        _row = row;
        _loading = false;
        if (row == null) {
          _error = 'This installment link is no longer available.';
        } else if (!row.isPending) {
          _error = 'This installment has already been claimed.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this installment. Check your connection.';
      });
    }
  }

  Future<void> _confirm() async {
    setState(() => _claiming = true);
    bool ok;
    try {
      ok = await DatabaseService.claimInstallment(widget.installmentId);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _claiming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not claim this installment. It may already be taken.',
          ),
        ),
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_row?.itemDescription ?? 'Installment'} added!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Declines the offer and cleans up the unclaimed draft in Supabase so it
  /// doesn't linger. Best-effort — a cleanup failure still closes the screen.
  Future<void> _decline() async {
    if (_row != null && _row!.isPending) {
      try {
        await DatabaseService.declineInstallment(widget.installmentId);
      } catch (_) {
        // Non-fatal: the draft stays, but the user still leaves the screen.
      }
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: const Text(
          'New Installment Plan',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // A signed-out user can't claim (RLS needs auth.uid()) — send them to
    // sign in first; the link can be reopened afterwards.
    if (!AuthService.hasActiveSession) {
      return _message(
        icon: Icons.lock_outline,
        title: 'Sign in to claim this plan',
        actionLabel: 'Go to Sign In',
        onAction: () => Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destinationScreen(AuthDestination.loggedOut)),
          (route) => false,
        ),
      );
    }

    if (_error != null || _row == null) {
      return _message(
        icon: Icons.link_off,
        title: _error ?? 'Something went wrong.',
        actionLabel: 'Close',
        onAction: () => Navigator.pop(context),
      );
    }

    final row = _row!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _kBrand.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront, color: _kBrand),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'A merchant shared this installment plan with you',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _detail('Item', row.itemDescription),
                _detail('Total', _currency.format(row.totalAmount)),
                _detail('Term', '${row.totalMonths} months'),
                _detail(row.paymentFrequencyLabel, _currency.format(row.monthlyPayment)),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: _claiming ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _claiming
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Claim this installment',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _claiming ? null : _decline,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Decline', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    ),
  );

  Widget _message({
    required IconData icon,
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _kBrand),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
