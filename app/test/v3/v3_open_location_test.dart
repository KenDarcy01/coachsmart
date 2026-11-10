import 'package:flutter_test/flutter_test.dart';
import 'package:coach_smart_v2/v3/v3_open_location.dart';

void main() {
  test('opens a pasted Google Maps link as is', () {
    expect(
        locationPinUri(' Https://maps.app.goo.gl/abc?g_st=aw', 'Pitch 3')
            .toString(),
        'https://maps.app.goo.gl/abc?g_st=aw');
  });
  test('searches the venue name when there is no link', () {
    final u = locationPinUri('', 'Clontarf GAA')!;
    expect(u.host, 'www.google.com');
    expect(u.queryParameters['query'], 'Clontarf GAA');
  });
  test('uses pin text when there is no name, nothing when both empty', () {
    expect(locationPinUri('P34', '')!.queryParameters['query'], 'P34');
    expect(locationPinUri('', ''), isNull);
    expect(locationPinUri('location_pin', null), isNull);
  });
}
