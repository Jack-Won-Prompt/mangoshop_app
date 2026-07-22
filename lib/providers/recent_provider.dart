import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 최근 본 상품 — 기기 로컬(shared_preferences)에 상품카드 JSON 을 최대 20개 저장.
/// 서버 세션 대신 클라이언트에서 관리한다.
class RecentlyViewedNotifier extends StateNotifier<List<Product>> {
  RecentlyViewedNotifier() : super(const []) {
    _load();
  }

  static const _key = 'recently_viewed_v1';
  static const _max = 20;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? [];
      state = raw
          .map((s) {
            try {
              return Product.fromJson(jsonDecode(s) as Map);
            } catch (_) {
              return null;
            }
          })
          .whereType<Product>()
          .toList();
    } catch (_) {
      state = const [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state.map((p) => jsonEncode(_toMap(p))).toList());
    } catch (_) {}
  }

  /// 상품 상세를 볼 때 호출 — 최신순 맨 앞으로, 중복 제거, 상한 유지
  void record(Product p) {
    final next = [p, ...state.where((e) => e.id != p.id)];
    state = next.length > _max ? next.sublist(0, _max) : next;
    _persist();
  }

  void clearAll() {
    state = const [];
    _persist();
  }

  /// 저장에 필요한 최소 필드만 직렬화 (상품카드 렌더용)
  Map<String, dynamic> _toMap(Product p) => {
        'id': p.id,
        'name': p.name,
        'slug': p.slug,
        'code': p.code,
        'unit': p.unit,
        'maker': p.maker,
        'summary': p.summary,
        'thumbnail': p.thumbnail,
        'price': p.price,
        'list_price': p.listPrice,
        'discount_rate': p.discountRate,
        'has_special': p.hasSpecial,
        'price_visible': p.priceVisible,
        'wholesale_only': p.wholesaleOnly,
        'stock': p.stock,
        'is_best': p.isBest,
        'is_new': p.isNew,
        'is_featured': p.isFeatured,
        'badge': p.badge,
        'brand': p.brand == null
            ? null
            : {'id': p.brand!.id, 'name': p.brand!.name, 'slug': p.brand!.slug},
        // 망고샵 — 상품카드가 수입사/원산지/규격/MOQ 를 렌더하므로 함께 보관
        'seller': p.seller == null
            ? null
            : {
                'id': p.seller!.id,
                'name': p.seller!.name,
                'slug': p.seller!.slug,
                'coldchain': p.seller!.coldchain,
              },
        'origin': p.origin,
        'variety': p.variety,
        'grade': p.grade,
        'box_spec': p.boxSpec,
        'moq': p.moq,
        'sale_status': p.saleStatus,
        'sale_status_label': p.saleStatusLabel,
        'purchasable': p.purchasable,
      };
}

final recentlyViewedProvider =
    StateNotifierProvider<RecentlyViewedNotifier, List<Product>>((ref) {
  return RecentlyViewedNotifier();
});
