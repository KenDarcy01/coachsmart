import 'package:url_launcher/url_launcher.dart';

/// Opens an event's location pin.
///
/// Coaches paste a Google Maps share link (e.g. https://maps.app.goo.gl/...)
/// into the pin field, so open that link itself: the Google Maps app if it is
/// installed, otherwise the browser. With no link, search Google Maps for the
/// venue name (or the pin text). FlutterFlow's launchMap treated the link as
/// search words at 0,0 and does nothing on the web, so it is not used here.
Uri? locationPinUri(String? locationPin, String? locationName) {
  final pin = (locationPin ?? '').trim();
  final name = (locationName ?? '').trim();
  final match = RegExp(r'https?://\S+', caseSensitive: false).firstMatch(pin);
  if (match != null) {
    final uri = Uri.tryParse(match.group(0)!);
    if (uri != null) return uri;
  }
  final query = name.isNotEmpty ? name : (pin == 'location_pin' ? '' : pin);
  if (query.isEmpty) return null;
  return Uri.https(
      'www.google.com', '/maps/search/', {'api': '1', 'query': query});
}

Future<void> openLocationPin(String? locationPin, String? locationName) async {
  final uri = locationPinUri(locationPin, locationName);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
