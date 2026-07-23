import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../models/admin_models.dart';
import '../models/models.dart';

// ===== 대시보드 =====
final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboard>((ref) async {
  final res = await ref.read(apiProvider).get('/admin/dashboard');
  return AdminDashboard.fromJson(res);
});

// ===== 주문 =====

/// 주문 목록 조회 조건 (상태 필터 + 검색어)
class OrderQuery {
  final String? status;
  final String q;
  const OrderQuery({this.status, this.q = ''});

  OrderQuery copyWith({String? status, String? q, bool clearStatus = false}) =>
      OrderQuery(status: clearStatus ? null : (status ?? this.status), q: q ?? this.q);

  @override
  bool operator ==(Object other) =>
      other is OrderQuery && other.status == status && other.q == q;

  @override
  int get hashCode => Object.hash(status, q);
}

class AdminOrderPage {
  final List<AdminOrderRow> orders;
  final Map<String, String> statuses;
  final int total;
  AdminOrderPage(this.orders, this.statuses, this.total);
}

final adminOrderQueryProvider = StateProvider<OrderQuery>((_) => const OrderQuery());

final adminOrdersProvider = FutureProvider.autoDispose<AdminOrderPage>((ref) async {
  final query = ref.watch(adminOrderQueryProvider);
  final res = await ref.read(apiProvider).get('/admin/orders', query: {
    if (query.status != null) 'status': query.status,
    if (query.q.isNotEmpty) 'q': query.q,
  });
  return AdminOrderPage(
    ((res['orders'] as List?) ?? []).map((e) => AdminOrderRow.fromJson(e)).toList(),
    Map<String, String>.from(
        (res['statuses'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {}),
    ((res['meta'] as Map?)?['total'] ?? 0) as int,
  );
});

class AdminOrderDetail {
  final OrderModel order;
  final AdminOrderCustomer? customer;
  final Map<String, String> statuses;
  AdminOrderDetail(this.order, this.customer, this.statuses);
}

final adminOrderProvider =
    FutureProvider.autoDispose.family<AdminOrderDetail, int>((ref, id) async {
  final res = await ref.read(apiProvider).get('/admin/orders/$id');
  final o = res['order'] as Map;
  return AdminOrderDetail(
    OrderModel.fromJson(o),
    o['customer'] is Map ? AdminOrderCustomer.fromJson(o['customer']) : null,
    Map<String, String>.from(
        (res['statuses'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {}),
  );
});

// ===== 회원 =====

class AdminUserPage {
  final List<AdminUserRow> users;
  final int pendingCount, total;
  AdminUserPage(this.users, this.pendingCount, this.total);
}

/// filter: pending | wholesale | retail | null(전체)
final adminUserFilterProvider = StateProvider<String?>((_) => 'pending');
final adminUserSearchProvider = StateProvider<String>((_) => '');

final adminUsersProvider = FutureProvider.autoDispose<AdminUserPage>((ref) async {
  final filter = ref.watch(adminUserFilterProvider);
  final q = ref.watch(adminUserSearchProvider);
  final res = await ref.read(apiProvider).get('/admin/users', query: {
    'filter': ?filter,
    if (q.isNotEmpty) 'q': q,
  });
  return AdminUserPage(
    ((res['users'] as List?) ?? []).map((e) => AdminUserRow.fromJson(e)).toList(),
    (res['pending_count'] ?? 0) as int,
    ((res['meta'] as Map?)?['total'] ?? 0) as int,
  );
});

class AdminUserDetail {
  final AdminUserRow user;
  final List<AdminOrderRow> recentOrders;
  AdminUserDetail(this.user, this.recentOrders);
}

final adminUserProvider =
    FutureProvider.autoDispose.family<AdminUserDetail, int>((ref, id) async {
  final res = await ref.read(apiProvider).get('/admin/users/$id');
  return AdminUserDetail(
    AdminUserRow.fromJson(res['user']),
    ((res['recent_orders'] as List?) ?? []).map((e) => AdminOrderRow.fromJson(e)).toList(),
  );
});

// ===== 문의 =====

class AdminInquiryPage {
  final List<AdminInquiry> inquiries;
  final Map<String, String> types;
  final int pendingCount, total;
  AdminInquiryPage(this.inquiries, this.types, this.pendingCount, this.total);
}

/// null=전체, 'pending'=미답변, 'answered'=답변완료
final adminInquiryStatusProvider = StateProvider<String?>((_) => 'pending');

final adminInquiriesProvider = FutureProvider.autoDispose<AdminInquiryPage>((ref) async {
  final status = ref.watch(adminInquiryStatusProvider);
  final res = await ref.read(apiProvider).get('/admin/inquiries', query: {
    'status': ?status,
  });
  return AdminInquiryPage(
    ((res['inquiries'] as List?) ?? []).map((e) => AdminInquiry.fromJson(e)).toList(),
    Map<String, String>.from(
        (res['types'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {}),
    (res['pending_count'] ?? 0) as int,
    ((res['meta'] as Map?)?['total'] ?? 0) as int,
  );
});

// ===== 후기 =====

/// null=전체, 'visible'=노출, 'hidden'=숨김
final adminReviewFilterProvider = StateProvider<String?>((_) => null);

final adminReviewsProvider = FutureProvider.autoDispose<List<AdminReview>>((ref) async {
  final filter = ref.watch(adminReviewFilterProvider);
  final res = await ref.read(apiProvider).get('/admin/reviews', query: {
    'filter': ?filter,
  });
  return ((res['reviews'] as List?) ?? []).map((e) => AdminReview.fromJson(e)).toList();
});

// ===== 액션 =====

/// 관리자 쓰기 작업 모음. 성공 시 서버 메시지를 반환하고,
/// 영향받는 목록 provider 를 무효화해 화면을 최신화한다.
class AdminActions {
  AdminActions(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiProvider);

  Future<String> updateOrderStatus(int orderId, String status) async {
    final res = await _api.put('/admin/orders/$orderId/status', data: {'status': status});
    _invalidateOrders(orderId);
    return (res['message'] ?? '주문 상태를 변경했습니다.').toString();
  }

  Future<String> updateShipping(int orderId, String courier, String trackingNo) async {
    final res = await _api.put('/admin/orders/$orderId/shipping',
        data: {'courier': courier, 'tracking_no': trackingNo});
    _invalidateOrders(orderId);
    return (res['message'] ?? '송장을 등록했습니다.').toString();
  }

  Future<String> approveUser(int userId, String bizStatus, {String? grade}) async {
    final res = await _api.put('/admin/users/$userId/approve',
        data: {'biz_status': bizStatus, 'grade': ?grade});
    _ref.invalidate(adminUsersProvider);
    _ref.invalidate(adminUserProvider(userId));
    _ref.invalidate(adminDashboardProvider);
    return (res['message'] ?? '처리했습니다.').toString();
  }

  Future<String> answerInquiry(int inquiryId, String answer) async {
    final res = await _api.post('/admin/inquiries/$inquiryId/answer', data: {'answer': answer});
    _ref.invalidate(adminInquiriesProvider);
    _ref.invalidate(adminDashboardProvider);
    return (res['message'] ?? '답변을 등록했습니다.').toString();
  }

  Future<String> toggleReview(int reviewId) async {
    final res = await _api.put('/admin/reviews/$reviewId/toggle');
    _ref.invalidate(adminReviewsProvider);
    return (res['message'] ?? '처리했습니다.').toString();
  }

  Future<String> deleteReview(int reviewId) async {
    final res = await _api.delete('/admin/reviews/$reviewId');
    _ref.invalidate(adminReviewsProvider);
    return (res['message'] ?? '후기를 삭제했습니다.').toString();
  }

  void _invalidateOrders(int orderId) {
    _ref.invalidate(adminOrdersProvider);
    _ref.invalidate(adminOrderProvider(orderId));
    _ref.invalidate(adminDashboardProvider);
  }
}

final adminActionsProvider = Provider<AdminActions>((ref) => AdminActions(ref));
