import 'package:url_launcher/url_launcher.dart';

/// Outcome of [SafetyService.sendSos] -- the caller (the SOS dialog) needs
/// to know whether the messaging app actually opened, since nothing here
/// ever auto-sends: launching the composer is success, and failure to even
/// launch it must be surfaced to the user rather than swallowed (AUDIT_2.md
/// F-1 -- on-device testing found the old signature let a launch failure
/// look identical to success from the caller's side).
enum SosResult { opened, failedToOpen }

class SafetyService {
  /// Opens the device's SMS composer with every contact prefilled as a
  /// recipient and the message body prefilled with the user's location.
  /// This does NOT send anything automatically -- the user still has to
  /// tap send in their messaging app. Returns [SosResult.failedToOpen] if
  /// the composer could not be launched at all, so the caller can show a
  /// real failure state (and a dialer fallback) instead of a false
  /// "sent" implication.
  static Future<SosResult> sendSos(List<EmergencyContact> contacts, double lat, double lng) async {
    if (contacts.isEmpty) return SosResult.failedToOpen;
    final locationUrl = 'https://maps.google.com/?q=$lat,$lng';
    final smsBody = 'Mwendo SOS: I need help. Location: $locationUrl';
    final recipients = contacts.map((c) => c.phone).join(',');
    final uri = Uri.parse('sms:$recipients?body=${Uri.encodeComponent(smsBody)}');
    try {
      if (await canLaunchUrl(uri) && await launchUrl(uri)) {
        return SosResult.opened;
      }
    } catch (_) {
      // fall through to failedToOpen
    }
    return SosResult.failedToOpen;
  }

  /// One-tap fallback when the SMS composer can't be opened: dial the
  /// first emergency contact directly instead. Returns false if even the
  /// phone dialer can't be launched (e.g. no telephony on this device).
  static Future<bool> callContact(EmergencyContact contact) async {
    final uri = Uri.parse('tel:${contact.phone}');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
    } catch (_) {
      // fall through to false
    }
    return false;
  }
}

class EmergencyContact {
  final String name;
  final String phone;
  final String relationship;

  EmergencyContact({required this.name, required this.phone, required this.relationship});

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        relationship: j['relationship'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };
}