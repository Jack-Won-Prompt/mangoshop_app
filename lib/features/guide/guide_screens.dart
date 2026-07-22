import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';

// ==========================================================
// 공통 위젯
// ==========================================================
Widget _sectionTitle(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 10),
        Text(s, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );

Widget _card({required Widget child, EdgeInsets? padding}) => Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );

Widget _infoRow(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(k, style: const TextStyle(color: AppColors.sub, fontSize: 13.5, fontWeight: FontWeight.w600))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13.5, height: 1.5))),
        ],
      ),
    );

Widget _benefitCell(IconData icon, String title, String desc) => _card(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      child: Column(children: [
        Icon(icon, size: 30, color: AppColors.navy),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(desc, style: const TextStyle(color: AppColors.sub, fontSize: 12.5, height: 1.4), textAlign: TextAlign.center),
      ]),
    );

Widget _guideScaffold(String title, Widget Function(SiteSettings s) body, WidgetRef ref) {
  final async = ref.watch(settingsProvider);
  return Scaffold(
    appBar: AppBar(title: Text(title)),
    body: async.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.navy)),
      error: (e, _) => ErrorRetry(e, () => ref.invalidate(settingsProvider)),
      data: (s) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [body(s)]),
    ),
  );
}

// ==========================================================
// 1. 신규회원 이벤트
// ==========================================================
class EventGuideScreen extends ConsumerWidget {
  const EventGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _guideScaffold('신규회원 이벤트', (s) {
      final point = won(s.signupPoint);
      final isLoggedIn = ref.watch(authProvider).isLoggedIn;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(children: [
              const Text('MANGOSHOP WELCOME', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Text('가입 즉시 $point 적립', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('신규회원가입만 해도 바로 사용 가능한\n적립금을 드립니다.',
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
              if (!isLoggedIn) ...[
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () => context.push('/register'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.navy, minimumSize: const Size(220, 48)),
                  child: const Text('회원가입하고 혜택받기'),
                ),
              ],
            ]),
          ),
          _sectionTitle('이벤트 혜택'),
          Row(children: [
            Expanded(child: _benefitCell(Icons.savings_outlined, '가입 적립금', '가입 즉시 $point 지급')),
            const SizedBox(width: 12),
            Expanded(child: _benefitCell(Icons.verified_outlined, '도매 전용가', '사업자 승인 시\n도매 특별가 적용')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _benefitCell(Icons.local_shipping_outlined, '빠른 배송', '평일 2시 이전\n주문 당일출고')),
            const SizedBox(width: 12),
            Expanded(child: _benefitCell(Icons.confirmation_number_outlined, '쿠폰 혜택', '기간별 할인쿠폰\n발행')),
          ]),
          _sectionTitle('이용 안내'),
          _card(
            child: Column(children: const [
              _GuideBullet('적립금은 가입 완료 즉시 마이페이지에 지급됩니다.'),
              _GuideBullet('도매(사업자) 회원은 관리자 승인 후 도매가가 적용됩니다.'),
              _GuideBullet('자세한 혜택은 공지사항을 참고해주세요.'),
            ]),
          ),
        ],
      );
    }, ref);
  }
}

// ==========================================================
// 2. 당일출고 / 배송안내
// ==========================================================
class DeliveryGuideScreen extends ConsumerWidget {
  const DeliveryGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _guideScaffold('배송 안내', (s) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            child: Row(children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.local_shipping_outlined, size: 32, color: AppColors.navy),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('평일 오후 2시 이전 결제 시 당일출고', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
                  SizedBox(height: 6),
                  Text('신선도 유지를 위해 콜드체인으로 빠르게 발송합니다.\n(재고 보유 상품 기준)', style: TextStyle(color: AppColors.sub, fontSize: 13, height: 1.4)),
                ]),
              ),
            ]),
          ),
          _sectionTitle('배송 안내'),
          _card(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(children: [
              _infoRow('당일출고 기준', '평일 오후 2:00 이전 결제 완료 건 (재고 보유 상품)'),
              const Divider(height: 1),
              _infoRow('배송 소요', '출고 후 영업일 기준 1~3일 내 수령'),
              const Divider(height: 1),
              _infoRow('배송비', '기본 ${won(s.shippingFee)} / ${won(s.freeShipOver)} 이상 구매 시 무료배송'),
              const Divider(height: 1),
              _infoRow('휴무', '주말·공휴일 (해당일 주문은 다음 영업일 출고)'),
            ]),
          ),
          _sectionTitle('유의사항'),
          _card(
            child: const Column(children: [
              _GuideBullet('재고 미보유·주문제작 상품은 별도 안내됩니다.'),
              _GuideBullet('도서산간 지역은 추가 배송비/기간이 발생할 수 있습니다.'),
              _GuideBullet('결제완료 시각 기준으로 당일출고 여부가 결정됩니다.'),
            ]),
          ),
        ],
      );
    }, ref);
  }
}

// ==========================================================
// 3. 간편결제 안내
// ==========================================================
class PaymentGuideScreen extends ConsumerWidget {
  const PaymentGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _guideScaffold('결제 안내', (s) {
      final pg = s.paymentPg == 'portone' ? '포트원(아임포트)' : '토스페이먼츠';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
            child: Row(children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.verified_user_outlined, size: 32, color: AppColors.navy),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('안전하고 빠른 간편결제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('$pg 결제창을 통해 카드·간편결제·가상계좌를 지원합니다.',
                      style: const TextStyle(color: AppColors.sub, fontSize: 13, height: 1.4)),
                ]),
              ),
            ]),
          ),
          _sectionTitle('지원 결제수단'),
          Row(children: [
            Expanded(child: _benefitCell(Icons.credit_card, '신용·체크카드', '전 카드사 결제\n무이자 할부(카드사별)')),
            const SizedBox(width: 12),
            Expanded(child: _benefitCell(Icons.smartphone, '간편결제', '토스·카카오·\n네이버페이 등')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _benefitCell(Icons.account_balance, '가상계좌/이체', '발급 계좌 입금 시\n자동 확인')),
            const SizedBox(width: 12),
            Expanded(child: _benefitCell(Icons.receipt_long_outlined, '무통장입금', '안내 계좌로\n직접 입금 후 확인')),
          ]),
          if (s.banks.isNotEmpty) ...[
            _sectionTitle('무통장 입금계좌'),
            _card(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Column(
                children: s.banks.whereType<Map>().map((b) {
                  return _infoRow(
                    (b['bank'] ?? '').toString(),
                    '${b['account'] ?? ''}${b['holder'] != null ? '  (예금주: ${b['holder']})' : ''}',
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _card(
            child: const Column(children: [
              _GuideBullet('세금계산서는 도매(사업자) 회원 결제완료 주문에 대해 발행됩니다.'),
              _GuideBullet('결제 관련 문의는 고객센터 또는 1:1 문의를 이용해주세요.'),
            ]),
          ),
        ],
      );
    }, ref);
  }
}

class _GuideBullet extends StatelessWidget {
  final String text;
  const _GuideBullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle, size: 5, color: AppColors.sub)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.ink))),
      ]),
    );
  }
}
