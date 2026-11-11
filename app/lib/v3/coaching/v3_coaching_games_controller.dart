// What the Games half of the Coaching tab has loaded and picked, shared by
// the landing view (V3CoachingGames) and the stage page pushed on top of
// it: the games, the club's pathways and stages, each stage's pathway
// content, the hearts, the plan in progress, and the Code and Type pills.
import 'package:flutter/foundation.dart';

import '../games/v3_games.dart';
import '../resources/v3_resources_api.dart';
import '../resources/v3_resources_models.dart';
import 'v3_coaching_games_models.dart';
import 'v3_plan_draft.dart';

class CoachingGamesController extends ChangeNotifier {
  /// [testData] as [V3CoachingGames.testData]; null talks to Supabase.
  CoachingGamesController(
      {Map<String, dynamic>? testData,
      V3PlanDraft? draft,
      this.pickMode = false})
      : draft = draft ?? V3PlanDraft.instance {
    final t = testData;
    if (t == null) {
      api = const V3GamesApi();
      rapi = const V3ResourcesApi();
    } else {
      api = V3OfflineGamesApi(
        games: parseGames(t['games']),
        favourites: parseFavouriteIds(t['favourites']),
        clubId: t['club_id'] as int?,
        club: '${t['club_name'] ?? ''}',
        uid: '${t['user_id'] ?? 'test-user'}',
        email: '${t['email'] ?? 'coach@example.com'}',
      );
      rapi = V3OfflineResourcesApi(t);
    }
    favs = V3GameFavourites(api);
    this.draft.load();
  }

  /// Whether the default club had a pathway the last time games loaded, so
  /// the Coaching switch can say "Pathway" straight away next time.
  static bool lastHadPathway = false;

  late final V3GamesApi api;
  late final V3ResourcesApi rapi;
  late final V3GameFavourites favs;
  final V3PlanDraft draft;

  /// The plan builder opened the list to add games.
  final bool pickMode;

  bool loading = true, error = false;
  List<V3Game> games = [];
  int? myClubId;
  String clubName = '';

  /// The club's pathways with their stages (empty: no pathway).
  List<(Pathway, List<CoachingStage>)> pathways = [];

  /// Pathway content per stage id, loaded when the stage is first opened.
  final Map<int, List<StageDetail>> details = {};

  /// Stages whose content failed to load (pull down to try again).
  final Set<int> detailsFailed = {};

  /// The Code and Type pills, shared by the landing view and stage pages.
  String? code;
  GameKind? kind;

  bool _disposed = false;

  bool get hasPathway => pathways.isNotEmpty;

  /// Every stage of every pathway, in order.
  List<CoachingStage> get stages => [for (final (_, s) in pathways) ...s];

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    favs.dispose();
    super.dispose();
  }

  Future<void> boot() async {
    if (!loading || error) {
      loading = true;
      error = false;
      notifyListeners();
    }
    try {
      final club = await api.myClubId();
      myClubId = club;
      final results = await Future.wait<Object?>([
        api.games(club),
        favs.load(),
        if (club != null) api.clubName(club),
        if (club != null) rapi.pathways(club),
      ]);
      games = results[0] as List<V3Game>;
      if (club != null) {
        clubName = results[2] as String;
        final found = results[3] as List<Pathway>;
        final stages = await Future.wait([
          for (final p in found)
            rapi.stages(p.id).catchError((_) => <PathwayStage>[])
        ]);
        pathways = [
          for (final (i, p) in found.indexed) (p, coachingStages(p, stages[i]))
        ];
      } else {
        pathways = [];
      }
      lastHadPathway = hasPathway;
    } catch (_) {
      error = true;
    }
    loading = false;
    notifyListeners();
  }

  /// Reloads the games (pull down, app resumed, after a game is added).
  Future<void> refresh() async {
    try {
      games = await api.games(myClubId);
      notifyListeners();
    } catch (_) {}
  }

  /// Loads a stage's pathway content once. False when it could not load.
  Future<bool> loadDetails(CoachingStage s, {bool retry = false}) async {
    final id = s.stage.id;
    if (details.containsKey(id)) return true;
    if (detailsFailed.contains(id) && !retry) return false;
    try {
      final d = await rapi.details(id);
      details[id] = d;
      detailsFailed.remove(id);
      notifyListeners();
      return true;
    } catch (_) {
      detailsFailed.add(id);
      notifyListeners();
      return false;
    }
  }

  void setCode(String? v) {
    code = v;
    notifyListeners();
  }

  void setKind(GameKind? v) {
    kind = v;
    notifyListeners();
  }

  void clearCodeAndKind() {
    code = null;
    kind = null;
    notifyListeners();
  }

  /// A game was edited on its page.
  void replaceGame(V3Game g) {
    games = [for (final x in games) x.gameId == g.gameId ? g : x];
    notifyListeners();
  }

  /// A game was deleted on its page.
  void removeGame(int id) {
    games = [
      for (final x in games)
        if (x.gameId != id) x
    ];
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 400), refresh);
  }
}
