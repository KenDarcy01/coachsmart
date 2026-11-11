// Backend for the plan builder, the Plans list and the event's plan entry.
// No backend changes: the same generate-session-plan actions the two older
// plan screens call, plus three plain reads.
//   fn generate-session-plan   get, generate, save_plan, attach_plan,
//                              get_user_plans, get_club_plans, get_plan,
//                              set_plan_club, deactivate_plan
//   rpc get_my_ai_features     users.ai_features ("Write the plan for me")
//   rpc get_event_attendance_v3  players marked as attending
//   events (+ teams.team_name) the event a plan is for
//   session_plans (+ events)   my own plans; RLS lets the creator read them
//   games                      the picked games' own words for a simple plan
//
// Pages take a [V3PlanApi]; tests pass a fake subclass.
import '/backend/supabase/supabase.dart';
import '../games/v3_game_models.dart';
import '../session_plan/v3_session_plan_api.dart';
import '../session_plan/v3_session_plan_models.dart';
import 'v3_plan_models.dart';

class V3PlanApi {
  const V3PlanApi();

  /// The signed-in auth user id (the edge function takes user_id).
  String get userId => spUserId();

  /// One edge function call. Throws only when the network fails.
  Future<SpResult> call(String fn, Map<String, dynamic> body) =>
      spLiveCall(fn, body);

  /// Null in the app; a fake hands its [call] to the plan screen here.
  SpCall? get callOverride => null;

  /// Null in the app; a fake's user id for the plan screen.
  String? get userIdOverride => null;

  /// Null in the app; a fake's answer to "is AI on?" for the plan screen.
  Future<bool> Function()? get aiProbe => null;

  /// One generate-session-plan action; user_id is added.
  Future<SpResult> plan(Map<String, dynamic> body) =>
      call(kSpFn, {...body, 'user_id': userId});

  /// users.ai_features for the signed-in user. Off when it can't be read.
  Future<bool> aiFeatures() => spAiFeatures();

  /// The event with its team; null when it can't be read.
  Future<PlanEvent?> event(int eventId) async {
    final r = await SupaFlow.client
        .from('events')
        .select('event_id, event_title, event_date_time, event_date_time_2, '
            'team_id, teams!events_team_id_fkey(team_name)')
        .eq('event_id', eventId)
        .maybeSingle();
    return r == null ? null : PlanEvent.fromJson(r);
  }

  /// Players marked as attending the event; null when nobody has replied.
  Future<int?> attending(int eventId) async =>
      attendingPlayers(await SupaFlow.client
          .rpc('get_event_attendance_v3', params: {'p_event_id': eventId}));

  /// My own active plans, newest first, each with its event when it has
  /// one (the rows [eventPlanItems] and [reusablePlanItems] read).
  Future<List<dynamic>> myPlanRows() async {
    if (userId.isEmpty) return const [];
    return await SupaFlow.client
        .from('session_plans')
        .select('plan_id, session_title, created_at, event_id, plan_json, '
            'events!session_plans_event_id_fkey(event_id, event_title, '
            'event_date_time, event_date_time_2, team_id, '
            'teams!events_team_id_fkey(team_name))')
        .eq('created_by', userId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(60);
  }

  /// The games picked for a plan, with their text, picture and video.
  Future<List<V3Game>> gamesByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    return parseGames(await SupaFlow.client
        .from('games')
        .select(kGameColumns)
        .inFilter('game_id', ids));
  }
}
