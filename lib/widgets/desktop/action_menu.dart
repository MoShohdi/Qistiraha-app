import 'package:flutter/material.dart';
import 'package:qistiraha/core/theme/app_theme.dart';

/// One row action for [ActionMenuButton].
class ActionMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onSelected;

  /// Renders in the danger color (e.g. Delete / Cancel).
  final bool destructive;

  const ActionMenuItem({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.destructive = false,
  });
}

/// A clean "⋯" overflow menu — replaces a cluster of Edit/Delete/Pay buttons
/// on a card or table row with a single, unobtrusive [PopupMenuButton].
class ActionMenuButton extends StatelessWidget {
  final List<ActionMenuItem> items;
  final double size;

  const ActionMenuButton({super.key, required this.items, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Actions',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, size: size, color: AppColors.textTertiary),
      splashRadius: 18,
      position: PopupMenuPosition.under,
      onSelected: (i) => items[i].onSelected(),
      itemBuilder: (context) => [
        for (int i = 0; i < items.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 42,
            child: Row(
              children: [
                Icon(
                  items[i].icon,
                  size: 16,
                  color: items[i].destructive
                      ? AppColors.danger
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  items[i].label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: items[i].destructive
                        ? AppColors.danger
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
