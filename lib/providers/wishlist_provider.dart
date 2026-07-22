import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/models.dart';
import 'auth_provider.dart';

class WishlistNotifier extends StateNotifier<Set<int>> {
  WishlistNotifier(this._api, this._loggedIn) : super({}) {
    if (_loggedIn) load();
  }
  final ApiClient _api;
  final bool _loggedIn;

  Future<void> load() async {
    if (!_loggedIn) return;
    try {
      final res = await _api.get('/wishlist');
      final ids = ((res['products'] as List?) ?? []).map((e) => Product.fromJson(e).id).toSet();
      state = ids;
    } catch (_) {}
  }

  bool contains(int id) => state.contains(id);

  /// 반환값: 추가되었으면 true
  Future<bool> toggle(int productId) async {
    final res = await _api.post('/wishlist/$productId');
    final wished = res['wished'] == true;
    final next = {...state};
    if (wished) {
      next.add(productId);
    } else {
      next.remove(productId);
    }
    state = next;
    return wished;
  }

  void clearLocal() => state = {};
}

final wishlistProvider = StateNotifierProvider<WishlistNotifier, Set<int>>((ref) {
  final loggedIn = ref.watch(authProvider).isLoggedIn;
  return WishlistNotifier(ref.read(apiProvider), loggedIn);
});

/// 관심상품 목록 (마이페이지)
final wishlistItemsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  ref.watch(wishlistProvider); // 토글 시 갱신
  final api = ref.read(apiProvider);
  final res = await api.get('/wishlist');
  return ((res['products'] as List?) ?? []).map((e) => Product.fromJson(e)).toList();
});
