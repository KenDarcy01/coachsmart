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

  test('team sponsor wins on its team, never on Home', () {
    V3Sponsors.apply({
      'teams': [
        {'team_id': 10, 'club_id': 1},
        {'team_id': 11, 'club_id': 1},
      ],
      'sponsors': [
        {'sponsor_id': 1, 'club_id': 1, 'team_id': null, 'name': 'Club', 'status': 'live'},
        {'sponsor_id': 2, 'club_id': 1, 'team_id': 10, 'name': 'Team', 'status': 'live', 'on_home': true},
        {'sponsor_id': 3, 'club_id': 1, 'team_id': 99, 'name': 'Other team', 'status': 'live'},
      ],
    });
    expect(V3Sponsors.forTeam(10, V3SponsorPlace.event)!.id, 2);
    expect(V3Sponsors.forTeam(10, V3SponsorPlace.live)!.id, 2);
    expect(V3Sponsors.forTeam(11, V3SponsorPlace.event)!.id, 1);
    expect(V3Sponsors.forTeam(99, V3SponsorPlace.live)!.id, 3);
    expect(V3Sponsors.forHome(10)!.id, 1);
    expect(V3Sponsors.forHome(null)!.id, 1);
    expect(V3Sponsors.onlyOne(V3SponsorPlace.live)!.id, 1);
  });
}
