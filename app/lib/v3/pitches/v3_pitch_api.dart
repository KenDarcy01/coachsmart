// v3 Pitch planner: the calls the pages make (all checked functions; only
// club officers get through). Tests pass a fake.
import '/backend/supabase/supabase.dart';

import '/v3/auth/v3_auth_service.dart';

import 'v3_pitch_models.dart';

class PitchApi {
  const PitchApi();

  Future<dynamic> _rpc(String fn, Map<String, dynamic> params) =>
      SupaFlow.client.rpc(fn, params: params);

  /// Signed in to CoachSmart (the club's own sign-in screen shows if not).
  bool get signedIn => SupaFlow.client.auth.currentUser != null;

  Future<String?> signIn(String email, String password) =>
      V3AuthService.signIn(email, password);

  Future<String?> sendReset(String email) =>
      V3AuthService.sendRecoveryCode(email);

  Future<void> signOut() => SupaFlow.client.auth.signOut();

  /// The club's name, crest and colours, for its sign-in screen.
  Future<PitchClub?> brand(int clubId) async {
    final r = await _rpc('club_brand', {'p_club': clubId});
    return r is Map ? PitchClub.fromJson(r) : null;
  }

  String _d(DateTime d) => isoLocal(dayOf(d)).substring(0, 10);

  /// Clubs the signed-in user can plan pitches for.
  Future<List<PitchClub>> clubs() async {
    // Officers with the "Pitch planner" tick (Ken, 2026-11-18); older
    // database: every officer.
    try {
      final r = await _rpc('pitch_officer_clubs', {});
      if (r is List) {
        return [for (final c in r.whereType<Map>()) PitchClub.fromJson(c)];
      }
    } catch (_) {}
    final r = await _rpc('get_my_officer_clubs', {});
    // The function returns {clubs: [...], is_super_user}; accept a bare
    // list too.
    final list = r is Map ? r['clubs'] : r;
    return [
      if (list is List)
        for (final c in list.whereType<Map>()) PitchClub.fromJson(c)
    ];
  }

  Future<PitchBoard> board(int clubId, DateTime from, DateTime to) async {
    final r = await _rpc('pitch_board_v2',
        {'p_club': clubId, 'p_from': _d(from), 'p_to': _d(to)});
    // Times marked not available (shaded on the board); none if not set up.
    dynamic blocks;
    try {
      blocks = await _rpc('pitch_blocks_get', {'p_club': clubId});
    } catch (_) {}
    return PitchBoard.fromJson(
        {...(r is Map ? r : const {}), if (blocks is List) 'blocks': blocks});
  }

  /// (pitch id, block): every "not available" time at the club.
  Future<List<(int, PitchBlock)>> blocks(int clubId) async {
    final r = await _rpc('pitch_blocks_get', {'p_club': clubId});
    return PitchBoard.fromJson({'blocks': r is List ? r : const []}).blocks;
  }

  /// Replaces every "not available" time of one pitch.
  /// Insights for a period (Ken, 2026-11-20).
  Future<Map> insights(int clubId, DateTime from, DateTime to) async {
    final r = await _rpc('pitch_insights',
        {'p_club': clubId, 'p_from': _d(from), 'p_to': _d(to)});
    return r is Map ? r : const {};
  }

  /// What the club pays per hour for a rented pitch (null clears it).
  Future<void> saveCost(int clubId, int pitchId, double? cost) => _rpc(
      'pitch_cost_save',
      {'p_club': clubId, 'p_pitch': pitchId, 'p_cost': cost});

  Future<void> saveBlocks(int clubId, int pitchId, List<PitchBlock> blocks) =>
      _rpc('pitch_blocks_save', {
        'p_club': clubId,
        'p_pitch': pitchId,
        'p_blocks': [for (final b in blocks) b.toJson()]
      });

  /// group id -> its default for home matches.
  Future<Map<int, GroupHome>> groupHomes(int clubId) async {
    final r = await _rpc('pitch_group_homes_get', {'p_club': clubId});
    return {
      if (r is List)
        for (final x in r.whereType<Map>())
          int.tryParse('${x['group_id']}') ?? 0: GroupHome.fromJson(x)
    };
  }

  Future<void> saveGroupHome(int clubId, int groupId, GroupHome? h) =>
      _rpc('pitch_group_home_save', {
        'p_club': clubId,
        'p_group': groupId,
        'p_pitch': h?.pitchId,
        'p_day': h?.day,
        'p_time': h?.time == null ? '' : hhmm(h!.time!),
      });

  /// Saves bookings worked out from the defaults, flagged auto.
  Future<Map> autofill(int clubId, List<Map<String, dynamic>> items) async {
    final r =
        await _rpc('pitch_autofill_save', {'p_club': clubId, 'p_items': items});
    return r is Map ? r : const {};
  }

  /// Ids of the week's auto-filled bookings not yet changed or kept.
  Future<Set<int>> autoIds(int clubId, DateTime monday) async {
    final r = await _rpc(
        'pitch_auto_ids', {'p_club': clubId, 'p_monday': _d(monday)});
    return {
      if (r is List)
        for (final x in r) int.tryParse('$x') ?? 0
    };
  }

  Future<void> autofillAccept(int clubId, DateTime monday) =>
      _rpc('pitch_autofill_accept', {'p_club': clubId, 'p_monday': _d(monday)});

  Future<void> autofillUndo(int clubId, DateTime monday) =>
      _rpc('pitch_autofill_undo', {'p_club': clubId, 'p_monday': _d(monday)});

  /// Copies last week's training into the week starting [monday] (once).
  Future<int> rollWeek(int clubId, DateTime monday) async {
    final r = await _rpc(
        'pitch_roll_week', {'p_club': clubId, 'p_monday': _d(monday)});
    return r is int ? r : int.tryParse('$r') ?? 0;
  }

  Future<PitchSetup> setup(int clubId) async {
    final r = await _rpc('pitch_setup', {'p_club': clubId});
    return PitchSetup.fromJson(r is Map ? r : const {});
  }

  Future<void> saveVenue(int clubId, Map<String, dynamic> venue) =>
      _rpc('pitch_venue_save', {'p_club': clubId, 'p': venue});

  Future<void> savePitch(int clubId, Map<String, dynamic> pitch) =>
      _rpc('pitch_save', {'p_club': clubId, 'p': pitch});

  Future<void> saveDurations(int clubId, PitchDurations d) => _rpc(
      'pitch_settings_save', {'p_club': clubId, 'p_durations': d.toJson()});

  Future<void> saveClosure(
          int clubId, int pitchId, DateTime from, DateTime to, String reason) =>
      _rpc('pitch_closure_save', {
        'p_club': clubId,
        'p': {
          'pitch_id': pitchId,
          'starts_on': _d(from),
          'ends_on': _d(to),
          'reason': reason
        }
      });

  Future<List<ClosureGroup>> closureGroups(int clubId) async {
    final r = await _rpc('pitch_closure_groups_get', {'p_club': clubId});
    return [
      if (r is List)
        for (final x in r.whereType<Map>()) ClosureGroup.fromJson(x)
    ];
  }

  Future<void> saveClosureGroup(
          int clubId, int? groupId, String name, List<int> pitchIds) =>
      _rpc('pitch_closure_group_save', {
        'p_club': clubId,
        'p_group': groupId,
        'p_name': name,
        'p_pitches': pitchIds
      });

  Future<void> deleteClosureGroup(int clubId, int groupId) => _rpc(
      'pitch_closure_group_delete', {'p_club': clubId, 'p_group': groupId});

  Future<void> closeGroup(
          int clubId, int groupId, DateTime from, DateTime to, String reason) =>
      _rpc('pitch_closure_group_close', {
        'p_club': clubId,
        'p_group': groupId,
        'p_from': _d(from),
        'p_to': _d(to),
        'p_reason': reason
      });

  Future<void> deleteClosure(int clubId, int closureId) =>
      _rpc('pitch_closure_delete', {'p_club': clubId, 'p_closure': closureId});

  Future<void> saveBooking(int clubId, Map<String, dynamic> booking) =>
      _rpc('pitch_booking_save_v2', {'p_club': clubId, 'p': booking});

  Future<void> saveGroup(int clubId, Map<String, dynamic> group) =>
      _rpc('pitch_group_save', {'p_club': clubId, 'p': group});

  /// Adds a group for each CoachSmart team that has none; returns how many.
  Future<int> syncGroups(int clubId) async {
    final r = await _rpc('pitch_groups_sync', {'p_club': clubId});
    return r is int ? r : int.tryParse('$r') ?? 0;
  }

  Future<void> publishWeek(int clubId, DateTime monday) =>
      _rpc('pitch_publish_week', {'p_club': clubId, 'p_monday': _d(monday)});

  /// Clubs whose published pitch plan the user can read (members).
  Future<List<PitchClub>> memberClubs() async {
    final r = await _rpc('pitch_member_clubs', {});
    return [
      if (r is List)
        for (final c in r.whereType<Map>()) PitchClub.fromJson(c)
    ];
  }

  /// The week's matches: official (league feed) and CoachSmart-only.
  Future<Map> fixturesWeek(int clubId, DateTime monday) async {
    final r = await _rpc(
        'pitch_fixtures_week', {'p_club': clubId, 'p_monday': _d(monday)});
    return r is Map ? r : const {};
  }

  /// Changes seen in the league fixtures (newest first) and the unread count.
  Future<Map> fixtureChanges(int clubId) async {
    final r = await _rpc('pitch_alerts_get', {'p_club': clubId});
    return r is Map ? r : const {};
  }

  Future<void> fixtureChangesSeen(int clubId) =>
      _rpc('pitch_alerts_seen', {'p_club': clubId});

  Future<Map> publishedWeek(int clubId, DateTime monday) async {
    final r = await _rpc(
        'pitch_published_week', {'p_club': clubId, 'p_monday': _d(monday)});
    return r is Map ? r : const {};
  }

  Future<void> deleteBooking(int clubId, int bookingId,
          {bool following = true}) =>
      _rpc('pitch_booking_delete',
          {'p_club': clubId, 'p_booking': bookingId, 'p_following': following});
}

/// A readable message for a failed call.
String pitchErrorText(Object e) {
  final s = '$e';
  final m = RegExp(r'message: ([^,}]+)').firstMatch(s);
  final msg = (m?.group(1) ?? s).trim();
  if (msg.contains('Only club')) return 'Only club officers can do that.';
  if (msg.contains('SocketException') || msg.contains('Failed host')) {
    return 'No connection. Try again.';
  }
  return msg.length > 160 ? 'Something went wrong. Try again.' : msg;
}
