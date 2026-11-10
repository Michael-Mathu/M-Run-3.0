import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';

/// Circular level indicator with the level number in the middle and a brand
/// gradient progress arc.
class LevelRing extends ConsumerWidget {
  final int level;
  final double progress; // 0..1
  final double size;
  final Color color;

  const LevelRing({
    super.key,
    required this.level,
    required this.progress,
    this.size = 64,
    this.color = AppTheme.brand,
  });

  static const double _stroke = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final grad = tokens.brandGradient;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) => SweepGradient(
              colors: [grad.colors.first, tokens.flagGreen, grad.colors.last],
              startAngle: -math.pi / 2,
              endAngle: 3 * math.pi / 2,
            ).createShader(rect),
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: _stroke,
              backgroundColor: cs.onSurface.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          // The label always fits inside the ring: tight line heights, and
          // scaled down within the stroke (it used to overflow onto the arc).
          Padding(
            padding: EdgeInsets.all(_stroke + size * 0.12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ref.tr('lv'),
                      style: text.labelSmall!.copyWith(
                          color: cs.onSurfaceVariant, letterSpacing: 0.5, height: 1.0)),
                  Text(level.toString(),
                      style: text.titleLarge!.copyWith(
                          color: cs.onSurface, fontWeight: FontWeight.w800, height: 1.05)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal XP bar toward the next level.
class XpBar extends StatelessWidget {
  final int xpIntoLevel;
  final int xpForNextLevel;
  final double progress;
  final Color color;

  const XpBar({
    super.key,
    required this.xpIntoLevel,
    required this.xpForNextLevel,
    required this.progress,
    this.color = AppTheme.brand,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.rFull),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 8,
            backgroundColor: cs.onSurface.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: AppTheme.s6),
        Text(
          '$xpIntoLevel / $xpForNextLevel XP',
          style: text.labelSmall!.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}


/// Profile photo wrapped in a level-progress ring with a level badge on its
/// edge (the Apple Fitness / Game Center pattern). Replaces the separate
/// "Lv" ring that sat beside the name and collided with it.
class LevelAvatar extends StatelessWidget {
  final Widget avatar; // a CircleAvatar sized to [avatarRadius]
  final double avatarRadius;
  final int level;
  final double progress; // 0..1

  const LevelAvatar({
    super.key,
    required this.avatar,
    required this.level,
    required this.progress,
    this.avatarRadius = 34,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final grad = tokens.brandGradient;
    const stroke = 3.5;
    const gap = 3.0;
    final size = (avatarRadius + gap + stroke) * 2;
    final surface = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      width: size,
      height: size + 6, // room for the badge overhang
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: ShaderMask(
              shaderCallback: (rect) => SweepGradient(
                colors: [grad.colors.first, tokens.flagGreen, grad.colors.last],
                startAngle: -math.pi / 2,
                endAngle: 3 * math.pi / 2,
              ).createShader(rect),
              child: CircularProgressIndicator(
                value: progress.clamp(0, 1),
                strokeWidth: stroke,
                strokeCap: StrokeCap.round,
                backgroundColor: cs.onSurface.withValues(alpha: 0.10),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          Positioned(
            top: gap + stroke,
            child: avatar,
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(AppTheme.rFull),
                border: Border.all(color: surface, width: 2),
              ),
              child: Text(
                '$level',
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
