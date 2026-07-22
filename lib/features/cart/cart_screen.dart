import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common.dart';

/// 장바구니 탭
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authProvider).isLoggedIn;
    final cart = ref.watch(cartProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('장바구니')),
      body: !loggedIn
          ? _notLoggedIn(context)
          : _body(context, ref, cart),
    );
  }

  Widget _notLoggedIn(BuildContext context) {
    return EmptyState(
      Icons.lock_outline_rounded,
      '로그인 후 장바구니를\n이용하실 수 있습니다.',
      action: SizedBox(
        width: 200,
        child: ElevatedButton(
          onPressed: () => context.push('/login'),
          child: const Text('로그인'),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, CartState cart) {
    if (cart.loading && cart.lines.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (cart.lines.isEmpty) {
      return RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => ref.read(cartProvider.notifier).load(),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.24),
            EmptyState(
              Icons.shopping_cart_outlined,
              '장바구니가 비어 있습니다',
              action: SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('쇼핑하러 가기'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final summary = cart.summary;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.navy,
            onRefresh: () => ref.read(cartProvider.notifier).load(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.lines.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CartLineCard(line: cart.lines[i]),
            ),
          ),
        ),
        if (summary != null) _SummaryBar(summary: summary),
      ],
    );
  }
}

class _CartLineCard extends ConsumerWidget {
  final CartLine line;
  const _CartLineCard({required this.line});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = line.product;
    return Dismissible(
      key: ValueKey('cart-${line.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _remove(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NetImage(p.thumbnail, width: 76, height: 76, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.brand != null)
                        Text(p.brand!.name,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.navy,
                                fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.3,
                              fontWeight: FontWeight.w600)),
                      if (p.unit != null && p.unit!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(p.unit!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.sub)),
                      ],
                      const SizedBox(height: 6),
                      Text(won(line.price),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _remove(context, ref),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: AppColors.sub),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _QtyStepper(
                  quantity: line.quantity,
                  onChanged: (q) => _updateQty(context, ref, q),
                ),
                Text(won(line.lineTotal),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateQty(BuildContext context, WidgetRef ref, int q) async {
    if (q < 1) return;
    try {
      await ref.read(cartProvider.notifier).updateQty(line.id, q);
    } catch (e) {
      if (context.mounted) {
        toast(context, e is ApiException ? e.firstError : '오류가 발생했습니다.');
      }
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(cartProvider.notifier).remove(line.id);
    } catch (e) {
      if (context.mounted) {
        toast(context, e is ApiException ? e.firstError : '오류가 발생했습니다.');
      }
    }
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _btn(Icons.remove, quantity > 1 ? () => onChanged(quantity - 1) : null),
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text('$quantity',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          _btn(Icons.add, () => onChanged(quantity + 1)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: Icon(icon,
            size: 18,
            color: onTap == null ? AppColors.line : AppColors.ink),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final CartSummary summary;
  const _SummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final freeGap = summary.freeShipOver - summary.subtotal;
    final showHint = summary.shipping > 0 && freeGap > 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 14, 16, 14 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHint)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.redSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${comma(freeGap)}원 더 담으면 무료배송',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.red,
                    fontWeight: FontWeight.w700),
              ),
            ),
          _row('상품금액', won(summary.subtotal)),
          const SizedBox(height: 6),
          _row('배송비', summary.shipping == 0 ? '무료' : won(summary.shipping)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('총 결제금액',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(won(summary.total),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.red)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: summary.count > 0
                  ? () => context.push('/checkout')
                  : null,
              child: const Text('주문하기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
