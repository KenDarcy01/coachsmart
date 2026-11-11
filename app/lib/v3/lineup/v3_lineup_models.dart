// Data and rules for the v3 lineup (team selector): a native copy of
// webviews/team_selector.html. Pure Dart so the tests run without a network.
// Ken (2026-10-15): keep drag and drop, keep manual Save and Share, club
// colours, autosave allowed, sub names must not overlap, no shirt-number
// override and no player sheet.
import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';

int _i(dynamic v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
String _s(dynamic v) => v == null ? '' : '$v';

/// One spot on the pitch. x and y are percentages, our goal at the bottom.
class LinePos {
  const LinePos(this.n, this.l, this.x, this.y);
  final int n;
  final String l;
  final double x, y;
}

const kFormats = [9, 11, 13, 15];
const kSubSlots = 5;

const Map<int, List<LinePos>> kLineupPositions = {
  15: [
    LinePos(1, 'GK', 50, 92),
    LinePos(2, 'RFB', 82, 78),
    LinePos(3, 'FB', 50, 78),
    LinePos(4, 'LFB', 18, 78),
    LinePos(5, 'RHB', 82, 63),
    LinePos(6, 'CHB', 50, 63),
    LinePos(7, 'LHB', 18, 63),
    LinePos(8, 'MF', 66, 45),
    LinePos(9, 'MF', 34, 45),
    LinePos(10, 'RHF', 82, 27),
    LinePos(11, 'CHF', 50, 27),
    LinePos(12, 'LHF', 18, 27),
    LinePos(13, 'RFF', 82, 11),
    LinePos(14, 'FF', 50, 11),
    LinePos(15, 'LFF', 18, 11),
  ],
  13: [
    LinePos(1, 'GK', 50, 92),
    LinePos(2, 'RFB', 68, 78),
    LinePos(3, 'LFB', 32, 78),
    LinePos(4, 'RHB', 82, 63),
    LinePos(5, 'CHB', 50, 63),
    LinePos(6, 'LHB', 18, 63),
    LinePos(7, 'MF', 66, 45),
    LinePos(8, 'MF', 34, 45),
    LinePos(9, 'RHF', 82, 27),
    LinePos(10, 'CHF', 50, 27),
    LinePos(11, 'LHF', 18, 27),
    LinePos(12, 'RFF', 68, 11),
    LinePos(13, 'LFF', 32, 11),
  ],
  11: [
    LinePos(1, 'GK', 50, 92),
    LinePos(2, 'RFB', 82, 78),
    LinePos(3, 'LFB', 18, 78),
    LinePos(4, 'RHB', 82, 63),
    LinePos(5, 'LHB', 18, 63),
    LinePos(6, 'MF', 66, 45),
    LinePos(7, 'MF', 34, 45),
    LinePos(8, 'RHF', 82, 27),
    LinePos(9, 'LHF', 18, 27),
    LinePos(10, 'RFF', 82, 11),
    LinePos(11, 'LFF', 18, 11),
  ],
  9: [
    LinePos(1, 'GK', 50, 92),
    LinePos(2, 'RB', 82, 74),
    LinePos(3, 'FB', 50, 74),
    LinePos(4, 'LB', 18, 74),
    LinePos(5, 'MF', 66, 45),
    LinePos(6, 'MF', 34, 45),
    LinePos(7, 'RFF', 82, 13),
    LinePos(8, 'FF', 50, 13),
    LinePos(9, 'LFF', 18, 13),
  ],
};

List<LinePos> positionsFor(int format) =>
    kLineupPositions[format] ?? kLineupPositions[15]!;

String positionLabel(int format, int n) {
  for (final p in positionsFor(format)) {
    if (p.n == n) return p.l;
  }
  return '';
}

/// Rows spread a little so the keeper's name stays on the pitch (percent).
double dispY(double y) => 8 + (y - 11) * (80 / 81);

/// Sub slot N wears shirt format + N.
int subShirt(int format, int slot) => format + slot;

/// Bench labels are narrow: first name plus surname initial ("Adam L.").
String shortName(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  if (p.isEmpty || p.first.isEmpty) return '';
  return p.length > 1 ? '${p.first} ${p.last[0]}.' : p.first;
}

/// Pitch names: first name, then the rest of the name on a second line.
List<String> nameLines(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  if (p.length < 2) return [name.trim()];
  return [p.first, p.sublist(1).join(' ')];
}

/// '#cc0000' or 'cc0000' to a colour; null when it isn't a 6-digit hex.
Color? hexColour(dynamic v) {
  final h = _s(v).trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(h)) return null;
  return Color(0xFF000000 | int.parse(h, radix: 16));
}

/// Shirt number colour: white on dark shirts, black on light ones.
Color numberColour(Color bg) {
  final r = (bg.r * 255), g = (bg.g * 255), b = (bg.b * 255);
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255 < 0.38
      ? const Color(0xFFFFFFFF)
      : const Color(0xFF000000);
}

/// Jerseys in the club's own colours (clubs.primary/secondary/third_colour).
class KitColours {
  const KitColours(this.primary, this.stripe, this.keeper);
  final Color primary, stripe, keeper;

  static const fallback =
      KitColours(Color(0xFFCC0000), Color(0xFFCC0000), Color(0xFFFFFFFF));

  factory KitColours.fromClub(Map? club) {
    final p = hexColour(club?['primary_colour']);
    if (p == null) return fallback;
    final s = hexColour(club?['secondary_colour']) ?? p;
    final t = hexColour(club?['third_colour']);
    return KitColours(
        p, s, t != null && t != p && t != s ? t : fallback.keeper);
  }
}

class LineupPlayer {
  const LineupPlayer(this.id, this.name);
  final int id;
  final String name;
}

enum DragFrom { strip, pos, sub }

/// What is being dragged: a player and where they came from.
class LineupDrag {
  const LineupDrag(this.playerId, this.from, [this.key]);
  final int playerId;
  final DragFrom from;
  final int? key; // position number or sub slot
}

/// The pitch and bench: position number -> member, sub slot -> member.
class LineupBoard {
  LineupBoard({this.format = 15, Map<int, int>? assign, Map<int, int>? subs})
      : assign = assign ?? {},
        subs = subs ?? {};

  int format;
  final Map<int, int> assign;
  final Map<int, int> subs;

  bool get isEmpty => assign.isEmpty && subs.isEmpty;
  bool onPitch(int id) =>
      assign.values.contains(id) || subs.values.contains(id);

  LineupBoard copy() =>
      LineupBoard(format: format, assign: {...assign}, subs: {...subs});

  /// New format: positions that don't exist in it are cleared, subs stay.
  void setFormat(int f) {
    format = f;
    final keep = positionsFor(f).map((p) => p.n).toSet();
    assign.removeWhere((k, _) => !keep.contains(k));
  }

  int? _firstEmptySub({int? except}) {
    for (var n = 1; n <= kSubSlots; n++) {
      if (n != except && !subs.containsKey(n)) return n;
    }
    return null;
  }

  /// Drop on a pitch position. Whoever was there goes back to where the
  /// dragged player came from (a strip drag sends them to the first free
  /// sub slot), as on the web page.
  void dropOnPosition(LineupDrag d, int to) {
    final displaced = assign[to];
    if (displaced != null) {
      if (d.from == DragFrom.pos) {
        assign[d.key!] = displaced;
      } else if (d.from == DragFrom.sub) {
        subs[d.key!] = displaced;
      } else {
        final e = _firstEmptySub();
        if (e != null) subs[e] = displaced;
      }
    } else {
      if (d.from == DragFrom.pos) assign.remove(d.key);
      if (d.from == DragFrom.sub) subs.remove(d.key);
    }
    subs.removeWhere((_, v) => v == d.playerId);
    assign[to] = d.playerId;
  }

  /// Drop on a sub slot; swaps with whoever is in it.
  void dropOnSub(LineupDrag d, int to) {
    final displaced = subs[to];
    if (displaced != null) {
      if (d.from == DragFrom.pos) {
        assign[d.key!] = displaced;
      } else if (d.from == DragFrom.sub) {
        subs[d.key!] = displaced;
      } else {
        final e = _firstEmptySub(except: to);
        if (e != null) subs[e] = displaced;
      }
    } else {
      if (d.from == DragFrom.pos) assign.remove(d.key);
      if (d.from == DragFrom.sub) subs.remove(d.key);
    }
    subs.removeWhere((k, v) => k != to && v == d.playerId);
    assign.removeWhere((_, v) => v == d.playerId);
    subs[to] = d.playerId;
  }

  /// Back to the squad strip (or dropped off the pitch).
  void remove(LineupDrag d) {
    if (d.from == DragFrom.pos) assign.remove(d.key);
    if (d.from == DragFrom.sub) subs.remove(d.key);
  }

  /// lineup_details rows for a saved lineup.
  List<Map<String, dynamic>> details(int lineupId) => [
        for (final e in assign.entries)
          {
            'lineup_id': lineupId,
            'member_id': e.value,
            'position_num': e.key,
            'position_label': positionLabel(format, e.key),
            'is_sub': false,
          },
        for (final e in subs.entries)
          {
            'lineup_id': lineupId,
            'member_id': e.value,
            'position_num': e.key,
            'position_label': 'SUB',
            'is_sub': true,
          },
      ];
}

/// Everything the page shows. The live loader builds this map from the same
/// tables the web page reads; tests pass it directly.
class LineupData {
  LineupData.fromJson(Map j)
      : message = _s(j['message']),
        teamName = _s(j['team_name']),
        teamsheet = j['teamsheet'] == true,
        kit = KitColours.fromClub(j['club'] is Map ? j['club'] : null),
        imageSub = _s(j['image_sub']),
        players = [
          for (final p in (j['players'] as List? ?? const []))
            if (p is Map) LineupPlayer(_i(p['member_id']), _s(p['name']))
        ]..sort((a, b) => a.name.compareTo(b.name)),
        saved = j['lineup'] is Map ? j['lineup'] as Map : null;

  /// Set when there is nothing to pick from (no match squad, nobody
  /// accepted, ...): shown instead of the pitch.
  final String message;
  final String teamName, imageSub;
  final bool teamsheet;
  final KitColours kit;
  final List<LineupPlayer> players;
  final Map? saved;

  bool get hasMessage => message.isNotEmpty;

  LineupPlayer? player(int id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The newest saved lineup, without anyone no longer in the squad.
  LineupBoard initialBoard() {
    final s = saved;
    if (s == null) return LineupBoard();
    final f = _i(s['format']);
    final b = LineupBoard(format: kFormats.contains(f) ? f : 15);
    final valid = players.map((p) => p.id).toSet();
    for (final d in (s['details'] as List? ?? const [])) {
      if (d is! Map) continue;
      final id = _i(d['member_id']);
      if (!valid.contains(id)) continue;
      if (d['is_sub'] == true) {
        b.subs[_i(d['position_num'])] = id;
      } else {
        b.assign[_i(d['position_num'])] = id;
      }
    }
    return b;
  }

  bool get hasSavedLineup =>
      saved != null && ((saved!['details'] as List?)?.isNotEmpty ?? false);
}

// ------------------------------------------------------------ load helpers

/// match_squad_details ordered by id desc: one member id per member, in the
/// order of their newest row.
List<int> latestMemberIds(List rows) {
  final seen = <int>{};
  final out = <int>[];
  for (final r in rows) {
    final id = _i((r as Map)['member_id']);
    if (seen.add(id)) out.add(id);
  }
  return out;
}

/// event_attendance ordered by member, newest first: members whose latest
/// reply is 3 (attending).
List<int> attendingMemberIds(List rows) {
  final latest = <int, int>{};
  for (final r in rows) {
    final m = r as Map;
    latest.putIfAbsent(_i(m['member_id']), () => _i(m['response_id']));
  }
  return [
    for (final e in latest.entries)
      if (e.value == 3) e.key
  ];
}

/// member_team_link rows with member_team_role_link(roles(role_level)):
/// members holding any of [levels].
Set<int> membersWithRoleLevel(List rows, Set<int> levels) => {
      for (final r in rows)
        if (((r as Map)['member_team_role_link'] as List? ?? const []).any(
            (x) =>
                x is Map &&
                levels.contains(_i((x['roles'] as Map?)?['role_level']))))
          _i(r['member_id'])
    };

String fullName(Map m) => '${_s(m['first_name'])} ${_s(m['last_name'])}'.trim();

/// Shared image header: "Football Match  ·  15 Nov 2026" (no opposition,
/// Ken 2026-10-16).
String imageSubtitle(String code, String type, DateTime? when) {
  final head = '$code $type'.trim();
  final ds = when == null ? '' : DateFormat('dd MMM yyyy').format(when);
  return [head, ds].where((s) => s.isNotEmpty).join('  ·  ');
}

String lineupFileName(String teamName) =>
    'CoachSmart_${teamName.trim().replaceAll(RegExp(r'\s+'), '_')}_lineup.png';

/// Name sizes under a pitch jersey, by the space between rows (from the web
/// page): two lines when there's room, two small lines when tight, else one.
class NameFit {
  const NameFit(this.lines, this.size);
  final List<String> lines;
  final double size;
}

NameFit fitName(String name, double room) {
  final two = nameLines(name);
  if (two.length == 2 && room >= 25) return NameFit(two, 11);
  if (two.length == 2 && room >= 17) return NameFit(two, 9);
  return NameFit([name.trim()], 10);
}

/// Smallest gap between rows of jerseys, in pixels, for a pitch [h] high.
double rowGap(int format, double h) {
  final ys = positionsFor(format).map((p) => dispY(p.y)).toSet().toList()
    ..sort();
  var gap = double.infinity;
  for (var i = 1; i < ys.length; i++) {
    gap = (ys[i] - ys[i - 1]) * h / 100 < gap
        ? (ys[i] - ys[i - 1]) * h / 100
        : gap;
  }
  return gap;
}
