// Supabase reads and writes for the v3 lineup. The same tables and filters
// as webviews/team_selector.html (initFromParams, loadExistingLineup and
// persistLineup), so both pages see the same lineups.
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import 'v3_lineup_models.dart';

SupabaseClient get _sb => SupaFlow.client;

/// Builds the map [LineupData.fromJson] reads. A 'message' key means there
/// is nobody to pick from; the wording is the web page's.
Future<Map<String, dynamic>> fetchLineupJson(
    {required int eventId, required int teamId, int? squadId}) async {
  final sq = (squadId ?? 0) > 0 ? squadId : null;
  final out = <String, dynamic>{};

  // Team name, teamsheet flag and club colours in one call.
  List team;
  try {
    team = await _sb
        .from('teams')
        .select(
            'team_name,teamsheet,clubs(primary_colour,secondary_colour,third_colour)')
        .eq('team_id', teamId);
  } catch (_) {
    team = await _sb
        .from('teams')
        .select('team_name,teamsheet')
        .eq('team_id', teamId);
  }
  if (team.isNotEmpty) {
    final t = team.first as Map;
    out['team_name'] = t['team_name'];
    out['teamsheet'] = t['teamsheet'];
    out['club'] = t['clubs'];
  }

  final ev = await _sb
      .from('events')
      .select(
          'event_date_time,opposition,event_codes(event_code),event_types(event_type)')
      .eq('event_id', eventId);
  if (ev.isNotEmpty) {
    final e = ev.first;
    final when = DateTime.tryParse('${e['event_date_time']}')?.toLocal();
    out['image_sub'] = imageSubtitle(
        '${(e['event_codes'] as Map?)?['event_code'] ?? ''}',
        '${(e['event_types'] as Map?)?['event_type'] ?? ''}',
        when);
  }

  // Latest published match day squad for this event.
  final ms = await _sb
      .from('match_squads')
      .select('match_squad_id')
      .eq('event_id', eventId)
      .order('match_squad_id', ascending: false)
      .limit(1);
  if (ms.isEmpty) {
    return out..['message'] = 'No match squad set up for this event';
  }
  var detQ = _sb
      .from('match_squad_details')
      .select('id,member_id')
      .eq('match_squad_id', ms.first['match_squad_id']);
  if (sq != null) detQ = detQ.eq('squad_id', sq);
  final squadIds = latestMemberIds(await detQ.order('id', ascending: false));
  if (squadIds.isEmpty) {
    return out..['message'] = 'No players found in match squad';
  }

  final att = await _sb
      .from('event_attendance')
      .select('member_id,response_id,created_at')
      .eq('event_id', eventId)
      .inFilter('member_id', squadIds)
      .order('member_id')
      .order('created_at', ascending: false);
  final attending = attendingMemberIds(att);
  if (attending.isEmpty) {
    return out..['message'] = 'No players have accepted for this event';
  }

  // Players only (role_level 10).
  final roles = await _sb
      .from('member_team_link')
      .select('member_id,member_team_role_link(roles(role_level))')
      .eq('team_id', teamId)
      .inFilter('member_id', attending);
  final playerIds = membersWithRoleLevel(roles, {10});
  final eligible = attending.where(playerIds.contains).toList();
  if (eligible.isEmpty) {
    return out..['message'] = 'No eligible players found';
  }
  final mem = await _sb
      .from('members')
      .select('member_id,first_name,last_name')
      .inFilter('member_id', eligible);
  final players = [
    for (final m in mem) {'member_id': m['member_id'], 'name': fullName(m)}
  ];

  // Newest saved lineup for this event, team and squad.
  try {
    var lq = _sb
        .from('lineup')
        .select()
        .eq('event_id', eventId)
        .eq('team_id', teamId);
    lq = sq != null ? lq.eq('squad_id', sq) : lq.isFilter('squad_id', null);
    final rows = await lq.order('lineup_id', ascending: false).limit(1);
    if (rows.isNotEmpty) {
      final details = await _sb
          .from('lineup_details')
          .select()
          .eq('lineup_id', rows.first['lineup_id']);
      out['lineup'] = {'format': rows.first['format'], 'details': details};
      // member_team_link is RLS-limited, so saved players may be missing
      // from the list: add those still in this squad (as the web page does).
      final known = players.map((p) => p['member_id']).toSet();
      final missing = [
        for (final d in details)
          if (!known.contains(d['member_id']) &&
              squadIds.contains(d['member_id']))
            d['member_id'] as int
      ];
      if (missing.isNotEmpty) {
        final extra = await _sb
            .from('members')
            .select('member_id,first_name,last_name')
            .inFilter('member_id', missing.toSet().toList());
        for (final m in extra) {
          players.add({'member_id': m['member_id'], 'name': fullName(m)});
        }
      }
    }
  } catch (_) {
    // As on the web: a lineup that won't load just starts empty.
  }
  out['players'] = players;
  return out;
}

/// Saves the board as a new version (the newest one loads next time).
Future<void> saveLineup(LineupBoard b,
    {required int eventId, required int teamId, int? squadId}) async {
  final row = await _sb
      .from('lineup')
      .insert({
        'event_id': eventId,
        'team_id': teamId,
        'squad_id': (squadId ?? 0) > 0 ? squadId : null,
        'format': b.format,
        'created_by': currentUserUid.isEmpty ? null : currentUserUid,
      })
      .select()
      .single();
  final details = b.details(row['lineup_id'] as int);
  if (details.isNotEmpty) await _sb.from('lineup_details').insert(details);
}
