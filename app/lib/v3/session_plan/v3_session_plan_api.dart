// Session plan backend: the same two edge functions webviews/session-plan.html
// calls.
//   generate-session-plan      get, generate, revise_plan, update_plan,
//                              save_plan, get_user_plans, get_club_plans,
//                              get_plan, attach_plan, set_plan_club,
//                              upload_session_image, remove_session_image,
//                              get_game
//   generate-session-plan-pdf  the A4 overview or the phone share (base64)
// Favourites, coach notes and the game card PDF go through the shared games
// library (V3GamesApi), which uses the same tables and RPC.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/v3/tracking/v3_track.dart';

/// A call's outcome: [ok] for a 2xx reply, [data] the decoded JSON body
/// (also on errors, so the server's message can be shown).
class SpResult {
  const SpResult(this.ok, this.data);
  final bool ok;
  final dynamic data;

  Map<String, dynamic> get map => data is Map
      ? Map<String, dynamic>.from(data as Map)
      : <String, dynamic>{};
}

/// Calls edge function [fn] with [body]. Tests pass a fake.
typedef SpCall = Future<SpResult> Function(
    String fn, Map<String, dynamic> body);

dynamic _decode(dynamic d) {
  if (d is String && d.isNotEmpty) {
    try {
      return jsonDecode(d);
    } catch (_) {
      return d;
    }
  }
  return d;
}

/// The live call: supabase functions.invoke, which sends the session token.
Future<SpResult> spLiveCall(String fn, Map<String, dynamic> body) async {
  V3Track.feature(fn, body['action']);
  try {
    final res = await SupaFlow.client.functions.invoke(fn, body: body);
    return SpResult(res.status >= 200 && res.status < 300, _decode(res.data));
  } on FunctionException catch (e) {
    return SpResult(false, _decode(e.details));
  }
}

/// The signed-in user (the edge function takes user_id in the body).
String spUserId() => currentUserUid;

/// users.ai_features for the signed-in user ("Write the plan for me" and
/// "Tell me what to change"). Off when it can't be read.
Future<bool> spAiFeatures() async {
  try {
    return await SupaFlow.client.rpc('get_my_ai_features') == true;
  } catch (_) {
    return false;
  }
}

/// Bumped whenever a plan is saved, attached, shared or removed, so the
/// Plans list reloads.
final ValueNotifier<int> spPlansChanged = ValueNotifier<int>(0);
