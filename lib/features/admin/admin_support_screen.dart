import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';

/// 문의 답변 + 후기 노출관리를 한 탭에서 처리한다.
class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.sub,
          indicatorColor: AppColors.brand,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          tabs: const [Tab(text: '문의'), Tab(text: '후기')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [_InquiryTab(), _ReviewTab()],
          ),
        ),
      ],
    );
  }
}

// ===================== 문의 =====================

class _InquiryTab extends ConsumerWidget {
  const _InquiryTab();

  static const _filters = [('pending', '미답변'), ('answered', '답변완료'), (null, '전체')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(adminInquiryStatusProvider);
    final async = ref.watch(adminInquiriesProvider);

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: _filters
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: status == f.$1,
                        onSelected: (_) =>
                            ref.read(adminInquiryStatusProvider.notifier).state = f.$1,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: status == f.$1 ? Colors.white : AppColors.sub,
                        ),
                        showCheckmark: false,
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
            error: (e, _) => ErrorRetry(e, () => ref.invalidate(adminInquiriesProvider)),
            data: (page) => page.inquiries.isEmpty
                ? EmptyState(Icons.forum_outlined,
                    status == 'pending' ? '미답변 문의가 없습니다.' : '문의가 없습니다.')
                : RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: () async => ref.invalidate(adminInquiriesProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: page.inquiries.length,
                      itemBuilder: (_, i) => _InquiryTile(page.inquiries[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _InquiryTile extends ConsumerWidget {
  final AdminInquiry inquiry;
  const _InquiryTile(this.inquiry);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _chip(inquiry.typeLabel, AppColors.cool),
            const SizedBox(width: 6),
            _chip(inquiry.isAnswered ? '답변완료' : '미답변',
                inquiry.isAnswered ? AppColors.leaf : AppColors.warn),
            if (inquiry.isSecret) ...[
              const SizedBox(width: 6),
              const Icon(Icons.lock_outline, size: 13, color: AppColors.sub),
            ],
            const Spacer(),
            Text(inquiry.createdAt ?? '',
                style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
          ]),
          const SizedBox(height: 8),
          Text(inquiry.subject ?? '(제목 없음)',
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(inquiry.body ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4)),
          const SizedBox(height: 6),
          Text(
            [inquiry.name, inquiry.phone, inquiry.email]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.sub),
          ),
          if (inquiry.isAnswered && (inquiry.answer ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.leafSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('답변 · ${inquiry.answeredAt ?? ''}',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.leaf)),
                  const SizedBox(height: 4),
                  Text(inquiry.answer!,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _answer(context, ref),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
              child: Text(inquiry.isAnswered ? '답변 수정' : '답변하기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
      );

  Future<void> _answer(BuildContext context, WidgetRef ref) async {
    final ctl = TextEditingController(text: inquiry.answer ?? '');

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(inquiry.subject ?? '문의 답변',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: ctl,
                  maxLines: 6,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '답변 내용을 입력하세요.'),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => Navigator.pop(sheetCtx, true),
                  child: const Text('답변 등록'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final answer = ctl.text.trim();
    ctl.dispose();
    if (submitted != true || !context.mounted) return;
    if (answer.isEmpty) {
      toast(context, '답변 내용을 입력해주세요.');
      return;
    }

    try {
      final msg = await ref.read(adminActionsProvider).answerInquiry(inquiry.id, answer);
      if (context.mounted) toast(context, msg);
    } catch (e) {
      if (context.mounted) {
        toast(context, e is ApiException ? e.firstError : '답변 등록에 실패했습니다.');
      }
    }
  }
}

// ===================== 후기 =====================

class _ReviewTab extends ConsumerWidget {
  const _ReviewTab();

  static const _filters = [(null, '전체'), ('visible', '노출'), ('hidden', '숨김')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(adminReviewFilterProvider);
    final async = ref.watch(adminReviewsProvider);

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: _filters
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: filter == f.$1,
                        onSelected: (_) =>
                            ref.read(adminReviewFilterProvider.notifier).state = f.$1,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: filter == f.$1 ? Colors.white : AppColors.sub,
                        ),
                        showCheckmark: false,
                      ),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
            error: (e, _) => ErrorRetry(e, () => ref.invalidate(adminReviewsProvider)),
            data: (list) => list.isEmpty
                ? const EmptyState(Icons.rate_review_outlined, '후기가 없습니다.')
                : RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: () async => ref.invalidate(adminReviewsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _ReviewTile(list[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReviewTile extends ConsumerWidget {
  final AdminReview review;
  const _ReviewTile(this.review);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: review.isHidden ? AppColors.bg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ...List.generate(
              5,
              (i) => Icon(
                i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 15,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 6),
            if (review.isHidden)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sub.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text('숨김',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.sub)),
              ),
            const Spacer(),
            Text(review.date ?? '',
                style: const TextStyle(fontSize: 11.5, color: AppColors.sub)),
          ]),
          const SizedBox(height: 8),
          if ((review.productName ?? '').isNotEmpty)
            Text(review.productName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w700)),
          Text(review.title ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(review.body ?? '',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4)),
          const SizedBox(height: 6),
          Text(review.author, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _toggle(context, ref),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                child: Text(review.isHidden ? '노출하기' : '숨기기'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _delete(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red),
                minimumSize: const Size(56, 42),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.delete_outline, size: 20),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      final msg = await ref.read(adminActionsProvider).toggleReview(review.id);
      if (context.mounted) toast(context, msg);
    } catch (e) {
      if (context.mounted) {
        toast(context, e is ApiException ? e.firstError : '처리에 실패했습니다.');
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('후기를 삭제할까요?'),
        content: const Text('삭제한 후기는 되돌릴 수 없습니다.\n숨기기를 먼저 고려해보세요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('닫기')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      final msg = await ref.read(adminActionsProvider).deleteReview(review.id);
      if (context.mounted) toast(context, msg);
    } catch (e) {
      if (context.mounted) {
        toast(context, e is ApiException ? e.firstError : '삭제에 실패했습니다.');
      }
    }
  }
}
