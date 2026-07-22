import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// 주문 상태별 칩 색상
Color orderStatusColor(String status) {
  switch (status) {
    case 'pending':
      return AppColors.warn;
    case 'paid':
    case 'preparing':
      return AppColors.navy;
    case 'shipped':
      return const Color(0xFF2563EB);
    case 'done':
    case 'completed':
      return AppColors.success;
    case 'cancelled':
    case 'canceled':
      return AppColors.sub;
    default:
      return AppColors.sub;
  }
}

Widget orderStatusChip(OrderModel order) {
  final c = orderStatusColor(order.status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(order.statusLabel,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: c)),
  );
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scrollCtl = ScrollController();
  final List<OrderModel> _orders = [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scrollCtl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollCtl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtl.position.pixels >=
            _scrollCtl.position.maxScrollExtent - 300 &&
        !_loading &&
        _page < _lastPage) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final page = reset ? 1 : _page + 1;
      final res =
          await ref.read(apiProvider).get('/orders', query: {'page': page});
      final paged = Paginated<OrderModel>.from(
          res as Map, 'orders', (e) => OrderModel.fromJson(e));
      setState(() {
        if (reset) _orders.clear();
        _orders.addAll(paged.items);
        _page = paged.currentPage;
        _lastPage = paged.lastPage;
        _loading = false;
        _initialLoaded = true;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _initialLoaded = true;
        if (reset) _error = e is ApiException ? e.firstError : '주문 내역을 불러오지 못했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주문내역')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_initialLoaded) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    }
    if (_error != null && _orders.isEmpty) {
      return ErrorRetry(_error!, () => _load(reset: true));
    }
    if (_orders.isEmpty) {
      return RefreshIndicator(
        color: AppColors.navy,
        onRefresh: () => _load(reset: true),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            const EmptyState(
                Icons.receipt_long_outlined, '주문 내역이 없습니다'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.navy,
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scrollCtl,
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length + (_page < _lastPage ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= _orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.navy)),
            );
          }
          return _OrderCard(order: _orders[i]);
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/orders/${order.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                orderStatusChip(order),
                const Spacer(),
                if (order.createdAt != null)
                  Text(order.createdAt!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.sub)),
              ],
            ),
            const SizedBox(height: 12),
            Text('주문번호 ${order.orderNo}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.itemCount != null
                      ? '상품 ${order.itemCount}건'
                      : '상품 ${order.items.length}건',
                  style: const TextStyle(fontSize: 13, color: AppColors.sub),
                ),
                Text(won(order.total),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
