import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mwendo_app/core/navigation/navigation.dart';
import 'package:mwendo_app/core/perf/glass_quality.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/widgets/pressable.dart';

/// Standard iPhone page gutter.
const double kIosGutter = 16;

/// An iOS page with a collapsing large title (Settings / Music / Fitness
/// style): the title sits large under the status bar, shrinks into a
/// translucent blurred bar as content scrolls under it, and the bar only
/// shows its hairline once something is behind it.
///
/// [inTabBar] adds bottom clearance for the floating glass tab bar.
class LargeTitlePage extends StatelessWidget {
  final String title;
  final List<Widget> slivers;
  final Widget? trailing;
  final bool showBack;
  final bool inTabBar;
  final ScrollController? controller;

  const LargeTitlePage({
    super.key,
    required this.title,
    required this.slivers,
    this.trailing,
    this.showBack = false,
    this.inTabBar = true,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bg = theme.scaffoldBackgroundColor;
    return CupertinoPageScaffold(
      backgroundColor: bg,
      child: Material(
        type: MaterialType.transparency,
        child: CustomScrollView(
          controller: controller,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(title),
              automaticallyImplyLeading: false,
              automaticallyImplyTitle: false,
              leading: showBack ? const IosBackButton() : null,
              trailing: trailing,
              transitionBetweenRoutes: false,
              enableBackgroundFilterBlur: GlassScope.blurOf(context),
              backgroundColor: GlassScope.blurOf(context)
                  ? (dark ? AppTheme.glassDark : AppTheme.glassLight)
                  : (dark ? const Color(0xF2121214) : const Color(0xF2F6F6F8)),
              border: Border(
                bottom: BorderSide(
                  color: dark ? AppTheme.separatorDark : AppTheme.separatorLight,
                  width: 0.0,
                ),
              ),
            ),
            ...slivers,
            SliverToBoxAdapter(
              child: SizedBox(
                height: inTabBar
                    ? AppTheme.tabBarClearance(context)
                    : MediaQuery.paddingOf(context).bottom + AppTheme.s24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS back chevron in the tint colour. Uses the app's back logic so deep
/// links still land one level up instead of closing the app.
class IosBackButton extends StatelessWidget {
  final Color? color;
  const IosBackButton({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      excludeSemantics: true,
      child: Pressable(
        onTap: () => onAppBack(context),
        child: SizedBox(
          width: AppTheme.minTap,
          height: AppTheme.minTap,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Icon(CupertinoIcons.chevron_back, size: 28, color: tint),
          ),
        ),
      ),
    );
  }
}

/// Round glass-free icon button for nav-bar trailing slots.
class IosBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool highlighted;
  const IosBarButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: SizedBox(
          width: AppTheme.minTap,
          height: AppTheme.minTap,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: highlighted ? tint : tint.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: highlighted ? Colors.white : tint),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header in the iOS 17+ style: bold Title 3 on the left, a tinted
/// "See All" on the right.
class IosSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const IosSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s28, kIosGutter, AppTheme.s10),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTheme.bodyFont(
                  size: 22,
                  weight: FontWeight.w700,
                  height: 1.2,
                  color: cs.onSurface,
                ).copyWith(letterSpacing: -0.4),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.s4),
                child: Text(
                  actionLabel!,
                  style: AppTheme.bodyFont(size: 17, color: cs.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Footnote-style uppercase caption above an inset grouped list.
class IosListCaption extends StatelessWidget {
  final String text;
  const IosListCaption(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kIosGutter + AppTheme.s16, AppTheme.s20, kIosGutter, AppTheme.s6),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.bodyFont(
          size: 13,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ).copyWith(letterSpacing: -0.1),
      ),
    );
  }
}

/// Native iOS search field, padded to the page gutter.
class IosSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String placeholder;

  const IosSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(kIosGutter, AppTheme.s4, kIosGutter, AppTheme.s4),
      child: CupertinoSearchTextField(
        controller: controller,
        onChanged: onChanged,
        placeholder: placeholder,
        style: AppTheme.bodyFont(size: 17, color: cs.onSurface),
        placeholderStyle: AppTheme.bodyFont(size: 17, color: cs.onSurfaceVariant),
        itemColor: cs.onSurfaceVariant,
        backgroundColor: cs.onSurface.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsetsDirectional.fromSTEB(6, 9, 6, 9),
      ),
    );
  }
}

/// iOS sliding segmented control with the app's text styles.
class IosSegmented<T extends Object> extends StatelessWidget {
  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  const IosSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: cs.onSurface.withValues(alpha: dark ? 0.12 : 0.07),
        thumbColor: dark ? const Color(0xFF636366) : Colors.white,
        padding: const EdgeInsets.all(2),
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
        children: {
          for (final e in segments.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Text(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyFont(
                  size: 13,
                  weight: e.key == value ? FontWeight.w600 : FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
            ),
        },
      ),
    );
  }
}

/// Horizontally scrolling capsule filters (App Store / Music style).
class IosFilterPills extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final String Function(String)? labelOf;

  const IosFilterPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppTheme.s8),
        itemBuilder: (_, i) {
          final opt = options[i];
          final active = opt == selected;
          return Semantics(
            button: true,
            selected: active,
            child: Pressable(
              onTap: () => onSelected(opt),
              child: AnimatedContainer(
                duration: AppTheme.motion(context, AppTheme.dFast),
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.s14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? cs.onSurface : cs.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.rFull),
                ),
                child: Text(
                  labelOf?.call(opt) ?? opt,
                  style: AppTheme.bodyFont(
                    size: 15,
                    weight: FontWeight.w600,
                    color: active ? Theme.of(context).scaffoldBackgroundColor : cs.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Rounded "inset grouped" card that holds list rows (iOS Settings style).
class IosInsetGroup extends StatelessWidget {
  final List<Widget> children;
  final double dividerIndent;
  const IosInsetGroup({super.key, required this.children, this.dividerIndent = 16});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Padding(
          padding: EdgeInsetsDirectional.only(start: dividerIndent),
          child: Container(
            height: 0.5,
            color: dark ? AppTheme.separatorDark : AppTheme.separatorLight,
          ),
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kIosGutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.r12),
        child: ColoredBox(
          color: cs.surface,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
    );
  }
}
