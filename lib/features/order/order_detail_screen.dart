import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import 'orders_screen.dart' show orderStatusChip;

class OrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  OrderModel? _order;
  bool _loading = true;
  bool _cancelling = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).get('/orders/${widget.orderId}');
      setState(() {
        _order = OrderModel.fromJson(res['order']);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.firstError : '주문 정보를 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('주문 취소'),
        content: const Text('이 주문을 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('닫기',
                style: TextStyle(color: AppColors.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('주문취소',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      final res = await ref
          .read(apiProvider)
          .post('/orders/${widget.orderId}/cancel');
      setState(() {
        _order = OrderModel.fromJson(res['order']);
        _cancelling = false;
      });
      // 적립금 복원 반영
      await ref.read(authProvider.notifier).refresh();
      if (mounted) toast(context, (res['message'] ?? '주문이 취소되었습니다.').toString());
    } catch (e) {
      setState(() => _cancelling = false);
      if (mounted) {
        toast(context, e is ApiException ? e.firstError : '주문 취소에 실패했습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문상세')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.navy))
          : _error != null
              ? ErrorRetry(_error!, _load)
              : _content(_order!),
    );
  }

  Widget _content(OrderModel order) {
    final isBank = order.paymentMethod == 'bank';
    final hasVa = order.vaAccount != null && order.vaAccount!.isNotEmpty;
    final shipped = order.courier != null &&
        order.courier!.isNotEmpty &&
        order.trackingNo != null &&
        order.trackingNo!.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _headerCard(order),
              const SizedBox(height: 16),
              if (shipped) ...[
                _card('배송조회', _shippingInfo(order)),
                const SizedBox(height: 16),
              ],
              _card('주문상품', _items(order)),
              const SizedBox(height: 16),
              _card('배송지', _delivery(order)),
              const SizedBox(height: 16),
              _card('결제정보', _payment(order)),
              if (isBank) ...[
                const SizedBox(height: 16),
                _card(hasVa ? '가상계좌 정보' : '입금정보',
                    hasVa ? _vaInfo(order) : _depositInfo(order)),
              ],
            ],
          ),
        ),
        if (order.canCancel) _cancelBar(),
      ],
    );
  }

  Widget _headerCard(OrderModel order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              orderStatusChip(order),
              const Spacer(),
              if (order.createdAt != null)
                Text(order.createdAt!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.sub)),
            ],
          ),
          const SizedBox(height: 12),
          Text('주문번호 ${order.orderNo}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _items(OrderModel order) {
    return Column(
      children: [
        for (int i = 0; i < order.items.length; i++) ...[
          if (i > 0) const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          _itemRow(order.items[i]),
        ],
      ],
    );
  }

  Widget _itemRow(OrderItem it) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NetImage(it.thumbnail, width: 60, height: 60, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(it.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (it.unit != null && it.unit!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(it.unit!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.sub)),
              ],
              const SizedBox(height: 6),
              Text('${won(it.price)} · ${it.quantity}개',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.sub)),
            ],
          ),
        ),
        Text(won(it.subtotal),
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _delivery(OrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelRow('받는분', order.receiverName ?? '-'),
        const SizedBox(height: 10),
        _labelRow('연락처', order.receiverPhone ?? '-'),
        const SizedBox(height: 10),
        _labelRow(
          '주소',
          [
            if (order.postcode != null && order.postcode!.isNotEmpty)
              '(${order.postcode})',
            order.address1 ?? '',
            order.address2 ?? '',
          ].where((e) => e.isNotEmpty).join(' '),
        ),
        if (order.memo != null && order.memo!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _labelRow('배송메모', order.memo!),
        ],
      ],
    );
  }

  Widget _payment(OrderModel order) {
    return Column(
      children: [
        _amountRow('상품금액', won(order.subtotal)),
        const SizedBox(height: 8),
        _amountRow('배송비',
            order.shippingFee == 0 ? '무료' : won(order.shippingFee)),
        if (order.discount > 0) ...[
          const SizedBox(height: 8),
          _amountRow('할인', '-${won(order.discount)}', color: AppColors.red),
        ],
        if (order.pointUsed > 0) ...[
          const SizedBox(height: 8),
          _amountRow('적립금 사용', '-${won(order.pointUsed)}',
              color: AppColors.red),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
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
        const SizedBox(height: 10),
        _amountRow('결제수단', order.paymentLabel),
      ],
    );
  }

  Widget _depositInfo(OrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.bank != null && order.bank!.isNotEmpty)
          _labelRow('입금은행', order.bank!),
        if (order.depositor != null && order.depositor!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _labelRow('입금자명', order.depositor!),
        ],
        const SizedBox(height: 10),
        _labelRow('입금금액', won(order.total)),
      ],
    );
  }

  Widget _vaInfo(OrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (order.vaBank != null && order.vaBank!.isNotEmpty)
          _labelRow('은행', order.vaBank!),
        const SizedBox(height: 10),
        _labelRow('계좌번호', order.vaAccount ?? '-'),
        if (order.vaHolder != null && order.vaHolder!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _labelRow('예금주', order.vaHolder!),
        ],
        const SizedBox(height: 10),
        _labelRow('입금금액', won(order.total)),
        if (order.vaDueAt != null && order.vaDueAt!.isNotEmpty) ...[
          const SizedBox(height: 10),
          _labelRow('입금기한', order.vaDueAt!),
        ],
      ],
    );
  }

  Widget _shippingInfo(OrderModel order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelRow('택배사', order.courier ?? '-'),
        const SizedBox(height: 10),
        _labelRow('운송장번호', order.trackingNo ?? '-'),
      ],
    );
  }

  Widget _labelRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: const TextStyle(fontSize: 13, color: AppColors.sub)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
        ),
      ],
    );
  }

  Widget _amountRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.ink)),
      ],
    );
  }

  Widget _cancelBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _cancelling ? null : _cancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.red,
            side: const BorderSide(color: AppColors.red),
          ),
          child: _cancelling
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.red))
              : const Text('주문취소'),
        ),
      ),
    );
  }
}
