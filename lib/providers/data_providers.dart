import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/models.dart';

// ===== 홈 =====
class HomeData {
  final List<Banner> mainBanners, subBanners;
  final List<Product> deals, best, featured, newArrivals;
  final List<NoticeItem> notices;
  final List<Brand> brands;
  final List<Map<String, dynamic>> categoryTabs; // {category: Category, products: [Product]}
  HomeData.fromJson(Map j)
      : mainBanners = _plist(j['banners']?['main'], (e) => Banner.fromJson(e)),
        subBanners = _plist(j['banners']?['sub'], (e) => Banner.fromJson(e)),
        deals = _plist(j['deals'], (e) => Product.fromJson(e)),
        best = _plist(j['best'], (e) => Product.fromJson(e)),
        featured = _plist(j['featured'], (e) => Product.fromJson(e)),
        newArrivals = _plist(j['new'], (e) => Product.fromJson(e)),
        notices = _plist(j['notices'], (e) => NoticeItem.fromJson(e)),
        brands = _plist(j['brands'], (e) => Brand.fromJson(e)),
        categoryTabs = ((j['category_tabs'] as List?) ?? []).map((t) {
          return {
            'category': Category.fromJson(t['category']),
            'products': _plist(t['products'], (e) => Product.fromJson(e)),
          };
        }).toList();
}

List<T> _plist<T>(dynamic list, T Function(Map) parse) =>
    ((list as List?) ?? []).map((e) => parse(e as Map)).toList();

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) async {
  final res = await ref.read(apiProvider).get('/home');
  return HomeData.fromJson(res);
});

// ===== 사이트 설정 =====
class SiteSettings {
  final Map company;
  final int freeShipOver, shippingFee, signupPoint;
  final double pointRate;
  final List banks;
  final List<String> popularKeywords;
  final String paymentPg;
  SiteSettings.fromJson(Map j)
      : company = j['company'] ?? {},
        freeShipOver = (j['policy']?['free_ship_over'] ?? 0) as int,
        shippingFee = (j['policy']?['shipping_fee'] ?? 0) as int,
        signupPoint = (j['policy']?['signup_point'] ?? 0) as int,
        pointRate = ((j['policy']?['point_rate'] ?? 0) as num).toDouble(),
        banks = (j['banks'] as List?) ?? [],
        popularKeywords = ((j['popular_keywords'] as List?) ?? []).map((e) => e.toString()).toList(),
        paymentPg = j['payment_pg'] ?? 'toss';
}

final settingsProvider = FutureProvider<SiteSettings>((ref) async {
  final res = await ref.read(apiProvider).get('/settings');
  return SiteSettings.fromJson(res);
});

// ===== 카테고리 트리 =====
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final res = await ref.read(apiProvider).get('/categories');
  return ((res['categories'] as List?) ?? []).map((e) => Category.fromJson(e)).toList();
});

// ===== 상품 상세 =====
class ProductDetail {
  final Product product;
  final List<Product> related;
  final bool wished;
  ProductDetail(this.product, this.related, this.wished);
}

final productDetailProvider =
    FutureProvider.autoDispose.family<ProductDetail, String>((ref, slug) async {
  final res = await ref.read(apiProvider).get('/product/$slug');
  return ProductDetail(
    Product.fromJson(res['product']),
    ((res['related'] as List?) ?? []).map((e) => Product.fromJson(e)).toList(),
    res['wished'] == true,
  );
});

// ===== 카탈로그 목록 (필터/정렬/페이징) =====
class CatalogQuery {
  final String? categorySlug;
  final String? keyword;
  final String sort;
  final List<int> brandIds;
  final int? priceMin, priceMax;
  final int page;
  const CatalogQuery({
    this.categorySlug,
    this.keyword,
    this.sort = 'new',
    this.brandIds = const [],
    this.priceMin,
    this.priceMax,
    this.page = 1,
  });

  Map<String, dynamic> toQuery() => {
        'sort': sort,
        'page': page,
        if (keyword != null && keyword!.isNotEmpty) 'q': keyword,
        if (brandIds.isNotEmpty) 'brand': brandIds,
        if (priceMin != null) 'price_min': priceMin,
        if (priceMax != null) 'price_max': priceMax,
      };

  String get path {
    if (categorySlug != null) return '/category/$categorySlug';
    if (keyword != null) return '/products/search';
    return '/products';
  }
}

class BrandFilter {
  final int id;
  final String name;
  final int count;
  BrandFilter.fromJson(Map j)
      : id = (j['id'] ?? 0) as int,
        name = j['name'] ?? '',
        count = (j['count'] ?? 0) as int;
}

class CatalogResult {
  final List<Product> products;
  final int currentPage, lastPage;
  final bool hasMore;
  final List<BrandFilter> brands;
  final Category? category;
  CatalogResult.fromJson(Map j)
      : products = ((j['products'] as List?) ?? []).map((e) => Product.fromJson(e)).toList(),
        currentPage = (j['meta']?['current_page'] ?? 1) as int,
        lastPage = (j['meta']?['last_page'] ?? 1) as int,
        hasMore = (j['meta']?['has_more'] ?? false) as bool,
        brands = ((j['filters']?['brands'] as List?) ?? []).map((e) => BrandFilter.fromJson(e)).toList(),
        category = j['category'] is Map ? Category.fromJson(j['category']) : null;
}

/// 카탈로그 조회. 화면(ConsumerWidget)에서 [WidgetRef] 를 그대로 넘겨 호출한다.
Future<CatalogResult> fetchCatalog(WidgetRef ref, CatalogQuery q) async {
  final res = await ref.read(apiProvider).get(q.path, query: q.toQuery());
  return CatalogResult.fromJson(res);
}
