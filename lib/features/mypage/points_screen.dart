import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// 적립금 내역 — 무한 스크롤 페이지네이션
class PointsScreen extends ConsumerStatefulWidget {
  const PointsScreen({super.key});

  @override
  ConsumerState<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends ConsumerState<PointsScreen> {
  final _scrollCtrl = ScrollController();
  final List<PointLog> _logs = [];
  int _balance = 0;
  int _page = 1;
  bool _hasMore = true;
  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetch();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).get('/mypage/points', query: {'page': _page});
      final map = Map<String, dynamic>.from(res as Map);
      _balance = _asInt(map['balance']);
      final page = Paginated.from(map, 'logs', (m) => PointLog.fromJson(m));
      setState(() {
        _logs.addAll(page.items);
        _hasMore = page.hasMore;
        _page += 1;
        _initialLoaded = true;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _logs.clear();
      _page = 1;
      _hasMore = true;
      _initialLoaded = false;
      _error = null;
    });
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('적립금')),
      body: _body(),
    );
  }

  Widget _body() {
    if (!_initialLoaded && _loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    }
    if (!_initialLoaded && _error != null) {
      return ErrorRetry(_error!, _refresh);
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _logs.isEmpty ? 2 : _logs.length + 2,
        separatorBuilder: (_, i) => (i == 0 || _logs.isEmpty) ? const SizedBox.shrink() : const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i == 0) return _balanceCard();
          if (_logs.isEmpty) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: const EmptyState(Icons.savings_outlined, '적립금 내역이 없습니다'),
            );
          }
          if (i == _logs.length + 1) {
            return _loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.navy)),
                  )
                : const SizedBox(height: 8);
          }
          return _logRow(_logs[i - 1]);
        },
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
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
          const Text('보유 적립금', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            won(_balance),
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _logRow(PointLog log) {
    final earn = log.amount >= 0;
    final sign = earn ? '+' : '-';
    final amountColor = earn ? AppColors.success : AppColors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.reason ?? '적립금 변동',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (log.date != null) ...[
                  const SizedBox(height: 4),
                  Text(log.date!, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${comma(log.amount.abs())}원',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: amountColor),
              ),
              const SizedBox(height: 4),
              Text('잔액 ${comma(log.balance)}원', style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
            ],
          ),
        ],
      ),
    );
  }

  int _asInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);
}
