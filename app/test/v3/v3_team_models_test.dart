import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/teams/v3_team_models.dart';

void main() {
  test('TeamSummary parses counts and sorts roles highest first', () {
    final t = TeamSummary.fromJson({
      'team_id': '12',
      'team_name': '2018 Boys',
      'team_unique_code': 'ABC123',
      'club_id': 1,
      'club_name': 'Clontarf GAA',
      'club_crest': '',
      'team_highest_role_level': 100,
      'team_role_name': 'Admin',
      'role_names': ['Player', 'Admin', 'Coach'],
      'player_count': 24,
      'coach_count': 3,
      'admin_count': 1,
      'pending_approvals': 2,
    });
    expect(t.teamId, 12);
    expect(t.players, 24);
    expect(t.coaches, 3);
    expect(t.admins, 1);
    expect(t.pending, 2);
    expect(t.rolesSorted, ['Admin', 'Coach', 'Player']);
  });

  test('TeamSummary falls back to the single role name', () {
    final t = TeamSummary.fromJson({
      'team_id': 1,
      'team_name': 'U10',
      'team_role_name': 'Coach',
    });
    expect(t.roleNames, ['Coach']);
    expect(t.players, 0);
  });

  test('TeamRoster groups sort by role level and count members once', () {
    final r = TeamRoster.fromJson({
      'team_id': 5,
      'team_name': 'U12',
      'team_unique_code': 'X',
      'club_id': 1,
      'user_highest_role_level': 30,
      'club_codes': [
        {'code_id': 3, 'event_code': 'Hurling'},
        {'code_id': 2, 'event_code': 'Football'},
        {'code_id': 1, 'event_code': '-'},
      ],
      'role_groups': [
        {
          'role_level': 30,
          'role_name': 'Coach',
          'members': [
            {'member_id': 9, 'first_name': 'Pat', 'last_name': 'Coach'},
          ],
        },
        {
          'role_level': 10,
          'role_name': 'Player',
          'members': [
            {
              'member_id': 7,
              'first_name': 'Zoe',
              'last_name': 'A',
              'squad_codes': [
                {'code_id': 1, 'squad_id': 3, 'squad_name': 'A squad'},
              ],
            },
            {'member_id': 8, 'first_name': 'Amy', 'last_name': 'B'},
            {'member_id': 9, 'first_name': 'Pat', 'last_name': 'Coach'},
          ],
        },
      ],
    });
    expect(r.groups.map((g) => g.roleLevel).toList(), [10, 30]);
    expect(r.groups.first.members.map((m) => m.firstName).toList(),
        ['Amy', 'Pat', 'Zoe']);
    // "-" (code 1) is left out for squads; real codes sorted by id.
    expect(r.codes.map((c) => c.codeId).toList(), [2, 3]);
    expect(r.count((l) => l >= 10), 3);
    expect(r.count((l) => l >= 20), 1);
    expect(r.member(7)!.squadFor(1)!.squadId, 3);
    expect(r.member(7)!.squadFor(2), isNull);
  });

  test('countsLine wording', () {
    expect(countsLine(1, 0, 0), '1 player');
    expect(countsLine(24, 3, 1), '24 players · 3 coaches · 1 admin');
  });

  test('team squad cards and squad order for one code', () {
    final r = TeamRoster.fromJson({
      'team_id': 5,
      'club_codes': [
        {'code_id': 2, 'event_code': 'Football'},
      ],
      'role_groups': [
        {
          'role_level': 10,
          'role_name': 'Player',
          'role_name_plural': 'Players',
          'members': [
            {
              'member_id': 1,
              'first_name': 'Amy',
              'squad_codes': [
                {'code_id': 2, 'squad_id': 12}
              ]
            },
            {
              'member_id': 2,
              'first_name': 'Beth',
              'squad_codes': [
                {'code_id': 2, 'squad_id': 11}
              ]
            },
            {'member_id': 3, 'first_name': 'Cara'},
            {
              'member_id': 4,
              'first_name': 'Dee',
              'squad_codes': [
                {'code_id': 2, 'squad_id': 99, 'squad_name': 'No Team'}
              ]
            },
          ],
        },
        {
          'role_level': 30,
          'role_name': 'Coach',
          'role_name_plural': 'Coaches',
          'members': [
            {
              'member_id': 9,
              'first_name': 'Pat',
              'squad_codes': [
                {'code_id': 2, 'squad_id': 11}
              ]
            },
          ],
        },
      ],
    });
    const squads = [
      TeamSquad(11, 'Blue', '', '#2266cc'),
      TeamSquad(12, 'Red', '', ''),
    ];
    final cards = teamSquadCards(r, 2, squads);
    expect(cards.map((c) => c.name), ['Blue', 'Red', 'Unassigned']);
    expect(cards[0].count, 1); // players only
    expect(cards[0].lines, ['Coaches: 1']);
    expect(cards[2].count, 2); // no squad and No Team are both Unassigned
    final ordered = orderBySquad(r.groups.first.members, 2, squads);
    expect(ordered.map((m) => m.firstName), ['Beth', 'Amy', 'Cara', 'Dee']);
  });
}
