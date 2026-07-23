import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminDashboardProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
      error: (e, _) => ErrorRetry(e, () => ref.invalidate(adminDashboardProvider)),
      data: (d) => RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () async => ref.invalidate(adminDashboardProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _salesCard(d),
            const SizedBox(height: 16),
            const Text('처리 대기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _actionTile(context, '입금대기 주문', d.pendingOrders, Icons.receipt_long_outlined, AppColors.brand, '/admin/orders?status=pending')),
              const SizedBox(width: 10),
              Expanded(child: _actionTile(context, '도매 승인대기', d.pendingUsers, Icons.how_to_reg_outlined, AppColors.wholesale, '/admin/users')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _actionTile(context, '미답변 문의', d.pendingInquiries, Icons.forum_outlined, AppColors.cool, '/admin/inquiries')),
              const SizedBox(width: 10),
              Expanded(child: _actionTile(context, '상품준비중', d.preparingOrders, Icons.inventory_2_outlined, AppColors.leaf, '/admin/orders?status=preparing')),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              const Text('최근 주문', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/admin/orders'),
                style: TextButton.styleFrom(foregroundColor: AppColors.sub, padding: EdgeInsets.zero),
                child: const Row(children: [Text('전체', style: TextStyle(fontSize: 13)), Icon(Icons.chevron_right, size: 18)]),
              ),
            ]),
            const SizedBox(height: 6),
            if (d.recentOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('아직 주문이 없습니다.', style: TextStyle(color: AppColors.sub))),
              )
            else
              ...d.recentOrders.map((o) => AdminOrderTile(o)),
          ],
        ),
      ),
    );
  }

  Widget _salesCard(AdminDashboard d) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘 매출',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(won(d.salesToday),
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          Text('주문 ${d.salesTodayCount}건',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(children: [
            Expanded(child: _miniStat('이번 달 매출', won(d.salesMonth))),
            Expanded(child: _miniStat('이번 달 주문', '${d.salesMonthCount}건')),
            Expanded(child: _miniStat('등록 상품', '${d.totalProducts}개')),
          ]),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      );

  Widget _actionTile(BuildContext context, String label, int count, IconData icon, Color color, String route) {
    final urgent = count > 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: urgent ? color.withValues(alpha: 0.45) : AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: urgent ? color : AppColors.sub),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
            const SizedBox(height: 2),
            Text('$count',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: urgent ? color : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// 주문 목록 행 — 대시보드/주문목록/회원상세에서 공용으로 쓴다.
class AdminOrderTile extends StatelessWidget {
  final AdminOrderRow order;
  const AdminOrderTile(this.order, {super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/admin/orders/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              OrderStatusChip(order.status, order.statusLabel),
              const SizedBox(width: 8),
              Expanded(
                child: Text(order.orderNo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
              ),
              Text(won(order.total),
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.sub),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [order.customerName ?? order.receiverName ?? '-',
                   if (order.itemCount != null) '${order.itemCount}개 상품']
                      .join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
                ),
              ),
              if (order.createdAt != null)
                Text(order.createdAt!.split('T').first,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 주문상태 배지 — 상태별 색을 한 곳에서 정의한다.
class OrderStatusChip extends StatelessWidget {
  final String status, label;
  const OrderStatusChip(this.status, this.label, {super.key});

  static Color colorOf(String status) => switch (status) {
        'pending' => AppColors.warn,
        'paid' => AppColors.cool,
        'preparing' => AppColors.wholesale,
        'shipped' => AppColors.brand,
        'done' => AppColors.leaf,
        'cancelled' => AppColors.sub,
        _ => AppColors.sub,
      };

  @override
  Widget build(BuildContext context) {
    final c = colorOf(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: c)),
    );
  }
}
