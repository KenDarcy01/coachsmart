// Writes a member's squad for v3 (see v3_squads.dart for Unassigned).
import '/backend/supabase/supabase.dart';

/// Put a member in a squad for one code. [squadId] 0 = Unassigned: the
/// team's No Team squad, or no squad when the team has none.
Future<void> v3SetMemberSquad(
    {required int memberId,
    required int teamId,
    required int codeId,
    required int squadId}) async {
  var target = squadId;
  if (target == 0) {
    final nt = await SquadsTable().queryRows(
        queryFn: (q) =>
            q.eq('team_id', teamId).eq('squad_name', 'No Team').limit(1));
    if (nt.isNotEmpty) target = nt.first.squadId;
  }
  final existing = await MemberSquadLinkTable().queryRows(
      queryFn: (q) => q
          .eq('member_id', memberId)
          .eq('team_id', teamId)
          .eq('code_id', codeId));
  if (existing.isNotEmpty) {
    if (target == 0) {
      await MemberSquadLinkTable().delete(
          matchingRows: (q) =>
              q.eq('member_squad_id', existing.first.memberSquadId));
    } else {
      await MemberSquadLinkTable().update(
          data: {'squad_id': target},
          matchingRows: (q) =>
              q.eq('member_squad_id', existing.first.memberSquadId));
    }
  } else if (target != 0) {
    await MemberSquadLinkTable().insert({
      'member_id': memberId,
      'squad_id': target,
      'code_id': codeId,
      'team_id': teamId,
    });
  }
}
