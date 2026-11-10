import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/core/utils/format.dart';
import 'package:mwendo_app/core/utils/haptics.dart';
import 'package:mwendo_app/features/learn/data/beat_legends.dart';
import 'package:mwendo_app/features/learn/data/legends.dart';
import 'package:mwendo_app/features/legends/legend_photos.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// Rich two-stop gradient derived from a legend's accent (lit top-left,
/// deep bottom-right) — the "artwork" for a legend everywhere in the app.
LinearGradient legendGradient(Legend l) {
  final a = legendAccent(l);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(a, Colors.white, 0.12)!,
      Color.lerp(a, Colors.black, 0.55)!,
    ],
  );
}

/// Circular legend portrait: the legend's photo (bundled, Wikimedia Commons,
/// see [legendPhotoCredits]) on their artwork gradient, or their emoji when
/// no freely licensed photo exists.
class LegendAvatar extends StatelessWidget {
  final Legend legend;
  final double size;
  final bool ring;
  const LegendAvatar({super.key, required this.legend, this.size = 44, this.ring = false});

  @override
  Widget build(BuildContext context) {
    final asset = legendPhotoAsset(legend);
    final emoji = Text(legend.emoji, style: TextStyle(fontSize: size * 0.48, height: 1));
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: legendGradient(legend)),
      foregroundDecoration: ring
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: size / 28),
            )
          : null,
      child: asset == null
          ? emoji
          : Image.asset(
              asset,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => emoji,
            ),
    );
  }
}

/// One legend in an inset grouped list: portrait, name, discipline · country,
/// flag and chevron.
class LegendRow extends StatelessWidget {
  final Legend legend;
  final AppLocale locale;
  const LegendRow({super.key, required this.legend, required this.locale});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${legend.name}, ${lt(legend.discipline, locale)}, ${lt(legend.country, locale)}',
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 1,
        onTap: () {
          Haptics.selection();
          context.push('/legends/${legend.slug}');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s10),
          child: Row(
            children: [
              LegendAvatar(legend: legend, size: 46),
              const SizedBox(width: AppTheme.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      legend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyFont(size: 17, weight: FontWeight.w600, color: cs.onSurface)
                          .copyWith(letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lt(legend.discipline, locale)} · ${lt(legend.country, locale)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyFont(size: 15, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.s8),
              Text(legend.flag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: AppTheme.s8),
              Icon(CupertinoIcons.chevron_right, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ghost race "tile" for horizontal carousels: legend artwork on top,
/// distance + target time below.
class GhostRaceCard extends StatelessWidget {
  final GhostPace ghost;
  final double width;
  final String? userPbLabel;
  const GhostRaceCard({super.key, required this.ghost, this.width = 164, this.userPbLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = ghost.legend;
    return Semantics(
      button: true,
      label: '${l.name}, ${ghost.distanceLabel}, ${formatDuration(ghost.totalSeconds * 1000)}',
      excludeSemantics: true,
      child: Pressable(
        onTap: () {
          Haptics.light();
          context.push('/beat/${ghost.id}');
        },
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: legendGradient(l),
                    borderRadius: BorderRadius.circular(AppTheme.r16),
                  ),
                  padding: const EdgeInsets.all(AppTheme.s12),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: _GlassPill(text: ghost.distanceLabel),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(l.flag, style: const TextStyle(fontSize: 18)),
                      ),
                      Align(
                        alignment: const Alignment(0, -0.1),
                        child: LegendAvatar(legend: l, size: width * 0.46, ring: true),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          formatDuration(ghost.totalSeconds * 1000),
                          style: AppTheme.displayFont(size: 26, weight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.s8),
              Text(
                l.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyFont(size: 15, weight: FontWeight.w600, color: cs.onSurface),
              ),
              Text(
                userPbLabel ?? '${formatPace(ghost.avgPaceMinPerKm)} /km',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyFont(size: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;
  const _GlassPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppTheme.rFull),
      ),
      child: Text(
        text,
        style: AppTheme.bodyFont(size: 12, weight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// White-on-glass capsule button used on gradient artwork.
class ArtworkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  const ArtworkButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.black : Colors.white;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.s20),
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(AppTheme.rFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: AppTheme.s6),
              Text(label, style: AppTheme.bodyFont(size: 15, weight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
