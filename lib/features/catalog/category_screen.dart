import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';

/// 카테고리 탭
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  void _open(BuildContext context, Category c) {
    context.push('/category/${c.slug}?name=${Uri.encodeComponent(c.name)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('카테고리')),
      body: Column(
        children: [
          // 검색바
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: AppColors.sub, size: 22),
                    SizedBox(width: 8),
                    Text('찾으시는 상품을 검색해보세요', style: TextStyle(color: AppColors.sub, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: cats.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.navy)),
              error: (e, _) => ErrorRetry(e, () => ref.invalidate(categoriesProvider)),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(Icons.category_outlined, '등록된 카테고리가 없습니다.');
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _CategoryTile(category: list[i], onOpen: _open),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final void Function(BuildContext, Category) onOpen;
  const _CategoryTile({required this.category, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final children = category.children;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: children.isEmpty
          ? ListTile(
              leading: _icon(),
              title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.sub),
              onTap: () => onOpen(context, category),
            )
          : Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: _icon(),
                title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                childrenPadding: const EdgeInsets.only(bottom: 6),
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  // 전체 보기
                  _ChildRow(
                    label: '${category.name} 전체',
                    bold: true,
                    onTap: () => onOpen(context, category),
                  ),
                  ...children.map((sub) {
                    if (sub.children.isEmpty) {
                      return _ChildRow(label: sub.name, onTap: () => onOpen(context, sub));
                    }
                    return _SubGroup(sub: sub, onOpen: onOpen);
                  }),
                ],
              ),
            ),
    );
  }

  Widget _icon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: CategoryIcon(category.icon, size: 20),
    );
  }
}

class _SubGroup extends StatelessWidget {
  final Category sub;
  final void Function(BuildContext, Category) onOpen;
  const _SubGroup({required this.sub, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChildRow(label: sub.name, bold: true, onTap: () => onOpen(context, sub)),
        ...sub.children.map(
          (g) => _ChildRow(label: g.name, indent: true, onTap: () => onOpen(context, g)),
        ),
      ],
    );
  }
}

class _ChildRow extends StatelessWidget {
  final String label;
  final bool bold;
  final bool indent;
  final VoidCallback onTap;
  const _ChildRow({required this.label, required this.onTap, this.bold = false, this.indent = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent ? 40 : 24, 11, 16, 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: bold ? AppColors.navy : AppColors.ink,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 13, color: AppColors.sub),
          ],
        ),
      ),
    );
  }
}
