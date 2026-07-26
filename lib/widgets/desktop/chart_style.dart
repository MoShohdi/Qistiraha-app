import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:qistiraha/core/theme/app_theme.dart';

/// Shared fl_chart styling so every chart across the app reads as one system:
/// subtle horizontal-only grid lines, no hard border, muted axis labels, and a
/// clean dark tooltip. Drop these into `LineChartData` / `BarChartData` instead
/// of hand-styling each chart.
abstract final class ChartStyle {
  /// Faint horizontal gridlines only (vertical lines are visual noise here).
  static FlGridData grid(double interval) => FlGridData(
    show: true,
    drawVerticalLine: false,
    horizontalInterval: interval <= 0 ? 1 : interval,
    getDrawingHorizontalLine: (_) =>
        const FlLine(color: AppColors.border, strokeWidth: 1),
  );

  static FlBorderData get noBorder => FlBorderData(show: false);

  /// Month/category labels along the x-axis.
  static AxisTitles bottomLabels(List<String> labels) => AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 26,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final i = value.round();
        if ((value - i).abs() > 0.01 || i < 0 || i >= labels.length) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            labels[i],
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        );
      },
    ),
  );

  /// Compact left-axis money labels (1.2K, 3M …).
  static AxisTitles leftMoney(double interval) => AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 42,
      interval: interval <= 0 ? 1 : interval,
      getTitlesWidget: (value, meta) => Text(
        compact(value),
        style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
      ),
    ),
  );

  static AxisTitles get hidden =>
      const AxisTitles(sideTitles: SideTitles(showTitles: false));

  static String compact(double v) {
    if (v == 0) return '0';
    if (v.abs() >= 1000000) {
      return '${(v / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    }
    if (v.abs() >= 1000) {
      return '${(v / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    }
    return v.toStringAsFixed(0);
  }

  static LineTouchData lineTooltip(String Function(double) fmt) => LineTouchData(
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => AppColors.ink,
      tooltipRoundedRadius: 8,
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      getTooltipItems: (spots) => spots
          .map(
            (s) => LineTooltipItem(
              fmt(s.y),
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          )
          .toList(),
    ),
  );

  static BarTouchData barTooltip(String Function(double) fmt) => BarTouchData(
    touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => AppColors.ink,
      tooltipRoundedRadius: 8,
      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
        fmt(rod.toY),
        const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    ),
  );

  /// Muted line series with a soft gradient fill.
  static LineChartBarData lineSeries(
    List<double> values, {
    Color color = AppColors.accent,
  }) {
    return LineChartBarData(
      spots: [
        for (int i = 0; i < values.length; i++)
          FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}
