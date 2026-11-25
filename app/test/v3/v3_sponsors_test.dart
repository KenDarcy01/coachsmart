import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coach_smart_v2/v3/sponsors/v3_sponsors.dart';

void main() {
  test('sponsor parses colour, status and placements', () {
    final s = V3Sponsor.fromJson({
      'sponsor_id': 3, 'club_id': 1, 'name': 'Nolans Supermarket',
      'tagline': 'Proud partner', 'link_url': 'https://nolans.ie',
      'logo_url': '', 'card_colour': '#15302a', 'status': 'draft',
      'on_home': true, 'on_events': false, 'on_live': true,
    });
    expect(s.id, 3);
    expect(s.live, isFalse);
    expect(s.cardColour, const Color(0xFF15302A));
    expect(s.showsOn(V3SponsorPlace.event), isFalse);
    expect(s.showsOn(V3SponsorPlace.live), isTrue);
    expect(V3Sponsor.fromJson({'card_colour': 'red'}).cardColour, isNull);
  });
}
