import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';

/// 관리자 모드 하단 탭 셸.
///
/// 관리자 계정으로 로그인하면 쇼핑 화면 대신 이 셸로 진입한다.
/// 앱바의 '고객 화면' 버튼으로 언제든 일반 쇼핑 화면으로 넘어갈 수 있다.
class AdminShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const AdminShell(this.shell, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    // 처리 대기 건수 — 탭 배지. 로딩/실패 시에는 배지를 숨긴다.
    final dash = ref.watch(adminDashboardProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('관리자',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                user?.name ?? '망고샵',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text('고객 화면'),
            style: TextButton.styleFrom(foregroundColor: AppColors.brand),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: shell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: '대시보드',
          ),
          BottomNavigationBarItem(
            icon: _badged(Icons.receipt_long_outlined, dash?.pendingOrders ?? 0),
            activeIcon: _badged(Icons.receipt_long, dash?.pendingOrders ?? 0),
            label: '주문',
          ),
          BottomNavigationBarItem(
            icon: _badged(Icons.how_to_reg_outlined, dash?.pendingUsers ?? 0),
            activeIcon: _badged(Icons.how_to_reg, dash?.pendingUsers ?? 0),
            label: '회원승인',
          ),
          BottomNavigationBarItem(
            icon: _badged(Icons.forum_outlined, dash?.pendingInquiries ?? 0),
            activeIcon: _badged(Icons.forum, dash?.pendingInquiries ?? 0),
            label: '문의·후기',
          ),
        ],
      ),
    );
  }

  Widget _badged(IconData icon, int count) => Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: AppColors.red,
        child: Icon(icon),
      );
}
