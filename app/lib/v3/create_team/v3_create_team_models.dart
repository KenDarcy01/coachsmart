// v3 Create a team: the data and rules behind webviews/create_team.html,
// as pure functions so tests run without a network.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The squad colour swatches, as cs-colour-picker.js.
const kSquadSwatches = [
  '#2F6FD6', '#D63B3B', '#2FA84F', '#F2C230', '#F07B22', '#8A4FD6', //
  '#1A1A1A', '#F1F4F8', '#9AA0A6', '#7A1F2B', '#4CC3E6', '#E85D9C',
];

/// The colours new squads get, in order, as cs-colour-picker.js.
const kSquadDefaults = [
  '#2F6FD6', '#D63B3B', '#2FA84F', '#F2C230', '#F07B22', //
  '#8A4FD6', '#1A1A1A', '#4CC3E6', '#7A1F2B', '#E85D9C',
];

const kMaxSquads = 10;

class CtClub {
  const CtClub(this.clubId, this.clubName);
  final int clubId;
  final String clubName;
}

class CtCode {
  const CtCode(this.codeId, this.name);
  final int codeId;
  final String name;
}

class CtSquad {
  CtSquad(this.name, this.colour);
  String name;
  String colour;

  Map<String, dynamic> toJson() => {'name': name, 'colour': colour};
}

int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;

/// Rows of `clubs` (club_id, club_name).
List<CtClub> parseClubs(dynamic rows) => [
      if (rows is List)
        for (final r in rows)
          if (r is Map && _int(r['club_id']) > 0)
            CtClub(_int(r['club_id']), '${r['club_name'] ?? ''}'),
    ];

/// The get_club_codes result: [{code_id, name}].
List<CtCode> parseCodes(dynamic rows) => [
      if (rows is List)
        for (final r in rows)
          if (r is Map && _int(r['code_id']) > 0)
            CtCode(_int(r['code_id']), '${r['name'] ?? ''}'),
    ];

/// The search box: a case-blind "contains" on the club name.
List<CtClub> filterClubs(List<CtClub> clubs, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return clubs;
  return clubs.where((c) => c.clubName.toLowerCase().contains(q)).toList();
}

/// Hurling shows as Camogie for a female team.
String codeLabel(String name, bool female) =>
    (female && name == 'Hurling') ? 'Camogie' : name;

/// The line under a code; empty when it adds nothing to the label.
String codeSub(String name, bool female) {
  String s = '';
  if (name == 'Football') {
    s = female ? 'Ladies / girls football' : 'Gaelic football';
  } else if (name == 'Hurling') {
    s = female ? 'Camogie' : 'Hurling';
  } else if (name == 'S&C') {
    s = 'Strength and conditioning';
  }
  return s == codeLabel(name, female) ? '' : s;
}

/// The codes ticked when the codes step opens. Picks still valid for the
/// club are kept; if none are left, a single-code club gets its one code,
/// otherwise Football and Hurling are ticked (not extras like S&C).
List<int> defaultCodeIds(List<CtCode> codes, List<int>? current) {
  final valid = codes.map((c) => c.codeId).toSet();
  final kept = (current ?? const <int>[]).where(valid.contains).toList();
  if (kept.isNotEmpty) return kept;
  if (codes.length == 1) return [codes.first.codeId];
  return [
    for (final c in codes)
      if (c.name == 'Football' || c.name == 'Hurling') c.codeId
  ];
}

/// The colour for a new squad: the first default not yet used.
String nextSquadColour(List<CtSquad> squads) {
  final used = squads.map((q) => q.colour.toUpperCase()).toSet();
  for (final c in kSquadDefaults) {
    if (!used.contains(c)) return c;
  }
  return kSquadDefaults[squads.length % kSquadDefaults.length];
}

/// The squads step's check before Create Team; null when all is well.
String? squadsError(List<CtSquad> squads) {
  final names = squads.map((q) => q.name.trim()).toList();
  if (names.any((n) => n.isEmpty)) {
    return 'Give every squad a name, or lower the number of squads.';
  }
  if (names.any((n) => n.toLowerCase() == 'no team')) {
    return 'No Team is added for you. Pick another name.';
  }
  if (names.map((n) => n.toLowerCase()).toSet().length != names.length) {
    return 'Two squads have the same name.';
  }
  return null;
}

/// Everything the coach has entered so far. Saved as a draft so the flow
/// can be picked up again, as the web page does.
class CreateTeamDraft {
  CreateTeamDraft({
    this.firstName = '',
    this.lastName = '',
    this.clubId,
    this.clubName = '',
    this.teamName = '',
    this.juvenile = false,
    this.female = false,
    this.codeIds,
    List<CtSquad>? squads,
  }) : squads = squads ?? [];

  String firstName;
  String lastName;
  int? clubId;
  String clubName;
  String teamName;
  bool juvenile;
  bool female;

  /// null until the codes step has been filled in for the picked club.
  List<int>? codeIds;
  List<CtSquad> squads;

  /// The web page offers "Continue where you left off?" only when one of
  /// these was filled in.
  bool get worthResuming => clubId != null || teamName.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'clubId': clubId,
        'clubName': clubName,
        'teamName': teamName,
        'juvenile': juvenile,
        'female': female,
        'carpool': false,
        'codeIds': codeIds,
        'squads': [for (final q in squads) q.toJson()],
      };

  factory CreateTeamDraft.fromJson(Map<String, dynamic> j) {
    final club = _int(j['clubId']);
    final codes = j['codeIds'];
    return CreateTeamDraft(
      firstName: '${j['firstName'] ?? ''}',
      lastName: '${j['lastName'] ?? ''}',
      clubId: club > 0 ? club : null,
      clubName: '${j['clubName'] ?? ''}',
      teamName: '${j['teamName'] ?? ''}',
      juvenile: j['juvenile'] == true,
      female: j['female'] == true,
      codeIds: codes is List
          ? [
              for (final c in codes)
                if (_int(c) > 0) _int(c)
            ]
          : null,
      squads: [
        if (j['squads'] is List)
          for (final q in j['squads'] as List)
            if (q is Map)
              CtSquad(
                  '${q['name'] ?? ''}',
                  isHexColour('${q['colour'] ?? ''}')
                      ? '${q['colour']}'.toUpperCase()
                      : kSquadDefaults.first),
      ],
    );
  }
}

/// The create_team_with_admin parameters, as the web page sends them.
/// Car pooling starts off (the page sets it false); codes are only sent
/// when the club has codes and some are picked.
Map<String, dynamic> createTeamParams(CreateTeamDraft d,
        {required bool clubHasCodes}) =>
    {
      'p_club_id': d.clubId,
      'p_team_name': d.teamName,
      'p_team_juvenile': d.juvenile,
      'p_team_female': d.female,
      'p_car_pooling_allowed': false,
      'p_first_name': d.firstName,
      'p_last_name': d.lastName,
      'p_code_ids':
          (clubHasCodes && (d.codeIds?.isNotEmpty ?? false)) ? d.codeIds : null,
      'p_squads': [
        for (final q in d.squads) {'name': q.name.trim(), 'colour': q.colour}
      ],
    };

/// The new team's join code from the create_team_with_admin result.
String teamCodeFrom(dynamic result) =>
    result is Map ? '${result['team_unique_code'] ?? ''}' : '';

// ------------------------------------------------------------------ colours

bool isHexColour(String s) => RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s);

Color colourFromHex(String hex) {
  if (!isHexColour(hex)) return const Color(0xFF9AA0A6);
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}

/// Dark or white text on a colour, as CSColourPicker.textOn.
Color textOnHex(String hex) {
  final c = colourFromHex(hex);
  final r = (c.r * 255).round(), g = (c.g * 255).round();
  final b = (c.b * 255).round();
  return (r * 299 + g * 587 + b * 114) / 1000 > 150
      ? const Color(0xFF111418)
      : const Color(0xFFFFFFFF);
}

/// A hex colour from hue (0-359), saturation and lightness (0-1), as the
/// picker's custom colour sliders.
String hslToHex(double h, double s, double l) {
  double k(int n) => (n + h / 30) % 12;
  final a = s * math.min(l, 1 - l);
  double f(int n) =>
      l - a * math.max(-1, math.min(k(n) - 3, math.min(9 - k(n), 1)));
  String two(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(f(0))}${two(f(8))}${two(f(4))}'.toUpperCase();
}

/// Hue (0-359) and lightness (0-1) of a hex colour, to set the sliders.
(double, double) hexToHueLight(String hex) {
  final c = colourFromHex(hex);
  final r = c.r, g = c.g, b = c.b;
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
  final l = (mx + mn) / 2;
  double h = 0;
  if (mx != mn) {
    final d = mx - mn;
    if (mx == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (mx == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h *= 60;
  }
  return (h, l);
}
