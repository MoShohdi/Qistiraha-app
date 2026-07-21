import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import 'package:qistiraha/features/auth/models/business_account.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';
import 'package:qistiraha/features/auth/screens/welcome_screen.dart';
import 'package:qistiraha/features/auth/screens/login_screen_desktop.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'merchant_customer_profile_screen.dart';
import 'merchant_installment_details_desktop.dart';
import 'merchant_portal_desktop.dart';
import 'merchant_portal_screen.dart';

const _kBrand = Color(0xFF99AFD7);
const _kBrandDark = Color(0xFF5A75AD);
const _kBg = Color(0xFFF8F9FA);
const _kSidebarWidth = 260.0;

/// Crisp desktop corner radius — the "8-12px" mandate for a modern B2B
/// surface, as opposed to the rounder, larger radii mobile UIs tend to use.
const _kCardRadius = 10.0;

/// A soft, diffused resting shadow — enough depth to lift a card off the
/// page without the heavy, high-opacity elevation mobile Material widgets
/// default to.
List<BoxShadow> get _kCardShadow => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 20,
    offset: const Offset(0, 6),
  ),
];

enum _MerchantNav { overview, customers, active, insights }

enum _ActiveFilter { all, overdue, pending, paid }

/// Desktop/web shell for the merchant side — a fixed sidebar (store identity,
/// the primary "Generate Payment Link" action, and section navigation) next
/// to a main content area that reflows per section: a data-dense Overview
/// (KPIs, revenue trend, upcoming-installments table), premium inbox-style
/// master-detail layouts for Customers/Active Installments, and a dashboard
/// grid for Insights. Reuses the same Hive-backed data throughout; the
/// Active Installments detail pane renders the desktop-native
/// [MerchantInstallmentDetailsDesktop] (ported logic, not the mobile screen).
class MerchantDashboardDesktop extends StatefulWidget {
  const MerchantDashboardDesktop({super.key});

  @override
  State<MerchantDashboardDesktop> createState() =>
      _MerchantDashboardDesktopState();
}

class _MerchantDashboardDesktopState extends State<MerchantDashboardDesktop> {
  final _currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);
  _MerchantNav _nav = _MerchantNav.overview;
  String? _selectedCustomerKey;
  Installment? _selectedInstallment;

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveService.getBusinessBox().listenable(),
      builder: (context, Box<BusinessAccount> businessBox, _) {
        if (businessBox.isEmpty) {
          return const Scaffold(
            backgroundColor: _kBg,
            body: Center(child: Text('No merchant account found.')),
          );
        }
        final business = businessBox.values.first;

        return Scaffold(
          backgroundColor: _kBg,
          body: ValueListenableBuilder(
            valueListenable: HiveService.getInstallmentBox().listenable(),
            builder: (context, Box<Installment> installmentBox, _) {
              final plans = installmentBox.values
                  .where((i) => i.merchantId == business.id)
                  .toList();

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Sidebar(
                    business: business,
                    nav: _nav,
                    onSelectNav: (n) => setState(() => _nav = n),
                    onLogout: () => _logout(context),
                  ),
                  Expanded(child: _buildMainContent(plans)),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMainContent(List<Installment> plans) {
    switch (_nav) {
      case _MerchantNav.overview:
        return _OverviewGrid(
          plans: plans,
          currency: _currency,
          onSelectInstallment: (inst) {
            setState(() {
              _nav = _MerchantNav.active;
              _selectedInstallment = inst;
            });
          },
        );
      case _MerchantNav.customers:
        return _CustomersMasterDetail(
          plans: plans,
          currency: _currency,
          selectedKey: _selectedCustomerKey,
          onSelect: (key) => setState(() => _selectedCustomerKey = key),
        );
      case _MerchantNav.active:
        return _ActiveMasterDetail(
          plans: plans,
          currency: _currency,
          selected: _selectedInstallment,
          onSelect: (inst) => setState(() => _selectedInstallment = inst),
          onCancelled: () => setState(() => _selectedInstallment = null),
        );
      case _MerchantNav.insights:
        return _InsightsGrid(plans: plans, currency: _currency);
    }
  }
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------
class _Sidebar extends StatelessWidget {
  final BusinessAccount business;
  final _MerchantNav nav;
  final ValueChanged<_MerchantNav> onSelectNav;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.business,
    required this.nav,
    required this.onSelectNav,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(_kCardRadius),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          business.businessName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          business.category,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 11.5,
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResponsiveLayout(
                            mobileWidget: MerchantPortalScreen(
                              business: business,
                            ),
                            desktopWidget: MerchantPortalDesktopScreen(
                              business: business,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code, size: 17),
                    label: const Text(
                      'Generate Payment Link',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E2337),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_kCardRadius),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                children: [
                  _NavItem(
                    icon: Icons.dashboard_outlined,
                    label: 'Overview',
                    selected: nav == _MerchantNav.overview,
                    onTap: () => onSelectNav(_MerchantNav.overview),
                  ),
                  _NavItem(
                    icon: Icons.people_outline,
                    label: 'Customers',
                    selected: nav == _MerchantNav.customers,
                    onTap: () => onSelectNav(_MerchantNav.customers),
                  ),
                  _NavItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Active Installments',
                    selected: nav == _MerchantNav.active,
                    onTap: () => onSelectNav(_MerchantNav.active),
                  ),
                  _NavItem(
                    icon: Icons.insights_outlined,
                    label: 'Insights',
                    selected: nav == _MerchantNav.insights,
                    onTap: () => onSelectNav(_MerchantNav.insights),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
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
      padding: const EdgeInsets.only(bottom: 3),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: fg),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: widget.selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 13,
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
// Shared: dense stat card, inbox-style row chrome
// ---------------------------------------------------------------------------
class _DesktopStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DesktopStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
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

/// Premium "web inbox" row chrome (Superhuman/Gmail-style): a colored left
/// accent bar and faint tint when selected, a subtle hover tint at rest, and
/// a hairline bottom divider — deliberately no shadow or rounded corners per
/// row, since the containing panel already carries the card-level depth.
class _InboxRowChrome extends StatefulWidget {
  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  const _InboxRowChrome({
    required this.child,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_InboxRowChrome> createState() => _InboxRowChromeState();
}

class _InboxRowChromeState extends State<_InboxRowChrome> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = widget.selected
        ? _kBrand.withValues(alpha: 0.08)
        : (_hovering ? Colors.grey[50]! : Colors.white);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                color: widget.selected ? _kBrand : Colors.transparent,
                width: 3,
              ),
              bottom: BorderSide(color: Colors.grey[100]!, width: 1),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// The white, bordered panel every master-detail pane (list and detail side
/// alike) sits inside — the single source of "card" depth for these layouts,
/// so individual rows can stay flush and flat.
class _PanelFrame extends StatelessWidget {
  final Widget child;
  const _PanelFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: _kCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Overview — KPIs, revenue trend line chart, upcoming-installments table
// ---------------------------------------------------------------------------
class _OverviewGrid extends StatefulWidget {
  final List<Installment> plans;
  final NumberFormat currency;
  final ValueChanged<Installment> onSelectInstallment;

  const _OverviewGrid({
    required this.plans,
    required this.currency,
    required this.onSelectInstallment,
  });

  @override
  State<_OverviewGrid> createState() => _OverviewGridState();
}

class _OverviewGridState extends State<_OverviewGrid> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _totalExpected =>
      widget.plans.fold(0.0, (sum, i) => sum + i.amount);

  double get _totalReceived => widget.plans.fold(0.0, (sum, i) {
    if (i.pastPayments.isNotEmpty) {
      return sum + i.pastPayments.fold(0.0, (a, b) => a + b);
    }
    return sum + (i.paidPayments * i.monthlyPayment);
  });

  /// Reconstructs a 6-month revenue trend from each plan's completed
  /// payments. There's no per-payment timestamp in the model beyond the
  /// most recent one, so — exactly like the payment-history views — each
  /// past payment's date is approximated backward from `dueDate` in
  /// payment-period increments.
  List<double> _revenueTrend() {
    final buckets = List<double>.filled(6, 0.0);
    final now = TimeService.now();

    for (final inst in widget.plans) {
      final paid = inst.paidPayments;
      if (paid <= 0) continue;

      for (int i = 0; i < paid; i++) {
        final amount = i < inst.pastPayments.length
            ? inst.pastPayments[i]
            : inst.monthlyPayment;
        final approxDate = inst.dueDate.subtract(
          Duration(days: 30 * inst.monthsPerPayment * (paid - i)),
        );
        final monthsAgo =
            (now.year - approxDate.year) * 12 + (now.month - approxDate.month);
        if (monthsAgo >= 0 && monthsAgo < 6) {
          buckets[5 - monthsAgo] += amount;
        }
      }
    }
    return buckets;
  }

  /// Overdue plans first, then anything due within the next 3 days — the
  /// short list of things that actually need attention right now.
  List<Installment> _urgentAlerts(List<Installment> upcoming) {
    final now = TimeService.now();
    final today = DateTime(now.year, now.month, now.day);
    final urgent = upcoming.where((i) {
      final due = DateTime(i.dueDate.year, i.dueDate.month, i.dueDate.day);
      final isOverdue = i.statusEnum == InstallmentStatus.overdue;
      final daysUntilDue = due.difference(today).inDays;
      return isOverdue || (daysUntilDue >= 0 && daysUntilDue <= 3);
    }).toList();
    urgent.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return urgent.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming =
        widget.plans
            .where((i) => i.statusEnum != InstallmentStatus.paid)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final urgentAlerts = _urgentAlerts(upcoming);

    final trend = _revenueTrend();
    final now = TimeService.now();
    final trendLabels = List.generate(
      6,
      (i) => DateFormat('MMM').format(DateTime(now.year, now.month - (5 - i))),
    );

    return DesktopCenteredContent(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DesktopStatCard(
                        label: 'Total Expected Revenue',
                        value: widget.currency.format(_totalExpected),
                        icon: Icons.trending_up,
                        color: _kBrand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DesktopStatCard(
                        label: 'Total Received',
                        value: widget.currency.format(_totalReceived),
                        icon: Icons.account_balance_wallet_outlined,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _RevenueLineChartCard(
                buckets: trend,
                labels: trendLabels,
                currency: widget.currency,
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _UpcomingInstallmentsTable(
                      installments: upcoming,
                      currency: widget.currency,
                      onSelect: widget.onSelectInstallment,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    flex: 2,
                    child: _RecentAlertsCard(
                      alerts: urgentAlerts,
                      onSelect: widget.onSelectInstallment,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueLineChartCard extends StatelessWidget {
  final List<double> buckets;
  final List<String> labels;
  final NumberFormat currency;

  const _RevenueLineChartCard({
    required this.buckets,
    required this.labels,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = buckets.isEmpty
        ? 0.0
        : buckets.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal > 0 ? maxVal * 1.25 : 1000.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Trend',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          ),
          const SizedBox(height: 2),
          Text(
            'Collected revenue over the last 6 months',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (buckets.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey[100], strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if ((value - i).abs() > 0.01 ||
                            i < 0 ||
                            i >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        String text;
                        if (value == 0) {
                          text = '0';
                        } else if (value >= 1000) {
                          text =
                              '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
                        } else {
                          text = value.toStringAsFixed(0);
                        }
                        return Text(
                          text,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            currency.format(s.y),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (int i = 0; i < buckets.length; i++)
                        FlSpot(i.toDouble(), buckets[i]),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: _kBrand,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                            radius: 3,
                            color: _kBrandDark,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _kBrand.withValues(alpha: 0.22),
                          _kBrand.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingInstallmentsTable extends StatefulWidget {
  final List<Installment> installments;
  final NumberFormat currency;
  final ValueChanged<Installment> onSelect;

  const _UpcomingInstallmentsTable({
    required this.installments,
    required this.currency,
    required this.onSelect,
  });

  @override
  State<_UpcomingInstallmentsTable> createState() =>
      _UpcomingInstallmentsTableState();
}

class _UpcomingInstallmentsTableState
    extends State<_UpcomingInstallmentsTable> {
  int? _pressedIndex;

  /// Flashes the tapped row with a brand tint before navigating, so the
  /// click reads as a deliberate, tactile action instead of an instant,
  /// "dead" jump straight to the detail pane.
  void _handleTap(Installment inst, int index) {
    setState(() => _pressedIndex = index);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _pressedIndex = null);
      widget.onSelect(inst);
    });
  }

  DataRow _buildRow(Installment inst, int index) {
    final isOverdue = inst.statusEnum == InstallmentStatus.overdue;
    final statusColor = isOverdue ? Colors.red : _kBrand;
    final statusLabel = isOverdue ? 'Overdue' : 'Pending';
    final isPressed = index == _pressedIndex;

    Widget cursor(Widget child) =>
        MouseRegion(cursor: SystemMouseCursors.click, child: child);

    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (isPressed) return _kBrand.withValues(alpha: 0.16);
        if (states.contains(WidgetState.hovered)) return Colors.grey[50];
        return index.isEven ? Colors.white : const Color(0xFFFAFBFC);
      }),
      onSelectChanged: (_) => _handleTap(inst, index),
      cells: [
        DataCell(
          cursor(
            Text(
              inst.customerName ?? 'Customer',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(
          cursor(Text(inst.itemDescription, overflow: TextOverflow.ellipsis)),
        ),
        DataCell(
          cursor(
            Text(
              isOverdue
                  ? 'Overdue since ${DateFormat('dd MMM').format(inst.dueDate)}'
                  : DateFormat('dd MMM yyyy').format(inst.dueDate),
              style: TextStyle(
                color: isOverdue ? Colors.red[700] : Colors.black87,
                fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
        DataCell(
          cursor(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
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
          ),
        ),
        DataCell(
          cursor(
            Text(
              widget.currency.format(inst.monthlyPayment),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upcoming Installments',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  'Across all customers, soonest first',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (widget.installments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No upcoming installments yet.',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
                headingRowHeight: 36,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 44,
                columnSpacing: 28,
                horizontalMargin: 20,
                headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                headingTextStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 0.4,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
                columns: const [
                  DataColumn(label: Text('CUSTOMER')),
                  DataColumn(label: Text('ITEM')),
                  DataColumn(label: Text('DUE DATE')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('AMOUNT'), numeric: true),
                ],
                rows: [
                  for (int i = 0; i < widget.installments.length; i++)
                    _buildRow(widget.installments[i], i),
                ],
              ),
            ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Fills the space next to the upcoming-installments table with a short,
/// real feed of overdue and soon-due plans — the things a merchant actually
/// needs to act on today, rather than an empty gap.
class _RecentAlertsCard extends StatelessWidget {
  final List<Installment> alerts;
  final ValueChanged<Installment> onSelect;

  const _RecentAlertsCard({required this.alerts, required this.onSelect});

  String _urgencyText(Installment inst) {
    final now = TimeService.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      inst.dueDate.year,
      inst.dueDate.month,
      inst.dueDate.day,
    );
    final days = due.difference(today).inDays;
    if (inst.statusEnum == InstallmentStatus.overdue) {
      return 'Overdue by ${-days} day${-days == 1 ? '' : 's'}';
    }
    if (days == 0) return 'Due today';
    return 'Due in $days day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return _PanelFrame(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  size: 17,
                  color: _kBrandDark,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recent Alerts',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Overdue and soon-due plans',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 14),
            if (alerts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.green[400],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All caught up — nothing urgent.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (int i = 0; i < alerts.length; i++)
                _AlertRow(
                  installment: alerts[i],
                  urgencyText: _urgencyText(alerts[i]),
                  isLast: i == alerts.length - 1,
                  onTap: () => onSelect(alerts[i]),
                ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Installment installment;
  final String urgencyText;
  final bool isLast;
  final VoidCallback onTap;

  const _AlertRow({
    required this.installment,
    required this.urgencyText,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = installment.statusEnum == InstallmentStatus.overdue;
    final color = isOverdue ? Colors.red : Colors.orange[700]!;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        installment.customerName ?? 'Customer',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        urgencyText,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Customers — master-detail
// ---------------------------------------------------------------------------
class _CustomerSummary {
  final String key;
  final String name;
  final List<Installment> plans;
  _CustomerSummary({
    required this.key,
    required this.name,
    required this.plans,
  });

  bool get hasOverdue =>
      plans.any((p) => p.statusEnum == InstallmentStatus.overdue);
  bool get allPaid =>
      plans.every((p) => p.statusEnum == InstallmentStatus.paid);
  double get outstanding => plans
      .where((p) => p.statusEnum != InstallmentStatus.paid)
      .fold(
        0.0,
        (sum, p) =>
            sum + ((p.totalPayments - p.paidPayments) * p.monthlyPayment),
      );
}

class _CustomersMasterDetail extends StatefulWidget {
  final List<Installment> plans;
  final NumberFormat currency;
  final String? selectedKey;
  final ValueChanged<String?> onSelect;

  const _CustomersMasterDetail({
    required this.plans,
    required this.currency,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  State<_CustomersMasterDetail> createState() => _CustomersMasterDetailState();
}

class _CustomersMasterDetailState extends State<_CustomersMasterDetail> {
  final _listController = ScrollController();

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  List<_CustomerSummary> _groupByCustomer() {
    final Map<String, List<Installment>> grouped = {};
    for (final p in widget.plans) {
      final key = (p.customerPhone?.isNotEmpty == true)
          ? p.customerPhone!
          : (p.customerName ?? 'Unknown');
      grouped.putIfAbsent(key, () => []).add(p);
    }
    return grouped.entries
        .map(
          (e) => _CustomerSummary(
            key: e.key,
            name: e.value.first.customerName ?? 'Customer',
            plans: e.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.plans.length.compareTo(a.plans.length));
  }

  @override
  Widget build(BuildContext context) {
    final customers = _groupByCustomer();
    _CustomerSummary? selected;
    for (final c in customers) {
      if (c.key == widget.selectedKey) {
        selected = c;
        break;
      }
    }

    return DesktopCenteredContent(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _PanelFrame(
                child: customers.isEmpty
                    ? Center(
                        child: Text(
                          'No customers yet.',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : Scrollbar(
                        controller: _listController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _listController,
                          itemCount: customers.length,
                          itemBuilder: (context, index) {
                            final c = customers[index];
                            String healthLabel;
                            Color healthColor;
                            if (c.hasOverdue) {
                              healthLabel = 'Has Overdue Payment';
                              healthColor = Colors.red;
                            } else if (c.allPaid) {
                              healthLabel = 'Fully Paid';
                              healthColor = Colors.green;
                            } else {
                              healthLabel = 'Good Standing';
                              healthColor = _kBrand;
                            }

                            return _InboxRowChrome(
                              selected: c.key == widget.selectedKey,
                              onTap: () => widget.onSelect(c.key),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: healthColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: healthColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${c.plans.length} plan${c.plans.length == 1 ? '' : 's'} • ${widget.currency.format(c.outstanding)}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 11.5,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: healthColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        healthLabel,
                                        style: TextStyle(
                                          color: healthColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            VerticalDivider(width: 1, color: Colors.grey[300]),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _PanelFrame(
                child: selected == null
                    ? const DesktopEmptyDetail(
                        icon: Icons.person_search_outlined,
                        message:
                            'Select a customer to view their installment history',
                      )
                    : EmbeddedScreen(
                        key: ValueKey('customer-${selected.key}'),
                        child: MerchantCustomerProfileScreen(
                          customerName: selected.name,
                          customerPhone: selected.plans.first.customerPhone,
                          plans: selected.plans,
                          currency: widget.currency,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active Installments — master-detail
// ---------------------------------------------------------------------------
class _ActiveMasterDetail extends StatefulWidget {
  final List<Installment> plans;
  final NumberFormat currency;
  final Installment? selected;
  final ValueChanged<Installment> onSelect;
  final VoidCallback onCancelled;

  const _ActiveMasterDetail({
    required this.plans,
    required this.currency,
    required this.selected,
    required this.onSelect,
    required this.onCancelled,
  });

  @override
  State<_ActiveMasterDetail> createState() => _ActiveMasterDetailState();
}

class _ActiveMasterDetailState extends State<_ActiveMasterDetail> {
  final _listController = ScrollController();
  _ActiveFilter _filter = _ActiveFilter.all;

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.plans.where((p) {
      switch (_filter) {
        case _ActiveFilter.overdue:
          return p.statusEnum == InstallmentStatus.overdue;
        case _ActiveFilter.pending:
          return p.statusEnum == InstallmentStatus.active;
        case _ActiveFilter.paid:
          return p.statusEnum == InstallmentStatus.paid;
        case _ActiveFilter.all:
          return true;
      }
    }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return DesktopCenteredContent(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 2,
              child: _PanelFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          _filterChip('All', _ActiveFilter.all),
                          _filterChip('Overdue', _ActiveFilter.overdue),
                          _filterChip('Pending', _ActiveFilter.pending),
                          _filterChip('Paid', _ActiveFilter.paid),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No installments match this filter.',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            )
                          : Scrollbar(
                              controller: _listController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _listController,
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final p = filtered[index];
                                  return _ActiveInboxRow(
                                    installment: p,
                                    currency: widget.currency,
                                    selected: widget.selected?.id == p.id,
                                    onTap: () => widget.onSelect(p),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            VerticalDivider(width: 1, color: Colors.grey[300]),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _PanelFrame(
                child: widget.selected == null
                    ? const DesktopEmptyDetail(
                        icon: Icons.receipt_long,
                        iconSize: 80,
                        message: 'Select an installment to view details',
                      )
                    : MerchantInstallmentDetailsDesktop(
                        key: ValueKey('installment-${widget.selected!.id}'),
                        installment: widget.selected!,
                        onCancelled: widget.onCancelled,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _ActiveFilter value) {
    final bool selected = _filter == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: _kBrand,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey[300]!),
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }
}

class _ActiveInboxRow extends StatelessWidget {
  final Installment installment;
  final NumberFormat currency;
  final bool selected;
  final VoidCallback onTap;

  const _ActiveInboxRow({
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
        statusLabel = 'Pending';
        break;
    }

    return _InboxRowChrome(
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    installment.itemDescription,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              installment.customerName ?? 'Customer',
              style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${installment.paidPayments}/${installment.totalPayments} paid',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                Text(
                  currency.format(installment.monthlyPayment),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: installment.totalPayments > 0
                    ? installment.paidPayments / installment.totalPayments
                    : 0.0,
                backgroundColor: Colors.grey[200],
                color: statusColor,
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Insights — dashboard grid
// ---------------------------------------------------------------------------
class _TopItem {
  final String name;
  int count = 0;
  double revenue = 0.0;
  _TopItem({required this.name});
}

class _ActivityEntry {
  final Installment installment;
  final double amountPaid;
  final DateTime timestamp;
  _ActivityEntry({
    required this.installment,
    required this.amountPaid,
    required this.timestamp,
  });
}

class _InsightsGrid extends StatefulWidget {
  final List<Installment> plans;
  final NumberFormat currency;
  const _InsightsGrid({required this.plans, required this.currency});

  @override
  State<_InsightsGrid> createState() => _InsightsGridState();
}

class _InsightsGridState extends State<_InsightsGrid> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double get _totalExpected =>
      widget.plans.fold(0.0, (sum, i) => sum + i.amount);

  double get _totalCollected => widget.plans.fold(0.0, (sum, i) {
    if (i.pastPayments.isNotEmpty) {
      return sum + i.pastPayments.fold(0.0, (a, b) => a + b);
    }
    return sum + (i.paidPayments * i.monthlyPayment);
  });

  int get _onTimeCount => widget.plans
      .where(
        (i) =>
            i.statusEnum != InstallmentStatus.overdue &&
            i.statusEnum != InstallmentStatus.defaulted,
      )
      .length;

  int get _overdueCount => widget.plans
      .where(
        (i) =>
            i.statusEnum == InstallmentStatus.overdue ||
            i.statusEnum == InstallmentStatus.defaulted,
      )
      .length;

  double get _onTimePct =>
      widget.plans.isEmpty ? 1.0 : _onTimeCount / widget.plans.length;

  /// Reconstructs a 6-month revenue trend from each plan's completed
  /// payments. There's no per-payment timestamp in the model beyond the
  /// most recent one, so — exactly like the payment-history views — each
  /// past payment's date is approximated backward from `dueDate` in
  /// payment-period increments.
  List<double> _revenueTrend() {
    final buckets = List<double>.filled(6, 0.0);
    final now = TimeService.now();

    for (final inst in widget.plans) {
      final paid = inst.paidPayments;
      if (paid <= 0) continue;

      for (int i = 0; i < paid; i++) {
        final amount = i < inst.pastPayments.length
            ? inst.pastPayments[i]
            : inst.monthlyPayment;
        final approxDate = inst.dueDate.subtract(
          Duration(days: 30 * inst.monthsPerPayment * (paid - i)),
        );
        final monthsAgo =
            (now.year - approxDate.year) * 12 + (now.month - approxDate.month);
        if (monthsAgo >= 0 && monthsAgo < 6) {
          buckets[5 - monthsAgo] += amount;
        }
      }
    }
    return buckets;
  }

  List<double> _projectCashFlow() {
    final buckets = List<double>.filled(6, 0.0);
    final now = TimeService.now();

    for (final inst in widget.plans) {
      if (inst.statusEnum == InstallmentStatus.paid) continue;
      final remaining = inst.totalPayments - inst.paidPayments;
      if (remaining <= 0) continue;

      final isOverdue =
          inst.statusEnum == InstallmentStatus.overdue ||
          inst.statusEnum == InstallmentStatus.defaulted;
      final anchorDate = isOverdue && inst.dueDate.isBefore(now)
          ? now
          : inst.dueDate;

      for (int p = 0; p < remaining; p++) {
        final projected = DateTime(
          anchorDate.year,
          anchorDate.month + (p * inst.monthsPerPayment),
          1,
        );
        final monthsDiff =
            (projected.year - now.year) * 12 + projected.month - now.month;
        if (monthsDiff >= 0 && monthsDiff < 6) {
          buckets[monthsDiff] += inst.monthlyPayment;
        }
      }
    }
    return buckets;
  }

  List<_TopItem> _topSellingItems() {
    final Map<String, _TopItem> grouped = {};
    for (final inst in widget.plans) {
      final key = inst.itemDescription.trim().isEmpty
          ? 'Other'
          : inst.itemDescription.trim();
      grouped.putIfAbsent(key, () => _TopItem(name: key));
      grouped[key]!.count++;
      grouped[key]!.revenue += inst.amount;
    }
    final items = grouped.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return items.take(6).toList();
  }

  List<_ActivityEntry> _recentActivity() {
    final entries = <_ActivityEntry>[];
    for (final inst in widget.plans) {
      if (inst.lastPaidAt == null || inst.paidPayments <= 0) continue;
      final amount = inst.pastPayments.isNotEmpty
          ? inst.pastPayments.last
          : inst.monthlyPayment;
      entries.add(
        _ActivityEntry(
          installment: inst,
          amountPaid: amount,
          timestamp: inst.lastPaidAt!,
        ),
      );
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plans.isEmpty) {
      return const Center(
        child: Text(
          'No installments yet — insights will appear here once you have active plans.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final cashFlow = _projectCashFlow();
    final topItems = _topSellingItems();
    final recentActivity = _recentActivity();
    final now = TimeService.now();
    final monthLabels = List.generate(
      6,
      (i) => DateFormat('MMM').format(DateTime(now.year, now.month + i, 1)),
    );
    final trend = _revenueTrend();
    final trendLabels = List.generate(
      6,
      (i) => DateFormat('MMM').format(DateTime(now.year, now.month - (5 - i))),
    );

    return DesktopCenteredContent(
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Insights',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DesktopStatCard(
                        label: 'Total Expected Revenue',
                        value: widget.currency.format(_totalExpected),
                        icon: Icons.account_balance_wallet_outlined,
                        color: _kBrand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DesktopStatCard(
                        label: 'Revenue Collected',
                        value: widget.currency.format(_totalCollected),
                        icon: Icons.savings_outlined,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StoreHealthDesktopCard(
                        onTimePct: _onTimePct,
                        onTimeCount: _onTimeCount,
                        overdueCount: _overdueCount,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _RevenueLineChartCard(
                buckets: trend,
                labels: trendLabels,
                currency: widget.currency,
              ),
              const SizedBox(height: 18),
              _CashFlowBarChartCard(buckets: cashFlow, labels: monthLabels),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final sideBySide = constraints.maxWidth >= 700;
                  final topSelling = _TopSellingCard(
                    items: topItems,
                    currency: widget.currency,
                  );
                  final activity = _RecentActivityCard(
                    entries: recentActivity,
                    currency: widget.currency,
                  );
                  if (!sideBySide) {
                    return Column(
                      children: [
                        topSelling,
                        const SizedBox(height: 18),
                        activity,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: topSelling),
                      const SizedBox(width: 18),
                      Expanded(child: activity),
                    ],
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

/// A dedicated, sleeker bar chart for the merchant Insights dashboard —
/// gradient rounded-cap bars that grow up from the x-axis on load. Kept
/// self-contained here rather than reusing the shared `BrandedBarChartCard`
/// (also used by the consumer dashboard) so this redesign stays scoped to
/// this file.
class _CashFlowBarChartCard extends StatelessWidget {
  final List<double> buckets;
  final List<String> labels;

  const _CashFlowBarChartCard({required this.buckets, required this.labels});

  @override
  Widget build(BuildContext context) {
    final maxBucket = buckets.isEmpty
        ? 0.0
        : buckets.reduce((a, b) => a > b ? a : b);
    final maxY = maxBucket > 0 ? maxBucket * 1.2 : 1000.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Projected Cash Flow',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          ),
          const SizedBox(height: 2),
          Text(
            'Expected collections over the next 6 months',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, growth, child) {
                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final original =
                              group.x >= 0 && group.x < buckets.length
                              ? buckets[group.x]
                              : rod.toY;
                          return BarTooltipItem(
                            original.toStringAsFixed(0),
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= labels.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: maxY / 5,
                          getTitlesWidget: (value, meta) {
                            String text;
                            if (value == 0) {
                              text = '0';
                            } else if (value >= 1000000) {
                              text =
                                  '${(value / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
                            } else if (value >= 1000) {
                              text =
                                  '${(value / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
                            } else {
                              text = value.toStringAsFixed(0);
                            }
                            return Text(
                              text,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 5,
                      getDrawingHorizontalLine: (value) =>
                          FlLine(color: Colors.grey[100], strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (int i = 0; i < buckets.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: buckets[i] * growth,
                              width: 22,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [_kBrand, _kBrandDark],
                              ),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY,
                                color: Colors.grey[50],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: Duration.zero,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreHealthDesktopCard extends StatelessWidget {
  final double onTimePct;
  final int onTimeCount;
  final int overdueCount;

  const _StoreHealthDesktopCard({
    required this.onTimePct,
    required this.onTimeCount,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: _kCardShadow,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            // Entrance animation: the ring fills clockwise from 0 up to
            // `onTimePct` on every mount (CircularProgressIndicator always
            // starts its sweep at 12 o'clock) — and re-animates smoothly to
            // a new value if the underlying data changes while visible.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: onTimePct.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.grey[100],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          _kBrand,
                        ),
                      ),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Store Health',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _dot(_kBrand),
                    const SizedBox(width: 5),
                    Text(
                      '$onTimeCount on-time',
                      style: TextStyle(color: Colors.grey[700], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _dot(Colors.red),
                    const SizedBox(width: 5),
                    Text(
                      '$overdueCount overdue',
                      style: TextStyle(color: Colors.grey[700], fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _TopSellingCard extends StatelessWidget {
  final List<_TopItem> items;
  final NumberFormat currency;
  const _TopSellingCard({required this.items, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxCount = items.isEmpty ? 0 : items.first.count;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Selling Items',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          ),
          Text(
            'Ranked by number of active installment plans',
            style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No items yet.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            for (int i = 0; i < items.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == items.length - 1 ? 0 : 12,
                ),
                child: _TopItemRow(
                  rank: i + 1,
                  item: items[i],
                  currency: currency,
                  maxCount: maxCount,
                ),
              ),
        ],
      ),
    );
  }
}

class _TopItemRow extends StatelessWidget {
  final int rank;
  final _TopItem item;
  final NumberFormat currency;
  final int maxCount;

  const _TopItemRow({
    required this.rank,
    required this.item,
    required this.currency,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final progress = maxCount > 0 ? item.count / maxCount : 0.0;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _kBrand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$rank',
            style: const TextStyle(
              color: _kBrandDark,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Text(
                    '${item.count} plan${item.count == 1 ? '' : 's'}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11.5),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  color: _kBrand,
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final List<_ActivityEntry> entries;
  final NumberFormat currency;
  const _RecentActivityCard({required this.entries, required this.currency});

  String _timestampLabel(DateTime ts) {
    final now = TimeService.now();
    final isToday =
        ts.year == now.year && ts.month == now.month && ts.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        ts.year == yesterday.year &&
        ts.month == yesterday.month &&
        ts.day == yesterday.day;
    final timeStr = DateFormat('h:mm a').format(ts);
    if (isToday) return 'Today, $timeStr';
    if (isYesterday) return 'Yesterday, $timeStr';
    return '${DateFormat('dd MMM').format(ts)}, $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
          ),
          Text(
            'Latest payments — handy for your own records',
            style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No payments yet.',
                style: TextStyle(color: Colors.grey[500]),
              ),
            )
          else
            for (int i = 0; i < entries.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == entries.length - 1 ? 0 : 12,
                ),
                child: _buildRow(entries[i]),
              ),
        ],
      ),
    );
  }

  Widget _buildRow(_ActivityEntry entry) {
    final inst = entry.installment;
    final name = inst.customerName ?? 'Customer';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                  children: [
                    TextSpan(
                      text: name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text:
                          ' paid ${currency.format(entry.amountPaid)} for ${inst.itemDescription}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _timestampLabel(entry.timestamp),
                style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
