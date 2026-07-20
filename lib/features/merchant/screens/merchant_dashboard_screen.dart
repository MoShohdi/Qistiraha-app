import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/hive_service.dart';
import 'package:qistiraha/core/utils/card_entrance_animation.dart';
import 'package:qistiraha/features/auth/models/business_account.dart';
import 'package:qistiraha/features/auth/services/auth_service.dart';
import 'package:qistiraha/features/auth/screens/welcome_screen.dart';
import 'package:qistiraha/features/consumer/models/installment.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'package:qistiraha/features/merchant/widgets/merchant_plan_row.dart';
import 'merchant_customer_profile_screen.dart';
import 'merchant_insights_screen.dart';
import 'merchant_installment_details_screen.dart';
import 'merchant_portal_screen.dart';

const _kBrand = Color(0xFF99AFD7);
const _kBg = Color(0xFFF8F9FA);

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  final _currency = NumberFormat.currency(symbol: 'EGP ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: ValueListenableBuilder(
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
            appBar: AppBar(
              backgroundColor: _kBg,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 18,
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
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.black87),
                  tooltip: 'Log Out',
                  onPressed: () async {
                    await AuthService.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WelcomeScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
              bottom: const TabBar(
                labelColor: _kBrand,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _kBrand,
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Customers'),
                  Tab(text: 'Active Installments'),
                  Tab(text: 'Insights'),
                ],
              ),
            ),
            body: ValueListenableBuilder(
              valueListenable: HiveService.getInstallmentBox().listenable(),
              builder: (context, Box<Installment> installmentBox, _) {
                final List<Installment> plans = installmentBox.values
                    .where((i) => i.merchantId == business.id)
                    .toList();

                return TabBarView(
                  children: [
                    _OverviewTab(plans: plans, currency: _currency),
                    _CustomersTab(plans: plans, currency: _currency),
                    _ActiveInstallmentsTab(plans: plans, currency: _currency),
                    MerchantInsightsScreen(plans: plans, currency: _currency),
                  ],
                );
              },
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1E2337),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code),
              label: const Text(
                'Generate Payment Link',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MerchantPortalScreen(business: business),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Overview
// ---------------------------------------------------------------------------
class _OverviewTab extends StatelessWidget {
  final List<Installment> plans;
  final NumberFormat currency;
  const _OverviewTab({required this.plans, required this.currency});

  double get _totalExpected => plans.fold(0.0, (sum, i) => sum + i.amount);

  double get _totalReceived => plans.fold(0.0, (sum, i) {
    if (i.pastPayments.isNotEmpty) {
      return sum + i.pastPayments.fold(0.0, (a, b) => a + b);
    }
    return sum + (i.paidPayments * i.monthlyPayment);
  });

  @override
  Widget build(BuildContext context) {
    final upcoming =
        plans.where((i) => i.statusEnum != InstallmentStatus.paid).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Expected Revenue',
                value: currency.format(_totalExpected),
                icon: Icons.trending_up,
                color: _kBrand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Total Received',
                value: currency.format(_totalReceived),
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
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
          ...upcoming.map(
            (i) => _UpcomingTile(installment: i, currency: currency),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CardPopIn(
      id: 'merchant-stat-card-$label',
      builder: (context, animate) => Container(
        padding: const EdgeInsets.all(18),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ).popInIf(animate, 0),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ).popInIf(animate, 0),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ).popInIf(animate, 1),
          ],
        ),
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final Installment installment;
  final NumberFormat currency;
  const _UpcomingTile({required this.installment, required this.currency});

  @override
  Widget build(BuildContext context) {
    final bool isOverdue = installment.statusEnum == InstallmentStatus.overdue;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MerchantInstallmentDetailsScreen(installment: installment),
          ),
        );
      },
      child: CardPopIn(
        id: installment.id,
        builder: (context, animate) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOverdue
                  ? Colors.red.withValues(alpha: 0.4)
                  : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      installment.customerName ?? 'Customer',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ).popInIf(animate, 0),
                    const SizedBox(height: 2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          installment.itemDescription,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOverdue
                              ? 'Overdue since ${DateFormat('dd MMM').format(installment.dueDate)}'
                              : 'Due ${DateFormat('dd MMM yyyy').format(installment.dueDate)}',
                          style: TextStyle(
                            color: isOverdue
                                ? Colors.red[700]
                                : Colors.grey[500],
                            fontSize: 12,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ).popInIf(animate, 1),
                  ],
                ),
              ),
              Text(
                currency.format(installment.monthlyPayment),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ).popInIf(animate, 0),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Customers
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

class _CustomersTab extends StatelessWidget {
  final List<Installment> plans;
  final NumberFormat currency;
  const _CustomersTab({required this.plans, required this.currency});

  List<_CustomerSummary> _groupByCustomer() {
    final Map<String, List<Installment>> grouped = {};
    for (final p in plans) {
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

    if (customers.isEmpty) {
      return Center(
        child: Text(
          'No customers yet.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
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

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MerchantCustomerProfileScreen(
                  customerName: c.name,
                  customerPhone: c.plans.first.customerPhone,
                  plans: c.plans,
                  currency: currency,
                ),
              ),
            );
          },
          child: CardPopIn(
            id: 'merchant-customer-${c.key}',
            builder: (context, animate) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: healthColor.withValues(alpha: 0.15),
                    child: Icon(Icons.person, color: healthColor),
                  ).popInIf(animate, 0),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          '${c.plans.length} plan${c.plans.length == 1 ? '' : 's'} • Outstanding ${currency.format(c.outstanding)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ).popInIf(animate, 1),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: healthColor.withValues(alpha: 0.12),
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
                  ).popInIf(animate, 2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Active Installments
// ---------------------------------------------------------------------------
enum _StatusFilter { all, overdue, pending, paid }

class _ActiveInstallmentsTab extends StatefulWidget {
  final List<Installment> plans;
  final NumberFormat currency;
  const _ActiveInstallmentsTab({required this.plans, required this.currency});

  @override
  State<_ActiveInstallmentsTab> createState() => _ActiveInstallmentsTabState();
}

class _ActiveInstallmentsTabState extends State<_ActiveInstallmentsTab> {
  _StatusFilter _filter = _StatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.plans.where((p) {
      switch (_filter) {
        case _StatusFilter.overdue:
          return p.statusEnum == InstallmentStatus.overdue;
        case _StatusFilter.pending:
          return p.statusEnum == InstallmentStatus.active;
        case _StatusFilter.paid:
          return p.statusEnum == InstallmentStatus.paid;
        case _StatusFilter.all:
          return true;
      }
    }).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              _filterChip('All', _StatusFilter.all),
              const SizedBox(width: 8),
              _filterChip('Overdue', _StatusFilter.overdue),
              const SizedBox(width: 8),
              _filterChip('Pending', _StatusFilter.pending),
              const SizedBox(width: 8),
              _filterChip('Paid', _StatusFilter.paid),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No installments match this filter.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final p = filtered[index];
                    return MerchantPlanRow(
                      installment: p,
                      currency: widget.currency,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MerchantInstallmentDetailsScreen(
                              installment: p,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, _StatusFilter value) {
    final bool selected = _filter == value;
    return ChoiceChip(
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
    );
  }
}
