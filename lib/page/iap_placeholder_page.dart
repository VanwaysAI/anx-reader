import 'package:flutter/material.dart';

class IapPlaceholderPage extends StatelessWidget {
  const IapPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anx Reader 高级版计划'),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: IapPlaceholderContent(),
        ),
      ),
    );
  }
}

class IapPlaceholderContent extends StatelessWidget {
  const IapPlaceholderContent({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bodyColor = colorScheme.onSurface.withAlpha(220);
    final secondaryColor = colorScheme.onSurfaceVariant;

    Widget bullet(String text) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(
              Icons.brightness_1,
              size: 8,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: bodyColor,
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withAlpha(40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outlineVariant.withAlpha(80),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anx Reader 高级版计划',
                  style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ) ??
                      TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前功能暂时免费，预计免费使用期持续至 2026 年 2 月 1 日。',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.7,
                    color: bodyColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '未来会接入官方应用内购买（IAP），提供 高级版永久激活，用于支持后续开发与运维成本。',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.7,
                    color: bodyColor,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '上线内购后的 1 周内，计划提供限时优惠：',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    color: bodyColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                bullet('Anx Reader 永久激活高级订阅，将在活动期间优惠至 28 元（人民币）。'),
                const SizedBox(height: 6),
                bullet('具体活动时间和细节会通过官方社交媒体发布，建议关注以免错过。'),
                const SizedBox(height: 22),
                Text(
                  '* 以上价格与活动为当前计划，可能会根据实际情况进行调整，具体以正式上线时的页面说明为准。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
