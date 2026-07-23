import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/admin_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/common.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  static const _filters = [
    ('pending', '승인대기'),
    ('wholesale', '도매'),
    ('retail', '소매'),
    (null, '전체'),
  ];

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminUserFilterProvider);
    final search = ref.watch(adminUserSearchProvider);
    final async = ref.watch(adminUsersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '이름 · 이메일 · 상호',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              suffixIcon: search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtl.clear();
                        ref.read(adminUserSearchProvider.notifier).state = '';
                      },
                    ),
            ),
            onSubmitted: (v) =>
                ref.read(adminUserSearchProvider.notifier).state = v.trim(),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: _filters
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.$2),
                        selected: filter == f.$1,
                        onSelected: (_) =>
                            ref.read(adminUserFilterProvider.notifier).state = f.$1,
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
        const Divider(height: 16),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.brand)),
            error: (e, _) => ErrorRetry(e, () => ref.invalidate(adminUsersProvider)),
            data: (page) => page.users.isEmpty
                ? EmptyState(
                    Icons.how_to_reg_outlined,
                    filter == 'pending' ? '승인 대기 중인 회원이 없습니다.' : '조건에 맞는 회원이 없습니다.',
                  )
                : RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: () async => ref.invalidate(adminUsersProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: page.users.length + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text('총 ${page.total}명',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
                          );
                        }
                        return _UserTile(page.users[i - 1]);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final AdminUserRow user;
  const _UserTile(this.user);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/admin/users/${user.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: user.isPending ? AppColors.warn.withValues(alpha: 0.5) : AppColors.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    UserStatusChip(user),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
                  if ((user.companyName ?? '').isNotEmpty)
                    Text('${user.companyName}${user.bizNo != null ? " · ${user.bizNo}" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.sub)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.line),
          ],
        ),
      ),
    );
  }
}

/// 회원 상태 배지 (승인/대기/반려/소매)
class UserStatusChip extends StatelessWidget {
  final AdminUserRow user;
  const UserStatusChip(this.user, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = switch (user.bizStatus) {
      'approved' => AppColors.leaf,
      'pending' => AppColors.warn,
      'rejected' => AppColors.red,
      _ => AppColors.sub,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(user.statusLabel,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c)),
    );
  }
}
