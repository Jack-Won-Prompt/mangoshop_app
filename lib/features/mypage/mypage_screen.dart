import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

/// 마이 탭 — 비로그인 시 로그인 유도, 로그인 시 요약/메뉴 표시
class MypageScreen extends ConsumerStatefulWidget {
  const MypageScreen({super.key});

  @override
  ConsumerState<MypageScreen> createState() => _MypageScreenState();
}

class _MypageScreenState extends ConsumerState<MypageScreen> {
  Future<Map<String, dynamic>>? _future;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _wasLoggedIn = ref.read(authProvider).isLoggedIn;
    if (_wasLoggedIn) _load();
  }

  void _load() {
    _future = ref.read(apiProvider).get('/mypage').then((v) => Map<String, dynamic>.from(v as Map));
  }

  Future<void> _refresh() async {
    _load();
    setState(() {});
    await _future;
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.sub),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = ref.watch(authProvider).isLoggedIn;

    // 로그인 상태 전환 시 데이터 재적재
    if (loggedIn && !_wasLoggedIn) {
      _wasLoggedIn = true;
      _load();
    } else if (!loggedIn && _wasLoggedIn) {
      _wasLoggedIn = false;
      _future = null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: loggedIn ? _loggedInView() : _loginPrompt(),
    );
  }

  // ── 비로그인 ──────────────────────────────────────────────
  Widget _loginPrompt() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/brand/logo_stacked.png',
              height: 120,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const Text(
                '망고샵',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brand,
                  letterSpacing: -1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '로그인하고 다양한 혜택을 누리세요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.sub, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text('로그인'),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('아직 회원이 아니신가요?', style: TextStyle(color: AppColors.sub)),
                TextButton(
                  onPressed: () => context.push('/register'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.navy),
                  child: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 로그인 ────────────────────────────────────────────────
  Widget _loggedInView() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.navy));
          }
          if (snap.hasError) {
            return ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: ErrorRetry(snap.error!, _refresh),
                ),
              ],
            );
          }
          final data = snap.data ?? const {};
          final user = _resolveUser(data);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (user != null) _profileCard(user),
              const SizedBox(height: 16),
              _statsRow(data),
              const SizedBox(height: 20),
              _recentOrders(data),
              const SizedBox(height: 8),
              _menuGroups(),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _confirmLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sub,
                  side: const BorderSide(color: AppColors.line),
                ),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text('로그아웃'),
              ),
            ],
          );
        },
      ),
    );
  }

  AppUser? _resolveUser(Map<String, dynamic> data) {
    if (data['user'] is Map) {
      return AppUser.fromJson(Map<String, dynamic>.from(data['user']));
    }
    return ref.read(authProvider).user;
  }

  Widget _profileCard(AppUser user) {
    final pending = user.isPendingApproval;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.navy, AppColors.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _gradeBadge(user),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              user.memberLabel,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          if (pending) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '도매회원 승인 대기중입니다. 승인 후 도매 전용가로 구매하실 수 있습니다.',
                      style: TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gradeBadge(AppUser user) {
    final grade = user.grade;
    if (grade == null || grade.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        grade,
        style: const TextStyle(color: AppColors.navy, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _statsRow(Map<String, dynamic> data) {
    final point = _asInt(data['point']);
    final coupon = _asInt(data['coupon_count']);
    final wishlist = _asInt(data['wishlist_count']);
    final orders = _asInt(data['order_count']);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          _statCell('적립금', comma(point), Icons.savings_outlined, () => context.push('/mypage/points')),
          _statDivider(),
          _statCell('쿠폰', '$coupon', Icons.confirmation_number_outlined, () => context.push('/mypage/coupons')),
          _statDivider(),
          _statCell('관심상품', '$wishlist', Icons.favorite_border, () => context.go('/wishlist')),
          _statDivider(),
          _statCell('주문', '$orders', Icons.receipt_long_outlined, () => context.push('/orders')),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 34, color: AppColors.line);

  Widget _statCell(String label, String value, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.navy),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentOrders(Map<String, dynamic> data) {
    final list = ((data['recent_orders'] as List?) ?? [])
        .map((e) => OrderModel.fromJson(e))
        .toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(
              children: [
                const Text('최근 주문', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/orders'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.sub, padding: EdgeInsets.zero),
                  child: const Row(children: [
                    Text('전체보기', style: TextStyle(fontSize: 13)),
                    Icon(Icons.chevron_right, size: 18),
                  ]),
                ),
              ],
            ),
          ),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 6, 16, 20),
              child: Text('최근 주문 내역이 없습니다.', style: TextStyle(color: AppColors.sub, fontSize: 13.5)),
            )
          else
            ...list.map((o) => _orderRow(o)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _orderRow(OrderModel o) {
    return InkWell(
      onTap: () => context.push('/orders/${o.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.orderNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(o.statusLabel, style: const TextStyle(fontSize: 11, color: AppColors.navy, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const Spacer(),
            Text(won(o.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.sub),
          ],
        ),
      ),
    );
  }

  Widget _menuGroups() {
    final isAdmin = ref.read(authProvider).user?.isAdmin ?? false;
    return Column(
      children: [
        // 관리자 계정이 고객 화면을 보고 있을 때 다시 관리자 모드로 돌아가는 경로
        if (isAdmin) ...[
          _menuGroup('관리', [
            // isTab: 관리자 셸은 별도 셸이라 push 가 아닌 go 로 전환해야 한다
            _MenuItem(Icons.admin_panel_settings_outlined, '관리자 모드', '/admin', isTab: true),
          ]),
          const SizedBox(height: 12),
        ],
        _menuGroup('주문/혜택', [
          _MenuItem(Icons.receipt_long_outlined, '주문내역', '/orders'),
          _MenuItem(Icons.favorite_border, '관심상품', '/wishlist', isTab: true),
          _MenuItem(Icons.savings_outlined, '적립금', '/mypage/points'),
          _MenuItem(Icons.confirmation_number_outlined, '쿠폰함', '/mypage/coupons'),
          _MenuItem(Icons.manage_accounts_outlined, '회원정보 수정', '/mypage/profile'),
        ]),
        const SizedBox(height: 12),
        _menuGroup('고객센터', [
          _MenuItem(Icons.campaign_outlined, '공지사항', '/community/notices'),
          _MenuItem(Icons.rate_review_outlined, '상품후기', '/community/reviews'),
          _MenuItem(Icons.help_outline, '자주묻는질문', '/community/faq'),
          _MenuItem(Icons.forum_outlined, '1:1 문의', '/community/qna'),
          _MenuItem(Icons.support_agent_outlined, '실시간 상담', '/chat'),
        ]),
        const SizedBox(height: 12),
        _menuGroup('이용안내', [
          _MenuItem(Icons.card_giftcard_outlined, '신규회원 혜택', '/guide/event'),
          _MenuItem(Icons.local_shipping_outlined, '배송 안내', '/guide/delivery'),
          _MenuItem(Icons.credit_card_outlined, '결제 안내', '/guide/payment'),
        ]),
      ],
    );
  }

  Widget _menuGroup(String title, List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.sub)),
          ),
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: Icon(items[i].icon, color: AppColors.navy, size: 22),
              title: Text(items[i].label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.sub),
              onTap: () => items[i].isTab ? context.go(items[i].route) : context.push(items[i].route),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  int _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;
  final bool isTab;
  const _MenuItem(this.icon, this.label, this.route, {this.isTab = false});
}
