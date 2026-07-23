import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';
import 'admin_dashboard_screen.dart' show AdminOrderTile;

class AdminOrdersScreen extends ConsumerStatefulWidget {
  /// 대시보드에서 특정 상태로 바로 진입할 때 사용
  final String? initialStatus;
  const AdminOrdersScreen({super.key, this.initialStatus});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 진입 시 전달된 상태 필터를 반영 (build 중 provider 수정 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cur = ref.read(adminOrderQueryProvider);
      if (cur.status != widget.initialStatus) {
        ref.read(adminOrderQueryProvider.notifier).state =
            OrderQuery(status: widget.initialStatus, q: cur.q);
      }
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(adminOrderQueryProvider);
    final async = ref.watch(adminOrdersProvider);

    return Column(
      children: [
        // 검색
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '주문번호 · 받는분 · 입금자명',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: query.q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtl.clear();
                        ref.read(adminOrderQueryProvider.notifier).state = query.copyWith(q: '');
                      },
                    ),
            ),
            onSubmitted: (v) => ref.read(adminOrderQueryProvider.notifier).state =
                query.copyWith(q: v.trim()),
          ),
        ),
        // 상태 필터
        SizedBox(
          height: 44,
          child: async.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (page) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _statusChip(null, '전체', query.status == null),
                ...page.statuses.entries.map(
                  (e) => _statusChip(e.key, e.value, query.status == e.key),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 16),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
            error: (e, _) => ErrorRetry(e, () => ref.invalidate(adminOrdersProvider)),
            data: (page) => page.orders.isEmpty
                ? const EmptyState(Icons.receipt_long_outlined, '조건에 맞는 주문이 없습니다.')
                : RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: () async => ref.invalidate(adminOrdersProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: page.orders.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text('총 ${page.total}건',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
                          );
                        }
                        return AdminOrderTile(page.orders[i - 1]);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String? value, String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          final q = ref.read(adminOrderQueryProvider);
          ref.read(adminOrderQueryProvider.notifier).state =
              value == null ? q.copyWith(clearStatus: true) : q.copyWith(status: value);
        },
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.sub,
        ),
        showCheckmark: false,
      ),
    );
  }
}
