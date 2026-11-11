// v3 Onboarding: every Supabase call webviews/onboarding.html makes, behind
// one interface so widget tests can swap in a fake.
import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import 'v3_onboarding_models.dart';

abstract class OnboardingBackend {
  String get userId;
  String get email;

  /// users row (user_id, first_name, last_name) or null when there is none.
  /// Throws when the query fails.
  Future<Map<String, dynamic>?> loadUser();

  /// member_id of every active user_member_link row of this user.
  Future<List<dynamic>> ownedMembers();

  /// True when any of [memberIds] has an active member_team_link.
  Future<bool> hasActiveTeamLink(List<int> memberIds);

  /// Pending member_team_link rows with teams(team_name) and
  /// members(first_name, last_name).
  Future<List<dynamic>> pendingJoinRequests(List<int> memberIds);

  /// Pending user_member_link rows of this user with the member's name and
  /// team links.
  Future<List<dynamic>> pendingAccessRequests();

  Future<void> saveDetails(String firstName, String lastName);
  Future<dynamic> teamByCode(String code);
  Future<dynamic> createMemberByCode(
      String firstName, String lastName, String code);
  Future<dynamic> requestMemberAccess(int memberId, String code);
  Future<dynamic> lookupMemberByCode(String memberCode);
  Future<void> updateOnboardingStatus(String status);

  /// request-new-team. Returns null when sent, else the message to show.
  Future<String?> requestNewTeam(Map<String, dynamic> body);

  /// users.onboarding_status, live (the wrapper's Continue button).
  Stream<String?> onboardingStatus();
}

class SupabaseOnboardingBackend implements OnboardingBackend {
  SupabaseClient get _sb => SupaFlow.client;

  @override
  String get userId => currentUserUid;

  @override
  String get email => currentUserEmail;

  @override
  Future<Map<String, dynamic>?> loadUser() async {
    final r = await _sb
        .from('users')
        .select('user_id, first_name, last_name')
        .eq('user_id', userId)
        .maybeSingle();
    return r == null ? null : Map<String, dynamic>.from(r);
  }

  @override
  Future<List<dynamic>> ownedMembers() async {
    try {
      return await _sb
          .from('user_member_link')
          .select('member_id')
          .eq('user_id', userId)
          .eq('status', 'active');
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> hasActiveTeamLink(List<int> memberIds) async {
    if (memberIds.isEmpty) return false;
    try {
      final r = await _sb
          .from('member_team_link')
          .select('member_team_id')
          .inFilter('member_id', memberIds)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();
      return r != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<dynamic>> pendingJoinRequests(List<int> memberIds) async {
    if (memberIds.isEmpty) return const [];
    try {
      return await _sb
          .from('member_team_link')
          .select('member_id, teams(team_name), members(first_name, last_name)')
          .inFilter('member_id', memberIds)
          .eq('status', 'pending');
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<dynamic>> pendingAccessRequests() async {
    try {
      return await _sb
          .from('user_member_link')
          .select('user_member_id, members(first_name, last_name, '
              'member_team_link(status, teams(team_name)))')
          .eq('user_id', userId)
          .eq('status', 'pending');
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveDetails(String firstName, String lastName) async {
    await _sb.rpc('save_onboarding_details', params: {
      'p_user_id': userId,
      'p_email': email,
      'p_first_name': firstName,
      'p_last_name': lastName,
    });
  }

  @override
  Future<dynamic> teamByCode(String code) =>
      _sb.rpc('get_team_by_code', params: {'p_joining_code': code});

  @override
  Future<dynamic> createMemberByCode(
          String firstName, String lastName, String code) =>
      _sb.rpc('create_new_member_by_code', params: {
        'p_first_name': firstName,
        'p_last_name': lastName,
        'p_joining_code': code,
      });

  @override
  Future<dynamic> requestMemberAccess(int memberId, String code) =>
      _sb.rpc('request_member_access',
          params: {'p_member_id': memberId, 'p_joining_code': code});

  @override
  Future<dynamic> lookupMemberByCode(String memberCode) =>
      _sb.rpc('lookup_member_by_code',
          params: {'p_unique_member_code': memberCode});

  @override
  Future<void> updateOnboardingStatus(String status) async {
    try {
      await _sb
          .from('users')
          .update({'onboarding_status': status}).eq('user_id', userId);
    } catch (_) {}
  }

  @override
  Future<String?> requestNewTeam(Map<String, dynamic> body) async {
    try {
      await _sb.functions.invoke('request-new-team', body: body);
      return null;
    } on FunctionException catch (e) {
      return obNewTeamError(e.details);
    } catch (_) {
      return 'Could not send request — please try again.';
    }
  }

  @override
  Stream<String?> onboardingStatus() => _sb
      .from('users')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', userId)
      .map((rows) =>
          rows.isEmpty ? null : rows.first['onboarding_status'] as String?);
}
