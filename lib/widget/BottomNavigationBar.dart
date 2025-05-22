import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const BottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF31394E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildNavItem(
                  1, Icons.store_outlined, Icons.store_rounded, 'Store'),
              _buildSpecialNavItem(),
              _buildNavItem(3, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
              _buildNavItem(4, Icons.info_outline, Icons.info_rounded, 'Info'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    final bool isSelected = selectedIndex == index;

    return InkWell(
      onTap: () => onItemTapped(index),
      borderRadius: BorderRadius.circular(16),
      splashColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? selectedIcon : unselectedIcon,
                color: isSelected
                    ? const Color(0xFFC58189)
                    : Colors.white.withOpacity(0.8),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFFC58189)
                    : Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialNavItem() {
    final bool isSelected = selectedIndex == 2;

    return GestureDetector(
      onTap: () => onItemTapped(2),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? const Color(0xFFC58189)
              : const Color(0xFFC58189).withOpacity(0.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC58189).withOpacity(0.4),
              blurRadius: isSelected ? 10 : 5,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
