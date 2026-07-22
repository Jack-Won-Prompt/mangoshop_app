import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/cart_provider.dart';

/// 하단 탭 네비게이션 셸
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const AppShell(this.shell, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider).count;

    return Scaffold(
      body: shell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: '홈'),
          const BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view_rounded), label: '카테고리'),
          BottomNavigationBarItem(
            icon: _cartIcon(cartCount, false),
            activeIcon: _cartIcon(cartCount, true),
            label: '장바구니',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: '관심'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: '마이'),
        ],
      ),
    );
  }

  Widget _cartIcon(int count, bool active) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.red,
      child: Icon(active ? Icons.shopping_cart : Icons.shopping_cart_outlined),
    );
  }
}
