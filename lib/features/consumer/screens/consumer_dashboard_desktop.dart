import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/engine/affordability_live.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';
import 'package:qistiraha/features/auth/screens/welcome_screen.dart';
import 'package:qistiraha/features/auth/screens/login_screen_desktop.dart';
import 'package:qistiraha/widgets/branded_bar_chart_card.dart';
import 'package:qistiraha/widgets/stream_error_view.dart';
import 'add_installment_desktop.dart';

const _kBrand = Color(0xFF99AFD7);
const _kBrandDark = Color(0xFF5A75AD);
const _kBg = Color(0xFFF8F9FA);
const _kSidebarWidth = 260.0;

enum _ConsumerNav { overview, history, insights }

class _StatusMeta {
  final Color color;
  final String label;
  const _StatusMeta(this.color, this.label);
}

/// Status chip for a live installment row. Overdue is derived from the due
/// date (no penalty state); completed maps to "Paid".
_StatusMeta _statusMeta(InstallmentRow row) {
  if (row.isCompleted) return const _StatusMeta(Colors.green, 'Paid');
  if (row.isOverdue) return const _StatusMeta(Colors.red, 'Overdue');
  return const _StatusMeta(_kBrand, 'Active');
}

/// Effective monthly amount for a plan — quarterly/semi-annual/annual plans
/// contribute their fair per-month share instead of spiking a single bucket.
double _normalizedMonthlyAmount(InstallmentRow i) => i.monthlyDrain;

double _totalPaidSoFar(InstallmentRow i) {
  if (i.pastPayments.isNotEmpty) {
    return i.pastPayments.fold(0.0, (a, b) => a + b);
  }
  return i.paidPayments * i.monthlyPayment;
}

Color _affordabilityDotColor(AffordabilityStatus status) {
  switch (status) {
    case AffordabilityStatus.green:
      return Colors.green;
    case AffordabilityStatus.yellow:
      return Colors.amber;
    case AffordabilityStatus.red:
      return Colors.red;
  }
}

/// Mirrors the mobile Insights screen's spend-tier tagging exactly (same
/// thresholds/colors) so the desktop Income Bar and Spend Advisor read
/// identically to mobile. Duplicated locally since the mobile version is
/// private to `insights_screen.dart`.
class _BudgetStatus {
  final String label;
  final Color tierColor;
  final Color bgColor;
  final String tierName;

  const _BudgetStatus({
    required this.label,
    required this.tierColor,
    required this.bgColor,
    required this.tierName,
  });
}

_BudgetStatus _getBudgetStatus(double pct) {
  if (pct <= 0.30) {
    return const _BudgetStatus(
      label: 'Safe-to-Spend',
      tierColor: Color(0xFF2ECC71),
      bgColor: Color(0xFFF0FDF4),
      tierName: 'Optimized',
    );
  } else if (pct <= 0.50) {
    return const _BudgetStatus(
      label: 'Watch-Your-Spend',
      tierColor: Color(0xFFE67E22),
      bgColor: Color(0xFFFFF8F0),
      tierName: 'Mindful',
    );
  } else {
    return const _BudgetStatus(
      label: 'Limit-Your-Spend',
      tierColor: Color(0xFFE74C3C),
      bgColor: Color(0xFFFFF0F0),
      tierName: 'Critical',
    );
  }
}

/// Desktop/web shell for the consumer side — a fixed sidebar (identity, the
/// primary "Add Installment" action, and section navigation) replaces the
/// mobile bottom-nav/top-appbar entirely. The main content reflows per
/// section: a KPI + grid dashboard for Overview, a completed-plans grid for
/// History, and a personal finance Insights dashboard. Clicking any
/// installment card opens a wide, dual-column detail dialog (Payment
/// Timeline / Merchant & Debt Breakdown) instead of squeezing the mobile
/// detail screen into a narrow pane.
class ConsumerDashboardDesktop extends StatefulWidget {
  const ConsumerDashboardDesktop({super.key});

  @override
  State<ConsumerDashboardDesktop> createState() =>
      _ConsumerDashboardDesktopState();
}

class _ConsumerDashboardDesktopState extends State<ConsumerDashboardDesktop> {
  final _currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
  _ConsumerNav _nav = _ConsumerNav.overview;

  // Income/salary/name now live on the Supabase profile, not Hive. Fetched
  // once at mount (and again after an income edit); the installment list
  // itself streams live via DatabaseService.consumerInstallments().
  double _income = 0;
  int _salaryDay = 1;
  String _name = '';
  bool _profileLoaded = false;

  // Created once — recreating it in build() resubscribed on every rebuild.
  // Not `final` so [_retry] can rebuild it after an error.
  Stream<List<InstallmentRow>> _installmentsStream =
      DatabaseService.consumerInstallments();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    ProfileFinance p;
    try {
      p = await DatabaseService.profileFinance();
    } catch (_) {
      p = const ProfileFinance();
    }
    if (!mounted) return;
    setState(() {
      _income = p.monthlyIncome;
      _salaryDay = p.salaryDay;
      _name = p.name;
      _profileLoaded = true;
    });
  }

  /// Rebuilds the realtime subscription and re-fetches the profile — wired to
  /// the Retry button shown when the stream errors.
  void _retry() {
    setState(() {
      _profileLoaded = false;
      _installmentsStream = DatabaseService.consumerInstallments();
    });
    _loadProfile();
  }

  Future<void> _editIncome() async {
    final incomeController = TextEditingController(
      text: _income > 0 ? _income.toStringAsFixed(0) : '',
    );
    int pendingSalaryDay = _salaryDay;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Income & Payday'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Income',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: incomeController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixText: 'EGP ',
                  hintText: '0',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Payday (day your salary lands)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: pendingSalaryDay,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (int d = 1; d <= 28; d++)
                    DropdownMenuItem(value: d, child: Text('Day $d')),
                ],
                onChanged: (v) => setDialogState(
                  () => pendingSalaryDay = v ?? pendingSalaryDay,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final income = double.tryParse(incomeController.text) ?? _income;
    await DatabaseService.updateIncome(income, salaryDay: pendingSalaryDay);
    await _loadProfile();
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const ResponsiveLayout(
            mobileWidget: WelcomeScreen(),
            desktopWidget: LoginScreenDesktop(),
          ),
        ),
        (route) => false,
      );
    }
  }

  void _openDetail(InstallmentRow installment) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _ConsumerDetailDialog(installment: installment),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InstallmentRow>>(
      stream: _installmentsStream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <InstallmentRow>[];
        final hasError = snapshot.hasError;
        final loading = !_profileLoaded || !snapshot.hasData;

        return Scaffold(
          backgroundColor: _kBg,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(
                userName: _name.isEmpty ? 'You' : _name,
                nav: _nav,
                onSelectNav: (n) => setState(() => _nav = n),
                onAddInstallment: () => showAddInstallmentModal(context),
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: hasError
                    ? StreamErrorView(onRetry: _retry)
                    : (loading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildMainContent(all)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent(List<InstallmentRow> all) {
    switch (_nav) {
      case _ConsumerNav.overview:
        final active = all.where((i) => !i.isCompleted).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return _OverviewTab(
          income: _income,
          salaryDay: _salaryDay,
          allInstallments: all,
          activeInstallments: active,
          currency: _currency,
          onSelectInstallment: _openDetail,
        );
      case _ConsumerNav.history:
        final paid = all.where((i) => i.isCompleted).toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
        return _HistoryTab(
          paidInstallments: paid,
          currency: _currency,
          onSelectInstallment: _openDetail,
        );
      case _ConsumerNav.insights:
        return _InsightsTab(
          income: _income,
          salaryDay: _salaryDay,
          installments: all,
          currency: _currency,
          onEditIncome: _editIncome,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------
class _Sidebar extends StatelessWidget {
  final String userName;
  final _ConsumerNav nav;
  final ValueChanged<_ConsumerNav> onSelectNav;
  final VoidCallback onAddInstallment;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.userName,
    required this.nav,
    required this.onSelectNav,
    required this.onAddInstallment,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final initial = userName.trim().isNotEmpty
        ? userName.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: _kSidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kBrand,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Qistiraha',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ElevatedButton.icon(
                    onPressed: onAddInstallment,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add Installment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2337),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Overview',
                    selected: nav == _ConsumerNav.overview,
                    onTap: () => onSelectNav(_ConsumerNav.overview),
                  ),
                  _NavItem(
                    icon: Icons.history,
                    label: 'History',
                    selected: nav == _ConsumerNav.history,
                    onTap: () => onSelectNav(_ConsumerNav.history),
                  ),
                  _NavItem(
                    icon: Icons.insights_outlined,
                    label: 'Insights',
                    selected: nav == _ConsumerNav.insights,
                    onTap: () => onSelectNav(_ConsumerNav.insights),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _NavItem(
                icon: Icons.logout,
                label: 'Log Out',
                selected: false,
                onTap: onLogout,
                danger: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final Color fg = widget.danger
        ? Colors.red
        : (widget.selected ? Colors.white : Colors.black87);
    final Color bg = widget.selected
        ? _kBrand
        : (_hovering ? Colors.grey[100]! : Colors.transparent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(widget.icon, size: 19, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: widget.selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview — KPI row + active plans grid
// ---------------------------------------------------------------------------
class _OverviewTab extends StatefulWidget {
  final double income;
  final int salaryDay;
  final List<InstallmentRow> allInstallments;
  final List<InstallmentRow> activeInstallments;
  final NumberFormat currency;
  final ValueChanged<InstallmentRow> onSelectInstallment;

  const _OverviewTab({
    required this.income,
    required this.salaryDay,
    required this.allInstallments,
    required this.activeInstallments,
    required this.currency,
    required this.onSelectInstallment,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final _scrollController = ScrollController();
  final _costController = TextEditingController();
  final _downController = TextEditingController();
  final _monthsController = TextEditingController();
  SimulatedOutlook? _outlook;

  @override
  void initState() {
    super.initState();
    _costController.addListener(_runSimulation);
    _downController.addListener(_runSimulation);
    _monthsController.addListener(_runSimulation);
  }

  void _runSimulation() {
    final cost = double.tryParse(_costController.text);
    final months = int.tryParse(_monthsController.text);
    final downPayment = double.tryParse(_downController.text) ?? 0.0;
    if (cost == null || months == null || months <= 0) {
      setState(() => _outlook = null);
      return;
    }
    final outlook = LiveAffordabilityEngine.simulatePurchase(
      itemCost: cost,
      months: months,
      downPayment: downPayment,
      existing: widget.allInstallments,
      monthlyIncome: widget.income,
      salaryDay: widget.salaryDay,
    );
    setState(() => _outlook = outlook);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _costController.dispose();
    _downController.dispose();
    _monthsController.dispose();
    super.dispose();
  }

  Widget _buildSection({
    required String title,
    required List<InstallmentRow> sectionActive,
    required bool isLongTerm,
    required String debtFreeTitlePrefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        _SectionDebtFreeBanner(
          sectionActive: sectionActive,
          isLongTerm: isLongTerm,
          titlePrefix: debtFreeTitlePrefix,
        ),
        _SectionUrgentBanner(sectionActive: sectionActive),
        const SizedBox(height: 16),
        if (sectionActive.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No active installments in this section.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sectionActive.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisExtent: 196,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final inst = sectionActive[index];
              return _InstallmentGridCard(
                installment: inst,
                currency: widget.currency,
                onTap: () => widget.onSelectInstallment(inst),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.activeInstallments;
    final shortTermActive = active.where((i) => !i.isLongTerm).toList();
    final longTermActive = active.where((i) => i.isLongTerm).toList();

    final totalOutstanding = LiveAffordabilityEngine.totalOutstandingDebt(
      widget.allInstallments,
    );
    final monthlyPaymentThisMonth = LiveAffordabilityEngine.totalMonthlyPayment(
      widget.allInstallments,
    );
    final affordabilityStatus = LiveAffordabilityEngine.status(
      widget.allInstallments,
      widget.income,
    );
    final nextDue = active.isNotEmpty ? active.first : null;

    return DesktopCenteredContent(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ConsumerStatCard(
                        label: 'Total Outstanding',
                        value: widget.currency.format(totalOutstanding),
                        icon: Icons.account_balance_wallet_outlined,
                        color: _kBrandDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ConsumerStatCard(
                        label: 'Next Payment Due',
                        value: nextDue == null
                            ? 'Nothing due'
                            : '${widget.currency.format(nextDue.monthlyPayment)} • ${DateFormat('dd MMM').format(nextDue.dueDate)}',
                        icon: Icons.event_outlined,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ConsumerStatCard(
                        label: 'Monthly Commitment',
                        value: widget.currency.format(monthlyPaymentThisMonth),
                        icon: Icons.calendar_month_outlined,
                        color: _kBrand,
                        statusDotColor: _affordabilityDotColor(
                          affordabilityStatus,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _CheckoutCalculatorCard(
                        costController: _costController,
                        downController: _downController,
                        monthsController: _monthsController,
                        outlook: _outlook,
                        currency: widget.currency,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              _buildSection(
                title: 'Short-Term Obligations',
                sectionActive: shortTermActive,
                isLongTerm: false,
                debtFreeTitlePrefix: 'Retail Debt-Free',
              ),
              const SizedBox(height: 32),
              _buildSection(
                title: 'Long-Term Obligations',
                sectionActive: longTermActive,
                isLongTerm: true,
                debtFreeTitlePrefix: 'Asset Payoff Target',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsumerStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color? statusDotColor;

  const _ConsumerStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.statusDotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              if (statusDotColor != null)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusDotColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Checkout Calculator — desktop mini-widget version of the mobile "Checkout
// Advisor" what-if simulator. Uses AffordabilityEngine.simulatePurchase with
// the user's real installments/income, exactly like mobile.
// ---------------------------------------------------------------------------
class _CheckoutCalculatorCard extends StatelessWidget {
  final TextEditingController costController;
  final TextEditingController downController;
  final TextEditingController monthsController;
  final SimulatedOutlook? outlook;
  final NumberFormat currency;

  const _CheckoutCalculatorCard({
    required this.costController,
    required this.downController,
    required this.monthsController,
    required this.outlook,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    Color resultColor;
    IconData resultIcon;
    String resultText;

    final o = outlook;
    if (o == null) {
      resultColor = Colors.grey[500]!;
      resultIcon = Icons.calculate_outlined;
      resultText = 'Enter a cost to simulate';
    } else {
      switch (o.riskTier) {
        case RiskTier.safe:
          resultColor = Colors.green[700]!;
          resultIcon = Icons.check_circle_outline;
          resultText =
              'Affordable • ${currency.format(o.newSafeBuffer)} left/mo';
          break;
        case RiskTier.stretch:
          resultColor = Colors.orange[800]!;
          resultIcon = Icons.warning_amber_rounded;
          resultText =
              'Tight • ${(o.foir * 100).toStringAsFixed(0)}% of income';
          break;
        case RiskTier.danger:
          resultColor = Colors.red[700]!;
          resultIcon = Icons.error_outline;
          resultText =
              'Not recommended • ${(o.foir * 100).toStringAsFixed(0)}% of income';
          break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calculate_outlined,
                  color: Color(0xFF6366F1),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Checkout Calculator',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: _miniField(costController, 'Cost')),
              const SizedBox(width: 6),
              Expanded(flex: 2, child: _miniField(downController, 'Down')),
              const SizedBox(width: 6),
              Expanded(flex: 1, child: _miniField(monthsController, 'Mo.')),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(resultIcon, color: resultColor, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    resultText,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section status banners — Debt-Free ETA + urgent payment/overdue alert,
// mirroring the mobile Home screen's per-section (short/long-term) cards
// exactly (same AffordabilityEngine calls), restyled as
// full-width desktop banners instead of stacked mobile cards.
// ---------------------------------------------------------------------------
class _SectionDebtFreeBanner extends StatelessWidget {
  final List<InstallmentRow> sectionActive;
  final bool isLongTerm;
  final String titlePrefix;

  const _SectionDebtFreeBanner({
    required this.sectionActive,
    required this.isLongTerm,
    required this.titlePrefix,
  });

  @override
  Widget build(BuildContext context) {
    final debtFreeDate = LiveAffordabilityEngine.absoluteDebtFreeDate(
      sectionActive,
    );
    final now = TimeService.now();
    final isDebtFree = sectionActive.isEmpty;

    final String title;
    final String subtitle;
    final Color bgColor;
    final Color textColor;
    final IconData icon;

    if (isDebtFree) {
      title = 'No active ${isLongTerm ? 'long-term assets' : 'retail debt'}';
      subtitle =
          'All ${isLongTerm ? 'assets' : 'retail items'} are fully paid. Keep it up!';
      bgColor = const Color(0xFFF0FAF0);
      textColor = Colors.green[800]!;
      icon = Icons.celebration_outlined;
    } else {
      final formatted = DateFormat('MMMM yyyy').format(debtFreeDate);
      final totalMonths =
          ((debtFreeDate.year - now.year) * 12) +
          debtFreeDate.month -
          now.month;
      final timeAway = totalMonths <= 0
          ? 'this month'
          : '$totalMonths month${totalMonths == 1 ? '' : 's'} away';
      title = '$titlePrefix in $formatted';
      subtitle =
          'You will finish all ${isLongTerm ? 'assets' : 'retail installments'} in $formatted ($timeAway).';
      bgColor = const Color(0xFFF0F4FF);
      textColor = const Color(0xFF1E3A8A);
      icon = Icons.flag_outlined;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                    height: 1.4,
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

class _SectionUrgentBanner extends StatelessWidget {
  final List<InstallmentRow> sectionActive;

  const _SectionUrgentBanner({required this.sectionActive});

  @override
  Widget build(BuildContext context) {
    if (sectionActive.isEmpty) return const SizedBox.shrink();

    final sorted = [...sectionActive]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextInst = sorted.first;

    final currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);

    final now = TimeService.now();
    final justDate = DateTime(now.year, now.month, now.day);
    final dueDateJustDate = DateTime(
      nextInst.dueDate.year,
      nextInst.dueDate.month,
      nextInst.dueDate.day,
    );
    final daysLate = justDate.difference(dueDateJustDate).inDays;
    final daysUntilDue = dueDateJustDate.difference(justDate).inDays;

    // No penalties: the amount due is always the next period's payment.
    final displayAmountDue = nextInst.monthlyPayment;

    final amountStr = currency.format(displayAmountDue);
    final itemDetails = '${nextInst.provider} (${nextInst.itemDescription})';

    final String warningText;
    final Color bgColor;
    final Color textColor;
    final IconData iconData;

    if (daysLate > 0) {
      warningText = 'Payment is overdue for $itemDetails. Pay $amountStr';
      bgColor = const Color(0xFFFFF0F0);
      textColor = Colors.red[800]!;
      iconData = Icons.warning_amber_rounded;
    } else if (daysUntilDue >= 0 && daysUntilDue <= 3) {
      final timeStr = daysUntilDue == 0 ? 'Today' : 'in $daysUntilDue days';
      warningText = 'Due $timeStr for $itemDetails! Pay $amountStr';
      bgColor = const Color(0xFFFFFBE6);
      textColor = Colors.orange[800]!;
      iconData = Icons.access_time_rounded;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: textColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warningText,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Installment grid card (shared by Overview + History)
// ---------------------------------------------------------------------------
class _InstallmentGridCard extends StatelessWidget {
  final InstallmentRow installment;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _InstallmentGridCard({
    required this.installment,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(installment);

    // The lender/provider (who the money is owed to — e.g. "Valu", a bank)
    // is the headline; the store + item are secondary context. For
    // merchant-issued plans provider and merchantName are the same string,
    // so the merchant name is only appended when it adds new information.
    final subtitleBase = installment.itemDescription.isNotEmpty
        ? installment.itemDescription
        : installment.category;
    final showMerchantName =
        installment.merchantName.isNotEmpty &&
        installment.merchantName != installment.provider;
    final subtitle = showMerchantName
        ? '$subtitleBase • ${installment.merchantName}'
        : subtitleBase;

    return DesktopHoverCard(
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
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          installment.provider,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    meta.label,
                    style: TextStyle(
                      color: meta.color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
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
                color: meta.color,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Due ${DateFormat('dd MMM').format(installment.dueDate)}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History — completed plans grid
// ---------------------------------------------------------------------------
class _HistoryTab extends StatefulWidget {
  final List<InstallmentRow> paidInstallments;
  final NumberFormat currency;
  final ValueChanged<InstallmentRow> onSelectInstallment;

  const _HistoryTab({
    required this.paidInstallments,
    required this.currency,
    required this.onSelectInstallment,
  });

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paid = widget.paidInstallments;
    final totalPaidOff = paid.fold(0.0, (sum, i) => sum + _totalPaidSoFar(i));

    return DesktopCenteredContent(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'History',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _TotalPaidOffHeroCard(
                amount: totalPaidOff,
                completedCount: paid.length,
                currency: widget.currency,
              ),
              const SizedBox(height: 32),
              const Text(
                'Completed Plans',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              if (paid.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No payment history yet.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: paid.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 196,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    final inst = paid[index];
                    return _InstallmentGridCard(
                      installment: inst,
                      currency: widget.currency,
                      onTap: () => widget.onSelectInstallment(inst),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TotalPaidOffHeroCard extends StatelessWidget {
  final double amount;
  final int completedCount;
  final NumberFormat currency;

  const _TotalPaidOffHeroCard({
    required this.amount,
    required this.completedCount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34D399), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Paid Off',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currency.format(amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedCount installment${completedCount == 1 ? '' : 's'} fully paid off',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
// Insights — personal finance dashboard
// ---------------------------------------------------------------------------
class _CategorySlice {
  final String category;
  double amount = 0.0;
  _CategorySlice(this.category);
}

class _BucketResult {
  final List<double> buckets;
  final List<String> labels;
  _BucketResult(this.buckets, this.labels);
}

/// Dynamic payment-projection buckets, ported verbatim from the mobile
/// Insights screen so the desktop chart shows exactly the same numbers for
/// the same filter (All/Quarterly/Semi-Annually/Annually).
_BucketResult _computeBuckets(
  List<InstallmentRow> installments,
  String filter,
) {
  int stepSize = 1;
  int numBuckets = 6;

  if (filter == 'Quarterly') {
    stepSize = 3;
    numBuckets = 4;
  } else if (filter == 'Semi-Annually') {
    stepSize = 6;
    numBuckets = 4;
  } else if (filter == 'Annually') {
    stepSize = 12;
    numBuckets = 4;
  }

  final now = TimeService.now();
  final labels = <String>[];

  for (int i = 0; i < numBuckets; i++) {
    final mDate = DateTime(now.year, now.month + (i * stepSize), 1);
    if (filter == 'Annually') {
      labels.add(DateFormat('yyyy').format(mDate));
    } else if (filter == 'Quarterly' || filter == 'Semi-Annually') {
      final endDate = DateTime(
        now.year,
        now.month + (i * stepSize) + stepSize - 1,
        1,
      );
      final startStr = DateFormat('MMM').format(mDate);
      final endStr = DateFormat('MMM').format(endDate);
      labels.add('$startStr-$endStr');
    } else {
      labels.add(DateFormat('MMM').format(mDate));
    }
  }

  final buckets = List<double>.filled(numBuckets, 0.0);

  for (final inst in installments) {
    if (inst.isCompleted) continue;

    // No penalties/acceleration: project each remaining payment forward from
    // its due date by the plan's frequency step.
    int paymentsAdded = 0;
    final remainingPayments = inst.totalPayments - inst.paidPayments;
    DateTime projectedDate = inst.dueDate;

    while (paymentsAdded < remainingPayments) {
      final monthsDiff =
          ((projectedDate.year - now.year) * 12) +
          projectedDate.month -
          now.month;
      final bucketIndex = monthsDiff ~/ stepSize;
      if (bucketIndex >= numBuckets) break;
      if (bucketIndex >= 0) buckets[bucketIndex] += inst.monthlyPayment;
      projectedDate = DateTime(
        projectedDate.year,
        projectedDate.month + inst.monthsPerPayment,
        projectedDate.day,
      );
      paymentsAdded++;
    }
  }

  return _BucketResult(buckets, labels);
}

class _InsightsTab extends StatefulWidget {
  final double income;
  final int salaryDay;
  final List<InstallmentRow> installments;
  final NumberFormat currency;
  final VoidCallback onEditIncome;

  const _InsightsTab({
    required this.income,
    required this.salaryDay,
    required this.installments,
    required this.currency,
    required this.onEditIncome,
  });

  @override
  State<_InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<_InsightsTab> {
  final _scrollController = ScrollController();
  String _chartFilter = 'All';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<_CategorySlice> _categoryBreakdown() {
    final Map<String, _CategorySlice> grouped = {};
    for (final inst in widget.installments) {
      if (inst.isCompleted) continue;
      final key = inst.category.trim().isEmpty ? 'Other' : inst.category.trim();
      grouped.putIfAbsent(key, () => _CategorySlice(key));
      grouped[key]!.amount += _normalizedMonthlyAmount(inst);
    }
    final slices = grouped.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return slices;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.installments.isEmpty) {
      return const Center(
        child: Text(
          'No installments yet — insights will appear here once you add one.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final active = widget.installments.where((i) => !i.isCompleted).toList();
    final paidCount = widget.installments.length - active.length;
    final totalActiveAmount = active.fold(0.0, (sum, i) => sum + i.totalAmount);
    final totalActivePaid = active.fold(
      0.0,
      (sum, i) => sum + _totalPaidSoFar(i),
    );
    final payoffPct = totalActiveAmount > 0
        ? (totalActivePaid / totalActiveAmount).clamp(0.0, 1.0)
        : 1.0;

    final bucketResult = _computeBuckets(widget.installments, _chartFilter);
    final categories = _categoryBreakdown();

    return DesktopCenteredContent(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Insights',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _SpendAdvisorBanner(
                income: widget.income,
                salaryDay: widget.salaryDay,
                installments: widget.installments,
                currency: widget.currency,
              ),
              const SizedBox(height: 24),
              _IncomeBarCard(
                income: widget.income,
                salaryDay: widget.salaryDay,
                installments: widget.installments,
                currency: widget.currency,
                onEditIncome: widget.onEditIncome,
              ),
              const SizedBox(height: 24),
              _DebtFreeProgressCard(
                pct: payoffPct,
                activeCount: active.length,
                paidCount: paidCount,
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'Quarterly', 'Semi-Annually', 'Annually'].map(
                  (filter) {
                    final isSelected = _chartFilter == filter;
                    return FilterChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _chartFilter = filter),
                      backgroundColor: Colors.white,
                      selectedColor: _kBrand,
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? _kBrand : Colors.grey[300]!,
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
              const SizedBox(height: 16),
              BrandedBarChartCard(
                title: _chartFilter == 'All'
                    ? 'Monthly Payment Projections'
                    : 'Grouped $_chartFilter',
                subtitle: _chartFilter == 'All'
                    ? 'Expected commitments over the next 6 months'
                    : 'Your upcoming projected timeline',
                buckets: bucketResult.buckets,
                labels: bucketResult.labels,
                animateEntrance: false,
              ),
              const SizedBox(height: 24),
              _CategoryBreakdownCard(
                categories: categories,
                currency: widget.currency,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Watch-Your-Spend advisor banner — mirrors the mobile Insights screen's
// Affordability Advisor card exactly (same AffordabilityEngine calls and
// spend tiers), restyled as a desktop banner.
// ---------------------------------------------------------------------------
class _SpendAdvisorBanner extends StatelessWidget {
  final double income;
  final int salaryDay;
  final List<InstallmentRow> installments;
  final NumberFormat currency;

  const _SpendAdvisorBanner({
    required this.income,
    required this.salaryDay,
    required this.installments,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final now = TimeService.now();
    final cycle = LiveAffordabilityEngine.currentBillingCycle(salaryDay, now);

    final safeToSpend = LiveAffordabilityEngine.safeToSpend(
      installments,
      income,
      salaryDay,
    );
    final owed = LiveAffordabilityEngine.owedInCycle(installments, cycle);
    final paid = LiveAffordabilityEngine.paidInCycle(installments, cycle);
    final usedPct = income > 0 ? ((owed + paid) / income) * 100 : 0.0;
    final pct = income > 0 ? (owed + paid) / income : 0.0;
    final status = _getBudgetStatus(pct);

    final isOverBudget = safeToSpend < 0;
    final accentColor = isOverBudget
        ? const Color(0xFFE74C3C)
        : status.tierColor;
    final cardBg = isOverBudget ? const Color(0xFFFFF0F0) : status.bgColor;
    final icon = isOverBudget
        ? Icons.warning_amber_rounded
        : Icons.account_balance_wallet_outlined;

    final cycleLabel =
        '${DateFormat.MMMd().format(cycle.start)} – ${DateFormat.MMMd().format(cycle.end)}';

    final String headline;
    final String detail;
    if (isOverBudget) {
      headline =
          'Over Budget by ${currency.format(safeToSpend.abs())} this cycle';
      detail =
          'Cycle: $cycleLabel\n'
          '${currency.format(owed)} still owed  •  ${currency.format(paid)} already paid\n'
          'Your installment obligations exceed your income for this cycle. Avoid new purchases.';
    } else {
      headline =
          '${status.label}: ${currency.format(safeToSpend)} remaining this cycle';
      detail =
          'Cycle: $cycleLabel  ·  ${status.tierName}\n'
          '${currency.format(owed)} still owed  •  ${currency.format(paid)} already paid\n'
          '${usedPct.toStringAsFixed(0)}% of your income is committed to installments.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.6,
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
// Income Bar — mirrors the mobile Insights screen's "Cash Flow Health" card
// exactly (same billing-cycle math), with the same income-edit entry point.
// ---------------------------------------------------------------------------
class _IncomeBarCard extends StatelessWidget {
  final double income;
  final int salaryDay;
  final List<InstallmentRow> installments;
  final NumberFormat currency;
  final VoidCallback onEditIncome;

  const _IncomeBarCard({
    required this.income,
    required this.salaryDay,
    required this.installments,
    required this.currency,
    required this.onEditIncome,
  });

  @override
  Widget build(BuildContext context) {
    final now = TimeService.now();
    final cycle = LiveAffordabilityEngine.currentBillingCycle(salaryDay, now);
    final owed = LiveAffordabilityEngine.owedInCycle(installments, cycle);
    final paid = LiveAffordabilityEngine.paidInCycle(installments, cycle);
    final totalCommitted = owed + paid;
    final available = LiveAffordabilityEngine.safeToSpend(
      installments,
      income,
      salaryDay,
    );
    final percentage = income > 0 ? (totalCommitted / income) : 0.0;
    final status = _getBudgetStatus(percentage);
    final barColor = status.tierColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash Flow Health',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    "This month's income vs obligations",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: onEditIncome,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Cash',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    currency.format(available),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Income',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    currency.format(income),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${status.tierName} · ${(percentage * 100).toStringAsFixed(0)}% Consumed',
                style: TextStyle(
                  color: barColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                '${currency.format(totalCommitted)} Committed',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebtFreeProgressCard extends StatelessWidget {
  final double pct;
  final int activeCount;
  final int paidCount;

  const _DebtFreeProgressCard({
    required this.pct,
    required this.activeCount,
    required this.paidCount,
  });

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(pct * 100).toStringAsFixed(0)}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kBrand, _kBrandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Debt-Free Progress',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                pctLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 12,
              backgroundColor: Colors.white24,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            activeCount == 0
                ? 'All plans paid off — nothing outstanding.'
                : '$activeCount active plan${activeCount == 1 ? '' : 's'} in progress • $paidCount completed',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  final List<_CategorySlice> categories;
  final NumberFormat currency;

  const _CategoryBreakdownCard({
    required this.categories,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final maxAmount = categories.isEmpty ? 0.0 : categories.first.amount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category Breakdown',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            'Monthly commitment by category, active plans only',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No active plans yet.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            for (int i = 0; i < categories.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == categories.length - 1 ? 0 : 14,
                ),
                child: _CategoryRow(
                  slice: categories[i],
                  currency: currency,
                  maxAmount: maxAmount,
                ),
              ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final _CategorySlice slice;
  final NumberFormat currency;
  final double maxAmount;

  const _CategoryRow({
    required this.slice,
    required this.currency,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxAmount > 0 ? slice.amount / maxAmount : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                slice.category,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '${currency.format(slice.amount)}/mo',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            color: _kBrand,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Detail dialog — dual column: Payment Timeline / Merchant & Debt Breakdown
// ---------------------------------------------------------------------------
class _TimelineEntry {
  final String title;
  final DateTime date;
  final double amount;
  final String status;
  final Color statusBg;
  final Color statusFg;
  final IconData icon;

  _TimelineEntry({
    required this.title,
    required this.date,
    required this.amount,
    required this.status,
    required this.statusBg,
    required this.statusFg,
    required this.icon,
  });
}

class _ConsumerDetailDialog extends StatefulWidget {
  final InstallmentRow installment;
  const _ConsumerDetailDialog({required this.installment});

  @override
  State<_ConsumerDetailDialog> createState() => _ConsumerDetailDialogState();
}

class _ConsumerDetailDialogState extends State<_ConsumerDetailDialog> {
  final _currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 2);

  // Held in state so an in-dialog payment can refresh it from Supabase
  // without closing the dialog.
  late InstallmentRow _inst = widget.installment;
  bool _uploadingReceipt = false;

  Future<void> _refreshInst() async {
    final updated = await DatabaseService.fetchInstallment(_inst.id);
    if (updated != null && mounted) setState(() => _inst = updated);
  }

  Future<void> _pickReceipt() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;
      setState(() => _uploadingReceipt = true);
      final bytes = await image.readAsBytes();
      await DatabaseService.uploadReceipt(_inst.id, bytes);
      await _refreshInst();
    } catch (_) {
      if (mounted) {
        showDesktopSnackBar(context, message: 'Could not upload receipt.');
      }
    } finally {
      if (mounted) setState(() => _uploadingReceipt = false);
    }
  }

  Future<void> _removeReceipt() async {
    await DatabaseService.removeReceipt(_inst.id);
    await _refreshInst();
  }

  /// One node per *payment period*, not per month — a 60-month plan billed
  /// Quarterly yields 20 nodes, not 60. Node status maps to periods too
  /// ([paidPayments] of [totalPayments]), and each node's amount is the
  /// per-period chunk stored in [Installment.monthlyPayment] (or the exact
  /// recorded amount from [pastPayments], which is likewise one entry per
  /// period).
  List<_TimelineEntry> _buildTimeline() {
    final entries = <_TimelineEntry>[];

    if (_inst.paidPayments < _inst.totalPayments) {
      // No late fees: the next payment is simply the upcoming period amount.
      entries.add(
        _TimelineEntry(
          title: 'Payment ${_inst.paidPayments + 1}',
          date: _inst.dueDate,
          amount: _inst.monthlyPayment,
          status: 'UPCOMING',
          statusBg: Colors.grey[200]!,
          statusFg: Colors.black87,
          icon: Icons.access_time,
        ),
      );
    }

    for (int i = _inst.paidPayments - 1; i >= 0; i--) {
      final amount = i < _inst.pastPayments.length
          ? _inst.pastPayments[i]
          : _inst.monthlyPayment;
      final pastDate = _inst.dueDateForPeriodsBack(_inst.paidPayments - i);
      entries.add(
        _TimelineEntry(
          title: 'Payment ${i + 1}',
          date: pastDate,
          amount: amount,
          status: 'PAID',
          statusBg: Colors.green[50]!,
          statusFg: Colors.green,
          icon: Icons.check_circle,
        ),
      );
    }

    return entries;
  }

  /// Records a single on-time period payment via Supabase — no penalties, no
  /// arrears. The live stream behind the dialog updates on its own; here we
  /// refetch the row so the open dialog reflects the new progress too (or
  /// close it once the plan is fully paid).
  Future<void> _pay() async {
    if (_inst.paidPayments >= _inst.totalPayments) return;

    try {
      await DatabaseService.recordPayment(_inst);
    } catch (_) {
      if (mounted) {
        showDesktopSnackBar(context, message: 'Could not record payment.');
      }
      return;
    }

    final updated = await DatabaseService.fetchInstallment(_inst.id);
    if (!mounted) return;

    if (updated == null || updated.isCompleted) {
      showDesktopSnackBar(
        context,
        message: 'Installment fully paid — moved to History.',
        backgroundColor: Colors.green,
      );
      Navigator.pop(context);
    } else {
      setState(() => _inst = updated);
    }
  }

  /// Deletes a self-added plan. Only reachable when [canDelete] is true
  /// (merchant_id == consumer_id); RLS also enforces it server-side. The
  /// dashboard grid is stream-backed, so it drops the row reactively once the
  /// dialog closes.
  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Installment?'),
        content: const Text(
          'This permanently removes this self-added plan from your dashboard. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await DatabaseService.deleteInstallment(_inst.id);
    } catch (_) {
      if (mounted) {
        showDesktopSnackBar(
          context,
          message: 'Could not delete this installment.',
        );
      }
      return;
    }
    if (mounted) {
      Navigator.pop(context);
      showDesktopSnackBar(context, message: 'Installment deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _statusMeta(_inst);
    // Strict subtraction — never monthlyPayment × remainingMonths, which
    // rounds (833.33 × 12 = 9,999.96 instead of 10,000).
    final double remainingDebt = _inst.remaining;
    final timeline = _buildTimeline();
    // A consumer may delete ONLY a self-added plan (merchant_id == consumer_id,
    // i.e. they are their own "merchant"). A merchant-issued contract is the
    // merchant's to cancel — RLS enforces this, and we surface it read-only.
    final bool canDelete = _inst.merchantId == _inst.consumerId;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              // Lead with the lender/provider — who the
                              // debt is owed to — matching the dashboard
                              // grid card the user clicked to get here.
                              _inst.provider,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: meta.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                meta.label,
                                style: TextStyle(
                                  color: meta.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_inst.itemDescription.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              _inst.itemDescription,
                              _inst.category,
                              if (_inst.merchantName.isNotEmpty &&
                                  _inst.merchantName != _inst.provider)
                                _inst.merchantName,
                            ].join(' • '),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: _PaymentTimelineColumn(
                      entries: timeline,
                      currency: _currency,
                    ),
                  ),
                  VerticalDivider(width: 1, color: Colors.grey[200]),
                  Expanded(
                    flex: 4,
                    child: _DebtBreakdownColumn(
                      installment: _inst,
                      currency: _currency,
                      remainingDebt: remainingDebt,
                      canDelete: canDelete,
                      onPay: _pay,
                      onDelete: _delete,
                      uploadingReceipt: _uploadingReceipt,
                      onPickReceipt: _pickReceipt,
                      onRemoveReceipt: _removeReceipt,
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

class _PaymentTimelineColumn extends StatelessWidget {
  final List<_TimelineEntry> entries;
  final NumberFormat currency;

  const _PaymentTimelineColumn({required this.entries, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Timeline',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: entries.isEmpty
                ? Text(
                    'No payment history yet.',
                    style: TextStyle(color: Colors.grey[500]),
                  )
                : Scrollbar(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final isLast = index == entries.length - 1;
                        return _TimelineTile(
                          entry: entries[index],
                          currency: currency,
                          isLast: isLast,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _TimelineEntry entry;
  final NumberFormat currency;
  final bool isLast;

  const _TimelineTile({
    required this.entry,
    required this.currency,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: entry.statusFg,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: Colors.grey[200])),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(entry.icon, size: 15, color: Colors.black54),
                            const SizedBox(width: 8),
                            Text(
                              entry.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy').format(entry.date),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currency.format(entry.amount),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: entry.statusBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            entry.status,
                            style: TextStyle(
                              color: entry.statusFg,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtBreakdownColumn extends StatelessWidget {
  final InstallmentRow installment;
  final NumberFormat currency;
  final double remainingDebt;
  final bool canDelete;
  final Future<void> Function() onPay;
  final VoidCallback onDelete;
  final bool uploadingReceipt;
  final Future<void> Function() onPickReceipt;
  final Future<void> Function() onRemoveReceipt;

  const _DebtBreakdownColumn({
    required this.installment,
    required this.currency,
    required this.remainingDebt,
    required this.canDelete,
    required this.onPay,
    required this.onDelete,
    required this.uploadingReceipt,
    required this.onPickReceipt,
    required this.onRemoveReceipt,
  });

  Widget _buildReceiptSection(BuildContext context) {
    final url = installment.receiptImageUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text(
          'WARRANTY & RECEIPT',
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        if (uploadingReceipt)
          const Center(child: CircularProgressIndicator())
        else if (url == null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: OutlinedButton.icon(
              onPressed: onPickReceipt,
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Upload receipt photo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kBrandDark,
                minimumSize: const Size(double.infinity, 44),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          )
        else
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(url),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onPickReceipt,
                        child: const Text('Replace', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onRemoveReceipt,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('Remove', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = installment.isCompleted;

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 28, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Merchant & Debt Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _BreakdownStat(
              label: 'TOTAL AMOUNT',
              value: currency.format(installment.totalAmount),
            ),
            const SizedBox(height: 14),
            _BreakdownStat(
              label: 'REMAINING DEBT',
              value: currency.format(remainingDebt),
              trailing: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: installment.totalPayments > 0
                      ? installment.paidPayments / installment.totalPayments
                      : 0.0,
                  backgroundColor: Colors.grey[200],
                  color: _kBrand,
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${installment.paidPayments} of ${installment.totalPayments} paid',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),
            if (isPaid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FAF0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Plan Fully Paid',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1B8A4C),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      installment.paymentFrequencyLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currency.format(installment.monthlyPayment),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 13,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Due ${installment.dueDate.day}th of ${installment.paymentCadencePhrase}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => onPay(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kBrand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Mark ${installment.periodNoun} as Paid (${currency.format(installment.monthlyPayment)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (canDelete) ...[
              const SizedBox(height: 18),
              Center(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    'Delete Installment',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 18),
              Text(
                'This plan is linked to a merchant — only the merchant can cancel it.',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
            _buildReceiptSection(context),
          ],
        ),
      ),
    );
  }
}

class _BreakdownStat extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const _BreakdownStat({
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        if (trailing != null) ...[const SizedBox(height: 10), trailing!],
      ],
    );
  }
}
