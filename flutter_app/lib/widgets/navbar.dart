import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Navbar extends StatelessWidget {
  const Navbar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final isMarketplace = currentPath == '/' || currentPath.isEmpty;
    final isRegister = currentPath == '/register';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100, width: 1),
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1280),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => context.go('/'),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316), // orange-500
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.smartphone,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1C1917), // stone-900
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(text: 'SmartGrade'),
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: Color(0xFFF97316)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                // Desktop navigation
                if (MediaQuery.of(context).size.width >= 768) ...[
                  const SizedBox(width: 40),
                  _NavLink(
                    label: '마켓플레이스',
                    isActive: isMarketplace,
                    onTap: () => context.go('/'),
                  ),
                  const SizedBox(width: 40),
                  _NavLink(
                    label: '판매 등록',
                    isActive: isRegister,
                    onTap: () => context.go('/register'),
                  ),
                ],
                const SizedBox(width: 16),
                // Sell button
                GestureDetector(
                  onTap: () => context.go('/register'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1917), // stone-900
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          '판매하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavLink({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          color: isActive
              ? const Color(0xFF1C1917) // stone-900
              : const Color(0xFFA8A29E), // stone-400
        ),
      ),
    );
  }
}






