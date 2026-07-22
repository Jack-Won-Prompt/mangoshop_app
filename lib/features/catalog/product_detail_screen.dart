import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/recent_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';

/// 상품 상세 화면
class ProductDetailScreen extends ConsumerWidget {
  final String slug;
  const ProductDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(productDetailProvider(slug));
    // 최근 본 상품 기록 (상세 로드 시)
    ref.listen(productDetailProvider(slug), (prev, next) {
      next.whenData((d) => ref.read(recentlyViewedProvider.notifier).record(d.product));
    });
    return detail.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: AppColors.navy),
              SizedBox(height: 16),
              Text('상품 정보를 불러오는 중...', style: TextStyle(color: AppColors.sub)),
            ],
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorRetry(e, () => ref.invalidate(productDetailProvider(slug))),
      ),
      data: (d) => _DetailScaffold(slug: slug, product: d.product, related: d.related),
    );
  }
}

class _DetailScaffold extends ConsumerWidget {
  final String slug;
  final Product product;
  final List<Product> related;
  const _DetailScaffold({required this.slug, required this.product, required this.related});

  bool _requireLogin(BuildContext context, WidgetRef ref) {
    if (ref.read(authProvider).isLoggedIn) return true;
    toast(context, '로그인이 필요합니다.');
    context.push('/login');
    return false;
  }

  Future<void> _toggleWish(BuildContext context, WidgetRef ref) async {
    if (!_requireLogin(context, ref)) return;
    try {
      await ref.read(wishlistProvider.notifier).toggle(product.id);
    } catch (_) {
      if (context.mounted) toast(context, '처리에 실패했습니다.');
    }
  }

  Future<void> _addToCart(BuildContext context, WidgetRef ref, {required bool buyNow}) async {
    if (!_requireLogin(context, ref)) return;
    if (!product.purchasable) {
      toast(context, product.saleStatusLabel.isNotEmpty ? '${product.saleStatusLabel} 상품입니다.' : '품절된 상품입니다.');
      return;
    }
    final qty = await _showQtySheet(context);
    if (qty == null) return;
    try {
      final msg = await ref.read(cartProvider.notifier).add(product.id, quantity: qty);
      if (!context.mounted) return;
      if (buyNow) {
        context.push('/checkout');
      } else {
        toast(context, msg);
      }
    } catch (e) {
      if (context.mounted) toast(context, e is ApiException ? e.firstError : '장바구니 담기에 실패했습니다.');
    }
  }

  Future<int?> _showQtySheet(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QtySheet(product: product),
    );
  }

  Future<void> _writeReview(BuildContext context, WidgetRef ref) async {
    if (!_requireLogin(context, ref)) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReviewSheet(productId: product.id),
    );
    if (ok == true) {
      ref.invalidate(productDetailProvider(slug));
      if (context.mounted) toast(context, '후기가 등록되었습니다.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wished = ref.watch(wishlistProvider).contains(product.id);
    final gallery = product.gallery.isNotEmpty
        ? product.gallery
        : (product.thumbnail != null ? [product.thumbnail!] : <String>[]);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 360,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.ink,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => toast(context, '상품 링크가 복사되었습니다.'),
              ),
              IconButton(
                icon: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? AppColors.red : AppColors.ink),
                onPressed: () => _toggleWish(context, ref),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _Gallery(images: gallery),
            ),
          ),
          SliverToBoxAdapter(child: _infoBlock(context)),
          if (product.spec != null && product.spec!.trim().isNotEmpty)
            SliverToBoxAdapter(child: _specBlock()),
          SliverToBoxAdapter(child: _descriptionBlock()),
          SliverToBoxAdapter(child: _reviewBlock(context, ref)),
          if (related.isNotEmpty) SliverToBoxAdapter(child: _relatedBlock()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _bottomBar(context, ref, wished),
    );
  }

  // ===== 기본 정보 =====
  Widget _infoBlock(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 판매 수입사 + 도매가 배지
          Row(
            children: [
              if (product.seller != null)
                Flexible(
                  child: Text(product.seller!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800, fontSize: 13)),
                )
              else if (product.brand != null)
                Text(product.brand!.name,
                    style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800, fontSize: 13)),
              if (product.hasSpecial) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.wholesale, borderRadius: BorderRadius.circular(6)),
                  child: const Text('도매가 적용', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.35)),
          if (product.summary != null && product.summary!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(product.summary!, style: const TextStyle(color: AppColors.sub, fontSize: 13.5, height: 1.4)),
          ],
          // 원산지 · 품종 · 등급 · 콜드체인 칩
          const SizedBox(height: 12),
          _attrChips(),
          const SizedBox(height: 16),
          if (!product.priceVisible) ...[
            // 도매 전용 상품 — 승인 도매회원만 가격 열람 가능
            const Text('도매회원 전용가',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.wholesale)),
            const SizedBox(height: 4),
            const Text('※ 사업자 승인을 받은 도매회원에게만 가격이 공개됩니다.',
                style: TextStyle(fontSize: 12.5, color: AppColors.sub)),
          ] else ...[
            if (product.onSale)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${product.discountRate}%', style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w900, fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(comma(product.listPrice),
                      style: const TextStyle(color: AppColors.sub, fontSize: 14, decoration: TextDecoration.lineThrough)),
                ],
              ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(won(product.price), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                if (product.unit != null && product.unit!.isNotEmpty)
                  Text(' / ${product.unit}', style: const TextStyle(fontSize: 13, color: AppColors.sub)),
              ],
            ),
            // 수량구간 할인표 — 많이 살수록 단가가 내려가는 B2B 가격
            if (product.priceTiers.isNotEmpty) ...[
              const SizedBox(height: 12),
              _tierTable(),
            ],
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (product.boxSpec != null && product.boxSpec!.isNotEmpty) _kv('규격', product.boxSpec!),
          if (product.weightKg != null && product.weightKg! > 0)
            _kv('중량', '${_trimNum(product.weightKg!)}kg'),
          if (product.unit != null && product.unit!.isNotEmpty) _kv('판매단위', product.unit!),
          if (product.moq > 1)
            _kv('최소주문수량', '${product.moq}${product.unit ?? "개"}', valueColor: AppColors.brand),
          if (product.storageMethod != null && product.storageMethod!.isNotEmpty)
            _kv('보관방법', product.storageMethod!),
          if (product.inboundDate != null) _kv('입고일', product.inboundDate!),
          if (product.expiryDate != null)
            _kv('소비기한', product.expiryDate!, valueColor: AppColors.warn),
          if (product.lotNo != null && product.lotNo!.isNotEmpty) _kv('LOT 번호', product.lotNo!),
          if (product.code != null && product.code!.isNotEmpty) _kv('상품코드', product.code!),
          _kv(
            '판매상태',
            product.isInbound && product.expectedInboundDate != null
                ? '입고예정 (${product.expectedInboundDate})'
                : (product.saleStatusLabel.isNotEmpty
                    ? product.saleStatusLabel
                    : (product.inStock ? '구매 가능' : '품절')),
            valueColor: product.purchasable ? AppColors.success : AppColors.red,
          ),
          // 수입사 배송정책
          if (product.seller != null) ...[
            const SizedBox(height: 16),
            _sellerBlock(context),
          ],
        ],
      ),
    );
  }

  /// 원산지/품종/등급/콜드체인 요약 칩
  Widget _attrChips() {
    final chips = <Widget>[
      if (product.origin != null && product.origin!.isNotEmpty)
        _chip('${product.origin}산', AppColors.leaf, AppColors.leafSoft),
      if (product.variety != null && product.variety!.isNotEmpty)
        _chip(product.variety!, AppColors.brand, AppColors.accentSoft),
      if (product.grade != null && product.grade!.isNotEmpty)
        _chip('${product.grade}등급', AppColors.brandDark, AppColors.accentSoft),
      if (product.seller?.coldchain ?? false)
        _chip('콜드체인 냉장배송', AppColors.cool, AppColors.coolSoft),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _chip(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  /// 수량구간 할인표
  Widget _tierTable() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.local_offer_outlined, size: 15, color: AppColors.brandDark),
            SizedBox(width: 5),
            Text('수량별 할인가',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
          ]),
          const SizedBox(height: 8),
          ...product.priceTiers.map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${t.minQty}${product.unit ?? "개"} 이상',
                        style: const TextStyle(fontSize: 13, color: AppColors.sub)),
                    Text(won(t.price),
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.brandDark)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// 수입사 정보 + 배송정책
  Widget _sellerBlock(BuildContext context) {
    final s = product.seller!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.storefront_outlined, size: 18, color: AppColors.brand),
            const SizedBox(width: 6),
            Expanded(
              child: Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
            if (s.ratingCount > 0) ...[
              const Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 2),
              Text('${s.rating} (${s.ratingCount})',
                  style: const TextStyle(fontSize: 12, color: AppColors.sub)),
            ],
          ]),
          if (s.intro != null && s.intro!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.intro!, style: const TextStyle(fontSize: 12.5, color: AppColors.sub, height: 1.4)),
          ],
          const SizedBox(height: 10),
          _kv('배송비',
              s.shippingFee > 0
                  ? '${won(s.shippingFee)}${s.freeShippingThreshold > 0 ? " (${won(s.freeShippingThreshold)} 이상 무료)" : ""}'
                  : '무료배송'),
          if (s.shippingNotice != null && s.shippingNotice!.isNotEmpty)
            _kv('배송안내', s.shippingNotice!),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 78, child: Text(k, style: const TextStyle(color: AppColors.sub, fontSize: 13.5))),
          Expanded(
            child: Text(v, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.ink)),
          ),
        ],
      ),
    );
  }

  // ===== 스펙 =====
  Widget _specBlock() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('상품 스펙'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Text(product.spec!, style: const TextStyle(fontSize: 13.5, height: 1.6)),
          ),
        ],
      ),
    );
  }

  // ===== 상세설명 (HTML) =====
  Widget _descriptionBlock() {
    final html = product.description ?? '';
    final images = _extractImages(html);
    final text = _stripHtml(html);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('상세 설명'),
          const SizedBox(height: 14),
          if (text.isNotEmpty)
            Text(text, style: const TextStyle(fontSize: 14, height: 1.7, color: AppColors.ink)),
          if (images.isNotEmpty) ...[
            if (text.isNotEmpty) const SizedBox(height: 14),
            ...images.map(
              (src) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NetImage(src, width: double.infinity, radius: 12),
              ),
            ),
          ],
          if (text.isEmpty && images.isEmpty)
            const Text('상세 설명이 없습니다.', style: TextStyle(color: AppColors.sub)),
        ],
      ),
    );
  }

  // ===== 후기 =====
  Widget _reviewBlock(BuildContext context, WidgetRef ref) {
    final reviews = product.reviews;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionTitle('상품 후기'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _writeReview(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 16),
                style: TextButton.styleFrom(foregroundColor: AppColors.navy),
                label: const Text('후기 작성', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.warn, size: 20),
              const SizedBox(width: 4),
              Text(product.ratingAvg.toStringAsFixed(1), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('후기 ${product.reviewCount}개', style: const TextStyle(color: AppColors.sub, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          if (reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('아직 등록된 후기가 없습니다.', style: TextStyle(color: AppColors.sub))),
            )
          else
            ...reviews.map(_reviewTile),
        ],
      ),
    );
  }

  Widget _reviewTile(Review r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _stars(r.rating),
              const Spacer(),
              Text(r.date ?? '', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.author, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.sub)),
          if (r.title != null && r.title!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(r.title!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ],
          if (r.body != null && r.body!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.body!, style: const TextStyle(fontSize: 13.5, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _stars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(i < rating ? Icons.star : Icons.star_border, color: AppColors.warn, size: 16),
      ),
    );
  }

  // ===== 관련 상품 =====
  Widget _relatedBlock() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('관련 상품'),
          SizedBox(
            height: 288,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: related.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ProductCard(related[i], width: 160),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));

  // ===== 하단 고정 바 =====
  Widget _bottomBar(BuildContext context, WidgetRef ref, bool wished) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            _iconBtn(
              icon: wished ? Icons.favorite : Icons.favorite_border,
              color: wished ? AppColors.red : AppColors.sub,
              onTap: () => _toggleWish(context, ref),
            ),
            const SizedBox(width: 10),
            if (!product.priceVisible)
              // 도매 전용 상품 — 가격 비공개. 도매 회원가입/승인으로 유도.
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/login'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.wholesale),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('도매회원 로그인 후 구매'),
                ),
              )
            else if (product.isInbound)
              // 입고예정 — 구매 대신 입고 문의로 유도
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push(
                      '/community/inquiry?type=product&product=${Uri.encodeComponent(product.name)}'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.leaf),
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: Text(product.expectedInboundDate != null
                      ? '입고예정 (${product.expectedInboundDate}) · 문의'
                      : '입고예정 · 문의하기'),
                ),
              )
            else ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: product.purchasable ? () => _addToCart(context, ref, buyNow: false) : null,
                  child: const Text('장바구니'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: product.purchasable ? () => _addToCart(context, ref, buyNow: true) : null,
                  child: Text(product.purchasable
                      ? '바로구매'
                      : (product.saleStatusLabel.isNotEmpty ? product.saleStatusLabel : '품절')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}

// ===== 이미지 갤러리 =====
class _Gallery extends StatefulWidget {
  final List<String> images;
  const _Gallery({required this.images});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        color: AppColors.chip,
        alignment: Alignment.center,
        child: const Icon(Icons.eco_outlined, size: 60, color: AppColors.line),
      );
    }
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => NetImage(widget.images[i], fit: BoxFit.cover, width: double.infinity),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AnimatedSmoothIndicator(
              activeIndex: _current,
              count: widget.images.length,
              effect: const WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: AppColors.navy,
                dotColor: Colors.white70,
              ),
            ),
          ),
      ],
    );
  }
}

// ===== 수량 선택 시트 =====
class _QtySheet extends StatefulWidget {
  final Product product;
  const _QtySheet({required this.product});

  @override
  State<_QtySheet> createState() => _QtySheetState();
}

class _QtySheetState extends State<_QtySheet> {
  late int _qty = widget.product.moq; // MOQ(최소주문수량)에서 시작

  /// 현재 수량에 적용되는 단가 — 수량구간 할인 중 가장 저렴한 값.
  /// 서버 `Product::unitPriceFor()` 와 동일한 규칙.
  int get _unitPrice {
    final p = widget.product;
    var best = p.price;
    for (final t in p.priceTiers) {
      if (_qty >= t.minQty && t.price > 0 && t.price < best) best = t.price;
    }
    return best;
  }

  /// 다음 할인 구간까지 남은 수량 (없으면 null)
  PriceTier? get _nextTier {
    final upcoming = widget.product.priceTiers.where((t) => t.minQty > _qty).toList()
      ..sort((a, b) => a.minQty.compareTo(b.minQty));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final maxQty = p.stock > 0 ? p.stock : 99;
    final moq = p.moq;
    final unit = _unitPrice;
    final next = _nextTier;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            if (moq > 1) ...[
              const SizedBox(height: 6),
              Text('최소주문수량 $moq${p.unit ?? "개"}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.brand, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('수량', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                // MOQ 미만으로는 내릴 수 없다
                _stepBtn(Icons.remove, _qty > moq ? () => setState(() => _qty--) : null),
                Container(
                  width: 52,
                  alignment: Alignment.center,
                  child: Text('$_qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                _stepBtn(Icons.add, _qty < maxQty ? () => setState(() => _qty++) : null),
              ],
            ),
            // 수량구간 할인 안내
            if (unit < p.price) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.local_offer, size: 14, color: AppColors.brandDark),
                const SizedBox(width: 5),
                Text('수량할인 적용 단가 ${won(unit)}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.brandDark, fontWeight: FontWeight.w700)),
              ]),
            ] else if (next != null) ...[
              const SizedBox(height: 12),
              Text('${next.minQty}${p.unit ?? "개"} 이상 구매 시 ${won(next.price)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('합계', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(won(unit * _qty), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.red)),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _qty),
              child: const Text('선택 완료'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 18, color: onTap == null ? AppColors.line : AppColors.ink),
      ),
    );
  }
}

// ===== 후기 작성 시트 =====
class _ReviewSheet extends ConsumerStatefulWidget {
  final int productId;
  const _ReviewSheet({required this.productId});

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _rating = 5;
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_body.text.trim().isEmpty) {
      toast(context, '후기 내용을 입력해주세요.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(apiProvider).post('/product/${widget.productId}/review', data: {
        'rating': _rating,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      toast(context, e is ApiException ? e.firstError : '후기 등록에 실패했습니다.');
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('후기 작성', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(
                children: List.generate(5, (i) {
                  final v = i + 1;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () => setState(() => _rating = v),
                    icon: Icon(v <= _rating ? Icons.star : Icons.star_border, color: AppColors.warn, size: 30),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _title,
                decoration: const InputDecoration(hintText: '제목 (선택)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                maxLines: 4,
                decoration: const InputDecoration(hintText: '상품은 어떠셨나요?'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('등록하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== HTML 간이 처리 =====
List<String> _extractImages(String html) {
  final re = RegExp(r'''<img[^>]+src\s*=\s*["']([^"']+)["']''', caseSensitive: false);
  return re.allMatches(html).map((m) => m.group(1)!).where((s) => s.isNotEmpty).toList();
}

String _stripHtml(String html) {
  var s = html;
  s = s.replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

/// 5.0 -> "5", 4.5 -> "4.5"
String _trimNum(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
