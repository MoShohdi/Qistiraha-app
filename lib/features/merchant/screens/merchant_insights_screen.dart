import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qistiraha/core/services/time_service.dart';
import 'package:qistiraha/core/services/database_service.dart';
import 'package:qistiraha/features/consumer/models/enums.dart';
import 'package:qistiraha/features/merchant/widgets/installment_row_compat.dart';
import 'package:qistiraha/widgets/branded_bar_chart_card.dart';
import 'package:qistiraha/core/utils/card_entrance_animation.dart';

const _kBrand = kBrandColor;
const _kBrandDark = kBrandColorDark;

/// Data-driven dashboard for beta merchants: revenue KPIs, a store-health
/// ring, a projected cash-flow chart, and a top-selling-items ranking —
/// all derived from the merchant's own active installment plans.
class MerchantInsightsScreen extends StatelessWidget {
  final List<InstallmentRow> plans;
  final NumberFormat currency;

  const MerchantInsightsScreen({
    super.key,
    required this.plans,
    required this.currency,
  });

  double get _totalExpected => plans.fold(0.0, (sum, i) => sum + i.amount);

  double get _totalCollected => plans.fold(0.0, (sum, i) {
    if (i.pastPayments.isNotEmpty) {
      return sum + i.pastPayments.fold(0.0, (a, b) => a + b);
    }
    return sum + (i.paidPayments * i.monthlyPayment);
  });

  int get _onTimeCount => plans
      .where(
        (i) =>
            i.statusEnum != InstallmentStatus.overdue &&
            i.statusEnum != InstallmentStatus.defaulted,
      )
      .length;

  int get _overdueCount => plans
      .where(
        (i) =>
            i.statusEnum == InstallmentStatus.overdue ||
            i.statusEnum == InstallmentStatus.defaulted,
      )
      .length;

  double get _onTimePct => plans.isEmpty ? 1.0 : _onTimeCount / plans.length;

  /// Projects expected collections for the next 6 months from each active
  /// plan's remaining payments. Overdue plans are anchored to "now" since
  /// their original schedule has already lapsed.
  List<double> _projectCashFlow() {
    final buckets = List<double>.filled(6, 0.0);
    final now = TimeService.now();

    for (final inst in plans) {
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
    for (final inst in plans) {
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

  /// Each installment contributes at most one row here — its most recent
  /// payment — since the data model only tracks a single [lastPaidAt] per
  /// plan rather than a timestamped ledger of every individual payment.
  List<_ActivityEntry> _recentActivity() {
    final entries = <_ActivityEntry>[];
    for (final inst in plans) {
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
    if (plans.isEmpty) {
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Expected Revenue',
                value: currency.format(_totalExpected),
                icon: Icons.account_balance_wallet_outlined,
                color: _kBrand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Revenue Collected',
                value: currency.format(_totalCollected),
                icon: Icons.savings_outlined,
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StoreHealthCard(
          onTimePct: _onTimePct,
          onTimeCount: _onTimeCount,
          overdueCount: _overdueCount,
        ),
        const SizedBox(height: 24),
        BrandedBarChartCard(
          title: 'Projected Cash Flow',
          subtitle: 'Expected collections over the next 6 months',
          buckets: cashFlow,
          labels: monthLabels,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardPopIn(
                id: 'merchant-top-items-header',
                builder: (context, animate) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Selling Items',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Ranked by number of active installment plans',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ).popInIf(animate, 0),
              ),
              const SizedBox(height: 16),
              if (topItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No items yet.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              else
                ...topItems.asMap().entries.map(
                  (e) => _TopItemRow(
                    rank: e.key + 1,
                    item: e.value,
                    currency: currency,
                    maxCount: topItems.first.count,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CardPopIn(
                id: 'merchant-recent-activity-header',
                builder: (context, animate) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Latest payments — handy for your own records',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ).popInIf(animate, 0),
              ),
              const SizedBox(height: 16),
              if (recentActivity.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No payments yet.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              else
                ...recentActivity.map(
                  (entry) => _ActivityRow(entry: entry, currency: currency),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopItem {
  final String name;
  int count = 0;
  double revenue = 0.0;
  _TopItem({required this.name});
}

class _ActivityEntry {
  final InstallmentRow installment;
  final double amountPaid;
  final DateTime timestamp;
  _ActivityEntry({
    required this.installment,
    required this.amountPaid,
    required this.timestamp,
  });
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
      id: 'merchant-insights-stat-$label',
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

class _StoreHealthCard extends StatelessWidget {
  final double onTimePct;
  final int onTimeCount;
  final int overdueCount;
  const _StoreHealthCard({
    required this.onTimePct,
    required this.onTimeCount,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    final pctLabel = '${(onTimePct * 100).toStringAsFixed(0)}%';
    return CardPopIn(
      id: 'merchant-store-health-card',
      builder: (context, animate) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: onTimePct.clamp(0.0, 1.0),
                      strokeWidth: 7,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(_kBrand),
                    ),
                  ),
                  Text(
                    pctLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ).popInIf(animate, 0),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Store Health',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _dot(_kBrand),
                      const SizedBox(width: 6),
                      Text(
                        '$onTimeCount on-time',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                      const SizedBox(width: 14),
                      _dot(Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        '$overdueCount overdue',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ).popInIf(animate, 1),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
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
    return CardPopIn(
      id: 'merchant-top-item-${item.name}',
      builder: (context, animate) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
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
            ).popInIf(animate, 0),
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
            ).popInIf(animate, 1),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final _ActivityEntry entry;
  final NumberFormat currency;
  const _ActivityRow({required this.entry, required this.currency});

  String get _timestampLabel {
    final now = TimeService.now();
    final ts = entry.timestamp;
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
    final inst = entry.installment;
    final name = inst.customerName ?? 'Customer';

    return CardPopIn(
      id: 'merchant-activity-${inst.id}',
      builder: (context, animate) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
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
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 17,
              ),
            ).popInIf(animate, 0),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
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
                    _timestampLabel,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ).popInIf(animate, 1),
          ],
        ),
      ),
    );
  }
}
