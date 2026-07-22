import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/theme.dart';
import '../../models/models.dart' as m;
import '../../providers/cart_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/recent_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';

/// 홈 화면
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(140),
        child: _HomeTopBar(),
      ),
      body: home.when(
        loading: () => const _HomeLoading(),
        error: (e, _) => ErrorRetry(e, () => ref.invalidate(homeProvider)),
        data: (data) {
          // 카테고리별 인기상품에서 다양한 제조사 상품 풀 구성 (라운드로빈)
          final diverse = _diversePool(data, max: 16);
          final heroPics = (diverse.isNotEmpty ? diverse : data.best)
              .map((p) => p.thumbnail)
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .toList();
          return RefreshIndicator(
            color: AppColors.navy,
            onRefresh: () async => ref.invalidate(homeProvider),
            child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (data.mainBanners.isNotEmpty)
                _BannerCarousel(banners: data.mainBanners, heroPics: heroPics),
              const _QuickCategories(),
              const _InfoLinks(),
              // 다양한 인기상품 (여러 제조사) — 메인 상단 노출
              if (diverse.isNotEmpty) ...[
                const SectionHeader('다양한 인기상품'),
                _HorizontalProducts(products: diverse),
              ],
              // 카테고리별 인기상품 (카테고리 탭)
              if (data.categoryTabs.isNotEmpty) ...[
                const SectionHeader('카테고리별 인기상품'),
                _CategoryBestTabs(tabs: data.categoryTabs),
              ],
              if (data.deals.isNotEmpty) ...[
                const SectionHeader('오늘의 특가', subtitle: '지금 이 가격!'),
                _HorizontalProducts(products: data.deals),
              ],
              if (data.best.isNotEmpty) ...[
                SectionHeader('BEST 상품', onMore: () => context.push('/products')),
                _HorizontalProducts(products: data.best),
              ],
              if (data.featured.isNotEmpty) ...[
                const SectionHeader('추천 상품'),
                _HorizontalProducts(products: data.featured),
              ],
              if (data.newArrivals.isNotEmpty) ...[
                const SectionHeader('신상품'),
                _HorizontalProducts(products: data.newArrivals),
              ],
              // 최근 본 상품 (기기 로컬)
              ...(() {
                final recent = ref.watch(recentlyViewedProvider);
                if (recent.isEmpty) return const <Widget>[];
                return [
                  const SectionHeader('최근 본 상품'),
                  _HorizontalProducts(products: recent),
                ];
              })(),
              if (data.notices.isNotEmpty) ...[
                SectionHeader('공지사항', onMore: () => context.push('/community/notices')),
                _NoticeList(notices: data.notices),
              ],
              if (data.brands.isNotEmpty) ...[
                const SectionHeader('브랜드'),
                _BrandRow(brands: data.brands),
              ],
              const SizedBox(height: 20),
            ],
          ),
            );
          },
        ),
      );
  }
}

/// 카테고리별 인기상품에서 여러 제조사 상품을 라운드로빈으로 모아 다양성 확보
List<m.Product> _diversePool(HomeData data, {int max = 16}) {
  final lists = data.categoryTabs
      .map((t) => ((t['products'] as List?) ?? const []).cast<m.Product>())
      .toList();
  final seen = <int>{};
  final out = <m.Product>[];
  var idx = 0;
  var added = true;
  while (out.length < max && added) {
    added = false;
    for (final l in lists) {
      if (idx < l.length) {
        final p = l[idx];
        if (seen.add(p.id)) {
          out.add(p);
          added = true;
        }
        if (out.length >= max) break;
      }
    }
    idx++;
  }
  return out;
}

// ===== 상단바 =====
class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartCount = ref.watch(cartProvider).count;
    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/brand/logo_horizontal.png',
                    height: 30,
                    filterQuality: FilterQuality.medium,
                    // 이미지 로드 실패 시에도 브랜드가 비지 않도록 텍스트 폴백
                    errorBuilder: (_, _, _) => const Text(
                      '망고샵',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.brand,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.headset_mic_outlined),
                    color: AppColors.ink,
                    onPressed: () => context.push('/chat'),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_bag_outlined),
                        color: AppColors.ink,
                        onPressed: () => context.go('/cart'),
                      ),
                      if (cartCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '$cartCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => context.push('/search'),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search, color: AppColors.sub, size: 22),
                      SizedBox(width: 8),
                      Text('찾으시는 상품을 검색해보세요', style: TextStyle(color: AppColors.sub, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== 카테고리별 인기상품 (탭 + 가로 리스트) =====
class _CategoryBestTabs extends StatefulWidget {
  final List<Map<String, dynamic>> tabs;
  const _CategoryBestTabs({required this.tabs});

  @override
  State<_CategoryBestTabs> createState() => _CategoryBestTabsState();
}

class _CategoryBestTabsState extends State<_CategoryBestTabs> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    final sel = _sel.clamp(0, tabs.length - 1);
    final cat = tabs[sel]['category'] as m.Category;
    final products = (tabs[sel]['products'] as List).cast<m.Product>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 카테고리 탭
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = tabs[i]['category'] as m.Category;
              final on = i == sel;
              return GestureDetector(
                onTap: () => setState(() => _sel = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? AppColors.navy : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: on ? AppColors.navy : AppColors.line),
                  ),
                  child: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: on ? Colors.white : AppColors.sub,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _HorizontalProducts(products: products),
        // 카테고리 전체보기
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: OutlinedButton(
            onPressed: () => context.push('/category/${cat.slug}?name=${Uri.encodeComponent(cat.name)}'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            child: Text('${cat.name} 전체보기'),
          ),
        ),
      ],
    );
  }
}

// ===== 이용안내 링크 (배너 하단 탭바) =====
class _InfoLinks extends StatelessWidget {
  const _InfoLinks();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.card_giftcard_outlined, '신규회원 혜택', '/guide/event'),
      (Icons.local_shipping_outlined, '당일출고', '/guide/delivery'),
      (Icons.credit_card_outlined, '간편결제', '/guide/payment'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: items.map((it) {
          return Expanded(
            child: GestureDetector(
              onTap: () => context.push(it.$3),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(children: [
                  Icon(it.$1, color: AppColors.navy, size: 22),
                  const SizedBox(height: 6),
                  Text(it.$2, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ===== 배너 캐러셀 (웹 히어로 슬라이더 스타일) =====
class _BannerCarousel extends StatefulWidget {
  final List<m.Banner> banners;
  final List<String> heroPics; // 배너 이미지가 없을 때 배경에 깔 베스트 상품 썸네일
  const _BannerCarousel({required this.banners, this.heroPics = const []});

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  int _current = 0;

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          CarouselSlider(
            options: CarouselOptions(
              height: 180,
              viewportFraction: 0.92,
              autoPlay: banners.length > 1,
              autoPlayInterval: const Duration(seconds: 4),
              autoPlayAnimationDuration: const Duration(milliseconds: 700),
              enableInfiniteScroll: banners.length > 1,
              onPageChanged: (i, _) => setState(() => _current = i),
            ),
            items: List.generate(banners.length, (i) => _slide(banners[i], i)).toList(),
          ),
          if (banners.length > 1) ...[
            const SizedBox(height: 12),
            AnimatedSmoothIndicator(
              activeIndex: _current,
              count: banners.length,
              effect: const ExpandingDotsEffect(
                dotHeight: 7,
                dotWidth: 7,
                expansionFactor: 3,
                activeDotColor: AppColors.navy,
                dotColor: AppColors.line,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _slide(m.Banner b, int index) {
    final accent = _parseColor(b.bgColor) ?? AppColors.navy;
    final hasImage = b.image != null && b.image!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        final link = b.link;
        if (link != null && link.startsWith('/')) context.push(link);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage) NetImage(b.image, fit: BoxFit.cover),
            // 이미지 없으면 오른쪽에 상품 썸네일 콜라주 (다양한 제조사)
            if (!hasImage && widget.heroPics.isNotEmpty)
              Positioned(right: -8, top: 0, bottom: 0, child: _visual(index)),
            // 텍스트
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MANGOSHOP',
                      style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  if (b.title != null)
                    SizedBox(
                      width: 210,
                      child: Text(b.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.ink, fontSize: 19, fontWeight: FontWeight.w900, height: 1.25)),
                    ),
                  if (b.subtitle != null && b.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 210,
                      child: Text(b.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.sub, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(30)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('상품 보러가기', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward, size: 14, color: Colors.white),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 오른쪽 상품 썸네일 콜라주 (겹쳐진 3개)
  Widget _visual(int index) {
    final pics = widget.heroPics;
    Widget card(int k, double top, double right, double size, double angle) {
      final src = pics[(index * 3 + k) % pics.length];
      return Positioned(
        top: top,
        right: right,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 5))],
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(4),
            child: NetImage(src, fit: BoxFit.contain, radius: 10),
          ),
        ),
      );
    }

    return SizedBox(
      width: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          card(2, 74, 12, 70, 0.12),
          card(1, 30, 74, 64, -0.10),
          card(0, 34, 8, 84, 0.02),
        ],
      ),
    );
  }
}

// ===== 퀵 카테고리 =====
class _QuickCategories extends ConsumerWidget {
  const _QuickCategories();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return cats.maybeWhen(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final roots = list.take(8).toList();
        return Padding(
          padding: const EdgeInsets.only(top: 18),
          child: SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: roots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) {
                final c = roots[i];
                return GestureDetector(
                  onTap: () => context.push('/category/${c.slug}?name=${Uri.encodeComponent(c.name)}'),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppColors.chip,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        alignment: Alignment.center,
                        child: CategoryIcon(c.icon, size: 28),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 64,
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

// ===== 가로 상품 리스트 =====
class _HorizontalProducts extends StatelessWidget {
  final List<m.Product> products;
  const _HorizontalProducts({required this.products});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 288,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => ProductCard(products[i], width: 160),
      ),
    );
  }
}

// ===== 공지 리스트 =====
class _NoticeList extends StatelessWidget {
  final List<m.NoticeItem> notices;
  const _NoticeList({required this.notices});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: notices.take(4).map((n) {
            final isLast = n == notices.take(4).last;
            return InkWell(
              onTap: () => context.push('/community/notices'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    if (n.pinned)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(6)),
                        child: const Text('중요', style: TextStyle(color: AppColors.red, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    Expanded(
                      child: Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(n.date ?? '', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ===== 브랜드 로고 =====
class _BrandRow extends StatelessWidget {
  final List<m.Brand> brands;
  const _BrandRow({required this.brands});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: brands.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final b = brands[i];
          return Container(
            width: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(10),
            child: (b.logo != null && b.logo!.isNotEmpty)
                ? NetImage(b.logo, fit: BoxFit.contain, height: 40)
                : Text(
                    b.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 13),
                  ),
          );
        },
      ),
    );
  }
}

// ===== 로딩 =====
class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(height: 170),
        ),
        GridShimmer(count: 4),
      ],
    );
  }
}
