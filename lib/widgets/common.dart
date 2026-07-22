import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/theme.dart';

/// 상품/배너 이미지 — 로딩 셔머 + 폴백 아이콘
class NetImage extends StatelessWidget {
  final String? url;
  final double? width, height;
  final BoxFit fit;
  final double radius;
  const NetImage(this.url, {super.key, this.width, this.height, this.fit = BoxFit.cover, this.radius = 0});

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (url == null || url!.isEmpty) {
      child = Container(
        width: width,
        height: height,
        color: AppColors.chip,
        child: const Icon(Icons.eco_outlined, color: AppColors.line, size: 34),
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: url!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, _) => Shimmer.fromColors(
          baseColor: const Color(0xFFEDEFF3),
          highlightColor: const Color(0xFFF7F8FA),
          child: Container(width: width, height: height, color: Colors.white),
        ),
        errorWidget: (_, _, _) => Container(
          width: width,
          height: height,
          color: AppColors.chip,
          child: const Icon(Icons.image_not_supported_outlined, color: AppColors.line, size: 30),
        ),
      );
    }
    return radius > 0 ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: child) : child;
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onMore;
  const SectionHeader(this.title, {super.key, this.subtitle, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              if (subtitle != null)
                Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.sub)),
            ],
          ),
          const Spacer(),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              style: TextButton.styleFrom(foregroundColor: AppColors.sub, padding: EdgeInsets.zero),
              child: const Row(children: [Text('더보기', style: TextStyle(fontSize: 13)), Icon(Icons.chevron_right, size: 18)]),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const EmptyState(this.icon, this.message, {super.key, this.action});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.line),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.sub, fontSize: 15)),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorRetry(this.error, this.onRetry, {super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 52, color: AppColors.line),
            const SizedBox(height: 14),
            Text('$error', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.sub)),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 46)),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 망고샵 서버의 `category.icon` 은 이모지 문자열(🥭 🥑 🍍 …)이다.
/// 하위 카테고리는 icon 이 null 이므로 기본 아이콘으로 대체한다.
class CategoryIcon extends StatelessWidget {
  final String? icon;
  final double size;
  final Color? fallbackColor;
  const CategoryIcon(this.icon, {super.key, this.size = 24, this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    final e = icon?.trim();
    if (e != null && e.isNotEmpty) {
      // 이모지는 폰트로 렌더 — 아이콘보다 살짝 작게 잡아야 시각 크기가 맞는다
      return Text(e, style: TextStyle(fontSize: size * 0.86, height: 1.1));
    }
    return Icon(Icons.eco_outlined, size: size, color: fallbackColor ?? AppColors.leaf);
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

/// 로딩 그리드 셔머
class GridShimmer extends StatelessWidget {
  final int count;
  const GridShimmer({super.key, this.count = 6});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.58, crossAxisSpacing: 12, mainAxisSpacing: 16),
      itemCount: count,
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: const Color(0xFFEDEFF3),
        highlightColor: const Color(0xFFF7F8FA),
        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
      ),
    );
  }
}
