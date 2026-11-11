// The Games half of the v3 Coaching tab: one searchable list of every game
// the coach can see (public games plus the default club's own), replacing
// the Resources page's pathway -> stage drill-down and the Favourites page.
//
//   search box      name, skills, type and code, as you type
//   pills           All, Saved, Stage (Age when the club has no pathway),
//                   Code, Type. Stage / Code / Type open a sheet.
//   one stage       its Player Pathways and Sample Sessions pictures show
//                   above the games, as on the Resources stage page
//   each game       heart (save) and + / tick (in the plan being built)
//   green bar       "N games in your plan · M min  Open ›"
//
// A widget, not a page: V3CoachingPage hosts it.
import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../resources/v3_resources_api.dart';
import '../resources/v3_resources_models.dart';
import '../v3_theme.dart';
import 'v3_coaching_games_detail.dart';
import 'v3_coaching_games_models.dart';
import 'v3_plan_draft.dart';

class V3CoachingGames extends StatefulWidget {
  const V3CoachingGames({
    super.key,
    this.draft,
    this.onOpenPlan,
    this.pickMode = false,
    this.testData,
  });

  /// The plan in progress; [V3PlanDraft.instance] when null.
  final V3PlanDraft? draft;

  /// The green bar's tap. Null: the bar does nothing.
  final void Function(BuildContext context)? onOpenPlan;

  /// The plan builder opened the list to add games: the bar always shows,
  /// reads "Done · N games in your plan" and pops the page.
  final bool pickMode;

  /// Widget tests pass everything here instead of calling Supabase (same
  /// shape as V3ResourcesPage.testData):
  /// {club_id, club_name, user_id, email, games: [games rows],
  ///  favourites: [ids], pathways: [club_pathway_link rows],
  ///  stages: [pathway_stages rows + pathway_type_id],
  ///  details: [pathway_stage_details rows + pathway_stage_id]}.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3CoachingGames> createState() => V3CoachingGamesState();
}

/// Public so the page can call [refresh] after a game is added.
class V3CoachingGamesState extends State<V3CoachingGames>
    with WidgetsBindingObserver {
  late final V3GamesApi _api;
  late final V3ResourcesApi _rapi;
  late final V3GameFavourites _favs;
  late final V3PlanDraft _draft;
  final _search = TextEditingController();

  bool _loading = true, _error = false;
  List<V3Game> _games = [];
  int? _myClubId;
  String _clubName = '';

  /// The club's pathways with their stages (empty: no pathway, so Age).
  List<(Pathway, List<CoachingStage>)> _pathways = [];

  /// Pathway content per stage id, loaded when the stage is first picked.
  final Map<int, List<StageDetail>> _details = {};

  bool _saved = false;
  CoachingStage? _stage;
  String? _age, _code;
  GameKind? _kind;

  bool get _hasPathway => _pathways.isNotEmpty;

  GamesFilter get _filter => GamesFilter(
      query: _search.text,
      saved: _saved,
      ages: _hasPathway ? _stage?.stage.ages : (_age == null ? null : [_age!]),
      code: _code,
      kind: _kind);

  @override
  void initState() {
    super.initState();
    final t = widget.testData;
    if (t == null) {
      _api = const V3GamesApi();
      _rapi = const V3ResourcesApi();
    } else {
      _api = V3OfflineGamesApi(
        games: parseGames(t['games']),
        favourites: parseFavouriteIds(t['favourites']),
        clubId: t['club_id'] as int?,
        club: '${t['club_name'] ?? ''}',
        uid: '${t['user_id'] ?? 'test-user'}',
        email: '${t['email'] ?? 'coach@example.com'}',
      );
      _rapi = V3OfflineResourcesApi(t);
    }
    _favs = V3GameFavourites(_api);
    _draft = widget.draft ?? V3PlanDraft.instance;
    _draft.load();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _favs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // As Resources: reload games when the app comes back.
    if (state == AppLifecycleState.resumed && !_loading) refresh();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final club = await _api.myClubId();
      _myClubId = club;
      final results = await Future.wait<Object?>([
        _api.games(club),
        _favs.load(),
        if (club != null) _api.clubName(club),
        if (club != null) _rapi.pathways(club),
      ]);
      _games = results[0] as List<V3Game>;
      if (club != null) {
        _clubName = results[2] as String;
        final pathways = results[3] as List<Pathway>;
        final stages = await Future.wait([
          for (final p in pathways)
            _rapi.stages(p.id).catchError((_) => <PathwayStage>[])
        ]);
        _pathways = [
          for (final (i, p) in pathways.indexed)
            (p, coachingStages(p, stages[i]))
        ];
      }
    } catch (_) {
      _error = true;
    }
    _loading = false;
    if (mounted) setState(() {});
  }

  /// Reloads the games (pull down, app resumed, after a game is added).
  Future<void> refresh() async {
    try {
      final games = await _api.games(_myClubId);
      if (mounted) setState(() => _games = games);
    } catch (_) {}
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    // Floats clear of the plan bar and the phone's bottom inset.
    final barShown = widget.pickMode || !_draft.isEmpty;
    final bottom =
        MediaQuery.of(context).padding.bottom + (barShown ? 72 : 0) + 12;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          content: Text(text,
              textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
          backgroundColor: warn ? V3.amber : V3.green));
  }

  // ------------------------------------------------------------ actions

  Future<void> _heart(V3Game g) async {
    final msg = await _favs.toggle(g.gameId);
    _snack(msg, warn: msg.startsWith('Could'));
  }

  void _togglePlan(V3Game g) {
    if (!_draft.contains(g.gameId) && _draft.isFull) {
      _snack(kPlanFullText, warn: true);
      return;
    }
    _draft.toggle(g.gameId, g.name);
  }

  void _openGame(V3Game g) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => V3CoachingGameDetailPage(
              game: g,
              api: _api,
              favourites: _favs,
              draft: _draft,
              myClubId: _myClubId,
              onChanged: (s) {
                if (!mounted) return;
                setState(() => _games = [
                      for (final x in _games) x.gameId == s.gameId ? s : x
                    ]);
              },
              onDeleted: (id) {
                if (!mounted) return;
                setState(() => _games = [
                      for (final x in _games)
                        if (x.gameId != id) x
                    ]);
                Future.delayed(const Duration(milliseconds: 400), refresh);
              },
            )));
  }

  void _clearFilters({bool search = false}) {
    setState(() {
      _saved = false;
      _stage = null;
      _age = null;
      _code = null;
      _kind = null;
      if (search) _search.clear();
    });
  }

  Future<void> _loadDetails(CoachingStage s) async {
    if (_details.containsKey(s.stage.id)) return;
    try {
      final d = await _rapi.details(s.stage.id);
      if (mounted) setState(() => _details[s.stage.id] = d);
    } catch (_) {
      _snack('Could not load stage — please try again', warn: true);
    }
  }

  Future<void> _pickStage() async {
    final groups = [
      for (final (p, stages) in _pathways)
        _SheetGroup<CoachingStage>(_pathways.length > 1 ? p.name : null, [
          for (final s in stages)
            _SheetOption(s, s.label,
                subtitle: [
                  s.stage.name,
                  if (s.stage.ages.isNotEmpty) s.stage.agesLabel
                ].join(' · '))
        ])
    ];
    final r = await _showPickSheet<CoachingStage>(context,
        title: 'Stage',
        allLabel: 'All stages',
        groups: groups,
        isSelected: (s) => s.stage.id == _stage?.stage.id,
        noneSelected: _stage == null,
        // The club site link the Resources pathway page had.
        footer: _SheetLink(
            label: kPathwayLinkLabel,
            onTap: () => openGameVideo(kPathwayLinkUrl)));
    if (r == null || !mounted) return;
    setState(() => _stage = r.value);
    if (r.value != null) _loadDetails(r.value!);
  }

  Future<void> _pickAge() async {
    final r = await _showPickSheet<String>(context,
        title: 'Age',
        allLabel: 'All ages',
        groups: [
          _SheetGroup(null,
              [for (final a in gameAges(_games)) _SheetOption(a, ageLabel(a))])
        ],
        isSelected: (a) => a == _age,
        noneSelected: _age == null);
    if (r == null || !mounted) return;
    setState(() => _age = r.value);
  }

  Future<void> _pickCode() async {
    final extra = [
      for (final d in _details[_stage?.stage.id] ?? const <StageDetail>[])
        if ((d.codeText ?? '').isNotEmpty) d.codeText!
    ];
    final r = await _showPickSheet<String>(context,
        title: 'Code',
        allLabel: 'All codes',
        groups: [
          _SheetGroup(null,
              [for (final c in gameCodes(_games, extra)) _SheetOption(c, c)])
        ],
        isSelected: (c) => c == _code,
        noneSelected: _code == null);
    if (r == null || !mounted) return;
    setState(() => _code = r.value);
  }

  Future<void> _pickType() async {
    final r = await _showPickSheet<GameKind>(context,
        title: 'Type',
        allLabel: 'All types',
        groups: [
          _SheetGroup(null, [
            for (final k in gameKinds(_games))
              _SheetOption(k, coachingKindLabel(k))
          ])
        ],
        isSelected: (k) => k == _kind,
        noneSelected: _kind == null);
    if (r == null || !mounted) return;
    setState(() => _kind = r.value);
  }

  void _openDetail(StageDetail d) {
    if (d.imageLink.isEmpty && d.videoLink.isNotEmpty) {
      openGameVideo(d.videoLink);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => V3ImageViewerPage(
            imageUrl: d.imageLink, title: d.heading, subtitle: d.subheading)));
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
    final stageLabel = _hasPathway
        ? (_stage?.label ?? 'Stage')
        : (_age == null ? 'Age' : ageLabel(_age!));
    return Container(
      // Left aligned even when the pills don't fill the row.
      alignment: Alignment.centerLeft,
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          _Pill(
              key: const ValueKey('pill-all'),
              label: 'All',
              on: !_filter.hasFilters,
              onTap: _clearFilters),
          const SizedBox(width: 8),
          _Pill(
              key: const ValueKey('pill-saved'),
              label: 'Saved',
              icon: _saved ? Icons.favorite : Icons.favorite_border,
              on: _saved,
              onTap: () => setState(() => _saved = !_saved)),
          const SizedBox(width: 8),
          _Pill(
              key: const ValueKey('pill-stage'),
              label: stageLabel,
              sheet: true,
              on: _hasPathway ? _stage != null : _age != null,
              onTap: _hasPathway ? _pickStage : _pickAge),
          const SizedBox(width: 8),
          _Pill(
              key: const ValueKey('pill-code'),
              label: _code ?? 'Code',
              sheet: true,
              on: _code != null,
              onTap: _pickCode),
          const SizedBox(width: 8),
          _Pill(
              key: const ValueKey('pill-type'),
              label: _kind == null ? 'Type' : coachingKindLabel(_kind!),
              sheet: true,
              on: _kind != null,
              onTap: _pickType),
        ]),
      ),
    );
  }

  Widget _gameCard(V3Game g) {
    final can = g.canFavourite;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: V3GameCard(
        game: g,
        clubName: _clubName,
        onTap: () => _openGame(g),
        trailing: !can
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: [
                V3HeartButton(
                    on: _favs.isFav(g.gameId), onPressed: () => _heart(g)),
                _PlanCircle(
                    on: _draft.contains(g.gameId),
                    onPressed: () => _togglePlan(g)),
              ]),
      ),
    );
  }

  Widget _detailRow(StageDetail d) {
    final video = d.videoLink.isNotEmpty;
    final color = video ? kVideoBlue : V3.green;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: V3.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetail(d),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(video ? Icons.play_arrow : Icons.image_outlined,
                      color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.heading,
                            style: V3.inter(17,
                                weight: FontWeight.w600, height: 1.3)),
                        if (d.subheading.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(d.subheading,
                              style:
                                  V3.inter(15, color: V3.muted, height: 1.4)),
                        ],
                      ]),
                ),
                const Icon(Icons.chevron_right, color: V3.muted, size: 26),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// The rows of the list, built lazily.
  List<WidgetBuilder> _rows() {
    final f = _filter;
    final rows = <WidgetBuilder>[];
    var first = true;
    void label(String text) {
      final top = first ? 4.0 : 14.0;
      first = false;
      rows.add((_) => _Label(text, top: top));
    }

    // One stage picked: its pathway content first, as the Resources stage
    // page showed it (pictures follow the code, not the type). Left out
    // while searching or looking at Saved, which are about games only.
    final s = _stage;
    var hasContent = false;
    if (_hasPathway && s != null && f.query.trim().isEmpty && !f.saved) {
      rows.add((_) => _StageHeader(stage: s));
      first = false;
      final details = _details[s.stage.id];
      if (details == null) {
        rows.add((_) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: V3.green, strokeWidth: 2.5)))));
      } else {
        for (final cat in const [kPlayerPathways, kSampleSessions]) {
          final list = filteredDetails(details, cat, _code ?? 'All');
          if (list.isEmpty) continue;
          hasContent = true;
          label(cat);
          for (final d in list) {
            rows.add((_) => _detailRow(d));
          }
        }
      }
    }

    final games = filterGames(_games, f, _favs.ids);
    for (final (kind, list) in coachingSections(games, only: _kind)) {
      label(coachingKindLabel(kind));
      for (final g in list) {
        rows.add((_) => _gameCard(g));
      }
    }
    if (games.isEmpty && !hasContent) {
      final text = emptyText(_games, f, _favs.ids);
      rows.add((_) => _Empty(
          text: text,
          action: f.isEmpty || text == kNoSavedText ? null : 'Clear filters',
          onAction: () => _clearFilters(search: true)));
    }
    return rows;
  }

  Widget _list() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: V3.green));
    }
    if (_error) {
      return SingleChildScrollView(
        child: _Empty(
            text: 'Could not load the games.',
            action: 'Try again',
            onAction: _boot),
      );
    }
    return RefreshIndicator(
      color: V3.green,
      backgroundColor: V3.card,
      onRefresh: () => Future.wait([refresh(), _favs.load()]),
      child: ListenableBuilder(
        listenable: Listenable.merge([_favs, _draft]),
        builder: (context, _) {
          final rows = _rows();
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

  Widget _planBar() {
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        if (!widget.pickMode && _draft.isEmpty) {
          return const SizedBox.shrink();
        }
        final pick = widget.pickMode;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Material(
              key: const ValueKey('plan-bar'),
              color: V3.green,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: pick
                    ? () => Navigator.of(context).maybePop()
                    : widget.onOpenPlan == null
                        ? null
                        : () => widget.onOpenPlan!(context),
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                            pick
                                ? pickDoneText(_draft.count)
                                : planBarText(_draft.count, _draft.totalMins),
                            textAlign: pick ? TextAlign.center : null,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V3.inter(17,
                                weight: FontWeight.w700, color: V3.bg)),
                      ),
                      if (!pick)
                        Text('Open ›',
                            style: V3.inter(17,
                                weight: FontWeight.w700, color: V3.bg)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _searchBox(),
      _pills(),
      Expanded(child: _list()),
      _planBar(),
    ]);
  }
}

// ------------------------------------------------------------ pieces

/// The + / tick circle on a game card: in or out of the plan being built.
class _PlanCircle extends StatelessWidget {
  const _PlanCircle({required this.on, required this.onPressed});
  final bool on;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: on ? 'Remove from plan' : 'Add to plan',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? V3.green : Colors.transparent,
            border: Border.all(color: V3.green, width: 2)),
        child: Icon(on ? Icons.check : Icons.add,
            size: 22, color: on ? V3.bg : V3.green),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {super.key,
      required this.label,
      required this.on,
      required this.onTap,
      this.icon,
      this.sheet = false});
  final String label;
  final bool on, sheet;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = on ? V3.bg : V3.text;
    return Material(
      color: on ? V3.green : V3.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: on ? V3.green : V3.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: sheet ? 8 : 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: on ? V3.bg : kHeartRed),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: V3.inter(16, weight: FontWeight.w600, color: fg)),
            if (sheet) Icon(Icons.arrow_drop_down, size: 24, color: fg),
          ]),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.top = 0});
  final String text;
  final double top;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 10),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.muted, letterSpacing: 1.4)),
      );
}

/// The picked stage's name, description and ages, above its content.
class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage});
  final CoachingStage stage;

  @override
  Widget build(BuildContext context) {
    final s = stage.stage;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.name, style: V3.tight(19)),
        if (s.desc.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(s.desc, style: V3.inter(15, color: V3.muted, height: 1.4)),
        ],
        if (s.ages.isNotEmpty) ...[
          const SizedBox(height: 8),
          V3GameTag(s.agesLabel, color: V3.green),
        ],
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(text,
            textAlign: TextAlign.center,
            style: V3.inter(17, color: V3.muted, height: 1.5)),
        if (action != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: V3.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: onAction,
                child: Text(action!,
                    style:
                        V3.inter(16, weight: FontWeight.w700, color: V3.bg))),
          ),
        ],
      ]),
    );
  }
}

// ------------------------------------------------------------ pick sheet

class _SheetOption<T> {
  const _SheetOption(this.value, this.label, {this.subtitle = ''});
  final T value;
  final String label, subtitle;
}

class _SheetGroup<T> {
  const _SheetGroup(this.heading, this.options);
  final String? heading;
  final List<_SheetOption<T>> options;
}

/// What a sheet returns: the value, or null inside for "All". (A null
/// result from the sheet itself means it was dismissed.)
class _Picked<T> {
  const _Picked(this.value);
  final T? value;
}

class _SheetLink extends StatelessWidget {
  const _SheetLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.public, color: V3.green, size: 22),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label, style: V3.inter(16, color: V3.muted))),
              const Icon(Icons.chevron_right, color: V3.muted, size: 24),
            ]),
          ),
        ),
      );
}

Future<_Picked<T>?> _showPickSheet<T>(
  BuildContext context, {
  required String title,
  required String allLabel,
  required List<_SheetGroup<T>> groups,
  required bool Function(T) isSelected,
  required bool noneSelected,
  Widget? footer,
}) {
  FocusScope.of(context).unfocus();
  Widget row(BuildContext ctx, String label, String subtitle, bool on,
          _Picked<T> result) =>
      InkWell(
        onTap: () => Navigator.of(ctx).pop(result),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: V3.inter(17,
                              weight: on ? FontWeight.w700 : FontWeight.w500,
                              color: on ? V3.green : V3.text)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: V3.inter(15, color: V3.muted)),
                      ],
                    ]),
              ),
              if (on) const Icon(Icons.check, color: V3.green, size: 26),
            ]),
          ),
        ),
      );

  return showModalBottomSheet<_Picked<T>>(
    context: context,
    backgroundColor: V3.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: V3.tight(20))),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              row(ctx, allLabel, '', noneSelected, _Picked<T>(null)),
              for (final g in groups) ...[
                if (g.heading != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                    child: Text(g.heading!.toUpperCase(),
                        style: V3.inter(13,
                            weight: FontWeight.w700,
                            color: V3.muted,
                            letterSpacing: 1.4)),
                  ),
                for (final o in g.options)
                  row(ctx, o.label, o.subtitle, isSelected(o.value),
                      _Picked<T>(o.value)),
              ],
              if (footer != null) ...[
                const Divider(color: V3.line, height: 17),
                footer,
              ],
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      ),
    ),
  );
}
