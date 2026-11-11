// Backend calls for the games library, the same ones
// webviews/games-resource-v2.html makes:
//   users.default_club             -> my club (club games + edit gate)
//   clubs.club_name                -> the "club" tag on club games
//   games (kGameColumns)           -> public games + my club's games
//   rpc get_user_game_links        -> my favourite game ids
//   rpc toggle_user_game_link      -> add / remove a favourite
//   game_coach_notes               -> my private notes per game
//   fn generate-game-card-pdf      -> the PDF card (base64)
//   fn ai-process-game             -> update_game / delete_game
//
// Pages take a [V3GamesApi] so tests (and previews) can pass
// [V3OfflineGamesApi] and run with no network.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import 'v3_game_models.dart';
import '/v3/tracking/v3_track.dart';

/// Thrown by [V3GamesApi] calls with a message fit to show the coach.
class V3GamesError implements Exception {
  V3GamesError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What the edit form changes (the update_game payload).
class GameEdit {
  const GameEdit({
    required this.name,
    required this.codes,
    required this.types,
    required this.setup,
    required this.howToPlay,
    required this.variations,
    required this.teachingPoints,
    required this.video,
    this.imagePng,
    this.removeImage = false,
  });
  final String name;
  final List<String> codes, types;
  final String setup, howToPlay, variations, teachingPoints, video;

  /// A new picture (a sketch rendered to PNG), or null to keep the current.
  final Uint8List? imagePng;

  /// Remove the current picture (ignored when [imagePng] is set).
  final bool removeImage;
}

/// Live Supabase implementation. Subclass (or use [V3OfflineGamesApi]) to
/// fake it.
class V3GamesApi {
  const V3GamesApi();

  /// The signed-in auth user id.
  String get userId => currentUserUid;

  /// The signed-in email (for the game admin delete gate).
  String get userEmail => currentUserEmail;

  /// users.default_club for the signed-in user, or null.
  Future<int?> myClubId() async {
    if (userId.isEmpty) return null;
    final r = await SupaFlow.client
        .from('users')
        .select('default_club')
        .eq('user_id', userId)
        .maybeSingle();
    final v = r?['default_club'];
    return v is int ? v : int.tryParse('${v ?? ''}');
  }

  /// clubs.club_name, '' when unknown.
  Future<String> clubName(int clubId) async {
    try {
      final r = await SupaFlow.client
          .from('clubs')
          .select('club_name')
          .eq('club_id', clubId)
          .maybeSingle();
      return '${r?['club_name'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  /// Public games plus [clubId]'s games (never another club's).
  Future<List<V3Game>> games(int? clubId) async {
    // Hidden (low quality) games have is_active = false (Ken, 2026-11-11).
    final q = SupaFlow.client
        .from('games')
        .select(kGameColumns)
        .eq('is_active', true);
    final rows = clubId != null
        ? await q.or('club_id.is.null,club_id.eq.$clubId')
        : await q.isFilter('club_id', null);
    return parseGames(rows);
  }

  /// My favourite game ids.
  Future<Set<int>> favouriteIds() async =>
      parseFavouriteIds(await SupaFlow.client.rpc('get_user_game_links'));

  /// Flips a favourite on the server (the RPC toggles; it takes no state).
  Future<void> toggleFavourite(int gameId) async {
    await SupaFlow.client
        .rpc('toggle_user_game_link', params: {'p_game_id': gameId});
    V3Track.event('favourite_toggled', {'game_id': gameId});
  }

  /// My private coaching note for a game, '' when none.
  Future<String> note(int gameId) async {
    final r = await SupaFlow.client
        .from('game_coach_notes')
        .select('notes')
        .eq('game_id', gameId)
        .maybeSingle();
    return '${r?['notes'] ?? ''}';
  }

  /// Saves my note (upsert on game_id + user_id).
  Future<void> saveNote(int gameId, String notes) async {
    if (userId.isEmpty) throw V3GamesError('Could not save');
    await SupaFlow.client.from('game_coach_notes').upsert(
        {'game_id': gameId, 'user_id': userId, 'notes': notes},
        onConflict: 'game_id,user_id');
    V3Track.event('coach_note_saved', {'game_id': gameId});
  }

  /// The printable game card. Returns the PDF bytes and its file name.
  Future<(Uint8List, String)> gameCardPdf(int gameId) async {
    final r = await _invoke('generate-game-card-pdf',
        {'game_id': gameId, 'user_id': userId, 'platform': 'mobile'});
    final pdf = '${r['pdf'] ?? ''}';
    if (pdf.isEmpty) throw V3GamesError('No PDF came back');
    final name = '${r['filename'] ?? 'game-card.pdf'}';
    return (base64Decode(pdf), name);
  }

  /// Saves an edit of a club game. Returns the game as now stored.
  Future<V3Game> updateGame(V3Game g, GameEdit e) async {
    final payload = <String, dynamic>{
      'action': 'update_game',
      'game_id': g.gameId,
      'game_name': e.name,
      'game_code': e.codes,
      'game_type': e.types,
      'game_skill': g.skills,
      'game_age': g.ages,
      'game_setup': e.setup,
      'game_how_to_play': e.howToPlay,
      'game_variations': e.variations,
      'game_teaching_points': e.teachingPoints,
      'game_video': e.video,
    };
    if (e.imagePng != null) {
      payload['image_base64'] = base64Encode(e.imagePng!);
      payload['image_mime_type'] = 'image/png';
    } else if (e.removeImage) {
      payload['game_image_remove'] = true;
    }
    final r = await _invoke('ai-process-game', payload);
    if (r['success'] != true) {
      throw V3GamesError('${r['error'] ?? 'Save failed'}');
    }
    return applyEdit(g, e,
        newImage:
            r.containsKey('game_image') ? '${r['game_image'] ?? ''}' : null);
  }

  /// Deletes a game for everyone (the edge function checks the gate).
  Future<void> deleteGame(int gameId) async {
    final r = await _invoke(
        'ai-process-game', {'action': 'delete_game', 'game_id': gameId});
    if (r['success'] != true) {
      throw V3GamesError('${r['error'] ?? 'Delete failed'}');
    }
  }

  Future<Map<String, dynamic>> _invoke(
      String fn, Map<String, dynamic> body) async {
    V3Track.feature(fn, body['action']);
    try {
      final res = await SupaFlow.client.functions.invoke(fn, body: body);
      final d = res.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      if (d is String && d.isNotEmpty) {
        final j = jsonDecode(d);
        if (j is Map) return Map<String, dynamic>.from(j);
      }
      return {};
    } on FunctionException catch (e) {
      final det = e.details;
      final msg = det is Map ? det['error'] : null;
      throw V3GamesError(msg != null ? '$msg' : 'Server error ${e.status}');
    }
  }
}

/// The game as it looks after [e] is saved (newImage null = unchanged,
/// '' = removed).
V3Game applyEdit(V3Game g, GameEdit e, {String? newImage}) => g.copyWith(
      name: e.name,
      codes: e.codes,
      types: e.types,
      setup: e.setup,
      howToPlay: e.howToPlay,
      variations: e.variations,
      teachingPoints: e.teachingPoints,
      video: e.video,
      image: newImage ?? (e.removeImage && e.imagePng == null ? '' : null),
    );

/// In-memory [V3GamesApi] for widget tests and previews: no network, every
/// write succeeds and is kept in memory.
class V3OfflineGamesApi extends V3GamesApi {
  V3OfflineGamesApi({
    List<V3Game> games = const [],
    Set<int>? favourites,
    Map<int, String>? notes,
    this.clubId,
    this.club = '',
    this.uid = 'test-user',
    this.email = 'coach@example.com',
  })  : allGames = [...games],
        favourites = favourites ?? <int>{},
        notes = notes ?? <int, String>{};

  final List<V3Game> allGames;
  final Set<int> favourites;
  final Map<int, String> notes;
  final int? clubId;
  final String club;
  final String uid, email;

  /// Calls made, in order (for test assertions).
  final List<String> calls = [];

  @override
  String get userId => uid;
  @override
  String get userEmail => email;
  @override
  Future<int?> myClubId() async => clubId;
  @override
  Future<String> clubName(int clubId) async => club;
  @override
  Future<List<V3Game>> games(int? clubId) async => [
        for (final g in allGames)
          if (g.clubId == null || g.clubId == clubId) g
      ];
  @override
  Future<Set<int>> favouriteIds() async => {...favourites};
  @override
  Future<void> toggleFavourite(int gameId) async {
    calls.add('toggle:$gameId');
    if (!favourites.remove(gameId)) favourites.add(gameId);
  }

  @override
  Future<String> note(int gameId) async => notes[gameId] ?? '';
  @override
  Future<void> saveNote(int gameId, String text) async {
    calls.add('note:$gameId');
    notes[gameId] = text;
  }

  @override
  Future<(Uint8List, String)> gameCardPdf(int gameId) async {
    calls.add('pdf:$gameId');
    throw V3GamesError('Offline');
  }

  @override
  Future<V3Game> updateGame(V3Game g, GameEdit e) async {
    calls.add('update:${g.gameId}');
    final n = applyEdit(g, e,
        newImage: e.imagePng != null ? 'memory://${g.gameId}.png' : null);
    final i = allGames.indexWhere((x) => x.gameId == g.gameId);
    if (i >= 0) allGames[i] = n;
    return n;
  }

  @override
  Future<void> deleteGame(int gameId) async {
    calls.add('delete:$gameId');
    allGames.removeWhere((g) => g.gameId == gameId);
  }
}

/// My favourites, shared by every list and detail view on a page so hearts
/// stay in step. Toggling is optimistic: the heart flips at once and flips
/// back if the server call fails.
class V3GameFavourites extends ChangeNotifier {
  V3GameFavourites(this.api, [Set<int>? initial]) : _ids = {...?initial};

  final V3GamesApi api;
  final Set<int> _ids;

  Set<int> get ids => Set.unmodifiable(_ids);
  bool isFav(int gameId) => _ids.contains(gameId);

  /// Loads from the server; keeps what it has if that fails.
  Future<void> load() async {
    try {
      final s = await api.favouriteIds();
      _ids
        ..clear()
        ..addAll(s);
      notifyListeners();
    } catch (_) {}
  }

  /// Forgets a deleted game.
  void forget(int gameId) {
    if (_ids.remove(gameId)) notifyListeners();
  }

  /// Flips [gameId]. Returns the message to show, as the web page words it.
  Future<String> toggle(int gameId) async {
    final on = !_ids.contains(gameId);
    _set(gameId, on);
    try {
      await api.toggleFavourite(gameId);
      return on ? 'Added to favourites' : 'Removed from favourites';
    } catch (_) {
      _set(gameId, !on);
      return 'Could not save — please try again';
    }
  }

  void _set(int id, bool on) {
    on ? _ids.add(id) : _ids.remove(id);
    notifyListeners();
  }
}
