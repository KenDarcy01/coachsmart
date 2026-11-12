import 'package:flutter_test/flutter_test.dart';
import 'package:coach_smart_v2/v3/v3_open_location.dart';

void main() {
  const pos = MapTarget(lat: 53.4386272, lng: -6.1515904, label: 'Pitch 19');
  const search = MapTarget(query: "St. Vincent's GAA Club, Malahide Rd");

  test('finds the pasted link', () {
    expect(pinLink(' Https://maps.app.goo.gl/abc?g_st=aw').toString(),
        'https://maps.app.goo.gl/abc?g_st=aw');
    expect(pinLink('P34'), isNull);
  });

  test('search text without a link', () {
    expect(fallbackQuery('', 'Clontarf GAA'), 'Clontarf GAA');
    expect(fallbackQuery('P34', ''), 'P34');
    expect(fallbackQuery('location_pin', null), '');
  });

  test('reads the map-pin reply', () {
    final a = targetFromResponse(
        {'lat': 53.1, 'lng': -6.2, 'name': 'Park'}, 'Venue')!;
    expect(a.hasPosition, isTrue);
    expect(a.label, 'Park');
    expect(targetFromResponse({'lat': 53.1, 'lng': -6.2}, 'Venue')!.label,
        'Venue');
    expect(targetFromResponse({'query': 'X Rd'}, '')!.query, 'X Rd');
    expect(targetFromResponse({'error': 'not found'}, ''), isNull);
    expect(targetFromResponse(null, ''), isNull);
  });

  test('app links', () {
    expect(googleMapsAppUri(pos).toString(),
        'comgooglemaps://?q=53.4386272%2C-6.1515904');
    expect(appleMapsUri(pos).toString(),
        'maps://?ll=53.4386272%2C-6.1515904&q=Pitch+19');
    expect(appleMapsUri(search).toString(),
        'maps://?q=St.+Vincent%27s+GAA+Club%2C+Malahide+Rd');
    expect(geoUri(pos).toString(),
        'geo:53.4386272,-6.1515904?q=53.4386272%2C-6.1515904(Pitch%2019)');
    expect(geoUri(search).toString(),
        "geo:0,0?q=St.%20Vincent's%20GAA%20Club%2C%20Malahide%20Rd");
    expect(googleMapsWebUri(search).host, 'www.google.com');
  });
}
