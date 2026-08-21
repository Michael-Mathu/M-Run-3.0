import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gps_pipeline/gps_pipeline.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = ref.watch(localeProvider);

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            L10n.tr('select_activity', locale),
            style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          _ActivityCard(
            isSelected: selectedProfile == ActivityProfile.run,
            onTap: () => onSelected(ActivityProfile.run),
            icon: Icons.directions_run,
            label: L10n.tr('run', locale),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            borderRadius: 16,
            borderWidth: 2,
            unselectedBackground: colorScheme.surfaceContainerHighest,
            unselectedBorderColor: Colors.transparent,
            iconSize: 32,
            textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            layout: _CardLayout.row,
            showCheckIcon: true,
            checkIconSize: 24,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActivityCard(
                  isSelected: selectedProfile == ActivityProfile.walk,
                  onTap: () => onSelected(ActivityProfile.walk),
                  icon: Icons.directions_walk,
                  label: L10n.tr('walk', locale),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  borderRadius: 12,
                  borderWidth: 2,
                  unselectedBackground: colorScheme.surfaceContainerHighest,
                  unselectedBorderColor: Colors.transparent,
                  iconSize: 28,
                  textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  layout: _CardLayout.column,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActivityCard(
                  isSelected: selectedProfile == ActivityProfile.cycle,
                  onTap: () => onSelected(ActivityProfile.cycle),
                  icon: Icons.directions_bike,
                  label: L10n.tr('cycle', locale),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  borderRadius: 12,
                  borderWidth: 2,
                  unselectedBackground: colorScheme.surfaceContainerHighest,
                  unselectedBorderColor: Colors.transparent,
                  iconSize: 28,
                  textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  layout: _CardLayout.column,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActivityCard(
                  isSelected: selectedProfile == ActivityProfile.hike,
                  onTap: () => onSelected(ActivityProfile.hike),
                  icon: Icons.terrain,
                  label: L10n.tr('hike', locale),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  borderRadius: 12,
                  borderWidth: 2,
                  unselectedBackground: colorScheme.surfaceContainerHighest,
                  unselectedBorderColor: Colors.transparent,
                  iconSize: 28,
                  textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  layout: _CardLayout.column,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActivityCard(
                  isSelected: selectedProfile == ActivityProfile.drive,
                  onTap: () => onSelected(ActivityProfile.drive),
                  icon: Icons.directions_car,
                  label: L10n.tr('drive', locale),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  borderRadius: 12,
                  borderWidth: 2,
                  unselectedBackground: colorScheme.surfaceContainerHighest,
                  unselectedBorderColor: Colors.transparent,
                  iconSize: 28,
                  textStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  layout: _CardLayout.column,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _ActivityCard(
            isSelected: selectedProfile == ActivityProfile.indoorPoor,
            onTap: () => onSelected(ActivityProfile.indoorPoor),
            icon: Icons.home,
            label: L10n.tr('indoor_poor_signal', locale),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            borderRadius: 12,
            borderWidth: 1,
            unselectedBackground: colorScheme.surfaceContainerLow,
            unselectedBorderColor: colorScheme.outlineVariant,
            iconSize: 24,
            textStyle: theme.textTheme.bodyLarge,
            layout: _CardLayout.row,
            showCheckIcon: true,
            checkIconSize: 20,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

enum _CardLayout { row, column }

/// Shared selectable-card chrome for [ActivityTypeSelector]'s three visual
/// variants (main/small/indoor), which previously duplicated the same
/// InkWell+Container+BoxDecoration skeleton with only sizing/color/layout
/// differing between them.
class _ActivityCard extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double borderWidth;
  final Color unselectedBackground;
  final Color unselectedBorderColor;
  final double iconSize;
  final TextStyle? textStyle;
  final _CardLayout layout;
  final bool showCheckIcon;
  final double checkIconSize;

  const _ActivityCard({
    required this.isSelected,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.padding,
    required this.borderRadius,
    required this.borderWidth,
    required this.unselectedBackground,
    required this.unselectedBorderColor,
    required this.iconSize,
    required this.textStyle,
    required this.layout,
    this.showCheckIcon = false,
    this.checkIconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;
    final labelColor = isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface;

    final iconWidget = Icon(icon, size: iconSize, color: iconColor);
    final labelWidget = Text(label, style: textStyle?.copyWith(color: labelColor));

    final content = layout == _CardLayout.row
        ? Row(
            children: [
              iconWidget,
              const SizedBox(width: 16),
              labelWidget,
              const Spacer(),
              if (showCheckIcon && isSelected)
                Icon(Icons.check_circle, color: colorScheme.primary, size: checkIconSize),
            ],
          )
        : Column(
            children: [
              iconWidget,
              const SizedBox(height: 8),
              labelWidget,
            ],
          );

    return Semantics(
      selected: isSelected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : unselectedBackground,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isSelected ? colorScheme.primary : unselectedBorderColor,
              width: borderWidth,
            ),
          ),
          child: ExcludeSemantics(child: content),
        ),
      ),
    );
  }
}
