import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mwendo_gps_engine/mwendo_gps_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phone makers whose Android skins are known to freeze or kill apps in the
/// background, including apps with a foreground service: a run then records
/// a straight line or stops when the screen turns off. Stock Android and
/// Pixel phones are left out, the foreground service is enough there.
enum PhoneFamily {
  /// Tecno, Infinix, itel (HiOS / XOS / itel OS): about half of the phones
  /// sold in Africa.
  transsion,
  xiaomi,
  samsung,

  /// Oppo, Realme, OnePlus and Vivo.
  oppo,
  huawei,
  other,
}

PhoneFamily phoneFamilyOf(String manufacturer) {
  final m = manufacturer.toLowerCase();
  bool has(List<String> names) => names.any(m.contains);
  if (has(const ['tecno', 'infinix', 'itel', 'transsion'])) return PhoneFamily.transsion;
  if (has(const ['xiaomi', 'redmi', 'poco'])) return PhoneFamily.xiaomi;
  if (has(const ['samsung'])) return PhoneFamily.samsung;
  if (has(const ['oppo', 'realme', 'oneplus', 'vivo'])) return PhoneFamily.oppo;
  if (has(const ['huawei', 'honor'])) return PhoneFamily.huawei;
  return PhoneFamily.other;
}

/// Translation keys of the steps for [family], most important first. The
/// first and last two apply to every phone; the middle ones are the maker's
/// own switches (menu names taken from dontkillmyapp.com).
List<String> keepAliveStepKeys(PhoneFamily family) => [
      'keep_step_unrestricted',
      ...switch (family) {
        PhoneFamily.transsion => const ['keep_step_transsion_autostart', 'keep_step_transsion_saving'],
        PhoneFamily.xiaomi => const ['keep_step_xiaomi_autostart', 'keep_step_xiaomi_saver'],
        PhoneFamily.samsung => const ['keep_step_samsung_sleep'],
        PhoneFamily.oppo => const ['keep_step_oppo_autostart'],
        PhoneFamily.huawei => const ['keep_step_huawei_launch'],
        PhoneFamily.other => const <String>[],
      },
      'keep_step_lock',
      'keep_step_saver',
    ];

/// Whether to bring the guide up unasked before a run: an aggressive maker
/// and the app is still battery-optimised.
bool shouldPromptKeepAlive(BatteryStatus s) =>
    s.known &&
    !s.ignoringBatteryOptimizations &&
    phoneFamilyOf(s.manufacturer) != PhoneFamily.other;

/// Current maker and battery-optimisation state. Re-read with
/// `ref.invalidate` after the user comes back from system settings.
final batteryStatusProvider = FutureProvider.autoDispose<BatteryStatus>(
  (ref) => MwendoGpsEngine().batteryStatus(),
);

const _kPrompted = 'keep_alive_prompted';

/// True the first time it is asked, false afterwards: the unprompted dialog
/// is shown once only (the guide stays available in Settings).
Future<bool> takeKeepAlivePrompt() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPrompted) ?? false) return false;
    await prefs.setBool(_kPrompted, true);
    return true;
  } catch (_) {
    return false;
  }
}
