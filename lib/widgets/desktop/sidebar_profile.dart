import 'package:flutter/material.dart';
import 'package:qistiraha/core/theme/app_theme.dart';
import 'package:qistiraha/widgets/desktop/action_menu.dart';

/// A profile card anchored at the bottom of a desktop sidebar: avatar, name,
/// and a secondary line, with a popover menu ("⋯") for the administrative
/// items (Profile, Settings, Log out) that shouldn't clutter the primary
/// navigation. Keeps the main nav focused on core views.
class SidebarProfileMenu extends StatelessWidget {
  final String name;
  final String? subtitle;
  final IconData avatarIcon;
  final List<ActionMenuItem> menuItems;

  const SidebarProfileMenu({
    super.key,
    required this.name,
    required this.menuItems,
    this.subtitle,
    this.avatarIcon = Icons.person_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accentWash,
            child: Icon(avatarIcon, size: 17, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          ActionMenuButton(items: menuItems),
        ],
      ),
    );
  }
}
