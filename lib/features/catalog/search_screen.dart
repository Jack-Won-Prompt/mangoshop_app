import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';
import 'catalog_screen.dart' show kSortLabels, runCatalog;

/// 최근 검색어 (메모리 보관)
final List<String> _recentSearches = [];

/// 상품 검색 화면
class SearchScreen extends ConsumerStatefulWidget {
  final String? initialKeyword;
  const SearchScreen({super.key, this.initialKeyword});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  final List<Product> _products = [];
  String _keyword = '';
  String _sort = 'new';
  int _page = 1;
  int _lastPage = 1;
  bool _hasMore = false;
  bool _searched = false;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    final k = widget.initialKeyword;
    if (k != null && k.trim().isNotEmpty) {
      _ctrl.text = k;
      _submit(k);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  CatalogQuery _query(int page) => CatalogQuery(keyword: _keyword, sort: _sort, page: page);

  Future<void> _submit(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    _focus.unfocus();
    _recentSearches
      ..remove(q)
      ..insert(0, q);
    if (_recentSearches.length > 10) _recentSearches.removeRange(10, _recentSearches.length);
    setState(() {
      _keyword = q;
      _searched = true;
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
    if (_keyword.isNotEmpty) _submit(_keyword);
  }

  Future<void> _openSortSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 42,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.sub, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autofocus: widget.initialKeyword == null || widget.initialKeyword!.trim().isEmpty,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submit,
                  decoration: const InputDecoration(
                    hintText: '상품명, 브랜드 검색',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _ctrl.clear()),
                  child: const Icon(Icons.cancel, color: AppColors.sub, size: 18),
                ),
            ],
          ),
        ),
      ),
      body: _searched ? _results() : _suggestions(),
    );
  }

  Widget _suggestions() {
    final popular = ref.watch(settingsProvider).maybeWhen(
          data: (s) => s.popularKeywords,
          orElse: () => const <String>[],
        );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(
            children: [
              const Text('최근 검색어', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _recentSearches.clear()),
                child: const Text('전체삭제', style: TextStyle(color: AppColors.sub, fontSize: 12.5)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches
                .map((k) => _keywordChip(k, onDelete: () => setState(() => _recentSearches.remove(k))))
                .toList(),
          ),
          const SizedBox(height: 28),
        ],
        if (popular.isNotEmpty) ...[
          const Text('인기 검색어', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: popular.map((k) => _keywordChip(k)).toList(),
          ),
        ],
        if (popular.isEmpty && _recentSearches.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: EmptyState(Icons.search, '찾으시는 상품을 검색해보세요.'),
          ),
      ],
    );
  }

  Widget _keywordChip(String k, {VoidCallback? onDelete}) {
    return GestureDetector(
      onTap: () {
        _ctrl.text = k;
        _submit(k);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.chip,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(k, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (onDelete != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.close, size: 15, color: AppColors.sub),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _results() {
    if (_loading) return const GridShimmer();
    if (_error != null) return ErrorRetry(_error!, () => _submit(_keyword));
    if (_products.isEmpty) {
      return EmptyState(Icons.search_off, "'$_keyword' 검색 결과가 없습니다.");
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Text('총 ${_products.length}개', style: const TextStyle(fontSize: 13, color: AppColors.sub, fontWeight: FontWeight.w600)),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _openSortSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_vert, size: 16, color: AppColors.ink),
                      const SizedBox(width: 5),
                      Text(kSortLabels[_sort] ?? '정렬', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
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
          ),
        ),
      ],
    );
  }
}
