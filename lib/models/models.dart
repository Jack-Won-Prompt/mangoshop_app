// 망고샵 API 응답 모델. JSON 맵에서 안전하게 파싱.

int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
double _dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
bool _bool(dynamic v) => v == true || v == 1 || v == '1';
String? _str(dynamic v) => v?.toString();

class Brand {
  final int id;
  final String name;
  final String? slug;
  final String? logo;
  final String? description;
  Brand.fromJson(Map j)
      : id = _int(j['id']),
        name = j['name'] ?? '',
        slug = _str(j['slug']),
        logo = _str(j['logo']),
        description = _str(j['description']);
}

/// 입점 수입사(판매자). 망고샵은 멀티벤더라 상품마다 판매 주체가 다르다.
class Seller {
  final int id;
  final String name;
  final String? slug, logo, originFocus;
  final bool coldchain;
  final double rating;
  final int ratingCount;

  // 상세 전용 (수입사 배송정책)
  final String? intro, banner, shippingNotice;
  final int shippingFee, freeShippingThreshold;

  Seller.fromJson(Map j)
      : id = _int(j['id']),
        name = j['name'] ?? '',
        slug = _str(j['slug']),
        logo = _str(j['logo']),
        originFocus = _str(j['origin_focus']),
        coldchain = _bool(j['coldchain']),
        rating = _dbl(j['rating']),
        ratingCount = _int(j['rating_count']),
        intro = _str(j['intro']),
        banner = _str(j['banner']),
        shippingNotice = _str(j['shipping_notice']),
        shippingFee = _int(j['shipping_fee']),
        freeShippingThreshold = _int(j['free_shipping_threshold']);
}

/// 수량구간 할인 — `min_qty` 이상 구매 시 `price` 단가 적용.
class PriceTier {
  final int minQty, price;
  PriceTier.fromJson(Map j)
      : minQty = _int(j['min_qty']),
        price = _int(j['price']);
}

class Product {
  final int id;
  final String name;
  final String slug;
  final String? code;
  final String? unit;
  final String? maker;
  final String? summary;
  final String? thumbnail;
  final int price;
  final int listPrice;
  final int discountRate;
  final bool hasSpecial;
  final int stock;
  final bool isBest, isNew, isFeatured;
  final String? badge;
  final Brand? brand;

  // ----- 망고샵: 멀티벤더 / 신선식품 -----
  final Seller? seller;
  final String? origin; // 원산지
  final String? variety; // 품종
  final String? grade; // 등급 (특/상/보통)
  final String? boxSpec; // 규격 (5kg/9~12과)
  final double? weightKg;
  final int moq; // 최소주문수량
  final String saleStatus; // on_sale / soldout / closed / inbound
  final String saleStatusLabel;
  final bool purchasable;

  /// 가격 노출 여부. 도매 전용 상품은 비로그인/소매회원에게 가격을 숨긴다.
  final bool priceVisible;
  final bool wholesaleOnly;

  // 상세 전용
  final String? description;
  final String? spec;
  final String? taxType;
  final List<String> gallery;
  final List<Review> reviews;
  final int reviewCount;
  final double ratingAvg;
  final List<PriceTier> priceTiers;
  final int? wholesalePrice;
  final String? inboundDate, expiryDate, storageMethod, lotNo, expectedInboundDate;
  final int salesCount;

  Product.fromJson(Map j)
      : id = _int(j['id']),
        name = j['name'] ?? '',
        slug = j['slug'] ?? '',
        code = _str(j['code']),
        unit = _str(j['unit']),
        maker = _str(j['maker']),
        summary = _str(j['summary']),
        thumbnail = _str(j['thumbnail']),
        price = _int(j['price']),
        listPrice = _int(j['list_price']),
        discountRate = _int(j['discount_rate']),
        hasSpecial = _bool(j['has_special']),
        stock = _int(j['stock']),
        isBest = _bool(j['is_best']),
        isNew = _bool(j['is_new']),
        isFeatured = _bool(j['is_featured']),
        badge = _str(j['badge']),
        brand = j['brand'] is Map ? Brand.fromJson(j['brand']) : null,
        seller = j['seller'] is Map ? Seller.fromJson(j['seller']) : null,
        origin = _str(j['origin']),
        variety = _str(j['variety']),
        grade = _str(j['grade']),
        boxSpec = _str(j['box_spec']),
        weightKg = j['weight_kg'] == null ? null : _dbl(j['weight_kg']),
        moq = j['moq'] == null ? 1 : (_int(j['moq']) < 1 ? 1 : _int(j['moq'])),
        saleStatus = j['sale_status'] ?? 'on_sale',
        saleStatusLabel = j['sale_status_label'] ?? '',
        // 구버전 서버(필드 미제공)에서는 재고만으로 판단 — 전 상품이 품절로 보이는 것을 방지
        purchasable = j['purchasable'] == null ? _int(j['stock']) > 0 : _bool(j['purchasable']),
        // 서버가 필드를 생략하면(레거시 응답) 노출 허용으로 간주
        priceVisible = j['price_visible'] == null || _bool(j['price_visible']),
        wholesaleOnly = _bool(j['wholesale_only']),
        description = _str(j['description']),
        spec = _str(j['spec']),
        taxType = _str(j['tax_type']),
        gallery = ((j['gallery'] as List?) ?? []).map((e) => e.toString()).toList(),
        reviews = ((j['reviews'] as List?) ?? []).map((e) => Review.fromJson(e)).toList(),
        reviewCount = _int(j['review_count']),
        ratingAvg = _dbl(j['rating_avg']),
        priceTiers = ((j['price_tiers'] as List?) ?? []).map((e) => PriceTier.fromJson(e)).toList(),
        wholesalePrice = j['wholesale_price'] == null ? null : _int(j['wholesale_price']),
        inboundDate = _str(j['inbound_date']),
        expiryDate = _str(j['expiry_date']),
        storageMethod = _str(j['storage_method']),
        lotNo = _str(j['lot_no']),
        expectedInboundDate = _str(j['expected_inbound_date']),
        salesCount = _int(j['sales_count']);

  bool get inStock => stock > 0;
  bool get onSale => discountRate > 0 && priceVisible;

  /// 입고예정 상품 — 재입고 알림 대상
  bool get isInbound => saleStatus == 'inbound';

  /// "태국산 · 남독마이 · 특" 형태의 산지 요약
  String get originLine =>
      [origin, variety, if (grade != null && grade!.isNotEmpty) '$grade등급']
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(' · ');
}

class Category {
  final int id;
  final String name;
  final String? slug;
  final String? tagline;
  final String? icon;
  final int? parentId;
  final List<Category> children;
  Category.fromJson(Map j)
      : id = _int(j['id']),
        name = j['name'] ?? '',
        slug = _str(j['slug']),
        tagline = _str(j['tagline']),
        icon = _str(j['icon']),
        parentId = j['parent_id'] == null ? null : _int(j['parent_id']),
        children = ((j['children'] as List?) ?? []).map((e) => Category.fromJson(e)).toList();
}

class Banner {
  final int id;
  final String? title, subtitle, image, link, bgColor;
  Banner.fromJson(Map j)
      : id = _int(j['id']),
        title = _str(j['title']),
        subtitle = _str(j['subtitle']),
        image = _str(j['image']),
        link = _str(j['link']),
        bgColor = _str(j['bg_color']);
}

class Review {
  final int id;
  final String author;
  final int rating;
  final String? title, body, date;
  Review.fromJson(Map j)
      : id = _int(j['id']),
        author = j['author'] ?? '',
        rating = _int(j['rating']),
        title = _str(j['title']),
        body = _str(j['body']),
        date = _str(j['date']);
}

class NoticeItem {
  final int id;
  final String title;
  final bool pinned;
  final int views;
  final String? date;
  final String? body;
  NoticeItem.fromJson(Map j)
      : id = _int(j['id']),
        title = j['title'] ?? '',
        pinned = _bool(j['is_pinned']),
        views = _int(j['views']),
        date = _str(j['date']),
        body = _str(j['body']);
}

class CartLine {
  final int id;
  final int quantity;
  final int price;
  final int lineTotal;
  final Product product;
  CartLine.fromJson(Map j)
      : id = _int(j['id']),
        quantity = _int(j['quantity']),
        price = _int(j['price']),
        lineTotal = _int(j['line_total']),
        product = Product.fromJson(j['product']);
}

class CartSummary {
  final int subtotal, shipping, total, count, freeShipOver;
  CartSummary.fromJson(Map j)
      : subtotal = _int(j['subtotal']),
        shipping = _int(j['shipping']),
        total = _int(j['total']),
        count = _int(j['count']),
        freeShipOver = _int(j['free_ship_over']);
}

class OrderItem {
  final int id;
  final int? productId;
  final String productName;
  final String? unit;
  final int price, quantity, subtotal;
  final String? thumbnail;
  OrderItem.fromJson(Map j)
      : id = _int(j['id']),
        productId = j['product_id'] == null ? null : _int(j['product_id']),
        productName = j['product_name'] ?? '',
        unit = _str(j['unit']),
        price = _int(j['price']),
        quantity = _int(j['quantity']),
        subtotal = _int(j['subtotal']),
        thumbnail = _str(j['thumbnail']);
}

class OrderModel {
  final int id;
  final String orderNo;
  final String status;
  final String statusLabel;
  final String paymentMethod;
  final String? receiverName, receiverPhone, postcode, address1, address2, memo;
  final int subtotal, shippingFee, discount, pointUsed, total;
  final String? couponCode, bank, depositor;
  final String? vaBank, vaAccount, vaHolder, vaDueAt;
  final String? courier, trackingNo, paidAt, createdAt;
  final int? itemCount;
  final bool canCancel;
  final List<OrderItem> items;

  OrderModel.fromJson(Map j)
      : id = _int(j['id']),
        orderNo = j['order_no'] ?? '',
        status = j['status'] ?? '',
        statusLabel = j['status_label'] ?? '',
        paymentMethod = j['payment_method'] ?? 'bank',
        receiverName = _str(j['receiver_name']),
        receiverPhone = _str(j['receiver_phone']),
        postcode = _str(j['postcode']),
        address1 = _str(j['address1']),
        address2 = _str(j['address2']),
        memo = _str(j['memo']),
        subtotal = _int(j['subtotal']),
        shippingFee = _int(j['shipping_fee']),
        discount = _int(j['discount']),
        pointUsed = _int(j['point_used']),
        total = _int(j['total']),
        couponCode = _str(j['coupon_code']),
        bank = _str(j['bank']),
        depositor = _str(j['depositor']),
        vaBank = _str(j['va_bank']),
        vaAccount = _str(j['va_account']),
        vaHolder = _str(j['va_holder']),
        vaDueAt = _str(j['va_due_at']),
        courier = _str(j['courier']),
        trackingNo = _str(j['tracking_no']),
        paidAt = _str(j['paid_at']),
        createdAt = _str(j['created_at']),
        itemCount = j['item_count'] == null ? null : _int(j['item_count']),
        canCancel = _bool(j['can_cancel']),
        items = ((j['items'] as List?) ?? []).map((e) => OrderItem.fromJson(e)).toList();

  String get paymentLabel => switch (paymentMethod) {
        'toss' => '토스페이먼츠',
        'portone' => '포트원',
        _ => '무통장입금',
      };
}

class Coupon {
  final int id;
  final String code, name, type, typeLabel;
  final int value, minOrderAmount;
  final int? maxDiscount, discount;
  final String? endsAt, usedAt;
  Coupon.fromJson(Map j)
      : id = _int(j['id']),
        code = j['code'] ?? '',
        name = j['name'] ?? '',
        type = j['type'] ?? 'fixed',
        typeLabel = j['type_label'] ?? '',
        value = _int(j['value']),
        minOrderAmount = _int(j['min_order_amount']),
        maxDiscount = j['max_discount'] == null ? null : _int(j['max_discount']),
        discount = j['discount'] == null ? null : _int(j['discount']),
        endsAt = _str(j['ends_at']),
        usedAt = _str(j['used_at']);
}

class PointLog {
  final int id;
  final int amount, balance;
  final String? reason, date;
  PointLog.fromJson(Map j)
      : id = _int(j['id']),
        amount = _int(j['amount']),
        balance = _int(j['balance']),
        reason = _str(j['reason']),
        date = _str(j['date']);
}

class AppUser {
  final int id;
  final String name, email, memberType;

  /// 도매(사업자) 회원 여부. 도매가·여신 이용 자격의 전제 조건.
  final bool isWholesale;
  final bool isApprovedBusiness, isAdmin;
  final String? bizStatus, grade, phone, postcode, address1, address2, companyName, bizNo, bizType;
  final int point;

  AppUser.fromJson(Map j)
      : id = _int(j['id']),
        name = j['name'] ?? '',
        email = j['email'] ?? '',
        memberType = j['member_type'] ?? 'retail',
        // is_wholesale 이 없으면 레거시 is_business 로 대체
        isWholesale = _bool(j['is_wholesale'] ?? j['is_business']),
        isApprovedBusiness = _bool(j['is_approved_business']),
        isAdmin = _bool(j['is_admin']),
        bizStatus = _str(j['biz_status']),
        grade = _str(j['grade']),
        phone = _str(j['phone']),
        postcode = _str(j['postcode']),
        address1 = _str(j['address1']),
        address2 = _str(j['address2']),
        companyName = _str(j['company_name']),
        bizNo = _str(j['biz_no']),
        bizType = _str(j['biz_type']),
        point = _int(j['point']);

  /// 도매가를 실제로 적용받는 상태인가 (사업자 승인 완료)
  bool get canSeeWholesalePrice => isWholesale && isApprovedBusiness;

  /// 사업자 승인 대기 중 — 아직 소매가로 노출된다
  bool get isPendingApproval => isWholesale && bizStatus == 'pending';

  String get memberLabel {
    if (!isWholesale) return '소매회원';
    return switch (bizStatus) {
      'approved' => '도매회원 (승인)',
      'pending' => '도매회원 (승인대기)',
      'rejected' => '도매회원 (반려)',
      _ => '도매회원',
    };
  }
}

class Paginated<T> {
  final List<T> items;
  final int currentPage, lastPage;
  final bool hasMore;
  Paginated(this.items, {required this.currentPage, required this.lastPage, required this.hasMore});
  factory Paginated.from(Map j, String key, T Function(Map) parse) {
    final meta = (j['meta'] as Map?) ?? {};
    return Paginated(
      ((j[key] as List?) ?? []).map((e) => parse(e)).toList(),
      currentPage: _int(meta['current_page'] ?? 1),
      lastPage: _int(meta['last_page'] ?? 1),
      hasMore: _bool(meta['has_more']),
    );
  }
}
