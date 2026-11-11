// The Games half of the v3 Coaching tab (pathway first, approved by Ken
// 2026-11-11).
//
// A club with a pathway opens on its stages:
//   search box      name, skills, type and code, as you type
//   pills           Saved, Code, Type
//   stage cards     number, description, ages and how many games; a tap
//                   opens V3CoachingStagePage (pathway content, then games)
//   search / Saved  swap the stages for matching games from every stage,
//                   each tagged with its stage
// A club with no pathway gets one flat list with All, Saved, Age, Code and
// Type pills.
//   each game       heart (save) and + / tick (in the plan being built)
//   green bar       "N games in your plan · M min  Open ›"
//
// A widget, not a page: V3CoachingPage hosts it.
import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../resources/v3_resources_models.dart';
import '../v3_theme.dart';
import 'v3_coaching_games_controller.dart';
import 'v3_coaching_games_models.dart';
import 'v3_coaching_games_widgets.dart';
import 'v3_coaching_stage_page.dart';
import 'v3_plan_draft.dart';

class V3CoachingGames extends StatefulWidget {
  const V3CoachingGames({
    super.key,
    this.draft,
    this.onOpenPlan,
    this.pickMode = false,
    this.onPathwayChanged,
    this.testData,
  });

  /// The plan in progress; [V3PlanDraft.instance] when null.
  final V3PlanDraft? draft;

  /// The green bar's tap. Null: the bar does nothing.
  final void Function(BuildContext context)? onOpenPlan;

  /// The plan builder opened the list to add games: the bar always shows,
  /// reads "Done · N games in your plan" and pops the page.
  final bool pickMode;

  /// Told once the games have loaded whether the default club has a
  /// pathway (the page names its switch "Pathway" or "Games" from it).
  final ValueChanged<bool>? onPathwayChanged;

  /// Widget tests pass everything here instead of calling Supabase (same
  /// shape as V3ResourcesPage.testData):
  /// {club_id, club_name, user_id, email, games: [games rows],
  ///  favourites: [ids], pathways: [club_pathway_link rows],
  ///  stages: [pathway_stages rows + pathway_type_id],
  ///  details: [pathway_stage_details rows + pathway_stage_id]}.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  /// Whether the default club had a pathway the last time games loaded.
  static bool get lastHadPathway => CoachingGamesController.lastHadPathway;

  @override
  State<V3CoachingGames> createState() => V3CoachingGamesState();
}

/// Public so the page can call [refresh] after a game is added.
class V3CoachingGamesState extends State<V3CoachingGames>
    with WidgetsBindingObserver {
  late final CoachingGamesController _c;
  final _search = TextEditingController();

  // Saved and the search box belong to this view; Code and Type are the
  // controller's, so a stage page opens with the same picks.
  bool _saved = false;
  String? _age;

  /// Search or Saved is on: games from every stage, not the stage cards.
  bool get _across => _saved || _search.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _c = CoachingGamesController(
        testData: widget.testData,
        draft: widget.draft,
        pickMode: widget.pickMode);
    _c.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _c.boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.removeListener(_changed);
    _c.dispose();
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    if (!_c.loading && !_c.error) widget.onPathwayChanged?.call(_c.hasPathway);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // As Resources: reload games when the app comes back.
    if (state == AppLifecycleState.resumed && !_c.loading) refresh();
  }

  /// Reloads the games (pull down, app resumed, after a game is added).
  Future<void> refresh() => _c.refresh();

  // ------------------------------------------------------------ actions

  void _clearFilters({bool search = false}) {
    setState(() {
      _saved = false;
      _age = null;
      if (search) _search.clear();
    });
    _c.clearCodeAndKind();
  }

  Future<void> _pickAge() async {
    final r = await showCoachingPickSheet<String>(context,
        title: 'Age',
        allLabel: 'All ages',
        groups: [
          CoachingSheetGroup(null, [
            for (final a in gameAges(_c.games))
              CoachingSheetOption(a, ageLabel(a))
          ])
        ],
        isSelected: (a) => a == _age,
        noneSelected: _age == null);
    if (r == null || !mounted) return;
    setState(() => _age = r.value);
  }

  /// Opens a stage, or "Other games" when [stage] is null.
  Future<void> _openStage(CoachingStage? stage) async {
    FocusScope.of(context).unfocus();
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3CoachingStage'),
        builder: (_) => V3CoachingStagePage(
            controller: _c, stage: stage, onOpenPlan: widget.onOpenPlan)));
    // "Done" on the stage page goes all the way back to the plan builder.
    if (done == true && mounted) Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------ build

  Widget _searchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        style: V3.inter(17),
        cursorColor: V3.green,
        decoration: InputDecoration(
          hintText: 'Search all games',
          hintStyle: V3.inter(17, color: V3.muted),
          filled: true,
          fillColor: V3.card,
          prefixIcon: const Icon(Icons.search, color: V3.muted, size: 24),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(Icons.close, color: V3.muted),
                  onPressed: () => setState(_search.clear)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: V3.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: V3.green)),
        ),
      ),
    );
  }

  Widget _pills() {
    final pathway = _c.hasPathway;
    return CoachingPillRow(children: [
      if (!pathway) ...[
        CoachingPill(
            key: const ValueKey('pill-all'),
            label: 'All',
            on: !_saved && _age == null && _c.code == null && _c.kind == null,
            onTap: _clearFilters),
        const SizedBox(width: 10),
      ],
      CoachingPill(
          key: const ValueKey('pill-saved'),
          label: 'Saved',
          icon: _saved ? Icons.favorite : Icons.favorite_border,
          on: _saved,
          onTap: () => setState(() => _saved = !_saved)),
      const SizedBox(width: 10),
      if (!pathway) ...[
        CoachingPill(
            key: const ValueKey('pill-age'),
            label: _age == null ? 'Age' : ageLabel(_age!),
            sheet: true,
            on: _age != null,
            onTap: _pickAge),
        const SizedBox(width: 10),
      ],
      ...coachingCodeTypePills(context, _c, _c.games),
    ]);
  }

  /// Games under their kind headings: the flat list, and search or Saved
  /// results (which carry a stage tag and a count heading).
  List<WidgetBuilder> _gameRows({required bool tagged}) {
    final f = GamesFilter(
        query: _search.text,
        saved: _saved,
        ages: tagged || _age == null ? null : [_age!],
        code: _c.code,
        kind: _c.kind);
    final games = filterGames(_c.games, f, _c.favs.ids);
    if (games.isEmpty) {
      final text = emptyText(_c.games, f, _c.favs.ids);
      return [
        (_) => CoachingEmpty(
            text: text,
            action: f.isEmpty || text == kNoSavedText ? null : 'Clear filters',
            onAction: () => _clearFilters(search: true))
      ];
    }
    final rows = <WidgetBuilder>[];
    final stages = tagged ? _c.stages : const <CoachingStage>[];
    if (tagged) {
      final count = resultsCountText(games.length, saved: _saved);
      rows.add((_) => Padding(
            key: const ValueKey('results-count'),
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(count, style: V3.inter(16, weight: FontWeight.w600)),
          ));
    }
    for (final (i, (kind, list))
        in coachingSections(games, only: _c.kind).indexed) {
      final label = coachingKindLabel(kind);
      rows.add((_) => CoachingLabel(label, top: i == 0 && !tagged ? 4 : 14));
      for (final g in list) {
        final tag = tagged ? stageTag(g, stages) : '';
        rows.add((_) => CoachingGameCard(game: g, controller: _c, stage: tag));
      }
    }
    return rows;
  }

  /// The pathway landing view: every stage as a card, under its pathway.
  List<WidgetBuilder> _stageRows() {
    final rows = <WidgetBuilder>[];
    for (final (i, (p, stages)) in _c.pathways.indexed) {
      final heading = pathwayHeading(p.name);
      rows.add((_) => CoachingLabel(heading, top: i == 0 ? 6 : 16));
      if (stages.isEmpty) {
        rows.add((_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('No stages found for this pathway.',
                  style: V3.inter(16, color: V3.muted)),
            ));
      }
      for (final s in stages) {
        final count =
            stageGames(_c.games, s, code: _c.code, kind: _c.kind).length;
        rows.add((_) => _StageCard(
            key: ValueKey('stage-${s.stage.id}'),
            number: s.number,
            title: stageTitle(s.stage),
            line: stageCardLine(s.stage.ages, count),
            onTap: () => _openStage(s)));
      }
    }
    // Games in no stage stay reachable.
    final all = _c.stages;
    if (otherGames(_c.games, all).isNotEmpty) {
      final count =
          otherGames(_c.games, all, code: _c.code, kind: _c.kind).length;
      rows.add((_) => _StageCard(
          key: const ValueKey('stage-other'),
          title: kOtherGamesTitle,
          line: gamesCount(count),
          onTap: () => _openStage(null)));
    }
    // The club site link the Resources pathway page had.
    rows.add((_) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CoachingLinkRow(
              label: kPathwayLinkLabel,
              onTap: () => openGameVideo(kPathwayLinkUrl)),
        ));
    return rows;
  }

  Widget _list() {
    if (_c.loading) {
      return const Center(child: CircularProgressIndicator(color: V3.green));
    }
    if (_c.error) {
      return SingleChildScrollView(
        child: CoachingEmpty(
            text: 'Could not load the games.',
            action: 'Try again',
            onAction: _c.boot),
      );
    }
    return RefreshIndicator(
      color: V3.green,
      backgroundColor: V3.card,
      onRefresh: () => Future.wait([refresh(), _c.favs.load()]),
      child: ListenableBuilder(
        listenable: Listenable.merge([_c.favs, _c.draft]),
        builder: (context, _) {
          final rows = !_c.hasPathway
              ? _gameRows(tagged: false)
              : _across
                  ? _gameRows(tagged: true)
                  : _stageRows();
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: rows.length,
            itemBuilder: (context, i) => rows[i](context),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _searchBox(),
      if (!_c.loading && !_c.error) _pills() else const SizedBox(height: 56),
      Expanded(child: _list()),
      CoachingPlanBar(
          controller: _c,
          onOpen: widget.onOpenPlan == null
              ? null
              : () => widget.onOpenPlan!(context),
          onDone: () => Navigator.of(context).maybePop()),
    ]);
  }
}

/// A stage on the landing view: number badge, description, then its ages
/// and how many games it holds. "Other games" has no number.
class _StageCard extends StatelessWidget {
  const _StageCard(
      {super.key,
      this.number,
      required this.title,
      required this.line,
      required this.onTap});
  final int? number;
  final String title, line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: V3.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: V3.greenTint,
                      borderRadius: BorderRadius.circular(12)),
                  child: number == null
                      ? const Icon(Icons.more_horiz, color: V3.green, size: 24)
                      : Text('$number',
                          style: V3.tight(20,
                              weight: FontWeight.w700, color: V3.green)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: V3.inter(17,
                                weight: FontWeight.w600, height: 1.25)),
                        const SizedBox(height: 3),
                        Text(line, style: V3.inter(15, color: V3.muted)),
                      ]),
                ),
                const Icon(Icons.chevron_right, color: V3.muted, size: 28),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
