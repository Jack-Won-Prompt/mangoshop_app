import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import 'admin_dashboard_screen.dart' show AdminOrderTile;
import 'admin_users_screen.dart' show UserStatusChip;

class AdminUserDetailScreen extends ConsumerWidget {
  final int userId;
  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminUserProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('회원 상세')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => ErrorRetry(e, () => ref.invalidate(adminUserProvider(userId))),
        data: (d) {
          final u = d.user;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Row(children: [
                UserStatusChip(u),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(u.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(u.email, style: const TextStyle(fontSize: 13, color: AppColors.sub)),

              // 도매 신청 회원만 승인 액션을 노출한다
              if (u.isWholesale) ...[
                const SizedBox(height: 18),
                _approvalPanel(context, ref, u),
              ],

              const SizedBox(height: 18),
              _card('사업자 정보', Column(children: [
                _kv('상호', u.companyName ?? '-'),
                _kv('사업자번호', u.bizNo ?? '-'),
                _kv('업태/종목', u.bizType ?? '-'),
                _kv('연락처', u.phone ?? '-'),
              ])),

              const SizedBox(height: 12),
              _card('회원 정보', Column(children: [
                _kv('회원구분', u.isWholesale ? '도매(사업자)' : '소매'),
                _kv('등급', u.grade ?? '-'),
                _kv('적립금', won(u.point)),
                _kv('주문건수', '${u.ordersCount}건'),
                _kv('가입일', u.createdAt ?? '-'),
              ])),

              if (d.recentOrders.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('최근 주문', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                ...d.recentOrders.map((o) => AdminOrderTile(o)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _approvalPanel(BuildContext context, WidgetRef ref, AdminUserRow u) {
    final pending = u.isPending;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pending ? AppColors.accentSoft : AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: pending ? AppColors.warn.withValues(alpha: 0.4) : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(pending ? Icons.pending_actions : Icons.verified_outlined,
                size: 18, color: pending ? AppColors.warn : AppColors.leaf),
            const SizedBox(width: 6),
            Text(pending ? '사업자 승인 대기 중' : '현재 상태: ${u.statusLabel}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          const Text('승인하면 이 회원에게 도매가가 적용됩니다.',
              style: TextStyle(fontSize: 12.5, color: AppColors.sub)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: u.bizStatus == 'rejected'
                    ? null
                    : () => _confirm(context, ref, u, 'rejected'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('반려'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: u.bizStatus == 'approved'
                    ? null
                    : () => _confirm(context, ref, u, 'approved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.leaf,
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('승인'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, AdminUserRow u, String status) async {
    final approving = status == 'approved';

    // 승인 시에는 등급도 함께 정한다 (서버 기본값 basic)
    String grade = u.grade ?? 'basic';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (_, setInner) => AlertDialog(
          title: Text(approving ? '도매회원으로 승인할까요?' : '승인을 반려할까요?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                approving
                    ? '${u.companyName ?? u.name} 님에게 도매가가 즉시 적용됩니다.'
                    : '${u.companyName ?? u.name} 님은 계속 소매가로 이용하게 됩니다.',
                style: const TextStyle(fontSize: 13.5),
              ),
              if (approving) ...[
                const SizedBox(height: 16),
                const Text('회원 등급', style: TextStyle(fontSize: 12.5, color: AppColors.sub)),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'basic', label: Text('basic')),
                    ButtonSegment(value: 'silver', label: Text('silver')),
                    ButtonSegment(value: 'gold', label: Text('gold')),
                  ],
                  selected: {grade},
                  onSelectionChanged: (s) => setInner(() => grade = s.first),
                  showSelectedIcon: false,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('닫기')),
            TextButton(
              onPressed: () => Navigator.pop(dCtx, true),
              style: TextButton.styleFrom(
                  foregroundColor: approving ? AppColors.leaf : AppColors.red),
              child: Text(approving ? '승인' : '반려'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final msg = await ref
          .read(adminActionsProvider)
          .approveUser(u.id, status, grade: approving ? grade : null);
      if (context.mounted) toast(context, msg);
    } catch (e) {
      if (context.mounted) {
        toast(context, e is ApiException ? e.firstError : '처리에 실패했습니다.');
      }
    }
  }

  Widget _card(String title, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 78,
              child: Text(k, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
            ),
            Expanded(
              child: Text(v, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}
