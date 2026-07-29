import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_update.dart';
import '../core/theme.dart';

/// 앱 전역 업데이트 알림 게이트.
///
/// MaterialApp.builder 에서 모든 화면 위에 씌워, 현재 화면과 무관하게
/// 업데이트 안내를 노출한다.
/// - 선택 업데이트: 상단 배너(닫기 가능, 세션 내 유지)
/// - 필수 업데이트: 전체 화면 차단(닫기 불가)
/// 앱 시작 시 1회, 이후 포그라운드 복귀(resume)마다 재확인한다.
class UpdateGate extends ConsumerStatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  ConsumerState<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends ConsumerState<UpdateGate> with WidgetsBindingObserver {
  bool _bannerDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드에서 새 버전이 배포됐을 수 있으므로 복귀 시 재확인
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(appUpdateProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = ref.watch(appUpdateProvider).valueOrNull ?? AppUpdate.none;

    return Stack(
      children: [
        widget.child,
        if (update.level == UpdateLevel.optional && !_bannerDismissed)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _UpdateBanner(
              update: update,
              onClose: () => setState(() => _bannerDismissed = true),
            ),
          ),
        if (update.level == UpdateLevel.forced)
          Positioned.fill(child: _ForcedUpdateScreen(update: update)),
      ],
    );
  }
}

/// 선택 업데이트 — 상단 배너
class _UpdateBanner extends StatelessWidget {
  final AppUpdate update;
  final VoidCallback onClose;
  const _UpdateBanner({required this.update, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              const Icon(Icons.system_update, color: AppColors.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '새 버전 출시${update.latestVersion != null ? ' (v${update.latestVersion})' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 1),
                    const Text('업데이트하고 새 기능을 만나보세요',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: update.openStore,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  backgroundColor: AppColors.accent,
                  minimumSize: const Size(0, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                child: const Text('업데이트', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 필수 업데이트 — 전체 화면 차단
class _ForcedUpdateScreen extends StatelessWidget {
  final AppUpdate update;
  const _ForcedUpdateScreen({required this.update});

  @override
  Widget build(BuildContext context) {
    // 뒤로가기로 빠져나가지 못하도록 차단
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.system_update, size: 72, color: AppColors.brand),
                const SizedBox(height: 22),
                const Text('업데이트가 필요합니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text(
                  (update.message != null && update.message!.trim().isNotEmpty)
                      ? update.message!.replaceAll(r'\n', '\n')
                      : '원활한 이용을 위해 최신 버전으로 업데이트해 주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5, color: AppColors.sub, height: 1.5),
                ),
                if (update.latestVersion != null) ...[
                  const SizedBox(height: 10),
                  Text('최신 버전 v${update.latestVersion}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.sub)),
                ],
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: update.openStore,
                  icon: const Icon(Icons.store_mall_directory_outlined, size: 20),
                  label: const Text('지금 업데이트'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
