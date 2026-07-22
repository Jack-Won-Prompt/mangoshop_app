import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// 쿠폰함 — 사용가능 / 사용완료 탭
class CouponsScreen extends ConsumerStatefulWidget {
  const CouponsScreen({super.key});

  @override
  ConsumerState<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends ConsumerState<CouponsScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ref.read(apiProvider).get('/mypage/coupons').then((v) => Map<String, dynamic>.from(v as Map));
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('쿠폰함'),
          bottom: const TabBar(
            indicatorColor: AppColors.navy,
            labelColor: AppColors.navy,
            unselectedLabelColor: AppColors.sub,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            tabs: [Tab(text: '사용가능'), Tab(text: '사용완료')],
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Center(child: CircularProgressIndicator(color: AppColors.navy));
            }
            if (snap.hasError) {
              return ErrorRetry(snap.error!, _refresh);
            }
            final data = snap.data ?? const {};
            final available = ((data['available'] as List?) ?? []).map((e) => Coupon.fromJson(e)).toList();
            final used = ((data['used'] as List?) ?? []).map((e) => Coupon.fromJson(e)).toList();
            return TabBarView(
              children: [
                _couponList(available, used: false),
                _couponList(used, used: true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _couponList(List<Coupon> coupons, {required bool used}) {
    if (coupons.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: EmptyState(
                Icons.confirmation_number_outlined,
                used ? '사용완료된 쿠폰이 없습니다' : '사용 가능한 쿠폰이 없습니다',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: coupons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) => _CouponCard(coupons[i], used: used),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  final bool used;
  const _CouponCard(this.coupon, {required this.used});

  String get _valueText =>
      coupon.type == 'percent' ? '${coupon.value}%' : won(coupon.value);

  @override
  Widget build(BuildContext context) {
    final accent = used ? AppColors.sub : AppColors.navy;
    return Opacity(
      opacity: used ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 값 영역
              Container(
                width: 104,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 22),
                decoration: BoxDecoration(
                  color: used ? AppColors.chip : AppColors.redSoft,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _valueText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: coupon.type == 'percent' ? 24 : 18,
                        fontWeight: FontWeight.w900,
                        color: used ? AppColors.sub : AppColors.red,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(coupon.typeLabel, style: const TextStyle(fontSize: 11, color: AppColors.sub)),
                  ],
                ),
              ),
              // 절취선
              CustomPaint(size: const Size(1, double.infinity), painter: _DashedLinePainter()),
              // 정보 영역
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        coupon.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (coupon.minOrderAmount > 0)
                        _infoRow(Icons.shopping_bag_outlined, '${won(coupon.minOrderAmount)} 이상 구매 시'),
                      if (used && coupon.usedAt != null)
                        _infoRow(Icons.check_circle_outline, '${coupon.usedAt} 사용')
                      else if (coupon.endsAt != null)
                        _infoRow(Icons.event_outlined, '${coupon.endsAt} 까지'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.chip,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          coupon.code,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent, letterSpacing: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.sub),
          const SizedBox(width: 5),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
          ),
        ],
      ),
    );
  }
}

/// 쿠폰 절취선 (세로 점선)
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 4.0;
    double y = 6;
    while (y < size.height - 6) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
