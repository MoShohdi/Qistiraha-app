import 'package:flutter/material.dart';
import '../models/user_role.dart';

/// Segmented "I am a Consumer" / "I am a Merchant" control shared by the
/// Login and Signup screens.
class RoleToggle extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;

  const RoleToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildOption(
              context,
              UserRole.consumer,
              'I am a Consumer',
              Icons.person_outline,
            ),
          ),
          Expanded(
            child: _buildOption(
              context,
              UserRole.merchant,
              'I am a Merchant',
              Icons.storefront_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context,
    UserRole role,
    String label,
    IconData icon,
  ) {
    final bool isSelected = selected == role;
    return GestureDetector(
      onTap: () => onChanged(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF99AFD7) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.black54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
