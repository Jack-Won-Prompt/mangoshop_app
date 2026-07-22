import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/models.dart';
import 'auth_provider.dart';

class CartState {
  final List<CartLine> lines;
  final CartSummary? summary;
  final bool loading;
  const CartState({this.lines = const [], this.summary, this.loading = false});
  int get count => summary?.count ?? lines.length;
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this._api, this._loggedIn) : super(const CartState()) {
    if (_loggedIn) load();
  }
  final ApiClient _api;
  final bool _loggedIn;

  CartState _parse(Map res) => CartState(
        lines: ((res['items'] as List?) ?? []).map((e) => CartLine.fromJson(e)).toList(),
        summary: res['summary'] != null ? CartSummary.fromJson(res['summary']) : null,
      );

  Future<void> load() async {
    if (!_loggedIn) return;
    state = CartState(lines: state.lines, summary: state.summary, loading: true);
    try {
      state = _parse(await _api.get('/cart'));
    } catch (_) {
      state = CartState(lines: state.lines, summary: state.summary);
    }
  }

  Future<String> add(int productId, {int quantity = 1}) async {
    final res = await _api.post('/cart/$productId', data: {'quantity': quantity});
    state = _parse(res);
    return res['message'] ?? '장바구니에 담았습니다.';
  }

  Future<void> updateQty(int itemId, int quantity) async {
    state = _parse(await _api.put('/cart/$itemId', data: {'quantity': quantity}));
  }

  Future<void> remove(int itemId) async {
    state = _parse(await _api.delete('/cart/$itemId'));
  }

  void clearLocal() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  final loggedIn = ref.watch(authProvider).isLoggedIn;
  return CartNotifier(ref.read(apiProvider), loggedIn);
});
