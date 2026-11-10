import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// Activity picker shown on the Run tab before a workout: a compact iOS
/// checklist (coloured icon tile, label, checkmark), in a sheet that sits
/// under the map.
class ActivityTypeSelector extends ConsumerWidget {
  final ActivityProfile selectedProfile;
  final ValueChanged<ActivityProfile> onSelected;

  const ActivityTypeSelector({
    super.key,
    required this.selectedProfile,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final items = <({ActivityProfile p, IconData icon, Color color, String label})>[
      (p: ActivityProfile.run, icon: Icons.directions_run_rounded, color: cs.primary, label: L10n.tr('run', locale)),
      (p: ActivityProfile.walk, icon: Icons.directions_walk_rounded, color: const Color(0xFF34C759), label: L10n.tr('walk', locale)),
      (p: ActivityProfile.cycle, icon: Icons.directions_bike_rounded, color: const Color(0xFF007AFF), label: L10n.tr('cycle', locale)),
      (p: ActivityProfile.hike, icon: Icons.terrain_rounded, color: const Color(0xFFA2845E), label: L10n.tr('hike', locale)),
      (p: ActivityProfile.drive, icon: Icons.directions_car_rounded, color: const Color(0xFF5856D6), label: L10n.tr('drive', locale)),
      (p: ActivityProfile.indoorPoor, icon: CupertinoIcons.house_fill, color: AppTheme.idle, label: L10n.tr('indoor_poor_signal', locale)),
    ];

    final separator = dark ? AppTheme.separatorDark : AppTheme.separatorLight;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppTheme.s16, AppTheme.s20, AppTheme.s16, AppTheme.s8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.r24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppTheme.s4, bottom: AppTheme.s10),
            child: Text(
              L10n.tr('select_activity', locale),
              style: AppTheme.bodyFont(size: 22, weight: FontWeight.w700, color: cs.onSurface)
                  .copyWith(letterSpacing: -0.4),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.r12),
            child: ColoredBox(
              color: cs.surface,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: AppTheme.s16 + 30 + AppTheme.s12),
                        child: Container(height: 0.5, color: separator),
                      ),
                    _ActivityRow(
                      icon: items[i].icon,
                      color: items[i].color,
                      label: items[i].label,
                      selected: selectedProfile == items[i].p,
                      onTap: () => onSelected(items[i].p),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        pressedScale: 1,
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: AppTheme.s12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTheme.bodyFont(
                      size: 17,
                      weight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: AppTheme.motion(context, AppTheme.dFast),
                  child: Icon(CupertinoIcons.checkmark_alt, size: 22, color: cs.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
