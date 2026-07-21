import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import 'package:qistiraha/features/auth/models/user_account.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';
import 'package:qistiraha/features/auth/screens/welcome_screen.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'add_installment_screen.dart';
import 'installment_details_screen.dart';

const _kBrand = Color(0xFF99AFD7);
const _kBrandDark = Color(0xFF5A75AD);
const _kBg = Color(0xFFF8F9FA);

enum _ConsumerNav { installments, history }

/// Desktop/web shell for the consumer side — a clean top app bar (logo,
/// section nav, add-installment action, profile menu) instead of a bottom
/// tab bar, and a centered master-detail dashboard instead of pushed pages.
/// The detail pane reuses the actual [InstallmentDetailsScreen] (embedded
/// via [EmbeddedScreen]) so payment actions, the timeline, and the
/// merchant-linked delete rule all behave identically to mobile.
class ConsumerDashboardDesktop extends StatefulWidget {
  const ConsumerDashboardDesktop({super.key});

  @override
  State<ConsumerDashboardDesktop> createState() =>
      _ConsumerDashboardDesktopState();
}

class _ConsumerDashboardDesktopState extends State<ConsumerDashboardDesktop> {
  final _listController = ScrollController();
  final _currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
  _ConsumerNav _nav = _ConsumerNav.installments;
  Installment? _selected;

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  void _selectNav(_ConsumerNav nav) {
    setState(() {
      _nav = nav;
      _selected = null;
    });
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveService.getUserBox().listenable(),
      builder: (context, Box<UserAccount> userBox, _) {
        if (userBox.isEmpty) {
          return const Scaffold(
            backgroundColor: _kBg,
            body: Center(child: Text('No user data found.')),
          );
        }
        final user = userBox.values.first;

        return ValueListenableBuilder(
          valueListenable: HiveService.getInstallmentBox().listenable(),
          builder: (context, Box<Installment> installmentBox, _) {
            final all = user.installments?.toList() ?? <Installment>[];

            return Scaffold(
              backgroundColor: _kBg,
              appBar: _TopBar(
                nav: _nav,
                onSelectNav: _selectNav,
                onAddInstallment: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddInstallmentScreen(),
                    ),
                  );
                },
                userName: user.name,
                onLogout: () => _logout(context),
              ),
              body: _buildBody(all),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(List<Installment> all) {
    final active =
        all.where((i) => i.statusEnum != InstallmentStatus.paid).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final paid =
        all.where((i) => i.statusEnum == InstallmentStatus.paid).toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    final totalOutstanding = active.fold(
      0.0,
      (sum, i) => sum + ((i.totalPayments - i.paidPayments) * i.monthlyPayment),
    );
    final nextDue = active.isNotEmpty ? active.first : null;

    final list = _nav == _ConsumerNav.installments ? active : paid;
    final emptyMessage = _nav == _ConsumerNav.installments
        ? 'No active installments yet.'
        : 'No paid installments yet.';

    return DesktopCenteredContent(
      maxWidth: 1000,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryCard(
              totalOutstanding: totalOutstanding,
              nextDue: nextDue,
              currency: _currency,
            ),
            const SizedBox(height: 28),
            Text(
              _nav == _ConsumerNav.installments ? 'My Installments' : 'History',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              emptyMessage,
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          )
                        : Scrollbar(
                            controller: _listController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _listController,
                              padding: const EdgeInsets.only(
                                right: 12,
                                bottom: 12,
                              ),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final inst = list[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _ConsumerInstallmentCard(
                                    installment: inst,
                                    currency: _currency,
                                    selected: _selected?.id == inst.id,
                                    onTap: () =>
                                        setState(() => _selected = inst),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _selected == null
                          ? const DesktopEmptyDetail(
                              icon: Icons.receipt_long_outlined,
                              message: 'Select an installment to view details',
                            )
                          : EmbeddedScreen(
                              key: ValueKey('installment-${_selected!.id}'),
                              child: InstallmentDetailsScreen(
                                installment: _selected!,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------
class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final _ConsumerNav nav;
  final ValueChanged<_ConsumerNav> onSelectNav;
  final VoidCallback onAddInstallment;
  final VoidCallback onLogout;
  final String userName;

  const _TopBar({
    required this.nav,
    required this.onSelectNav,
    required this.onAddInstallment,
    required this.onLogout,
    required this.userName,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _kBrand,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Qistiraha',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                _NavTextButton(
                  label: 'My Installments',
                  selected: nav == _ConsumerNav.installments,
                  onTap: () => onSelectNav(_ConsumerNav.installments),
                ),
                const SizedBox(width: 4),
                _NavTextButton(
                  label: 'History',
                  selected: nav == _ConsumerNav.history,
                  onTap: () => onSelectNav(_ConsumerNav.history),
                ),
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton.icon(
                    onPressed: onAddInstallment,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add Installment',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: PopupMenuButton<String>(
                    tooltip: 'Profile',
                    offset: const Offset(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text(
                          userName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, size: 18, color: Colors.red),
                            SizedBox(width: 10),
                            Text(
                              'Log Out',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'logout') onLogout();
                    },
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.grey[200],
                      child: const Icon(
                        Icons.person,
                        color: Colors.black54,
                        size: 18,
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

class _NavTextButton extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _NavTextButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavTextButton> createState() => _NavTextButtonState();
}

class _NavTextButtonState extends State<_NavTextButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final Color color = widget.selected
        ? _kBrandDark
        : (_hovering ? Colors.black87 : Colors.grey[600]!);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontWeight: widget.selected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------
class _SummaryCard extends StatelessWidget {
  final double totalOutstanding;
  final Installment? nextDue;
  final NumberFormat currency;

  const _SummaryCard({
    required this.totalOutstanding,
    required this.nextDue,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kBrand, _kBrandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Outstanding',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currency.format(totalOutstanding),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 56, color: Colors.white24),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Payment Due',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  nextDue == null
                      ? 'Nothing due'
                      : '${currency.format(nextDue!.monthlyPayment)} • ${DateFormat('dd MMM').format(nextDue!.dueDate)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Installment card (list side of the master-detail)
// ---------------------------------------------------------------------------
class _ConsumerInstallmentCard extends StatelessWidget {
  final Installment installment;
  final NumberFormat currency;
  final bool selected;
  final VoidCallback onTap;

  const _ConsumerInstallmentCard({
    required this.installment,
    required this.currency,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    switch (installment.statusEnum) {
      case InstallmentStatus.overdue:
        statusColor = Colors.red;
        statusLabel = 'Overdue';
        break;
      case InstallmentStatus.paid:
        statusColor = Colors.green;
        statusLabel = 'Paid';
        break;
      case InstallmentStatus.defaulted:
        statusColor = Colors.red[900]!;
        statusLabel = 'Defaulted';
        break;
      case InstallmentStatus.active:
        statusColor = _kBrand;
        statusLabel = 'Active';
        break;
    }

    return DesktopHoverCard(
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    installment.merchantName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (installment.itemDescription.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                installment.itemDescription,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${installment.paidPayments} of ${installment.totalPayments} paid',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  currency.format(installment.monthlyPayment),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: installment.totalPayments > 0
                    ? installment.paidPayments / installment.totalPayments
                    : 0.0,
                backgroundColor: Colors.grey[200],
                color: statusColor,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
