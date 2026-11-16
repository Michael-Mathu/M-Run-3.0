import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mwendo_app/core/device/keep_alive.dart';
import 'package:mwendo_app/core/l10n/app_strings.dart';
import 'package:mwendo_app/core/theme/app_theme.dart';
import 'package:mwendo_app/widgets/grouped_section.dart';
import 'package:mwendo_app/widgets/ios.dart';
import 'package:mwendo_gps_engine/mwendo_gps_engine.dart';

/// "Keep Mwendo running": explains, for this phone's maker, the settings that
/// stop the system freezing a recording when the screen is off, shows whether
/// the app is already unrestricted, and opens the right settings screen.
class KeepAlivePage extends ConsumerStatefulWidget {
  const KeepAlivePage({super.key});

  @override
  ConsumerState<KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends ConsumerState<KeepAlivePage> with WidgetsBindingObserver {
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
    // Back from system settings: re-read whether the app is now unrestricted.
    if (state == AppLifecycleState.resumed) ref.invalidate(batteryStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final status = ref.watch(batteryStatusProvider).value ?? const BatteryStatus();
    final family = phoneFamilyOf(status.manufacturer);
    final steps = keepAliveStepKeys(family);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final exempt = status.ignoringBatteryOptimizations;
    final phone = [
      if (status.manufacturer.isNotEmpty)
        status.manufacturer[0].toUpperCase() + status.manufacturer.substring(1),
      if (status.model.isNotEmpty) status.model,
    ].join(' ');

    return LargeTitlePage(
      title: L10n.tr('keep_running_title', locale),
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppTheme.s16, AppTheme.s8, AppTheme.s16, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(AppTheme.s4, 0, AppTheme.s4, AppTheme.s16),
                child: Text(
                  L10n.tr('keep_running_intro', locale),
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              if (status.known)
                GroupedSection(
                  children: [
                    GroupedRow(
                      icon: exempt
                          ? CupertinoIcons.checkmark_shield_fill
                          : CupertinoIcons.exclamationmark_triangle_fill,
                      iconColor: exempt ? AppTheme.success : context.tokens.warning,
                      title: L10n.tr('keep_battery_row', locale),
                      value: L10n.tr(exempt ? 'keep_unrestricted' : 'keep_restricted', locale),
                    ),
                    if (status.powerSaveMode)
                      GroupedRow(
                        icon: CupertinoIcons.battery_25,
                        iconColor: context.tokens.warning,
                        title: L10n.tr('keep_saver_on', locale),
                      ),
                    if (phone.isNotEmpty)
                      GroupedRow(
                        icon: CupertinoIcons.device_phone_portrait,
                        iconColor: AppTheme.idle,
                        title: L10n.tr('keep_phone_row', locale),
                        value: phone,
                      ),
                  ],
                ),
              GroupedSection(
                header: L10n.tr('keep_steps_header', locale),
                footer: L10n.tr('keep_steps_footer', locale),
                children: [
                  for (var i = 0; i < steps.length; i++)
                    _Step(number: i + 1, body: L10n.tr(steps[i], locale)),
                ],
              ),
              FilledButton(
                onPressed: () => MwendoGpsEngine().openBatterySettings(),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.r12),
                  ),
                ),
                child: Text(L10n.tr('keep_open_settings', locale)),
              ),
              const SizedBox(height: AppTheme.s32),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String body;
  const _Step({required this.number, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.s16, vertical: AppTheme.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: text.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppTheme.s16),
          Expanded(child: Text(body, style: text.bodyMedium)),
        ],
      ),
    );
  }
}
