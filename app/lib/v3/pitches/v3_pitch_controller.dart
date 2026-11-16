// v3 Pitch planner: the state the board, the phone view and the sheets
// share (club, the loaded week, the picked day) and the changes they make.
import 'package:flutter/foundation.dart';

import 'v3_pitch_api.dart';
import 'v3_pitch_models.dart';

class PitchController extends ChangeNotifier {
  PitchController(this.club, {this.api = const PitchApi(), DateTime? today})
      : day = dayOf(today ?? DateTime.now()),
        _today = dayOf(today ?? DateTime.now());

  final PitchClub club;
  final PitchApi api;
  final DateTime _today;

  DateTime day;
  PitchBoard? board;
  DateTime? _loadedMonday;
  String? error;
  bool loading = false;
  bool busy = false;

  /// Shown once after the week was filled from the week before.
  String? rolledNote;

  DateTime get monday => mondayOf(day);
  DateTime get today => _today;
  int get season => day.year;

  String group(String teamName) =>
      groupName(teamName, season: season, clubName: club.name);

  Future<void> load({bool force = false}) async {
    final m = monday;
    if (!force && _loadedMonday == m && board != null) {
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      // This week and later weeks start as a copy of the week before.
      if (!m.isBefore(mondayOf(_today))) {
        final n = await api.rollWeek(club.clubId, m);
        rolledNote = n > 0
            ? '$n training slot${n == 1 ? '' : 's'} carried over from the week before.'
            : null;
      }
      final b = await api.board(club.clubId, m, m.add(const Duration(days: 6)));
      board = b;
      _loadedMonday = m;
      error = null;
    } catch (e) {
      error = pitchErrorText(e);
    }
    loading = false;
    notifyListeners();
  }

  void pickDay(DateTime d) {
    day = dayOf(d);
    load();
  }

  void shiftDays(int n) => pickDay(day.add(Duration(days: n)));

  /// Runs a change, then reloads the week. Returns the error text, if any.
  Future<String?> run(Future<void> Function() call) async {
    busy = true;
    notifyListeners();
    try {
      await call();
      busy = false;
      await load(force: true);
      return null;
    } catch (e) {
      busy = false;
      // Puts back anything shown early (a move or a new group session).
      await load(force: true);
      return pitchErrorText(e);
    }
  }

  int minutesFor(PlaceItem item) => (board?.durations ?? const PitchDurations())
      .minutesFor(item.kind, item.age);

  /// Puts an inbox item (or a matched event) on a pitch.
  Future<String?> place(
      PlaceItem item, Pitch pitch, DateTime start, DateTime end, int part,
      {String referee = '', String rooms = ''}) {
    final p = <String, dynamic>{
      'pitch_id': pitch.pitchId,
      'part': part,
      'starts_at': isoLocal(start),
      'ends_at': isoLocal(end),
      'kind': item.kind,
      'status': 'confirmed',
      if (referee.isNotEmpty) 'referee': referee,
      if (rooms.isNotEmpty) 'dressing_rooms': rooms,
    };
    if (item.request != null) {
      p['booking_id'] = item.request!.bookingId;
    } else if (item.event != null) {
      p['event_id'] = item.event!.eventId;
    } else if (item.fixture != null) {
      p['gaa_game_id'] = item.fixture!.gameId;
      p['title'] = item.title;
    }
    return run(() => api.saveBooking(club.clubId, p));
  }

  /// Marks an item as not on our pitches (away, or another venue).
  Future<String?> offsite(PlaceItem item) {
    final p = <String, dynamic>{
      'status': 'offsite',
      'starts_at': isoLocal(item.start),
      'ends_at': isoLocal(item.start.add(Duration(minutes: minutesFor(item)))),
      'kind': item.kind,
      'title': item.title,
      if (item.event != null) 'event_id': item.event!.eventId,
      if (item.fixture != null) 'gaa_game_id': item.fixture!.gameId,
      if (item.request != null) 'booking_id': item.request!.bookingId,
    };
    return run(() => api.saveBooking(club.clubId, p));
  }

  Future<String?> saveBooking(Map<String, dynamic> p) =>
      run(() => api.saveBooking(club.clubId, p));

  /// Moves a booking on the board straight away, then saves it. The week is
  /// reloaded afterwards, which also puts it back if the save fails.
  Future<String?> moveBooking(
      Booking b, int pitchId, int part, DateTime start, DateTime end) {
    final list = board?.bookings;
    final i = list?.indexWhere((x) => x.bookingId == b.bookingId) ?? -1;
    if (list != null && i >= 0) {
      list[i] = b.moved(pitchId, part, start, end);
      notifyListeners();
    }
    return run(() => api.saveBooking(club.clubId, {
          'booking_id': b.bookingId,
          'pitch_id': pitchId,
          'part': part,
          'starts_at': isoLocal(start),
          'ends_at': isoLocal(end),
          'following': true,
        }));
  }

  Future<String?> deleteBooking(Booking b, {bool following = true}) => run(
      () => api.deleteBooking(club.clubId, b.bookingId, following: following));

  Future<String?> closePitch(
          int pitchId, DateTime from, DateTime to, String reason) =>
      run(() => api.saveClosure(club.clubId, pitchId, from, to, reason));

  Future<String?> reopen(Closure c) =>
      run(() => api.deleteClosure(club.clubId, c.closureId));

  /// Puts a group (a team placeholder) on a pitch for training.
  Future<String?> placeGroup(
      PitchGroup g, Pitch pitch, DateTime start, DateTime end, int part) {
    // Show it on the board straight away; the reload brings the real one.
    final list = board?.bookings;
    if (list != null) {
      try {
        list.add(Booking(
            bookingId: -DateTime.now().millisecondsSinceEpoch,
            pitchId: pitch.pitchId,
            part: part,
            start: start,
            end: end,
            teamId: g.teamId,
            groupId: g.groupId));
        notifyListeners();
      } on UnsupportedError {
        // A fixed list (an empty board): just wait for the reload.
      }
    }
    return saveBooking({
      'group_id': g.groupId,
      'pitch_id': pitch.pitchId,
      'part': part,
      'starts_at': isoLocal(start),
      'ends_at': isoLocal(end),
      'kind': 'training',
      'status': 'confirmed',
    });
  }

  Future<String?> publish() => run(() => api.publishWeek(club.clubId, monday));

  Future<String?> syncGroups() => run(() => api.syncGroups(club.clubId));

  Future<String?> saveGroup(Map<String, dynamic> g) =>
      run(() => api.saveGroup(club.clubId, g));

  /// The words for a booking on the board.
  String titleOf(Booking b) {
    final grp = board?.group(b.groupId);
    if (b.eventId == null) {
      if (grp != null) {
        final t = b.title.trim();
        return t.isEmpty || t.toLowerCase() == grp.name.toLowerCase()
            ? grp.name
            : '${grp.name} · $t';
      }
      if (b.title.isNotEmpty) return b.title;
    }
    final g = grp?.name ?? (b.teamName.isEmpty ? b.title : group(b.teamName));
    if (b.kind == 'match' && b.opposition.isNotEmpty) {
      return '$g v ${b.opposition}';
    }
    return g.isEmpty ? (b.kind == 'match' ? 'Match' : 'Training') : g;
  }

  String titleOfEvent(BoardEvent e) {
    final g = group(e.teamName);
    return e.isMatch && e.opposition.isNotEmpty ? '$g v ${e.opposition}' : g;
  }

  PlaceItem itemOfEvent(BoardEvent e) => PlaceItem(
      title: titleOfEvent(e),
      subtitle: e.location.isEmpty ? '' : 'Location: ${e.location}',
      start: e.start,
      kind: e.kind,
      codeKey: codeOf(e.code, female: e.female),
      event: e,
      age: ageOf(e.teamName, season: season),
      teamId: e.teamId,
      matchedPitchId: e.matchedPitchId);
}
