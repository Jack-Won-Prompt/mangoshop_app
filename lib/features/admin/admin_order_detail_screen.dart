import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import 'admin_dashboard_screen.dart' show OrderStatusChip;

class AdminOrderDetailScreen extends ConsumerWidget {
  final int orderId;
  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminOrderProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('주문 상세')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
        error: (e, _) => ErrorRetry(e, () => ref.invalidate(adminOrderProvider(orderId))),
        data: (d) {
          final o = d.order;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // 헤더
              Row(children: [
                OrderStatusChip(o.status, o.statusLabel),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(o.orderNo,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                [o.createdAt?.replaceFirst('T', ' ').split('.').first, o.paymentLabel]
                    .whereType<String>()
                    .join(' · '),
                style: const TextStyle(fontSize: 12.5, color: AppColors.sub),
              ),

              const SizedBox(height: 20),
              _actions(context, ref, d),

              const SizedBox(height: 20),
              _card('주문상품', Column(
                children: o.items
                    .map((i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            NetImage(i.thumbnail, width: 44, height: 44, radius: 8),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.productName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                  Text('${won(i.price)} × ${i.quantity}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                                ],
                              ),
                            ),
                            Text(won(i.subtotal),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ]),
                        ))
                    .toList(),
              )),

              const SizedBox(height: 12),
              _card('결제', Column(children: [
                _kv('상품금액', won(o.subtotal)),
                _kv('배송비', won(o.shippingFee)),
                if (o.discount > 0) _kv('쿠폰할인', '-${won(o.discount)}', color: AppColors.red),
                if (o.pointUsed > 0) _kv('적립금 사용', '-${won(o.pointUsed)}', color: AppColors.red),
                const Divider(height: 18),
                _kv('결제금액', won(o.total), bold: true),
                if (o.paymentMethod == 'bank') ...[
                  const SizedBox(height: 6),
                  _kv('입금은행', o.bank ?? '-'),
                  _kv('입금자명', o.depositor ?? '-'),
                ],
              ])),

              const SizedBox(height: 12),
              _card('배송지', Column(children: [
                _kv('받는분', o.receiverName ?? '-'),
                _kv('연락처', o.receiverPhone ?? '-'),
                _kv('주소', [o.postcode, o.address1, o.address2]
                    .whereType<String>()
                    .where((s) => s.isNotEmpty)
                    .join(' ')),
                if ((o.memo ?? '').isNotEmpty) _kv('요청사항', o.memo!),
                if ((o.trackingNo ?? '').isNotEmpty)
                  _kv('송장', '${o.courier ?? ''} ${o.trackingNo}', color: AppColors.brand),
              ])),

              if (d.customer != null) ...[
                const SizedBox(height: 12),
                _card('주문자', Column(children: [
                  _kv('회원', '${d.customer!.name} (${d.customer!.memberLabel ?? '-'})'),
                  if ((d.customer!.companyName ?? '').isNotEmpty)
                    _kv('상호', d.customer!.companyName!),
                  _kv('이메일', d.customer!.email ?? '-'),
                  _kv('연락처', d.customer!.phone ?? '-'),
                ])),
              ],
            ],
          );
        },
      ),
    );
  }

  // ===== 관리 액션 =====
  Widget _actions(BuildContext context, WidgetRef ref, AdminOrderDetail d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showStatusSheet(context, ref, d),
          icon: const Icon(Icons.sync_alt, size: 18),
          label: const Text('주문상태 변경'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _showShippingSheet(context, ref, d.order),
          icon: const Icon(Icons.local_shipping_outlined, size: 18),
          label: Text((d.order.trackingNo ?? '').isEmpty ? '송장 등록' : '송장 수정'),
        ),
      ],
    );
  }

  Future<void> _showStatusSheet(BuildContext context, WidgetRef ref, AdminOrderDetail d) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Text('주문상태 변경',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...d.statuses.entries.map((e) {
              final current = e.key == d.order.status;
              return ListTile(
                leading: Icon(
                  current ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: current ? AppColors.brand : AppColors.line,
                ),
                title: Text(e.value,
                    style: TextStyle(fontWeight: current ? FontWeight.w800 : FontWeight.w500)),
                subtitle: switch (e.key) {
                  // 부수효과가 있는 상태는 미리 알려준다
                  'paid' => const Text('입금 확인 처리 · 적립금 지급', style: TextStyle(fontSize: 12)),
                  'cancelled' => const Text('재고 복구 · 적립금 정산 · 결제 환불', style: TextStyle(fontSize: 12)),
                  _ => null,
                },
                onTap: current ? null : () => Navigator.pop(context, e.key),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;

    // 되돌리기 어려운 취소는 한 번 더 확인
    if (picked == 'cancelled') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('주문을 취소할까요?'),
          content: const Text('재고가 복구되고 적립금이 정산됩니다.\n카드결제 건은 환불이 요청됩니다.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('닫기')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.red),
              child: const Text('주문 취소'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }

    try {
      final msg = await ref.read(adminActionsProvider).updateOrderStatus(orderId, picked);
      if (context.mounted) toast(context, msg);
    } catch (e) {
      if (context.mounted) {
        toast(context, e is ApiException ? e.firstError : '상태 변경에 실패했습니다.');
      }
    }
  }

  Future<void> _showShippingSheet(BuildContext context, WidgetRef ref, OrderModel o) async {
    final courierCtl = TextEditingController(text: o.courier ?? '');
    final trackingCtl = TextEditingController(text: o.trackingNo ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('송장 등록',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('등록하면 주문이 배송중으로 전환됩니다.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.sub)),
                const SizedBox(height: 16),
                TextField(
                  controller: courierCtl,
                  decoration: const InputDecoration(labelText: '택배사', hintText: 'CJ대한통운'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: trackingCtl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '송장번호'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(sheetCtx, true),
                  child: const Text('등록'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final courier = courierCtl.text.trim();
    final tracking = trackingCtl.text.trim();
    courierCtl.dispose();
    trackingCtl.dispose();

    if (saved != true || !context.mounted) return;
    if (courier.isEmpty || tracking.isEmpty) {
      toast(context, '택배사와 송장번호를 모두 입력해주세요.');
      return;
    }

    try {
      final msg = await ref.read(adminActionsProvider).updateShipping(orderId, courier, tracking);
      if (context.mounted) toast(context, msg);
    } catch (e) {
      if (context.mounted) {
        toast(context, e is ApiException ? e.firstError : '송장 등록에 실패했습니다.');
      }
    }
  }

  // ===== 레이아웃 헬퍼 =====
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

  Widget _kv(String k, String v, {Color? color, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 78,
              child: Text(k, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
            ),
            Expanded(
              child: Text(v,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                    color: color ?? AppColors.ink,
                  )),
            ),
          ],
        ),
      );
}
