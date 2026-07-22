import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common.dart';
import 'address_search_screen.dart';
import 'payment_webview_screen.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _loading = true;
  Object? _error;
  bool _submitting = false;

  // 주문 요약
  final List<_LineItem> _items = [];
  int _subtotal = 0;
  int _shipping = 0;

  // 배송지
  final _nameCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _postcodeCtl = TextEditingController();
  final _addr1Ctl = TextEditingController();
  final _addr2Ctl = TextEditingController();
  final _memoCtl = TextEditingController();
  final _addr2Focus = FocusNode();

  // 쿠폰
  final _couponCtl = TextEditingController();
  List<Coupon> _availableCoupons = [];
  String? _appliedCouponCode;
  int _couponDiscount = 0;
  bool _couponLoading = false;

  // 적립금
  int _point = 0;
  final _pointCtl = TextEditingController(text: '0');
  int _pointUsed = 0;

  // 결제수단
  String _paymentPg = 'toss'; // toss | portone

  String _method = 'bank'; // bank | card
  List<Map<String, String>> _banks = [];
  String? _selectedBank;
  final _depositorCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _postcodeCtl.dispose();
    _addr1Ctl.dispose();
    _addr2Ctl.dispose();
    _memoCtl.dispose();
    _couponCtl.dispose();
    _pointCtl.dispose();
    _depositorCtl.dispose();
    _addr2Focus.dispose();
    super.dispose();
  }

  /// 우편번호(주소) 검색 → 선택 시 우편번호·기본주소 채우고 상세주소로 포커스
  Future<void> _searchAddress() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<AddressResult>(
      MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _postcodeCtl.text = result.zonecode;
      _addr1Ctl.text = result.address;
      if (_addr2Ctl.text.isEmpty && result.buildingName.isNotEmpty) {
        // 건물명은 참고용으로 상세주소에 미리 넣지 않고 비워둠(사용자 입력)
      }
    });
    // 상세주소 입력 유도
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _addr2Focus.requestFocus();
    });
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).get('/checkout');

      _items
        ..clear()
        ..addAll(((res['items'] as List?) ?? []).map((e) => _LineItem.from(e)));

      final summary = (res['summary'] as Map?) ?? {};
      _subtotal = _num(summary['subtotal']);
      _shipping = _num(summary['shipping']);

      // 배송지 — 회원정보의 기본 주소로 프리필
      final addr = (res['address'] as Map?) ?? {};
      _nameCtl.text = (addr['receiver_name'] ?? '').toString();
      _phoneCtl.text = (addr['receiver_phone'] ?? '').toString();
      _postcodeCtl.text = (addr['postcode'] ?? '').toString();
      _addr1Ctl.text = (addr['address1'] ?? '').toString();
      _addr2Ctl.text = (addr['address2'] ?? '').toString();

      _availableCoupons = ((res['available_coupons'] as List?) ?? [])
          .map((e) => Coupon.fromJson(e))
          .toList();
      if (res['coupon'] is Map) {
        _appliedCouponCode = Coupon.fromJson(res['coupon']).code;
        _couponDiscount = _num(res['coupon_discount']);
      }

      _point = _num(res['point']);

      _paymentPg = (res['payment_pg'] ?? 'toss').toString();
      _banks = ((res['banks'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => {
                'bank': (e['bank'] ?? '').toString(),
                'account': (e['account'] ?? '').toString(),
                'holder': (e['holder'] ?? '').toString(),
              })
          .toList();
      if (_banks.isNotEmpty) _selectedBank = _banks.first['bank'];

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.firstError : '주문 정보를 불러오지 못했습니다.';
          _loading = false;
        });
      }
    }
  }

  int get _maxPoint {
    final cap = _subtotal - _couponDiscount;
    return _point < cap ? _point : (cap < 0 ? 0 : cap);
  }

  int get _finalAmount {
    final v = _subtotal + _shipping - _couponDiscount - _pointUsed;
    return v < 0 ? 0 : v;
  }

  // ── 쿠폰 ──────────────────────────────────────────
  Future<void> _applyCoupon(String code) async {
    if (code.trim().isEmpty) return;
    setState(() => _couponLoading = true);
    try {
      final res = await ref
          .read(apiProvider)
          .post('/checkout/coupon', data: {'code': code.trim()});
      setState(() {
        _appliedCouponCode = res['coupon'] is Map
            ? Coupon.fromJson(res['coupon']).code
            : code.trim();
        _couponDiscount = _num(res['discount']);
        _couponCtl.clear();
        _syncPointCap();
      });
      if (mounted) toast(context, (res['message'] ?? '쿠폰이 적용되었습니다.').toString());
    } catch (e) {
      if (mounted) {
        toast(context, e is ApiException ? e.firstError : '쿠폰을 적용할 수 없습니다.');
      }
    } finally {
      if (mounted) setState(() => _couponLoading = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCouponCode = null;
      _couponDiscount = 0;
      _syncPointCap();
    });
  }

  // ── 적립금 ─────────────────────────────────────────
  void _onPointChanged(String v) {
    var p = int.tryParse(v.replaceAll(',', '')) ?? 0;
    if (p > _maxPoint) {
      p = _maxPoint;
      _pointCtl.text = '$p';
      _pointCtl.selection =
          TextSelection.collapsed(offset: _pointCtl.text.length);
    }
    setState(() => _pointUsed = p);
  }

  void _useAllPoint() {
    _pointCtl.text = '$_maxPoint';
    setState(() => _pointUsed = _maxPoint);
  }

  void _syncPointCap() {
    if (_pointUsed > _maxPoint) {
      _pointUsed = _maxPoint;
      _pointCtl.text = '$_pointUsed';
    }
  }

  // ── 주문 생성 ──────────────────────────────────────
  Future<void> _submit() async {
    if (_nameCtl.text.trim().isEmpty ||
        _phoneCtl.text.trim().isEmpty ||
        _addr1Ctl.text.trim().isEmpty) {
      toast(context, '받는분, 연락처, 주소를 입력해주세요.');
      return;
    }
    final isBank = _method == 'bank';
    if (isBank && _depositorCtl.text.trim().isEmpty) {
      toast(context, '입금자명을 입력해주세요.');
      return;
    }

    final data = <String, dynamic>{
      'receiver_name': _nameCtl.text.trim(),
      'receiver_phone': _phoneCtl.text.trim(),
      'postcode': _postcodeCtl.text.trim(),
      'address1': _addr1Ctl.text.trim(),
      'address2': _addr2Ctl.text.trim(),
      'memo': _memoCtl.text.trim(),
      'payment_method': isBank ? 'bank' : _paymentPg,
      'point_used': _pointUsed,
      if (_appliedCouponCode != null) 'coupon_code': _appliedCouponCode,
      if (isBank) 'depositor': _depositorCtl.text.trim(),
      if (isBank) 'bank': _selectedBank,
    };

    setState(() => _submitting = true);
    try {
      final res = await ref.read(apiProvider).post('/orders', data: data);
      final order = OrderModel.fromJson(res['order']);
      final needsPayment = res['needs_payment'] == true;
      final paymentUrl = res['payment_url']?.toString();

      if (!mounted) return;
      if (needsPayment && paymentUrl != null && paymentUrl.isNotEmpty) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PaymentWebviewScreen(
              paymentUrl: paymentUrl,
              orderId: order.id,
            ),
          ),
        );
        if (ok != true) {
          if (mounted) {
            setState(() => _submitting = false);
            toast(context, '결제가 취소되었습니다.');
          }
          return;
        }
      }

      // 장바구니 비워짐 + 적립금 변동 반영
      ref.read(cartProvider.notifier).clearLocal();
      await ref.read(authProvider.notifier).refresh();

      if (mounted) context.go('/order/complete/${order.id}');
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        toast(context, e is ApiException ? e.firstError : '주문에 실패했습니다.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문/결제')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.navy))
          : _error != null
              ? ErrorRetry(_error!, _fetch)
              : _content(),
      bottomNavigationBar: _loading || _error != null ? null : _payBar(),
    );
  }

  Widget _content() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _section('배송지', _addressForm()),
        const SizedBox(height: 16),
        _section('주문상품', _orderItems()),
        const SizedBox(height: 16),
        _section('쿠폰', _couponSection()),
        const SizedBox(height: 16),
        _section('적립금 사용', _pointSection()),
        const SizedBox(height: 16),
        _section('결제수단', _paymentSection()),
        const SizedBox(height: 16),
        _section('결제금액', _amountSection()),
      ],
    );
  }

  // ── UI 조각 ────────────────────────────────────────
  Widget _section(String title, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctl,
      {String? hint,
      TextInputType? keyboard,
      int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.sub,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: ctl,
            keyboardType: keyboard,
            maxLines: maxLines,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  Widget _addressForm() {
    return Column(
      children: [
        _field('받는분', _nameCtl, hint: '이름'),
        _field('연락처', _phoneCtl,
            hint: '010-0000-0000', keyboard: TextInputType.phone),
        // 우편번호 + 검색 버튼
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('우편번호',
                  style: TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _postcodeCtl,
                      readOnly: true,
                      onTap: _searchAddress,
                      decoration: const InputDecoration(hintText: '주소 검색'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _searchAddress,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('주소 검색'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 기본주소 (검색으로 채움 · 읽기전용)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('주소',
                  style: TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _addr1Ctl,
                readOnly: true,
                onTap: _searchAddress,
                decoration: const InputDecoration(hintText: '주소 검색 버튼을 눌러주세요'),
              ),
            ],
          ),
        ),
        // 상세주소 (직접 입력)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('상세주소',
                  style: TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _addr2Ctl,
                focusNode: _addr2Focus,
                decoration: const InputDecoration(hintText: '동/호수 등 상세주소'),
              ),
            ],
          ),
        ),
        _field('배송메모', _memoCtl,
            hint: '예) 부재 시 경비실에 맡겨주세요', maxLines: 2),
      ],
    );
  }

  Widget _orderItems() {
    return Column(
      children: [
        for (final it in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                NetImage(it.thumbnail, width: 52, height: 52, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('${won(it.price)} · ${it.quantity}개',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.sub)),
                    ],
                  ),
                ),
                Text(won(it.price * it.quantity),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _couponSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_appliedCouponCode != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.redSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.confirmation_num_outlined,
                    size: 18, color: AppColors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$_appliedCouponCode  (-${won(_couponDiscount)})',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.red)),
                ),
                TextButton(
                  onPressed: _removeCoupon,
                  style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('해제',
                      style: TextStyle(fontSize: 13, color: AppColors.sub)),
                ),
              ],
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponCtl,
                  decoration: const InputDecoration(hintText: '쿠폰 코드 입력'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _couponLoading
                      ? null
                      : () => _applyCoupon(_couponCtl.text),
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(72, 52)),
                  child: _couponLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('적용'),
                ),
              ),
            ],
          ),
        if (_availableCoupons.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('보유 쿠폰',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.sub,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final c in _availableCoupons)
            InkWell(
              onTap: _appliedCouponCode == c.code
                  ? null
                  : () => _applyCoupon(c.code),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _appliedCouponCode == c.code
                          ? AppColors.navy
                          : AppColors.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('${c.typeLabel} · 최소주문 ${won(c.minOrderAmount)}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.sub)),
                        ],
                      ),
                    ),
                    Text(
                      _appliedCouponCode == c.code ? '적용됨' : '적용',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _appliedCouponCode == c.code
                              ? AppColors.navy
                              : AppColors.red),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _pointSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pointCtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onPointChanged,
                decoration: const InputDecoration(hintText: '0'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _maxPoint > 0 ? _useAllPoint : null,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(96, 52)),
                child: const Text('전액사용'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('보유 적립금 ${won(_point)} (최대 ${won(_maxPoint)} 사용가능)',
            style: const TextStyle(fontSize: 12, color: AppColors.sub)),
      ],
    );
  }

  Widget _paymentSection() {
    final cardLabel =
        _paymentPg == 'portone' ? '카드결제 (포트원)' : '카드결제 (토스페이먼츠)';
    return Column(
      children: [
        _methodTile('bank', '무통장입금', Icons.account_balance_outlined),
        const SizedBox(height: 8),
        _methodTile('card', cardLabel, Icons.credit_card),
        if (_method == 'bank') ...[
          const SizedBox(height: 14),
          if (_banks.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('입금은행',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.sub,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedBank,
                  items: [
                    for (final b in _banks)
                      DropdownMenuItem(
                        value: b['bank'],
                        child: Text(
                            '${b['bank']}  ${b['account']} (${b['holder']})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _selectedBank = v),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _field('입금자명', _depositorCtl, hint: '입금하실 분 성함'),
        ],
      ],
    );
  }

  Widget _methodTile(String value, String label, IconData icon) {
    final selected = _method == value;
    return InkWell(
      onTap: () => setState(() => _method = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? AppColors.navy : AppColors.line,
              width: selected ? 1.6 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.chip : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? AppColors.navy : AppColors.sub),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.navy : AppColors.ink)),
            const Spacer(),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 20,
              color: selected ? AppColors.navy : AppColors.line,
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountSection() {
    return Column(
      children: [
        _amountRow('상품금액', won(_subtotal)),
        const SizedBox(height: 8),
        _amountRow('배송비', _shipping == 0 ? '무료' : won(_shipping)),
        if (_couponDiscount > 0) ...[
          const SizedBox(height: 8),
          _amountRow('쿠폰할인', '-${won(_couponDiscount)}', color: AppColors.red),
        ],
        if (_pointUsed > 0) ...[
          const SizedBox(height: 8),
          _amountRow('적립금 사용', '-${won(_pointUsed)}', color: AppColors.red),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('최종 결제금액',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            Text(won(_finalAmount),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.red)),
          ],
        ),
      ],
    );
  }

  Widget _amountRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.sub)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.ink)),
      ],
    );
  }

  Widget _payBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('최종 결제금액',
                  style: TextStyle(fontSize: 12, color: AppColors.sub)),
              Text(won(_finalAmount),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.red)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('결제하기'),
            ),
          ),
        ],
      ),
    );
  }
}

int _num(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);

class _LineItem {
  final String name;
  final String? thumbnail;
  final int price;
  final int quantity;
  _LineItem(this.name, this.thumbnail, this.price, this.quantity);
  factory _LineItem.from(Map j) {
    final p = (j['product'] as Map?) ?? {};
    return _LineItem(
      (p['name'] ?? '').toString(),
      p['thumbnail']?.toString(),
      _num(j['price']),
      _num(j['quantity']),
    );
  }
}
