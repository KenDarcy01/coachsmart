// The backend calls of the Join Team flow, the same ones
// webviews/join-team.html makes. Kept behind a small class so widget tests
// can pass a fake and run without a network.

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';

class JoinTeamApi {
  const JoinTeamApi();

  /// The signed-in user's first and last name (users table) and email.
  Future<({String firstName, String lastName, String email})> me() async {
    final rows = await SupaFlow.client
        .from('users')
        .select('user_id, first_name, last_name')
        .eq('user_id', currentUserUid)
        .maybeSingle();
    return (
      firstName: '${rows?['first_name'] ?? ''}',
      lastName: '${rows?['last_name'] ?? ''}',
      email: currentUserEmail,
    );
  }

  Future<dynamic> teamByCode(String code) =>
      SupaFlow.client.rpc('get_team_by_code', params: {'p_joining_code': code});

  Future<dynamic> createMemberByCode(
          {required String firstName,
          required String lastName,
          required String code}) =>
      SupaFlow.client.rpc('create_new_member_by_code', params: {
        'p_first_name': firstName,
        'p_last_name': lastName,
        'p_joining_code': code,
      });

  Future<dynamic> requestMemberAccess(int memberId, String code) =>
      SupaFlow.client.rpc('request_member_access',
          params: {'p_member_id': memberId, 'p_joining_code': code});

  Future<dynamic> lookupMemberByCode(String memberCode) =>
      SupaFlow.client.rpc('lookup_member_by_code',
          params: {'p_unique_member_code': memberCode});

  /// request-new-team edge function. Throws with the function's own error
  /// text when it answers with a failure.
  Future<void> requestNewTeam(Map<String, dynamic> body) async {
    try {
      await SupaFlow.client.functions.invoke('request-new-team', body: body);
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['error'] != null ? '${d['error']}' : null;
      throw JoinTeamError(msg ?? 'Something went wrong');
    }
  }
}

/// A failure whose text is shown to the user as is.
class JoinTeamError implements Exception {
  const JoinTeamError(this.message);
  final String message;
  @override
  String toString() => message;
}
