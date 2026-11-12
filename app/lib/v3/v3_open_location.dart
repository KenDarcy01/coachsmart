import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '/backend/supabase/supabase.dart';

/// Opens an event's location straight in a maps app.
///
/// Coaches paste Google Maps share links (https://maps.app.goo.gl/...) into
/// the pin field. Opening that link goes through a browser page first, which
/// stays behind blank once Maps opens (Ken, 2026-11-12: "open directly to
/// google maps"). So the map-pin edge function turns the link into a
/// position or search text, and the maps app is opened with its own link:
/// Google Maps if installed, else Apple Maps on iPhone; geo: on Android
/// (Android's map chooser / Google Maps). With no link, the venue name is
/// searched. Anything that can't be read falls back to opening the link.

/// What to show: a position (lat/lng, with an optional label) or search text.
class MapTarget {
  const MapTarget({this.lat, this.lng, this.label = '', this.query = ''});
  final double? lat;
  final double? lng;
  final String label;
  final String query;
  bool get hasPosition => lat != null && lng != null;
}

/// The pasted link in a pin field, if there is one.
Uri? pinLink(String? locationPin) {
  final match = RegExp(r'https?://\S+', caseSensitive: false)
      .firstMatch((locationPin ?? '').trim());
  return match == null ? null : Uri.tryParse(match.group(0)!);
}

/// Search text used when there is no link: venue name, else the pin text.
String fallbackQuery(String? locationPin, String? locationName) {
  final pin = (locationPin ?? '').trim();
  final name = (locationName ?? '').trim();
  if (name.isNotEmpty) return name;
  if (pin == 'location_pin' || pinLink(pin) != null) return '';
  return pin;
}

/// Reads the map-pin edge function's reply.
MapTarget? targetFromResponse(dynamic data, String venue) {
  if (data is! Map) return null;
  final lat = data['lat'], lng = data['lng'];
  final label = (data['name'] ?? '').toString().trim();
  final query = (data['query'] ?? '').toString().trim();
  if (lat is num && lng is num) {
    return MapTarget(
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        label: label.isNotEmpty ? label : venue);
  }
  if (query.isNotEmpty) return MapTarget(query: query, label: label);
  return null;
}

String _q(Map<String, String> p) => Uri(queryParameters: p).query;

/// Google Maps app (iOS): comgooglemaps://?q=53.4,-6.1
Uri googleMapsAppUri(MapTarget t) => Uri.parse('comgooglemaps://?${_q({
          'q': t.hasPosition ? '${t.lat},${t.lng}' : t.query,
        })}');

/// Apple Maps app: maps://?ll=53.4,-6.1&q=Pitch+19
Uri appleMapsUri(MapTarget t) => Uri.parse('maps://?${_q(t.hasPosition ? {
    'll': '${t.lat},${t.lng}',
    'q': t.label.isNotEmpty ? t.label : 'Location',
  } : {'q': t.query})}');

/// Android: geo:53.4,-6.1?q=53.4,-6.1(Pitch 19) or geo:0,0?q=search
Uri geoUri(MapTarget t) => t.hasPosition
    ? Uri.parse(
        'geo:${t.lat},${t.lng}?q=${Uri.encodeComponent('${t.lat},${t.lng}${t.label.isNotEmpty ? '(${t.label})' : ''}')}')
    : Uri.parse('geo:0,0?q=${Uri.encodeComponent(t.query)}');

/// Browser fallback (desktop web): Google Maps search page.
Uri googleMapsWebUri(MapTarget t) =>
    Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': t.hasPosition ? '${t.lat},${t.lng}' : t.query,
    });

Future<MapTarget?> _resolve(Uri link, String venue) async {
  try {
    final res = await SupaFlow.client.functions.invoke('map-pin',
        body: {'url': link.toString()}).timeout(const Duration(seconds: 4));
    return targetFromResponse(res.data, venue);
  } catch (_) {
    return null;
  }
}

Future<bool> _open(Uri uri, {bool sameWindow = false}) async {
  try {
    return await launchUrl(uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: sameWindow ? '_self' : null);
  } catch (_) {
    return false;
  }
}

Future<void> openLocationPin(String? locationPin, String? locationName) async {
  final venue = (locationName ?? '').trim();
  final link = pinLink(locationPin);
  MapTarget? target;
  if (link != null) {
    target = await _resolve(link, venue);
  } else {
    final q = fallbackQuery(locationPin, locationName);
    if (q.isNotEmpty) target = MapTarget(query: q, label: venue);
  }

  if (target != null) {
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final android = defaultTargetPlatform == TargetPlatform.android;
    if (kIsWeb) {
      // iPhone/Android browsers: the app link opens the maps app with no
      // page left behind. Desktop: Google Maps in a new tab.
      if (ios && await _open(appleMapsUri(target), sameWindow: true)) return;
      if (android && await _open(geoUri(target), sameWindow: true)) return;
      if (!ios && !android && await _open(googleMapsWebUri(target))) return;
    } else if (ios) {
      final g = googleMapsAppUri(target);
      if (await canLaunchUrl(g) && await _open(g)) return;
      if (await _open(appleMapsUri(target))) return;
    } else if (android) {
      if (await _open(geoUri(target))) return;
    }
  }

  // Couldn't read the link: open it as before.
  if (link != null) {
    await _open(link);
  } else if (target != null) {
    await _open(googleMapsWebUri(target));
  }
}
