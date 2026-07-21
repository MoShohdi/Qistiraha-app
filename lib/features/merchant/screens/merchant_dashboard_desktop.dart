import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/utils/responsive_layout.dart';
import 'package:qistiraha/features/auth/models/business_account.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';
import 'package:qistiraha/features/auth/screens/welcome_screen.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'package:qistiraha/widgets/branded_bar_chart_card.dart';
import 'merchant_customer_profile_screen.dart';
import 'merchant_installment_details_screen.dart';
import 'merchant_portal_screen.dart';

const _kBrand = Color(0xFF99AFD7);
const _kBrandDark = Color(0xFF5A75AD);
const _kBg = Color(0xFFF8F9FA);
const _kSidebarWidth = 260.0;

enum _MerchantNav { overview, customers, active, insights }

enum _ActiveFilter { all, overdue, pending, paid }

/// Desktop/web shell for the merchant side — a fixed sidebar (store identity,
/// the primary "Generate Payment Link" action, and section navigation) next
/// to a main content area that reflows per section: a KPI grid for Overview,
/// master-detail layouts for Customers/Active Installments, and a dashboard
/// grid for Insights. Reuses the same Hive-backed data and, for the detail
/// panes, the exact same mobile screens (embedded via [EmbeddedScreen]) so
/// there is a single source of truth for that logic.
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
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 20,
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
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          business.category,
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              MerchantPortalScreen(business: business),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code, size: 18),
                    label: const Text(
                      'Generate Payment Link',
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
// Overview — KPI + upcoming-installments grid
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

  @override
  Widget build(BuildContext context) {
    final upcoming =
        widget.plans
            .where((i) => i.statusEnum != InstallmentStatus.paid)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

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
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 280,
                    child: _DesktopStatCard(
                      label: 'Total Expected Revenue',
                      value: widget.currency.format(_totalExpected),
                      icon: Icons.trending_up,
                      color: _kBrand,
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: _DesktopStatCard(
                      label: 'Total Received',
                      value: widget.currency.format(_totalReceived),
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'Upcoming Installments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Across all customers, soonest first',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (upcoming.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No upcoming installments yet.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcoming.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 380,
                    mainAxisExtent: 136,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    final inst = upcoming[index];
                    return _UpcomingDesktopCard(
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
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 19),
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingDesktopCard extends StatelessWidget {
  final Installment installment;
  final NumberFormat currency;
  final VoidCallback onTap;

  const _UpcomingDesktopCard({
    required this.installment,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOverdue = installment.statusEnum == InstallmentStatus.overdue;
    return DesktopHoverCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    installment.customerName ?? 'Customer',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    installment.itemDescription,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isOverdue
                        ? 'Overdue since ${DateFormat('dd MMM').format(installment.dueDate)}'
                        : 'Due ${DateFormat('dd MMM yyyy').format(installment.dueDate)}',
                    style: TextStyle(
                      color: isOverdue ? Colors.red[700] : Colors.grey[500],
                      fontSize: 12,
                      fontWeight: isOverdue
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currency.format(installment.monthlyPayment),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
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
                        padding: const EdgeInsets.only(right: 12, bottom: 12),
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

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DesktopHoverCard(
                              selected: c.key == widget.selectedKey,
                              onTap: () => widget.onSelect(c.key),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: healthColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      child: Icon(
                                        Icons.person,
                                        color: healthColor,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${c.plans.length} plan${c.plans.length == 1 ? '' : 's'} • Outstanding ${widget.currency.format(c.outstanding)}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: healthColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        healthLabel,
                                        style: TextStyle(
                                          color: healthColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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

  const _ActiveMasterDetail({
    required this.plans,
    required this.currency,
    required this.selected,
    required this.onSelect,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _filterChip('All', _ActiveFilter.all),
                      _filterChip('Overdue', _ActiveFilter.overdue),
                      _filterChip('Pending', _ActiveFilter.pending),
                      _filterChip('Paid', _ActiveFilter.paid),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                              padding: const EdgeInsets.only(
                                right: 12,
                                bottom: 12,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final p = filtered[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _ActiveDesktopCard(
                                    installment: p,
                                    currency: widget.currency,
                                    selected: widget.selected?.id == p.id,
                                    onTap: () => widget.onSelect(p),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
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
                child: widget.selected == null
                    ? const DesktopEmptyDetail(
                        message: 'Select a contract to view details',
                      )
                    : EmbeddedScreen(
                        key: ValueKey('installment-${widget.selected!.id}'),
                        child: MerchantInstallmentDetailsScreen(
                          installment: widget.selected!,
                        ),
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

class _ActiveDesktopCard extends StatelessWidget {
  final Installment installment;
  final NumberFormat currency;
  final bool selected;
  final VoidCallback onTap;

  const _ActiveDesktopCard({
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
                    installment.itemDescription,
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
            const SizedBox(height: 4),
            Text(
              installment.customerName ?? 'Customer',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
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
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 260,
                    child: _DesktopStatCard(
                      label: 'Total Expected Revenue',
                      value: widget.currency.format(_totalExpected),
                      icon: Icons.account_balance_wallet_outlined,
                      color: _kBrand,
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: _DesktopStatCard(
                      label: 'Revenue Collected',
                      value: widget.currency.format(_totalCollected),
                      icon: Icons.savings_outlined,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: _StoreHealthDesktopCard(
                      onTimePct: _onTimePct,
                      onTimeCount: _onTimeCount,
                      overdueCount: _overdueCount,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BrandedBarChartCard(
                title: 'Projected Cash Flow',
                subtitle: 'Expected collections over the next 6 months',
                buckets: cashFlow,
                labels: monthLabels,
              ),
              const SizedBox(height: 24),
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
                        const SizedBox(height: 24),
                        activity,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: topSelling),
                      const SizedBox(width: 24),
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
    final pctLabel = '${(onTimePct * 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: onTimePct.clamp(0.0, 1.0),
                    strokeWidth: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(_kBrand),
                  ),
                ),
                Text(
                  pctLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Store Health',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
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
            'Top Selling Items',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            'Ranked by number of active installment plans',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
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
                  bottom: i == items.length - 1 ? 0 : 14,
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
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _kBrand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$rank',
            style: const TextStyle(
              color: _kBrandDark,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${item.count} plan${item.count == 1 ? '' : 's'}',
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
                  minHeight: 6,
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
            'Recent Activity',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            'Latest payments — handy for your own records',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
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
                  bottom: i == entries.length - 1 ? 0 : 14,
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
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
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
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
