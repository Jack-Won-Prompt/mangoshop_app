import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';

/// 정렬 옵션 라벨 (카탈로그/검색 공용)
const kSortLabels = <String, String>{
  'new': '신상품순',
  'price_low': '낮은가격순',
  'price_high': '높은가격순',
  'popular': '인기순',
  'name': '이름순',
};

/// 카탈로그 조회 (위젯 공용).
/// data_providers 의 fetchCatalog 는 provider 의 [Ref] 를 요구하지만,
/// 위젯에서는 [WidgetRef] 만 가지므로 동일 로직을 직접 호출한다.
Future<CatalogResult> runCatalog(WidgetRef ref, CatalogQuery q) async {
  final res = await ref.read(apiProvider).get(q.path, query: q.toQuery());
  return CatalogResult.fromJson(res);
}

/// 상품 목록 (카테고리별 / 전체)
class CatalogScreen extends ConsumerStatefulWidget {
  final String? categorySlug;
  final String? title;
  const CatalogScreen({super.key, this.categorySlug, this.title});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _scroll = ScrollController();
  final List<Product> _products = [];
  List<BrandFilter> _brands = [];
  Category? _category;

  String _sort = 'new';
  final Set<int> _selectedBrands = {};
  int? _priceMin, _priceMax;

  int _page = 1;
  int _lastPage = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  CatalogQuery _query(int page) => CatalogQuery(
        categorySlug: widget.categorySlug,
        sort: _sort,
        brandIds: _selectedBrands.toList(),
        priceMin: _priceMin,
        priceMax: _priceMax,
        page: page,
      );

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await runCatalog(ref, _query(1));
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(res.products);
        _brands = res.brands;
        _category = res.category;
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _hasMore = res.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final res = await runCatalog(ref, _query(_page + 1));
      if (!mounted) return;
      setState(() {
        _products.addAll(res.products);
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _hasMore = res.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _applySort(String sort) {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    _load(reset: true);
  }

  Future<void> _openSortSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 8),
            ...kSortLabels.entries.map(
              (e) => ListTile(
                title: Text(e.value, style: TextStyle(fontWeight: _sort == e.key ? FontWeight.w800 : FontWeight.w500)),
                trailing: _sort == e.key ? const Icon(Icons.check, color: AppColors.navy) : null,
                onTap: () => Navigator.pop(context, e.key),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) _applySort(picked);
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        brands: _brands,
        selectedBrands: {..._selectedBrands},
        priceMin: _priceMin,
        priceMax: _priceMax,
      ),
    );
    if (result == null) return;
    setState(() {
      _selectedBrands
        ..clear()
        ..addAll(result.brandIds);
      _priceMin = result.priceMin;
      _priceMax = result.priceMax;
    });
    _load(reset: true);
  }

  String get _appBarTitle => widget.title ?? _category?.name ?? '전체 상품';

  int get _activeFilters => _selectedBrands.length + (_priceMin != null || _priceMax != null ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => context.push('/search')),
        ],
      ),
      body: Column(
        children: [
          _controlBar(),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _controlBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Text(
            '총 ${_products.length}개',
            style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          _controlBtn(
            icon: Icons.tune,
            label: _activeFilters > 0 ? '필터 $_activeFilters' : '필터',
            active: _activeFilters > 0,
            onTap: _openFilterSheet,
          ),
          const SizedBox(width: 8),
          _controlBtn(
            icon: Icons.swap_vert,
            label: kSortLabels[_sort] ?? '정렬',
            onTap: _openSortSheet,
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({required IconData icon, required String label, bool active = false, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppColors.navy : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : AppColors.ink),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const GridShimmer();
    if (_error != null) return ErrorRetry(_error!, () => _load(reset: true));
    if (_products.isEmpty) {
      return const EmptyState(Icons.inventory_2_outlined, '조건에 맞는 상품이 없습니다.');
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.58,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _products.length + (_hasMore ? 2 : 0),
      itemBuilder: (_, i) {
        if (i >= _products.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy)));
        }
        return ProductCard(_products[i]);
      },
    );
  }
}

// ===== 필터 결과 =====
class _FilterResult {
  final Set<int> brandIds;
  final int? priceMin, priceMax;
  _FilterResult(this.brandIds, this.priceMin, this.priceMax);
}

class _FilterSheet extends StatefulWidget {
  final List<BrandFilter> brands;
  final Set<int> selectedBrands;
  final int? priceMin, priceMax;
  const _FilterSheet({
    required this.brands,
    required this.selectedBrands,
    required this.priceMin,
    required this.priceMax,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<int> _selected;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.selectedBrands};
    _minCtrl = TextEditingController(text: widget.priceMin?.toString() ?? '');
    _maxCtrl = TextEditingController(text: widget.priceMax?.toString() ?? '');
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    Navigator.pop(
      context,
      _FilterResult(
        _selected,
        int.tryParse(_minCtrl.text.trim()),
        int.tryParse(_maxCtrl.text.trim()),
      ),
    );
  }

  void _reset() {
    setState(() {
      _selected.clear();
      _minCtrl.clear();
      _maxCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, controller) {
        return Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Text('필터', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  const Text('가격', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '최소', suffixText: '원'),
                        ),
                      ),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('~')),
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '최대', suffixText: '원'),
                        ),
                      ),
                    ],
                  ),
                  if (widget.brands.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('브랜드', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.brands.map((b) {
                        final on = _selected.contains(b.id);
                        return FilterChip(
                          label: Text('${b.name} (${b.count})'),
                          selected: on,
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selected.add(b.id);
                            } else {
                              _selected.remove(b.id);
                            }
                          }),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: on ? Colors.white : AppColors.ink,
                          ),
                          backgroundColor: AppColors.chip,
                          selectedColor: AppColors.navy,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          side: BorderSide.none,
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(onPressed: _reset, child: const Text('초기화')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(onPressed: _apply, child: const Text('적용하기')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
