// Backend calls for Favourites and session plans, the same ones
// webviews/favourites.html (main) makes:
//   rpc get_my_ai_features            -> the users.ai_features gate
//   rpc toggle_user_game_link         -> remove / add back a favourite
//   fn generate-session-plan          -> every `action` (get, get_game,
//                                        save_coach_note, generate,
//                                        revise_plan, save_plan, update_plan,
//                                        set_plan_club, get_user_plans,
//                                        get_club_plans, get_plan,
//                                        deactivate_plan, attach_plan)
//   fn generate-game-card-pdf         -> game cards (platform mobile | web)
//   fn generate-session-plan-pdf      -> the plan (format mobile | a4)
//
// Pages take a [V3FavouritesApi]; tests pass [V3OfflineFavouritesApi].
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';

/// An edge function's answer: [ok] is false for a non-2xx status, and
/// [data] then holds the error body (`error`, `message`, `refusal`...).
class FavResult {
  const FavResult(this.ok, this.data);
  final bool ok;
  final Map<String, dynamic> data;

  String? get error => data['error'] == null ? null : '${data['error']}';
}

/// PDF layout: one column sized for a phone, or A4 pages to print.
enum PdfLayout { phone, a4 }

class V3FavouritesApi {
  const V3FavouritesApi();

  /// The signed-in auth user id (the page's user_id).
  String get userId => currentUserUid;

  /// users.ai_features for the signed-in user. Off when it can't be read.
  Future<bool> aiFeatures() async {
    try {
      return await SupaFlow.client.rpc('get_my_ai_features') == true;
    } catch (_) {
      return false;
    }
  }

  /// Flips a favourite (the RPC toggles). False when the call failed.
  Future<bool> toggleFavourite(int gameId) async {
    try {
      await SupaFlow.client
          .rpc('toggle_user_game_link', params: {'p_game_id': gameId});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One generate-session-plan call; user_id is added. Throws only on a
  /// network failure (the page's "Network error").
  Future<FavResult> plan(String action, [Map<String, dynamic>? body]) => invoke(
      'generate-session-plan', {'action': action, 'user_id': userId, ...?body});

  /// Game cards for the picked games (Export Games), or for one game
  /// ([single], the quick look's Export Game Card).
  Future<(Uint8List, String)> gameCardsPdf(List<int> gameIds,
      {PdfLayout layout = PdfLayout.phone, bool single = false}) async {
    final r = await invoke('generate-game-card-pdf', {
      if (single) 'game_id': gameIds.first else 'game_ids': gameIds,
      'user_id': userId,
      'platform': layout == PdfLayout.phone ? 'mobile' : 'web',
    });
    return _pdf(r, 'game-cards.pdf');
  }

  /// The session plan PDF (with the coach's edits).
  Future<(Uint8List, String)> planPdf(Map<String, dynamic> plan,
      {PdfLayout layout = PdfLayout.phone}) async {
    final r = await invoke('generate-session-plan-pdf', {
      'plan_json': plan,
      'user_id': userId,
      'format': layout == PdfLayout.phone ? 'mobile' : 'a4',
    });
    return _pdf(r, 'session-plan.pdf');
  }

  (Uint8List, String) _pdf(FavResult r, String fallback) {
    final pdf = '${r.data['pdf'] ?? ''}';
    if (!r.ok || pdf.isEmpty) throw Exception('Server error');
    return (base64Decode(pdf), '${r.data['filename'] ?? fallback}');
  }

  Future<FavResult> invoke(String fn, Map<String, dynamic> body) async {
    try {
      final res = await SupaFlow.client.functions.invoke(fn, body: body);
      return FavResult(true, _map(res.data));
    } on FunctionException catch (e) {
      return FavResult(false, _map(e.details));
    }
  }

  static Map<String, dynamic> _map(dynamic d) {
    if (d is Map) return Map<String, dynamic>.from(d);
    if (d is String && d.isNotEmpty) {
      try {
        final j = jsonDecode(d);
        if (j is Map) return Map<String, dynamic>.from(j);
      } catch (_) {}
    }
    return {};
  }
}

/// In-memory [V3FavouritesApi] for widget tests and previews. Each
/// generate-session-plan action is answered by [answers] (a fixed result or
/// a function of the body); anything else answers `{}`.
class V3OfflineFavouritesApi extends V3FavouritesApi {
  V3OfflineFavouritesApi({
    this.ai = false,
    Map<String, Object>? answers,
    this.uid = 'test-user',
  }) : answers = answers ?? {};

  final bool ai;
  final String uid;

  /// action -> FavResult, Map (an ok result) or FavResult Function(Map body).
  final Map<String, Object> answers;

  /// Calls made, in order ('toggle:12', 'plan:get', 'pdf:cards:1,2'...).
  final List<String> calls = [];

  /// Bodies of the generate-session-plan calls, in order.
  final List<Map<String, dynamic>> bodies = [];

  @override
  String get userId => uid;

  @override
  Future<bool> aiFeatures() async => ai;

  @override
  Future<bool> toggleFavourite(int gameId) async {
    calls.add('toggle:$gameId');
    return true;
  }

  @override
  Future<FavResult> plan(String action, [Map<String, dynamic>? body]) async {
    final b = {'action': action, 'user_id': userId, ...?body};
    calls.add('plan:$action');
    bodies.add(b);
    final a = answers[action];
    if (a is FavResult) return a;
    if (a is Map) return FavResult(true, Map<String, dynamic>.from(a));
    if (a is FavResult Function(Map<String, dynamic>)) return a(b);
    return const FavResult(true, {});
  }

  @override
  Future<(Uint8List, String)> gameCardsPdf(List<int> gameIds,
      {PdfLayout layout = PdfLayout.phone, bool single = false}) async {
    calls.add('pdf:cards:${gameIds.join(',')}:${layout.name}');
    throw Exception('Offline');
  }

  @override
  Future<(Uint8List, String)> planPdf(Map<String, dynamic> plan,
      {PdfLayout layout = PdfLayout.phone}) async {
    calls.add('pdf:plan:${layout.name}');
    throw Exception('Offline');
  }
}
