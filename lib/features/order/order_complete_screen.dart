import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class OrderCompleteScreen extends ConsumerWidget {
  final int orderId;
  const OrderCompleteScreen({super.key, required this.orderId});

  Future<OrderModel> _fetch(WidgetRef ref) async {
    final res = await ref.read(apiProvider).get('/orders/$orderId');
    return OrderModel.fromJson(res['order']);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('주문완료'),
      ),
      body: FutureBuilder<OrderModel>(
        future: _fetch(ref),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.navy));
          }
          if (snap.hasError || !snap.hasData) {
            return Center(
              child: EmptyState(
                Icons.error_outline,
                snap.error is ApiException
                    ? (snap.error as ApiException).firstError
                    : '주문 정보를 불러오지 못했습니다.',
                action: SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('홈으로'),
                  ),
                ),
              ),
            );
          }
          return _body(context, snap.data!);
        },
      ),
    );
  }

  Widget _body(BuildContext context, OrderModel order) {
    final isBank = order.paymentMethod == 'bank';
    final hasVa = order.vaAccount != null && order.vaAccount!.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: const BoxDecoration(
                    color: AppColors.redSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      color: AppColors.red, size: 56),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('주문이 완료되었습니다',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text('주문번호 ${order.orderNo}',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.sub)),
              ),
              const SizedBox(height: 24),
              _infoCard(order),
              if (isBank) ...[
                const SizedBox(height: 16),
                hasVa ? _vaCard(order) : _depositCard(order),
              ],
            ],
          ),
        ),
        _buttons(context, order),
      ],
    );
  }

  Widget _infoCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _row('결제수단', order.paymentLabel),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('총 결제금액',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(won(order.total),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _depositCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.account_balance_outlined,
                  size: 18, color: AppColors.red),
              SizedBox(width: 8),
              Text('입금 안내',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red)),
            ],
          ),
          const SizedBox(height: 14),
          if (order.bank != null && order.bank!.isNotEmpty)
            _row('입금은행', order.bank!),
          if (order.depositor != null && order.depositor!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _row('입금자명', order.depositor!),
          ],
          const SizedBox(height: 10),
          _row('입금금액', won(order.total), highlight: true),
          const SizedBox(height: 14),
          const Text(
            '입금 계좌 정보는 마이페이지 > 주문상세에서 확인하실 수 있습니다.\n입금이 확인되면 주문이 자동으로 처리됩니다.',
            style: TextStyle(fontSize: 12, color: AppColors.sub, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _vaCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.redSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: AppColors.red),
              SizedBox(width: 8),
              Text('가상계좌 입금 안내',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red)),
            ],
          ),
          const SizedBox(height: 14),
          if (order.vaBank != null) _row('은행', order.vaBank!),
          const SizedBox(height: 10),
          _row('계좌번호', order.vaAccount ?? '-'),
          if (order.vaHolder != null && order.vaHolder!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _row('예금주', order.vaHolder!),
          ],
          const SizedBox(height: 10),
          _row('입금금액', won(order.total), highlight: true),
          if (order.vaDueAt != null && order.vaDueAt!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _row('입금기한', order.vaDueAt!),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.sub)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: highlight ? 16 : 14,
                  fontWeight: highlight ? FontWeight.w900 : FontWeight.w600,
                  color: highlight ? AppColors.red : AppColors.ink)),
        ),
      ],
    );
  }

  Widget _buttons(BuildContext context, OrderModel order) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.push('/orders/${order.id}'),
              child: const Text('주문상세'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('쇼핑 계속'),
            ),
          ),
        ],
      ),
    );
  }
}
