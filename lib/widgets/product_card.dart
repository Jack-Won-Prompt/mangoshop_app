import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/wishlist_provider.dart';
import 'common.dart';

/// 세로형 상품 카드 (그리드/가로 리스트 공용)
class ProductCard extends ConsumerWidget {
  final Product product;
  final double? width;
  const ProductCard(this.product, {super.key, this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wished = ref.watch(wishlistProvider).contains(product.id);
    final p = product;

    return GestureDetector(
      onTap: () => context.push('/product/${p.slug}'),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: NetImage(p.thumbnail, fit: BoxFit.cover, radius: 0,
                      width: double.infinity),
                ),
                if (p.isBest || p.isNew || p.hasSpecial)
                  Positioned(
                    top: 8, left: 8,
                    child: _badge(p),
                  ),
                if (p.origin != null && p.origin!.isNotEmpty)
                  Positioned(
                    bottom: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${p.origin}산',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                Positioned(
                  top: 4, right: 4,
                  child: _WishBtn(product: p, wished: wished),
                ),
                // 품절/판매마감/입고예정 — 구매 불가 상태 오버레이
                if (!p.purchasable)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p.saleStatusLabel.isNotEmpty ? p.saleStatusLabel : '품절',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 판매 주체 = 입점 수입사 (멀티벤더)
                  if (p.seller != null)
                    Row(children: [
                      Flexible(
                        child: Text(p.seller!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.brand, fontWeight: FontWeight.w700)),
                      ),
                      if (p.seller!.coldchain) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.ac_unit, size: 11, color: AppColors.cool),
                      ],
                    ])
                  else if (p.brand != null)
                    Text(p.brand!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.brand, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.25, fontWeight: FontWeight.w500)),
                  // 품종 · 등급 · 규격
                  if (p.boxSpec != null && p.boxSpec!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(p.boxSpec!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                    ),
                  const SizedBox(height: 6),
                  if (!p.priceVisible)
                    // 도매 전용 상품 — 승인 도매회원에게만 가격 공개
                    const Text('로그인 후 가격 확인',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.wholesale))
                  else ...[
                    if (p.onSale)
                      Row(children: [
                        Text('${p.discountRate}%',
                            style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(width: 5),
                        Text(comma(p.listPrice),
                            style: const TextStyle(color: AppColors.sub, fontSize: 11, decoration: TextDecoration.lineThrough)),
                      ]),
                    Row(children: [
                      Text(won(p.price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      if (p.unit != null && p.unit!.isNotEmpty)
                        Text(' / ${p.unit}', style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                    ]),
                    // 최소주문수량(MOQ) — B2B 주문 단위 안내
                    if (p.moq > 1)
                      Text('최소 ${p.moq}${p.unit ?? "개"}부터',
                          style: const TextStyle(fontSize: 10, color: AppColors.sub)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(Product p) {
    late String text;
    late Color color;
    if (p.hasSpecial) {
      text = '도매가';
      color = AppColors.wholesale;
    } else if (p.isBest) {
      text = 'BEST';
      color = AppColors.red;
    } else {
      text = 'NEW';
      color = AppColors.leaf;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }
}

class _WishBtn extends ConsumerWidget {
  final Product product;
  final bool wished;
  const _WishBtn({required this.product, required this.wished});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () async {
          if (!ref.read(authProvider).isLoggedIn) {
            toast(context, '로그인이 필요합니다.');
            context.push('/login');
            return;
          }
          try {
            await ref.read(wishlistProvider.notifier).toggle(product.id);
          } catch (_) {
            if (context.mounted) toast(context, '처리에 실패했습니다.');
          }
        },
        child: Container(
          padding: const EdgeInsets.all(7),
          child: Icon(
            wished ? Icons.favorite : Icons.favorite_border,
            color: wished ? AppColors.red : Colors.white,
            size: 22,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}
