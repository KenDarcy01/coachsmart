// v3 Pitch planner (club officers, Ken approved 2026-11-16; plan and
// mock-ups in /mnt/project-files/coachsmart/pitch-allocation/). The data
// behind pitch_board / pitch_setup and the pure rules the board uses
// (slots, clashes, free places, age-group names, club colours), kept apart
// from the widgets so tests run without a network.
import 'dart:math' as math;

import 'package:flutter/material.dart';

int _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}') ?? 0;
int? _intOrNull(dynamic v) => v == null ? null : int.tryParse('$v');
String _s(dynamic v) => v == null ? '' : '$v';
bool _b(dynamic v) => v == true;
List<Map> _list(dynamic v) =>
    v is List ? v.whereType<Map>().toList() : const <Map>[];

/// Local wall-clock times (the DB stores Irish clock time without a zone).
DateTime parseLocal(dynamic v) {
  final s = _s(v);
  final d = DateTime.tryParse(s.length >= 19 ? s.substring(0, 19) : s);
  return d ?? DateTime(2000);
}

String isoLocal(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_2(d.month)}-${_2(d.day)}'
    'T${_2(d.hour)}:${_2(d.minute)}:00';

String _2(int n) => n.toString().padLeft(2, '0');
String hhmm(int minutes) => '${_2(minutes ~/ 60)}:${_2(minutes % 60)}';
String timeOf(DateTime d) => '${_2(d.hour)}:${_2(d.minute)}';
int minutesOf(DateTime d) => d.hour * 60 + d.minute;
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime mondayOf(DateTime d) =>
    dayOf(d).subtract(Duration(days: d.weekday - 1));
DateTime atMinutes(DateTime day, int m) =>
    DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);

int? parseHhmm(String s) {
  final m = RegExp(r'^\s*(\d{1,2})[:.](\d{2})\s*$').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
  if (h > 24 || mi > 59) return null;
  return h * 60 + mi;
}

const kWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December'
];
const kDayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday'
];

String longDay(DateTime d) =>
    '${kDayNames[d.weekday - 1]} ${d.day} ${kMonths[d.month - 1]}';

// ------------------------------------------------------------------ parts

/// Bit mask of pitch quarters: left half = 1|2, right half = 4|8.
class PitchPart {
  static const full = 15, left = 3, right = 12;
  static const q1 = 1, q2 = 2, q3 = 4, q4 = 8;

  static String label(int part, int split) {
    if (split == 1 || part == full) return 'Full';
    if (part == left) return 'Left half';
    if (part == right) return 'Right half';
    const q = {1: 'Quarter 1', 2: 'Quarter 2', 4: 'Quarter 3', 8: 'Quarter 4'};
    return q[part] ?? 'Part';
  }

  /// The parts a pitch can be booked in.
  static List<int> options(int split) => switch (split) {
        2 => const [full, left, right],
        4 => const [full, left, right, q1, q2, q3, q4],
        _ => const [full],
      };

  /// Horizontal span (0..1) of a part inside the pitch column.
  static (double, double) span(int part) {
    var lo = 4, hi = -1;
    for (var i = 0; i < 4; i++) {
      if (part & (1 << i) != 0) {
        lo = math.min(lo, i);
        hi = math.max(hi, i);
      }
    }
    if (hi < 0) return (0, 1);
    return (lo / 4, (hi + 1) / 4);
  }
}

// ------------------------------------------------------------------ club

class PitchClub {
  const PitchClub(
      {required this.clubId,
      required this.name,
      this.crest = '',
      this.primary = '',
      this.secondary = '',
      this.third = '',
      this.title = ''});

  factory PitchClub.fromJson(Map j) => PitchClub(
      clubId: _int(j['club_id']),
      name: _s(j['club_name'] ?? j['name']),
      crest: _s(j['crest']),
      primary: _s(j['primary_colour'] ?? j['primary']),
      secondary: _s(j['secondary_colour'] ?? j['secondary']),
      third: _s(j['third_colour'] ?? j['third']),
      title: _s(j['title']));

  final int clubId;
  final String name;
  final String crest;
  final String primary;
  final String secondary;
  final String third;
  final String title;

  Color get band => hexColour(primary) ?? const Color(0xFF2A3D17);

  /// The club colour used for buttons and highlights on the dark page: the
  /// first club colour that is clearly coloured (not white/grey/black) and
  /// stands out on the background; CoachSmart green if none does
  /// (Clontarf red, Ardcairn orange rather than navy, Kilmacud gold).
  Color get accent => pickAccent([primary, secondary, third]);
}

Color? hexColour(String hex) {
  final h = hex.trim();
  if (!RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(h)) return null;
  return Color(0xFF000000 |
      int.parse(h.startsWith('#') ? h.substring(1) : h, radix: 16));
}

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _saturation(Color c) {
  final mx = math.max(c.r, math.max(c.g, c.b));
  final mn = math.min(c.r, math.min(c.g, c.b));
  if (mx == mn) return 0;
  final l = (mx + mn) / 2;
  return (mx - mn) / (1 - (2 * l - 1).abs());
}

const _pageBg = Color(0xFFFFFFFF);
const _green = Color(0xFF3F7D0B);

Color pickAccent(List<String> hexes) {
  for (final h in hexes) {
    final c = hexColour(h);
    if (c == null) continue;
    if (_saturation(c) < 0.25) continue;
    if (contrast(c, _pageBg) >= 3) return c;
  }
  return _green;
}

/// Text colour on an accent button.
Color onAccent(Color c) =>
    _lum(c) > 0.3 ? const Color(0xFF14181B) : const Color(0xFFFFFFFF);

// ------------------------------------------------------------------ names

/// "Clontarf Boys 2012" in 2026 -> "U14 Boys". Teams without a birth year
/// keep their name (minus the club name when it leads).
String groupName(String teamName, {int? season, String clubName = ''}) {
  final m = RegExp(r'(19|20)\d{2}').firstMatch(teamName);
  var rest = teamName;
  for (final w in clubName.split(' ')) {
    if (w.length > 2 && rest.toLowerCase().startsWith(w.toLowerCase())) {
      rest = rest.substring(w.length).trim();
    }
  }
  if (m == null) return rest.isEmpty ? teamName : rest;
  final year = int.parse(m.group(0)!);
  final age = (season ?? DateTime.now().year) - year;
  final who = rest.replaceAll(m.group(0)!, '').replaceAll(RegExp(r'\s+'), ' ');
  return 'U$age ${who.trim()}'.trim();
}

/// Age from a team name or competition age ("U14", "Minor", "U21").
int? ageOf(String text, {int? season}) {
  final y = RegExp(r'(19|20)\d{2}').firstMatch(text);
  if (y != null)
    return (season ?? DateTime.now().year) - int.parse(y.group(0)!);
  final u = RegExp(r'U\s?(\d{1,2})', caseSensitive: false).firstMatch(text);
  if (u != null) return int.parse(u.group(1)!);
  if (text.toLowerCase().contains('minor')) return 18;
  return null;
}

class PitchDurations {
  const PitchDurations(
      {this.u12 = 50,
      this.u16 = 60,
      this.adult = 90,
      this.training = 60,
      this.other = 60,
      this.changeover = 15});

  factory PitchDurations.fromJson(dynamic j) {
    if (j is! Map) return const PitchDurations();
    int g(String k, int d) => _intOrNull(j[k]) ?? d;
    return PitchDurations(
        u12: g('u12', 50),
        u16: g('u16', 60),
        adult: g('adult', 90),
        training: g('training', 60),
        other: g('other', 60),
        changeover: g('changeover', 15));
  }

  final int u12, u16, adult, training, other, changeover;

  Map<String, int> toJson() => {
        'u12': u12,
        'u16': u16,
        'adult': adult,
        'training': training,
        'other': other,
        'changeover': changeover
      };

  /// Minutes a use of the pitch takes (a match includes warm-up and half
  /// time; the changeover is extra).
  int minutesFor(String kind, int? age) {
    if (kind == 'training') return training;
    if (kind != 'match') return other;
    if (age == null || age > 16) return adult;
    return age <= 12 ? u12 : u16;
  }
}

// ------------------------------------------------------------------ setup

/// A time the club's sheet marks a pitch as not available.
class PitchBlock {
  const PitchBlock(this.slot, this.reason);
  factory PitchBlock.fromJson(Map j) => PitchBlock(PitchSlot.fromJson(j),
      _s(j['reason']).isEmpty ? 'Not available' : _s(j['reason']));
  final PitchSlot slot;
  final String reason;

  Map<String, dynamic> toJson() => {...slot.toJson(), 'reason': reason};
}

/// Times between 08:00 and 22:00 that are neither held [slots] nor
/// already in [blocks], as "No slot" blocks.
List<PitchBlock> noSlotGaps(
    List<PitchSlot> slots, List<PitchBlock> blocks, int weekday) {
  final taken = [
    for (final s in slots) (s.opens, s.closes),
    for (final b in blocks) (b.slot.opens, b.slot.closes),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final out = <PitchBlock>[];
  var at = 8 * 60;
  for (final (o, c) in taken) {
    if (o - at >= 5) out.add(PitchBlock(PitchSlot(weekday, at, o), 'No slot'));
    if (c > at) at = c;
  }
  if (22 * 60 - at >= 5) {
    out.add(PitchBlock(PitchSlot(weekday, at, 22 * 60), 'No slot'));
  }
  return out;
}

class PitchSlot {
  const PitchSlot(this.weekday, this.opens, this.closes);
  factory PitchSlot.fromJson(Map j) => PitchSlot(_int(j['weekday']),
      parseHhmm(_s(j['opens'])) ?? 480, parseHhmm(_s(j['closes'])) ?? 1320);

  /// 1 = Monday ... 7 = Sunday.
  final int weekday;
  final int opens;
  final int closes;

  Map<String, dynamic> toJson() =>
      {'weekday': weekday, 'opens': hhmm(opens), 'closes': hhmm(closes)};

  String get label => '${hhmm(opens)}–${hhmm(closes)}';
}

class Pitch {
  const Pitch(
      {required this.pitchId,
      required this.venueId,
      required this.name,
      this.venue = '',
      this.venuePin = '',
      this.rented = false,
      this.surface = 'grass',
      this.floodlit = false,
      this.split = 1,
      this.aliases = const [],
      this.slots = const []});

  factory Pitch.fromJson(Map j) => Pitch(
          pitchId: _int(j['pitch_id']),
          venueId: _int(j['venue_id']),
          name: _s(j['name']),
          venue: _s(j['venue']),
          venuePin: _s(j['venue_pin']),
          rented: _b(j['rented']),
          surface: _s(j['surface']).isEmpty ? 'grass' : _s(j['surface']),
          floodlit: _b(j['floodlit']),
          split: _int(j['split']) == 0 ? 1 : _int(j['split']),
          aliases: [
            if (j['aliases'] is List)
              for (final a in j['aliases'] as List) '$a'
          ],
          slots: [
            for (final h in _list(j['hours'])) PitchSlot.fromJson(h)
          ]);

  final int pitchId;
  final int venueId;
  final String name;
  final String venue;
  final String venuePin;
  final bool rented;
  final String surface;
  final bool floodlit;

  /// 1 = whole pitch only, 2 = halves, 4 = quarters.
  final int split;
  final List<String> aliases;

  /// The slots the club holds; empty = open 08:00–22:00 every day.
  final List<PitchSlot> slots;

  String get surfaceLabel => switch (surface) {
        'astro' => 'Astro',
        'indoor' => 'Indoor',
        'other' => 'Other',
        _ => 'Grass'
      };

  String get splitLabel => switch (split) {
        2 => 'halves',
        4 => 'quarters',
        _ => 'full only',
      };

  String get subtitle => [
        surfaceLabel,
        if (floodlit) 'lights',
        if (split > 1) splitLabel,
      ].join(' · ');

  /// Slots on a weekday, earliest first.
  List<PitchSlot> slotsOn(int weekday) {
    if (slots.isEmpty) return [PitchSlot(weekday, 8 * 60, 22 * 60)];
    return [
      for (final s in slots)
        if (s.weekday == weekday) s
    ]..sort((a, b) => a.opens.compareTo(b.opens));
  }

  /// The slot a time falls in, if the club holds the pitch then.
  PitchSlot? slotAt(int weekday, int minute) {
    for (final s in slotsOn(weekday)) {
      if (minute >= s.opens && minute < s.closes) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'pitch_id': pitchId == 0 ? null : pitchId,
        'venue_id': venueId,
        'name': name,
        'surface': surface,
        'floodlit': floodlit,
        'split': split,
        'aliases': aliases,
        'hours': [for (final s in slots) s.toJson()],
      };

  Pitch copyWith(
          {int? venueId,
          String? name,
          String? surface,
          bool? floodlit,
          int? split,
          List<String>? aliases,
          List<PitchSlot>? slots}) =>
      Pitch(
          pitchId: pitchId,
          venueId: venueId ?? this.venueId,
          name: name ?? this.name,
          venue: venue,
          venuePin: venuePin,
          rented: rented,
          surface: surface ?? this.surface,
          floodlit: floodlit ?? this.floodlit,
          split: split ?? this.split,
          aliases: aliases ?? this.aliases,
          slots: slots ?? this.slots);
}

class Venue {
  const Venue(
      {required this.venueId,
      required this.name,
      this.address = '',
      this.pin = '',
      this.rented = false,
      this.pitches = const []});

  factory Venue.fromJson(Map j) => Venue(
      venueId: _int(j['venue_id']),
      name: _s(j['name']),
      address: _s(j['address']),
      pin: _s(j['location_pin']),
      rented: _b(j['rented']),
      pitches: [for (final p in _list(j['pitches'])) Pitch.fromJson(p)]);

  final int venueId;
  final String name;
  final String address;
  final String pin;
  final bool rented;
  final List<Pitch> pitches;
}

class UnmatchedLocation {
  const UnmatchedLocation(this.location, this.events);
  final String location;
  final int events;
}

class PitchSetup {
  const PitchSetup(
      {this.venues = const [],
      this.durations = const PitchDurations(),
      this.unmatched = const []});

  factory PitchSetup.fromJson(Map j) => PitchSetup(
      venues: [for (final v in _list(j['venues'])) Venue.fromJson(v)],
      durations: PitchDurations.fromJson(j['durations']),
      unmatched: [
        for (final u in _list(j['unmatched']))
          UnmatchedLocation(_s(u['location']), _int(u['events']))
      ]);

  final List<Venue> venues;
  final PitchDurations durations;
  final List<UnmatchedLocation> unmatched;

  List<Pitch> get pitches => [for (final v in venues) ...v.pitches];
}

// ------------------------------------------------------------------ board

/// What a booking or inbox item is for, to pick its colour.
enum PitchCode { football, hurling, camogie, ladies, other }

PitchCode codeOf(String code, {bool female = false, String name = ''}) {
  final c = code.toLowerCase();
  // The name says more than the code, which is often wrong: "U14 Girls",
  // "Clontarf Girls 2012", "Adult Camogie", "U13 Boys", "Senior Hurlers".
  final n = name.toLowerCase();
  final girls = RegExp(r'girl|ladies|women|camog|lgfa').hasMatch(n);
  final boys = !girls &&
      RegExp(r'\bboys?\b|\bmen\b|\bmens\b|hurlers|footballers').hasMatch(n);
  final hurl = c.contains('hurl') || c.contains('camog') || n.contains('hurl');
  if (girls) return hurl ? PitchCode.camogie : PitchCode.ladies;
  // Mixed groups: not boys or girls.
  if (!boys &&
      RegExp(r'nursery|all ?stars|social|mixed|academy|belgrove|school')
          .hasMatch(n)) {
    return PitchCode.other;
  }
  if (boys) return hurl ? PitchCode.hurling : PitchCode.football;
  if (c.contains('camogie')) return PitchCode.camogie;
  if (c.contains('ladies') || c.contains('lgfa')) return PitchCode.ladies;
  if (c.contains('hurling')) {
    return female ? PitchCode.camogie : PitchCode.hurling;
  }
  if (c.contains('football')) {
    return female ? PitchCode.ladies : PitchCode.football;
  }
  return PitchCode.other;
}

const _boys = Color(0xFF4D8EF0);
const _girls = Color(0xFFF06AA8);

/// Colour by who plays (Ken 2026-11-16): blue for boys and men, pink for
/// girls and women, grey when it is not known. Not by code.
const kCodeColours = {
  PitchCode.football: _boys,
  PitchCode.hurling: _boys,
  PitchCode.camogie: _girls,
  PitchCode.ladies: _girls,
  PitchCode.other: Color(0xFFB5B8BE),
};

const kCodeNames = {
  PitchCode.football: 'Football',
  PitchCode.hurling: 'Hurling',
  PitchCode.camogie: 'Camogie',
  PitchCode.ladies: 'Ladies Football',
  PitchCode.other: 'Other',
};

class PitchTeam {
  const PitchTeam(this.teamId, this.name, {this.female = false});
  final int teamId;
  final String name;
  final bool female;
}

/// A placeholder for every team at the club, CoachSmart or not (Ken,
/// 2026-11-16): U14 Boys, Nursery, All Stars, Social Ball…
class PitchGroup {
  const PitchGroup(
      {required this.groupId,
      required this.name,
      this.code = 'Other',
      this.teamId,
      this.teamName = '',
      this.sessions = 0,
      this.booked = 0});

  factory PitchGroup.fromJson(Map j) => PitchGroup(
      groupId: _int(j['group_id']),
      name: _s(j['name']),
      code: _s(j['code']).isEmpty ? 'Other' : _s(j['code']),
      teamId: _intOrNull(j['team_id']),
      teamName: _s(j['team_name']),
      sessions: _int(j['sessions']),
      booked: _int(j['booked']));

  final int groupId;
  final String name;
  final String code;
  final int? teamId;
  final String teamName;

  /// Training slots a week it should get (0 = no target).
  final int sessions;

  /// Training slots it has in the loaded week.
  final int booked;

  bool get short => sessions > 0 && booked < sessions;
  PitchCode get codeKey => codeOf(code, name: name);
}

const kGroupCodes = [
  'Football',
  'Hurling',
  'Camogie',
  'Ladies Football',
  'Other'
];

class Booking {
  const Booking(
      {required this.bookingId,
      required this.start,
      required this.end,
      this.pitchId,
      this.part = PitchPart.full,
      this.kind = 'training',
      this.title = '',
      this.teamId,
      this.teamName = '',
      this.female = false,
      this.eventId,
      this.gameId,
      this.status = 'confirmed',
      this.note = '',
      this.referee = '',
      this.dressingRooms = '',
      this.rolledFrom,
      this.code = '',
      this.eventTitle = '',
      this.opposition = '',
      this.groupId});

  factory Booking.fromJson(Map j, {int? groupId}) => Booking(
      groupId: groupId ?? _intOrNull(j['group_id']),
      bookingId: _int(j['booking_id']),
      pitchId: _intOrNull(j['pitch_id']),
      part: _int(j['part']) == 0 ? PitchPart.full : _int(j['part']),
      start: parseLocal(j['starts_at']),
      end: parseLocal(j['ends_at']),
      kind: _s(j['kind']).isEmpty ? 'training' : _s(j['kind']),
      title: _s(j['title']),
      teamId: _intOrNull(j['team_id']),
      teamName: _s(j['team_name']),
      female: _b(j['female']),
      eventId: _intOrNull(j['event_id']),
      gameId: _intOrNull(j['gaa_game_id']),
      status: _s(j['status']).isEmpty ? 'confirmed' : _s(j['status']),
      note: _s(j['note']),
      referee: _s(j['referee']),
      dressingRooms: _s(j['dressing_rooms']),
      rolledFrom: _intOrNull(j['rolled_from']),
      code: _s(j['code']).isNotEmpty ? _s(j['code']) : _s(j['event_code']),
      eventTitle: _s(j['event_title']),
      opposition: _s(j['opposition']));

  final int bookingId;
  final int? pitchId;
  final int part;
  final DateTime start;
  final DateTime end;
  final String kind;
  final String title;
  final int? teamId;
  final String teamName;
  final bool female;
  final int? eventId;
  final int? gameId;
  final String status;
  final String note;
  final String referee;
  final String dressingRooms;
  final int? rolledFrom;
  final String code;
  final String eventTitle;
  final String opposition;
  final int? groupId;

  bool get confirmed => status == 'confirmed';
  bool get offsite => status == 'offsite';

  /// The same booking at a new place and time (shown at once on a drop).
  Booking moved(int pitchId, int part, DateTime start, DateTime end) => Booking(
      bookingId: bookingId,
      start: start,
      end: end,
      pitchId: pitchId,
      part: part,
      kind: kind,
      title: title,
      teamId: teamId,
      teamName: teamName,
      female: female,
      eventId: eventId,
      gameId: gameId,
      status: status,
      note: note,
      referee: referee,
      dressingRooms: dressingRooms,
      rolledFrom: rolledFrom,
      code: code,
      eventTitle: eventTitle,
      opposition: opposition,
      groupId: groupId);

  bool overlaps(Booking o) =>
      start.isBefore(o.end) && o.start.isBefore(end) && (part & o.part) != 0;
}

class BoardEvent {
  const BoardEvent(
      {required this.eventId,
      required this.start,
      this.teamId = 0,
      this.teamName = '',
      this.female = false,
      this.code = '',
      this.title = '',
      this.opposition = '',
      this.homeAway = '',
      this.location = '',
      this.type = '',
      this.matchedPitchId});

  factory BoardEvent.fromJson(Map j) => BoardEvent(
      eventId: _int(j['event_id']),
      teamId: _int(j['team_id']),
      teamName: _s(j['team_name']),
      female: _b(j['female']),
      code: _s(j['code']),
      title: _s(j['title']),
      opposition: _s(j['opposition']),
      homeAway: _s(j['home_away']),
      location: _s(j['location']),
      type: _s(j['type']),
      start: parseLocal(j['starts_at']),
      matchedPitchId: _intOrNull(j['matched_pitch_id']));

  final int eventId;
  final int teamId;
  final String teamName;
  final bool female;
  final String code;
  final String title;
  final String opposition;
  final String homeAway;
  final String location;
  final String type;
  final DateTime start;
  final int? matchedPitchId;

  bool get isMatch => type == 'Match';
  String get kind =>
      isMatch ? 'match' : (type == 'Other' ? 'other' : 'training');

  /// Only training and matches need a pitch (Ken, 2026-11-16): not "Other"
  /// events and never S&C.
  bool get needsPitch =>
      kind != 'other' &&
      !code.toLowerCase().replaceAll(' ', '').contains('s&c');
}

class BoardFixture {
  const BoardFixture(
      {required this.gameId,
      required this.start,
      this.code = '',
      this.age = '',
      this.comp = '',
      this.home = '',
      this.away = '',
      this.venue = '',
      this.matchedPitchId});

  factory BoardFixture.fromJson(Map j) => BoardFixture(
      gameId: _int(j['game_id']),
      code: _s(j['code']),
      age: _s(j['age']),
      comp: _s(j['comp']),
      home: _s(j['home']),
      away: _s(j['away']),
      venue: _s(j['venue']),
      start: parseLocal(j['starts_at']),
      matchedPitchId: _intOrNull(j['matched_pitch_id']));

  final int gameId;
  final String code;
  final String age;
  final String comp;
  final String home;
  final String away;
  final String venue;
  final DateTime start;
  final int? matchedPitchId;
}

class Closure {
  const Closure(
      {required this.closureId,
      required this.pitchId,
      required this.from,
      required this.to,
      this.reason = ''});

  factory Closure.fromJson(Map j) => Closure(
      closureId: _int(j['closure_id']),
      pitchId: _int(j['pitch_id']),
      from: dayOf(parseLocal(j['starts_on'])),
      to: dayOf(parseLocal(j['ends_on'])),
      reason: _s(j['reason']));

  final int closureId;
  final int pitchId;
  final DateTime from;
  final DateTime to;
  final String reason;

  bool covers(DateTime day) {
    final d = dayOf(day);
    return !d.isBefore(from) && !d.isAfter(to);
  }
}

/// One thing that needs (or may need) a pitch: a CoachSmart event with no
/// booking, or a home league fixture.
class PlaceItem {
  const PlaceItem(
      {required this.title,
      required this.start,
      required this.kind,
      required this.codeKey,
      this.subtitle = '',
      this.event,
      this.fixture,
      this.request,
      this.age,
      this.teamId,
      this.matchedPitchId});

  final String title;
  final String subtitle;
  final DateTime start;
  final String kind;
  final PitchCode codeKey;
  final BoardEvent? event;
  final BoardFixture? fixture;

  /// A coach's request (a booking with status requested).
  final Booking? request;
  final int? age;
  final int? teamId;
  final int? matchedPitchId;

  String get key => event != null
      ? 'e${event!.eventId}'
      : fixture != null
          ? 'g${fixture!.gameId}'
          : 'r${request?.bookingId}';
}

class PitchBoard {
  const PitchBoard(
      {this.pitches = const [],
      this.closures = const [],
      this.bookings = const [],
      this.events = const [],
      this.fixtures = const [],
      this.teams = const [],
      this.groups = const [],
      this.publishedAt,
      this.changedSincePublish = true,
      this.blocks = const [],
      this.durations = const PitchDurations()});

  factory PitchBoard.fromJson(Map j) {
    final bg =
        j['booking_groups'] is Map ? j['booking_groups'] as Map : const {};
    final week = j['week'] is Map ? j['week'] as Map : const {};
    return PitchBoard(
        pitches: [for (final p in _list(j['pitches'])) Pitch.fromJson(p)],
        closures: [for (final c in _list(j['closures'])) Closure.fromJson(c)],
        bookings: [
          for (final b in _list(j['bookings']))
            Booking.fromJson(b, groupId: _intOrNull(bg['${b['booking_id']}']))
        ],
        groups: [for (final g in _list(j['groups'])) PitchGroup.fromJson(g)],
        blocks: [
          for (final b in _list(j['blocks']))
            (_int(b['pitch_id']), PitchBlock.fromJson(b))
        ],
        publishedAt: week['published_at'] == null
            ? null
            : DateTime.tryParse(_s(week['published_at']))?.toLocal(),
        changedSincePublish: week['changed'] != false,
        events: [for (final e in _list(j['events'])) BoardEvent.fromJson(e)],
        fixtures: [
          for (final f in _list(j['fixtures'])) BoardFixture.fromJson(f)
        ],
        teams: [
          for (final t in _list(j['teams']))
            PitchTeam(_int(t['team_id']), _s(t['team_name']),
                female: _b(t['female']))
        ],
        durations: PitchDurations.fromJson(j['durations']));
  }

  final List<Pitch> pitches;
  final List<Closure> closures;
  final List<Booking> bookings;

  /// (pitch id, block): times marked not available.
  final List<(int, PitchBlock)> blocks;

  /// Not-available times on a day. On an astro, every time outside the
  /// slots the club holds is "No slot" too (Ken, 2026-11-16); on grass a
  /// gap between slots is left plain.
  List<PitchBlock> blocksOn(int pitchId, int weekday) {
    final own = [
      for (final (id, b) in blocks)
        if (id == pitchId && b.slot.weekday == weekday) b
    ];
    Pitch? p;
    for (final x in pitches) {
      if (x.pitchId == pitchId) p = x;
    }
    if (p == null || p.surface != 'astro' || p.slots.isEmpty) return own;
    return [
      ...own,
      ...noSlotGaps([
        for (final s in p.slots)
          if (s.weekday == weekday) s
      ], own, weekday)
    ];
  }

  final List<BoardEvent> events;
  final List<BoardFixture> fixtures;
  final List<PitchTeam> teams;
  final List<PitchGroup> groups;
  final DateTime? publishedAt;
  final bool changedSincePublish;
  final PitchDurations durations;

  PitchGroup? group(int? id) {
    for (final g in groups) {
      if (g.groupId == id) return g;
    }
    return null;
  }

  PitchGroup? groupOfTeam(int? teamId) {
    if (teamId == null) return null;
    for (final g in groups) {
      if (g.teamId == teamId) return g;
    }
    return null;
  }

  Pitch? pitch(int? id) {
    for (final p in pitches) {
      if (p.pitchId == id) return p;
    }
    return null;
  }

  Closure? closureOn(int pitchId, DateTime day) {
    for (final c in closures) {
      if (c.pitchId == pitchId && c.covers(day)) return c;
    }
    return null;
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Booking> bookingsOn(DateTime day, {int? pitchId}) => [
        for (final b in bookings)
          if (!b.offsite &&
              b.pitchId != null &&
              sameDay(b.start, day) &&
              (pitchId == null || b.pitchId == pitchId))
            b
      ]..sort((a, b) => a.start.compareTo(b.start));

  /// Events whose own location already names one of our pitches; shown on
  /// the board in a lighter style until an officer confirms them. An event
  /// is left out when its team already has a booking that day, since that
  /// booking is its session (else the two sit side by side as a clash).
  List<BoardEvent> matchedOn(DateTime day, {int? pitchId}) {
    final booked = {
      for (final b in bookingsOn(day))
        if (b.teamId != null) b.teamId!,
    };
    return [
      for (final e in events)
        if (e.needsPitch &&
            e.matchedPitchId != null &&
            sameDay(e.start, day) &&
            (pitchId == null || e.matchedPitchId == pitchId) &&
            !booked.contains(e.teamId))
          e
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Pairs of confirmed bookings sharing a part of a pitch at the same time.
  List<(Booking, Booking)> clashesOn(DateTime day) {
    final out = <(Booking, Booking)>[];
    for (final p in pitches) {
      final list = [
        for (final b in bookingsOn(day, pitchId: p.pitchId))
          if (b.confirmed) b
      ];
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          if (list[i].overlaps(list[j])) out.add((list[i], list[j]));
        }
      }
    }
    return out;
  }

  Set<int> clashIds(DateTime day) => {
        for (final (a, b) in clashesOn(day)) ...[a.bookingId, b.bookingId]
      };

  /// Things that still need a pitch in the loaded range: events and home
  /// fixtures that match no pitch, plus coach requests.
  List<PlaceItem> inbox({String clubName = '', int? season}) {
    final out = <PlaceItem>[];
    for (final e in events) {
      if (e.matchedPitchId != null || !e.needsPitch) continue;
      final group = groupName(e.teamName, season: season, clubName: clubName);
      final title = e.isMatch && e.opposition.isNotEmpty
          ? '$group v ${e.opposition}'
          : '$group ${e.isMatch ? 'match' : e.type.toLowerCase()}'.trim();
      out.add(PlaceItem(
          title: title,
          subtitle:
              e.location.isEmpty ? 'No location' : 'Location: ${e.location}',
          start: e.start,
          kind: e.kind,
          codeKey: codeOf(e.code, female: e.female, name: e.teamName),
          event: e,
          age: ageOf(e.teamName, season: season),
          teamId: e.teamId));
    }
    for (final f in fixtures) {
      if (f.matchedPitchId != null) continue;
      out.add(fixtureItem(f));
    }
    for (final b in bookings) {
      if (b.status != 'requested') continue;
      out.add(PlaceItem(
          title: b.title.isNotEmpty
              ? b.title
              : groupName(b.teamName, season: season, clubName: clubName),
          subtitle: 'Request',
          start: b.start,
          kind: b.kind,
          codeKey: codeOf(b.code,
              female: b.female, name: '${b.teamName} ${b.title}'),
          request: b,
          teamId: b.teamId));
    }
    out.sort((a, b) => a.start.compareTo(b.start));
    return out;
  }

  static PlaceItem fixtureItem(BoardFixture f) => PlaceItem(
      title: '${f.age.isEmpty ? '' : '${f.age} '}${f.code} v ${f.away}'.trim(),
      subtitle: [
        if (f.comp.isNotEmpty) f.comp,
        if (f.venue.isNotEmpty) 'Venue: ${f.venue}'
      ].join(' · '),
      start: f.start,
      kind: 'match',
      codeKey: codeOf(f.code, name: f.comp),
      fixture: f,
      age: ageOf(f.age),
      matchedPitchId: f.matchedPitchId);

  /// Is [part] of [pitch] free from [start] to [end] (ignoring [except])?
  bool isFree(Pitch pitch, DateTime start, DateTime end, int part,
      {int? except}) {
    if (closureOn(pitch.pitchId, start) != null) return false;
    for (final b in bookingsOn(start, pitchId: pitch.pitchId)) {
      if (b.bookingId == except || !b.confirmed) continue;
      if (b.start.isBefore(end) &&
          start.isBefore(b.end) &&
          (b.part & part) != 0) {
        return false;
      }
    }
    return true;
  }

  /// Where an item could go: for each pitch, the slot holding the start
  /// time (or the next free slot that day), whole pitch first, then halves.
  List<PlaceOption> optionsFor(DateTime start, int minutes,
      {int? except, int wantPart = PitchPart.full}) {
    final out = <PlaceOption>[];
    final day = dayOf(start);
    final m = minutesOf(start);
    for (final p in pitches) {
      if (closureOn(p.pitchId, day) != null) continue;
      final parts = [
        wantPart,
        for (final x in PitchPart.options(p.split))
          if (x != wantPart && x != PitchPart.full) x
      ].where((x) => PitchPart.options(p.split).contains(x));
      final slot = p.slotAt(day.weekday, m);
      PlaceOption? found;
      if (slot != null) {
        final s = atMinutes(day, m);
        final e = s.add(Duration(minutes: minutes));
        for (final part in parts) {
          if (isFree(p, s, e, part, except: except)) {
            found = PlaceOption(p, s, e, part, exact: true);
            break;
          }
        }
      }
      if (found == null) {
        // The next slot that day with room.
        for (final sl in p.slotsOn(day.weekday)) {
          final from = math.max(sl.opens, m);
          if (from >= sl.closes) continue;
          final s = atMinutes(day, sl.opens >= m ? sl.opens : from);
          final e = s.add(Duration(minutes: minutes));
          final part = parts.firstWhere(
              (x) => isFree(p, s, e, x, except: except),
              orElse: () => 0);
          if (part != 0) {
            found = PlaceOption(p, s, e, part, exact: false);
            break;
          }
        }
      }
      if (found != null) out.add(found);
    }
    out.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      if (a.part != b.part) return a.part == PitchPart.full ? -1 : 1;
      return a.start.compareTo(b.start);
    });
    return out;
  }
}

class PlaceOption {
  const PlaceOption(this.pitch, this.start, this.end, this.part,
      {this.exact = true});
  final Pitch pitch;
  final DateTime start;
  final DateTime end;
  final int part;

  /// True when it fits at the asked time; false = a later slot that day.
  final bool exact;
}
