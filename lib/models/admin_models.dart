// 관리자 API(/api/v1/admin) 응답 모델.

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
bool _bool(dynamic v) => v == true || v == 1 || v == '1';
String? _str(dynamic v) => v?.toString();

/// 대시보드 요약
class AdminDashboard {
  final int pendingOrders, pendingUsers, pendingInquiries, preparingOrders, totalProducts;
  final int salesToday, salesTodayCount, salesMonth, salesMonthCount;
  final List<AdminOrderRow> recentOrders;

  /// 주문상태 코드 → 라벨 (서버 Order::STATUSES 를 그대로 받는다)
  final Map<String, String> statuses;

  AdminDashboard.fromJson(Map j)
      : pendingOrders = _int((j['stats'] ?? {})['pending_orders']),
        pendingUsers = _int((j['stats'] ?? {})['pending_users']),
        pendingInquiries = _int((j['stats'] ?? {})['pending_inquiries']),
        preparingOrders = _int((j['stats'] ?? {})['preparing_orders']),
        totalProducts = _int((j['stats'] ?? {})['total_products']),
        salesToday = _int((j['sales'] ?? {})['today']),
        salesTodayCount = _int((j['sales'] ?? {})['today_count']),
        salesMonth = _int((j['sales'] ?? {})['month']),
        salesMonthCount = _int((j['sales'] ?? {})['month_count']),
        recentOrders =
            ((j['recent_orders'] as List?) ?? []).map((e) => AdminOrderRow.fromJson(e)).toList(),
        statuses = Map<String, String>.from(
            (j['statuses'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {});

  /// 즉시 처리해야 하는 건수 합계 (탭 배지용)
  int get actionCount => pendingOrders + pendingUsers + pendingInquiries;
}

/// 주문 목록 행
class AdminOrderRow {
  final int id;
  final String orderNo, status, statusLabel;
  final String? receiverName, customerName, createdAt, paymentMethod, payStatus;
  final int total;
  final int? itemCount;
  final bool canCancel;

  AdminOrderRow.fromJson(Map j)
      : id = _int(j['id']),
        orderNo = j['order_no'] ?? '',
        status = j['status'] ?? '',
        statusLabel = j['status_label'] ?? '',
        receiverName = _str(j['receiver_name']),
        customerName = _str(j['customer_name']),
        createdAt = _str(j['created_at']),
        paymentMethod = _str(j['payment_method']),
        payStatus = _str(j['pay_status']),
        total = _int(j['total']),
        itemCount = j['item_count'] == null ? null : _int(j['item_count']),
        canCancel = _bool(j['can_cancel']);
}

/// 주문 상세에 붙는 주문자 정보
class AdminOrderCustomer {
  final int id;
  final String name;
  final String? email, phone, companyName, memberLabel;
  AdminOrderCustomer.fromJson(Map j)
      : id = _int(j['id']),
        name = j['name'] ?? '',
        email = _str(j['email']),
        phone = _str(j['phone']),
        companyName = _str(j['company_name']),
        memberLabel = _str(j['member_label']);
}

/// 회원 목록/상세 행
class AdminUserRow {
  final int id;
  final String name, email;
  final String? phone, memberType, bizStatus, grade, companyName, bizNo, bizType, createdAt;
  final bool isWholesale, isAdmin;
  final int point, ordersCount;

  AdminUserRow.fromJson(Map j)
      : id = _int(j['id']),
        name = j['name'] ?? '',
        email = j['email'] ?? '',
        phone = _str(j['phone']),
        memberType = _str(j['member_type']),
        bizStatus = _str(j['biz_status']),
        grade = _str(j['grade']),
        companyName = _str(j['company_name']),
        bizNo = _str(j['biz_no']),
        bizType = _str(j['biz_type']),
        createdAt = _str(j['created_at']),
        isWholesale = _bool(j['is_wholesale'] ?? j['is_business']),
        isAdmin = _bool(j['is_admin']),
        point = _int(j['point']),
        ordersCount = _int(j['orders_count']);

  bool get isPending => bizStatus == 'pending';

  String get statusLabel => switch (bizStatus) {
        'approved' => '승인',
        'pending' => '승인대기',
        'rejected' => '반려',
        _ => isWholesale ? '미신청' : '소매',
      };
}

/// 1:1 문의 / 견적문의
class AdminInquiry {
  final int id;
  final String type, typeLabel, status;
  final String? name, phone, email, subject, body, answer, answeredAt, createdAt;
  final bool isAnswered, isSecret;

  AdminInquiry.fromJson(Map j)
      : id = _int(j['id']),
        type = j['type'] ?? '',
        typeLabel = j['type_label'] ?? '',
        status = j['status'] ?? '',
        name = _str(j['name']),
        phone = _str(j['phone']),
        email = _str(j['email']),
        subject = _str(j['subject']),
        body = _str(j['body']),
        answer = _str(j['answer']),
        answeredAt = _str(j['answered_at']),
        createdAt = _str(j['created_at']),
        isAnswered = _bool(j['is_answered']),
        isSecret = _bool(j['is_secret']);
}

/// 후기 관리 행
class AdminReview {
  final int id;
  final String author;
  final int rating;
  final String? title, body, date, productName, productSlug;
  final bool isHidden;

  AdminReview.fromJson(Map j)
      : id = _int(j['id']),
        author = j['author'] ?? '',
        rating = _int(j['rating']),
        title = _str(j['title']),
        body = _str(j['body']),
        date = _str(j['date']),
        productName = _str(j['product_name']),
        productSlug = _str(j['product_slug']),
        isHidden = _bool(j['is_hidden']);
}
