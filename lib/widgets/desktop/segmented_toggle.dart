import 'package:flutter/material.dart';
import 'package:qistiraha/core/theme/app_theme.dart';

/// One option in a [SegmentedToggle].
class ToggleOption<T> {
  final T value;
  final String label;
  const ToggleOption(this.value, this.label);
}

/// A compact, professional segmented control — the quick comparison toggle
/// that sits above charts and lists ("This Month / Last Month",
/// "Active / Paid Off"). Muted, single-accent, no shouting.
class SegmentedToggle<T> extends StatelessWidget {
  final List<ToggleOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            _Segment(
              label: o.label,
              selected: o.value == value,
              onTap: () => onChanged(o.value),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.sm - 2),
            border: Border.all(
              color: selected ? AppColors.border : Colors.transparent,
            ),
            boxShadow: selected ? AppShadows.card : const [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
