import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/admin/admin_dashboard_screen.dart';
import 'features/admin/admin_order_detail_screen.dart';
import 'features/admin/admin_orders_screen.dart';
import 'features/admin/admin_shell.dart';
import 'features/admin/admin_support_screen.dart';
import 'features/admin/admin_user_detail_screen.dart';
import 'features/admin/admin_users_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/catalog/catalog_screen.dart';
import 'features/catalog/category_screen.dart';
import 'features/catalog/product_detail_screen.dart';
import 'features/catalog/search_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/community/community_screens.dart';
import 'features/community/inquiry_screen.dart';
import 'features/guide/guide_screens.dart';
import 'features/home/home_screen.dart';
import 'features/mypage/coupons_screen.dart';
import 'features/mypage/mypage_screen.dart';
import 'features/mypage/points_screen.dart';
import 'features/mypage/profile_edit_screen.dart';
import 'features/order/checkout_screen.dart';
import 'features/order/order_complete_screen.dart';
import 'features/order/order_detail_screen.dart';
import 'features/order/orders_screen.dart';
import 'features/wishlist/wishlist_screen.dart';
import 'widgets/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/catalog', builder: (_, _) => const CategoryScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/cart', builder: (_, _) => const CartScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/mypage', builder: (_, _) => const MypageScreen())]),
      ],
    ),

    // ===== 관리자 모드 =====
    // 관리자 계정으로 로그인하면 쇼핑 셸 대신 이 셸로 진입한다.
    // 접근 통제는 서버(admin 미들웨어)가 최종 판단하며, 여기서는 화면 노출만 제어한다.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AdminShell(shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin', builder: (_, _) => const AdminDashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/admin/orders',
            builder: (_, s) => AdminOrdersScreen(initialStatus: s.uri.queryParameters['status']),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/users', builder: (_, _) => const AdminUsersScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/inquiries', builder: (_, _) => const AdminSupportScreen()),
        ]),
      ],
    ),

    // 관리자 상세 (탭 위에 push)
    GoRoute(
      path: '/admin/orders/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, s) => AdminOrderDetailScreen(orderId: int.parse(s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/admin/users/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, s) => AdminUserDetailScreen(userId: int.parse(s.pathParameters['id']!)),
    ),

    // 전체 화면 라우트 (탭 위에 push)
    GoRoute(path: '/login', parentNavigatorKey: _rootKey, builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/register', parentNavigatorKey: _rootKey, builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/search', parentNavigatorKey: _rootKey, builder: (_, s) => SearchScreen(initialKeyword: s.uri.queryParameters['q'])),
    GoRoute(path: '/products', parentNavigatorKey: _rootKey, builder: (_, _) => const CatalogScreen()),
    GoRoute(path: '/product/:slug', parentNavigatorKey: _rootKey, builder: (_, s) => ProductDetailScreen(slug: s.pathParameters['slug']!)),
    GoRoute(path: '/category/:slug', parentNavigatorKey: _rootKey, builder: (_, s) => CatalogScreen(categorySlug: s.pathParameters['slug'], title: s.uri.queryParameters['name'])),

    GoRoute(path: '/checkout', parentNavigatorKey: _rootKey, builder: (_, _) => const CheckoutScreen()),
    GoRoute(path: '/order/complete/:id', parentNavigatorKey: _rootKey, builder: (_, s) => OrderCompleteScreen(orderId: int.parse(s.pathParameters['id']!))),
    GoRoute(path: '/orders', parentNavigatorKey: _rootKey, builder: (_, _) => const OrdersScreen()),
    GoRoute(path: '/orders/:id', parentNavigatorKey: _rootKey, builder: (_, s) => OrderDetailScreen(orderId: int.parse(s.pathParameters['id']!))),

    GoRoute(path: '/mypage/points', parentNavigatorKey: _rootKey, builder: (_, _) => const PointsScreen()),
    GoRoute(path: '/mypage/coupons', parentNavigatorKey: _rootKey, builder: (_, _) => const CouponsScreen()),
    GoRoute(path: '/mypage/profile', parentNavigatorKey: _rootKey, builder: (_, _) => const ProfileEditScreen()),

    GoRoute(path: '/community/notices', parentNavigatorKey: _rootKey, builder: (_, _) => const NoticesScreen()),
    GoRoute(path: '/community/reviews', parentNavigatorKey: _rootKey, builder: (_, _) => const ReviewsScreen()),
    GoRoute(path: '/community/faq', parentNavigatorKey: _rootKey, builder: (_, _) => const FaqScreen()),
    GoRoute(path: '/community/qna', parentNavigatorKey: _rootKey, builder: (_, _) => const QnaScreen()),
    GoRoute(path: '/community/inquiry', parentNavigatorKey: _rootKey, builder: (_, s) => InquiryScreen(type: s.uri.queryParameters['type'], product: s.uri.queryParameters['product'])),

    GoRoute(path: '/chat', parentNavigatorKey: _rootKey, builder: (_, _) => const ChatScreen()),

    // 이용안내
    GoRoute(path: '/guide/event', parentNavigatorKey: _rootKey, builder: (_, _) => const EventGuideScreen()),
    GoRoute(path: '/guide/delivery', parentNavigatorKey: _rootKey, builder: (_, _) => const DeliveryGuideScreen()),
    GoRoute(path: '/guide/payment', parentNavigatorKey: _rootKey, builder: (_, _) => const PaymentGuideScreen()),
  ],
);
