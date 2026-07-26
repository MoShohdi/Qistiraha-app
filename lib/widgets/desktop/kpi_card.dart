import 'package:flutter/material.dart';
import 'package:qistiraha/core/theme/app_theme.dart';
import 'package:qistiraha/widgets/desktop/sparkline.dart';

/// A professional KPI tile: label + icon, a large value, and — for immediate
/// context — an optional micro trend [sparkline] OR a [progress] bar, plus an
/// optional [delta] chip (e.g. "+12% vs last month"). One consistent card for
/// every dashboard metric so the numbers read as one system.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Accent for the icon chip / sparkline / progress. Defaults to the muted
  /// blue accent.
  final Color accent;

  /// Micro trend under the value. Ignored if null/too short.
  final List<double>? sparkline;

  /// 0..1 progress bar shown under the value (used when [sparkline] is null).
  final double? progress;

  /// Optional signed delta, e.g. +0.12 → "+12%". Rendered as a subtle chip.
  final double? deltaPct;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppColors.accent,
    this.sparkline,
    this.progress,
    this.deltaPct,
  });

  @override
  Widget build(BuildContext context) {
    final hasSpark = sparkline != null && sparkline!.length >= 2;

    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: AppRadii.smAll,
                ),
                child: Icon(icon, color: accent, size: 17),
              ),
              const Spacer(),
              if (deltaPct != null) _DeltaChip(deltaPct!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (hasSpark) ...[
            const SizedBox(height: AppSpacing.md),
            Sparkline(data: sparkline!, color: accent, height: 30),
          ] else if (progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.accentWash,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final double deltaPct;
  const _DeltaChip(this.deltaPct);

  @override
  Widget build(BuildContext context) {
    final up = deltaPct >= 0;
    final color = up ? AppColors.success : AppColors.danger;
    final pct = (deltaPct * 100).abs().toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 2),
          Text(
            '$pct%',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
