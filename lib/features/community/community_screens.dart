import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

/// HTML 문자열에서 태그를 제거해 읽기 좋은 평문으로 변환.
String stripHtml(String? s) {
  if (s == null || s.isEmpty) return '';
  var out = s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  // 과도한 빈 줄 정리
  out = out.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return out.trim();
}

// ============================================================
// 공지사항
// ============================================================

/// 공지사항 목록 — 무한 스크롤
class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  final _scroll = ScrollController();
  final List<NoticeItem> _items = [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  bool _initialLoad = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      if (!_loading && _page < _lastPage) _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiProvider).get('/community/notices', query: {'page': _page});
      final p = Paginated.from(res, 'notices', (m) => NoticeItem.fromJson(m));
      setState(() {
        _items.addAll(p.items);
        _lastPage = p.lastPage;
        _page++;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoad = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 1;
      _lastPage = 1;
      _initialLoad = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoad) return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    if (_error != null && _items.isEmpty) return ErrorRetry(_error!, _refresh);
    if (_items.isEmpty) {
      return const EmptyState(Icons.campaign_outlined, '등록된 공지가 없습니다.');
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_page <= _lastPage && _loading ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.navy)),
            );
          }
          return _noticeTile(_items[i]);
        },
      ),
    );
  }

  Widget _noticeTile(NoticeItem n) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _NoticeDetailScreen(id: n.id, title: n.title)),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (n.pinned) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('공지',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.sub, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule, size: 13, color: AppColors.sub),
                const SizedBox(width: 4),
                Text(n.date ?? '', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                const SizedBox(width: 12),
                const Icon(Icons.visibility_outlined, size: 13, color: AppColors.sub),
                const SizedBox(width: 4),
                Text(comma(n.views), style: const TextStyle(fontSize: 12, color: AppColors.sub)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 공지 상세 — body 를 별도 조회
class _NoticeDetailScreen extends ConsumerStatefulWidget {
  final int id;
  final String title;
  const _NoticeDetailScreen({required this.id, required this.title});

  @override
  ConsumerState<_NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<_NoticeDetailScreen> {
  NoticeItem? _notice;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).get('/community/notices/${widget.id}');
      setState(() => _notice = NoticeItem.fromJson(res['notice']));
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    if (_error != null) return ErrorRetry(_error!, _load);
    final n = _notice;
    if (n == null) return const EmptyState(Icons.campaign_outlined, '공지를 찾을 수 없습니다.');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(n.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.35)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(n.date ?? '', style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
              const SizedBox(width: 12),
              const Icon(Icons.visibility_outlined, size: 13, color: AppColors.sub),
              const SizedBox(width: 4),
              Text(comma(n.views), style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            stripHtml(n.body).isEmpty ? '내용이 없습니다.' : stripHtml(n.body),
            style: const TextStyle(fontSize: 15, height: 1.7, color: AppColors.ink),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============================================================
// 상품후기
// ============================================================

/// 상품후기 목록 — 무한 스크롤
class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key});

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final _scroll = ScrollController();
  final List<Map> _items = [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  bool _initialLoad = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      if (!_loading && _page < _lastPage) _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiProvider).get('/community/reviews', query: {'page': _page});
      final list = ((res['reviews'] as List?) ?? []).map((e) => e as Map).toList();
      final meta = (res['meta'] as Map?) ?? {};
      setState(() {
        _items.addAll(list);
        _lastPage = _asInt(meta['last_page'] ?? 1);
        _page++;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoad = false;
        });
      }
    }
  }

  int _asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 1;

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 1;
      _lastPage = 1;
      _initialLoad = true;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상품후기')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoad) return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    if (_error != null && _items.isEmpty) return ErrorRetry(_error!, _refresh);
    if (_items.isEmpty) {
      return const EmptyState(Icons.rate_review_outlined, '등록된 후기가 없습니다.');
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_page <= _lastPage && _loading ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.navy)),
            );
          }
          return _reviewTile(_items[i]);
        },
      ),
    );
  }

  Widget _reviewTile(Map r) {
    final review = Review.fromJson(r);
    final product = r['product'] is Map ? r['product'] as Map : null;
    final slug = product?['slug']?.toString();
    final pName = product?['name']?.toString() ?? '';
    final thumb = product?['thumbnail']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상품 헤더
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: slug == null ? null : () => context.push('/product/$slug'),
            child: Row(
              children: [
                NetImage(thumb, width: 52, height: 52, radius: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ),
                if (slug != null) const Icon(Icons.chevron_right, color: AppColors.sub, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _stars(review.rating),
          if (review.title != null && review.title!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.title!,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          ],
          if (review.body != null && review.body!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.body!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, color: AppColors.sub, height: 1.5),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(review.author, style: const TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(review.date ?? '', style: const TextStyle(fontSize: 12, color: AppColors.sub)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stars(int rating) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
          color: i < rating ? AppColors.warn : AppColors.line,
        );
      }),
    );
  }
}

// ============================================================
// 자주 묻는 질문 (FAQ)
// ============================================================

/// FAQ 데이터 조회 프로바이더 (그룹 목록)
final _faqProvider = FutureProvider.autoDispose<List<Map>>((ref) async {
  final res = await ref.read(apiProvider).get('/community/faq');
  return ((res['groups'] as List?) ?? []).map((e) => e as Map).toList();
});

/// FAQ — 카테고리별 섹션 + ExpansionTile
class FaqScreen extends ConsumerWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_faqProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('자주 묻는 질문')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.navy)),
        error: (e, _) => ErrorRetry(e, () => ref.invalidate(_faqProvider)),
        data: (groups) {
          if (groups.isEmpty) {
            return const EmptyState(Icons.help_outline, '등록된 FAQ가 없습니다.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final g in groups) ..._group(context, g),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _group(BuildContext context, Map g) {
    final category = g['category']?.toString() ?? '';
    final items = ((g['items'] as List?) ?? []).map((e) => e as Map).toList();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 8),
            Text(category, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _faqTile(context, items[i]),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _faqTile(BuildContext context, Map item) {
    final q = item['question']?.toString() ?? '';
    final a = stripHtml(item['answer']?.toString());
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: const Text('Q',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.navy)),
        title: Text(q, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.35)),
        iconColor: AppColors.navy,
        collapsedIconColor: AppColors.sub,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              a.isEmpty ? '내용이 없습니다.' : a,
              style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 1:1 문의 (QnA)
// ============================================================

/// 1:1 문의 목록 — 무한 스크롤
class QnaScreen extends ConsumerStatefulWidget {
  const QnaScreen({super.key});

  @override
  ConsumerState<QnaScreen> createState() => _QnaScreenState();
}

class _QnaScreenState extends ConsumerState<QnaScreen> {
  final _scroll = ScrollController();
  final List<Map> _items = [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  bool _initialLoad = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      if (!_loading && _page < _lastPage) _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiProvider).get('/community/qna', query: {'page': _page});
      final list = ((res['inquiries'] as List?) ?? []).map((e) => e as Map).toList();
      final meta = (res['meta'] as Map?) ?? {};
      setState(() {
        _items.addAll(list);
        _lastPage = _asInt(meta['last_page'] ?? 1);
        _page++;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _initialLoad = false;
        });
      }
    }
  }

  int _asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 1;

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 1;
      _lastPage = 1;
      _initialLoad = true;
    });
    await _load();
  }

  String _typeLabel(String? type) => switch (type) {
        'quote' => '견적문의',
        'request' => '상품요청',
        _ => '1:1문의',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1:1 문의')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/community/inquiry');
          if (mounted) _refresh();
        },
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('문의하기', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initialLoad) return const Center(child: CircularProgressIndicator(color: AppColors.navy));
    if (_error != null && _items.isEmpty) return ErrorRetry(_error!, _refresh);
    if (_items.isEmpty) {
      return const EmptyState(Icons.contact_support_outlined, '등록된 문의가 없습니다.');
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _items.length + (_page <= _lastPage && _loading ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.navy)),
            );
          }
          return _QnaTile(item: _items[i], typeLabel: _typeLabel);
        },
      ),
    );
  }
}

class _QnaTile extends StatefulWidget {
  final Map item;
  final String Function(String?) typeLabel;
  const _QnaTile({required this.item, required this.typeLabel});

  @override
  State<_QnaTile> createState() => _QnaTileState();
}

class _QnaTileState extends State<_QnaTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.item;
    final type = m['type']?.toString();
    final subject = m['subject']?.toString() ?? '';
    final status = m['status']?.toString() ?? 'pending';
    final answered = status == 'answered';
    final isSecret = m['is_secret'] == true || m['is_secret'] == 1;
    final isMine = m['is_mine'] == true || m['is_mine'] == 1;
    final locked = isSecret && !isMine;
    final body = m['body']?.toString();
    final answer = m['answer']?.toString();
    final name = m['name']?.toString() ?? '';
    final date = m['date']?.toString() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.chip,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(widget.typeLabel(type),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.navy)),
                      ),
                      const Spacer(),
                      _statusChip(answered),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (isSecret) ...[
                        const Text('🔒', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3),
                        ),
                      ),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.sub),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(date, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: locked
                  ? const Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: AppColors.sub),
                        SizedBox(width: 6),
                        Text('비밀글입니다.', style: TextStyle(color: AppColors.sub, fontSize: 14)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (body == null || body.isEmpty) ? '내용이 없습니다.' : body,
                          style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.ink),
                        ),
                        if (answered && answer != null && answer.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.support_agent, size: 16, color: AppColors.navy),
                                    SizedBox(width: 6),
                                    Text('답변', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 13)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(answer, style: const TextStyle(fontSize: 14, height: 1.6)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(bool answered) {
    final bg = answered ? AppColors.success.withValues(alpha: 0.12) : AppColors.warn.withValues(alpha: 0.14);
    final fg = answered ? AppColors.success : AppColors.warn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        answered ? '답변완료' : '답변대기',
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
