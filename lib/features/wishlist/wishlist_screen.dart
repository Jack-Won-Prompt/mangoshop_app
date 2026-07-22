import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';

/// 관심상품 탭 — 로그인 사용자의 찜한 상품 그리드
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(authProvider).isLoggedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('관심상품')),
      body: loggedIn ? _list(context, ref) : _loginRequired(context),
    );
  }

  Widget _loginRequired(BuildContext context) {
    return EmptyState(
      Icons.lock_outline,
      '로그인이 필요합니다',
      action: SizedBox(
        width: 200,
        child: ElevatedButton(
          onPressed: () => context.push('/login'),
          child: const Text('로그인'),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wishlistItemsProvider);
    return async.when(
      loading: () => const GridShimmer(),
      error: (e, _) => ErrorRetry(e, () => ref.invalidate(wishlistItemsProvider)),
      data: (products) {
        if (products.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(wishlistItemsProvider),
            child: ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: EmptyState(
                    Icons.favorite_border,
                    '관심상품이 없습니다',
                    action: SizedBox(
                      width: 200,
                      child: OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('쇼핑 계속하기'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(wishlistItemsProvider),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.58,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) => ProductCard(products[i]),
          ),
        );
      },
    );
  }
}
