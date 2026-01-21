import 'package:flutter/material.dart';
import '../utils/theme.dart';

class SkeletonBox extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline.withAlpha(30);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.45, end: 0.9),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: color,
              borderRadius: borderRadius ??
                  BorderRadius.circular(AppTheme.radiusM),
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.count = 4,
    this.itemHeight = 92,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
          child: SkeletonBox(height: itemHeight),
        ),
      ),
    );
  }
}

class SkeletonSection extends StatelessWidget {
  final double titleWidth;
  final double contentHeight;

  const SkeletonSection({
    super.key,
    this.titleWidth = 160,
    this.contentHeight = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(
          height: 18,
          width: titleWidth,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: AppTheme.spacingM),
        SkeletonBox(height: contentHeight),
      ],
    );
  }
}
