// The plan a coach is building right now: an ordered list of games, each
// with its minutes, and (optionally) the event it is for. One shared
// instance for the whole app, so the + on any game card, the green "N games
// in your plan" bar and the plan builder all see the same thing
// (Coaching tab proposal, approved by Ken 2026-11-11).
//
// Kept on the phone (SharedPreferences) so a half-built plan survives
// closing the app. Nothing here talks to the server.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The most games a plan can hold (the server's plan writer takes up to 10).
const int kPlanMaxGames = 10;

/// Minutes a game gets when it is first added.
const int kPlanDefaultGameMins = 10;

class PlanDraftGame {
  const PlanDraftGame(this.gameId, this.name, this.mins);
  final int gameId;
  final String name;
  final int mins;

  PlanDraftGame withMins(int m) => PlanDraftGame(gameId, name, m);

  Map<String, dynamic> toJson() => {'id': gameId, 'name': name, 'mins': mins};

  static PlanDraftGame? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'];
    if (id is! int) return null;
    final mins = j['mins'];
    return PlanDraftGame(
        id, '${j['name'] ?? ''}', mins is int ? mins : kPlanDefaultGameMins);
  }
}

class V3PlanDraft extends ChangeNotifier {
  V3PlanDraft({this.persist = true});

  /// The app's one draft. Tests make their own with `persist: false`.
  static final V3PlanDraft instance = V3PlanDraft();

  static const _key = 'v3_plan_draft';

  final bool persist;
  final List<PlanDraftGame> _games = [];
  int? _eventId;
  bool _loaded = false;

  List<PlanDraftGame> get games => List.unmodifiable(_games);
  int get count => _games.length;
  bool get isEmpty => _games.isEmpty;
  bool get isFull => _games.length >= kPlanMaxGames;

  /// The event this plan is being built for; null for a reusable plan.
  int? get eventId => _eventId;

  /// Minutes across all games.
  int get totalMins => _games.fold(0, (t, g) => t + g.mins);

  bool contains(int gameId) => _games.any((g) => g.gameId == gameId);

  /// Reads the saved draft once; safe to call from every page's initState.
  Future<void> load() async {
    if (_loaded || !persist) return;
    _loaded = true;
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null || raw.isEmpty) return;
      restore(raw);
    } catch (_) {}
  }

  /// Replaces the draft from [encode]'s output (used by [load] and tests).
  void restore(String raw) {
    final j = jsonDecode(raw);
    if (j is! Map) return;
    _games
      ..clear()
      ..addAll([
        for (final g in (j['games'] as List? ?? const []))
          if (PlanDraftGame.fromJson(g) case final PlanDraftGame p) p
      ].take(kPlanMaxGames));
    final e = j['event_id'];
    _eventId = e is int ? e : null;
    notifyListeners();
  }

  String encode() => jsonEncode({
        'games': [for (final g in _games) g.toJson()],
        'event_id': _eventId,
      });

  /// Adds a game at the end. False when it is already in or the plan is full.
  bool add(int gameId, String name, {int mins = kPlanDefaultGameMins}) {
    if (contains(gameId) || isFull) return false;
    _games.add(PlanDraftGame(gameId, name, mins));
    _changed();
    return true;
  }

  void remove(int gameId) {
    final before = _games.length;
    _games.removeWhere((g) => g.gameId == gameId);
    if (_games.length != before) _changed();
  }

  /// The + on a game card: in if it was out, out if it was in. Returns
  /// whether the game is in the plan afterwards.
  bool toggle(int gameId, String name) {
    if (contains(gameId)) {
      remove(gameId);
      return false;
    }
    return add(gameId, name);
  }

  /// Drag to reorder (ReorderableListView's indices).
  void move(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _games.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _games.length - 1);
    _games.insert(newIndex, _games.removeAt(oldIndex));
    _changed();
  }

  void setMins(int gameId, int mins) {
    final i = _games.indexWhere((g) => g.gameId == gameId);
    if (i < 0) return;
    _games[i] = _games[i].withMins(mins.clamp(1, 120));
    _changed();
  }

  void setEvent(int? eventId) {
    if (_eventId == eventId) return;
    _eventId = eventId;
    _changed();
  }

  /// Empties the draft (after the plan is saved, or "Start again").
  void clear() {
    if (_games.isEmpty && _eventId == null) return;
    _games.clear();
    _eventId = null;
    _changed();
  }

  void _changed() {
    notifyListeners();
    if (!persist) return;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_key, encode()))
        .catchError((_) => false);
  }
}
