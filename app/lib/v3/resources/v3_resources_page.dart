// v3 Resources: a native copy of webviews/games-resource-v2.html, the games
// and drills library for clubs with a pathway (TURAS). The web page stays
// for the old app.
//
// Flow (as the web page):
//   no pathway   -> six fixed stages -> games list (sport + type filters)
//   one pathway  -> its development stages
//   2+ pathways  -> pick a pathway -> its development stages
//   stage        -> code + type filters; Player Pathways and Sample Sessions
//                   pictures; Videos, Warmups, Drills, Games, Skills lists
//   game         -> V3GameDetailPage (heart, PDF card, notes, edit/delete
//                   gates), shared with Favourites and Session plan.
// Games are public ones plus the user's default club's own.
import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../v3_theme.dart';
import 'v3_resources_api.dart';
import 'v3_resources_models.dart';

class V3ResourcesPage extends StatefulWidget {
  const V3ResourcesPage({super.key, this.testData});

  /// Widget tests pass everything here instead of calling Supabase:
  /// {club_id, club_name, user_id, email, games: [games rows],
  ///  favourites: [ids], pathways: [club_pathway_link rows],
  ///  stages: [pathway_stages rows + pathway_type_id],
  ///  details: [pathway_stage_details rows + pathway_stage_id]}.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3ResourcesPage> createState() => _V3ResourcesPageState();
}

/// Shared state for the page and the pages it pushes: games, favourites,
/// my club. Lists listen to it so an edit or delete shows everywhere.
class _Lib extends ChangeNotifier {
  _Lib(this.api, this.rapi) : favs = V3GameFavourites(api);

  final V3GamesApi api;
  final V3ResourcesApi rapi;
  final V3GameFavourites favs;
  List<V3Game> games = [];
  int? myClubId;
  String clubName = '';

  Future<void> refresh() async {
    try {
      games = await api.games(myClubId);
      notifyListeners();
    } catch (_) {}
  }

  void replace(V3Game g) {
    games = [for (final x in games) x.gameId == g.gameId ? g : x];
    notifyListeners();
  }

  void remove(int id) {
    games = [
      for (final x in games)
        if (x.gameId != id) x
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    favs.dispose();
    super.dispose();
  }
}

enum _Mode { loading, error, fallback, pathway, select }

class _V3ResourcesPageState extends State<V3ResourcesPage>
    with WidgetsBindingObserver {
  late final _Lib _lib;
  _Mode _mode = _Mode.loading;
  List<Pathway> _pathways = [];
  List<PathwayStage> _stages = [];

  @override
  void initState() {
    super.initState();
    final t = widget.testData;
    _lib = t == null
        ? _Lib(const V3GamesApi(), const V3ResourcesApi())
        : _Lib(
            V3OfflineGamesApi(
              games: parseGames(t['games']),
              favourites: parseFavouriteIds(t['favourites']),
              clubId: t['club_id'] as int?,
              club: '${t['club_name'] ?? ''}',
              uid: '${t['user_id'] ?? 'test-user'}',
              email: '${t['email'] ?? 'coach@example.com'}',
            ),
            V3OfflineResourcesApi(t));
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lib.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The web page reloads games when it becomes visible again.
    if (state == AppLifecycleState.resumed && _mode != _Mode.loading) {
      _lib.refresh();
    }
  }

  Future<void> _boot() async {
    setState(() => _mode = _Mode.loading);
    try {
      final club = await _lib.api.myClubId();
      _lib.myClubId = club;
      final results = await Future.wait<Object?>([
        _lib.api.games(club),
        _lib.favs.load(),
        if (club != null) _lib.api.clubName(club),
        if (club != null) _lib.rapi.pathways(club),
      ]);
      _lib.games = results[0] as List<V3Game>;
      if (club != null) {
        _lib.clubName = results[2] as String;
        _pathways = results[3] as List<Pathway>;
      }
      if (_pathways.isEmpty) {
        _mode = _Mode.fallback;
      } else if (_pathways.length == 1) {
        _stages = await _lib.rapi.stages(_pathways.first.id);
        _mode = _Mode.pathway;
      } else {
        _mode = _Mode.select;
      }
    } catch (_) {
      _mode = _Mode.error;
    }
    if (mounted) setState(() {});
  }

  Future<void> _openPathway(Pathway p) async {
    List<PathwayStage> stages;
    try {
      stages = await _lib.rapi.stages(p.id);
    } catch (_) {
      if (mounted) {
        _snack(context, 'Could not load pathway — please try again',
            warn: true);
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _Scaffold(
            title: 'Player Pathway',
            child: _PathwayStages(lib: _lib, stages: stages))));
  }

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case _Mode.loading:
        return const _Scaffold(
            title: 'Resources',
            child: Center(child: CircularProgressIndicator(color: V3.green)));
      case _Mode.error:
        return _Scaffold(
          title: 'Resources',
          child: _Message(
              title: 'Something went wrong',
              text: 'Could not load coaching resources.',
              action: 'Try again',
              onAction: _boot),
        );
      case _Mode.fallback:
        return _Scaffold(title: 'Resources', child: _FallbackStages(lib: _lib));
      case _Mode.pathway:
        return _Scaffold(
            title: 'Player Pathway',
            child: _PathwayStages(lib: _lib, stages: _stages));
      case _Mode.select:
        return _Scaffold(
          title: 'Resources',
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const _Label('Select a pathway'),
            for (final p in _pathways)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RowCard(
                  leading: const _IconBox(Icons.menu),
                  title: p.name,
                  onTap: () => _openPathway(p),
                ),
              ),
          ]),
        );
    }
  }
}

// ------------------------------------------------------------ helpers

void _snack(BuildContext context, String text, {bool warn = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text,
          textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
      backgroundColor: warn ? V3.amber : V3.green));
}

/// Opens a game on the shared detail page and keeps lists in step.
void _openGame(BuildContext context, _Lib lib, V3Game g) {
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => V3GameDetailPage(
            game: g,
            api: lib.api,
            favourites: lib.favs,
            myClubId: lib.myClubId,
            onChanged: lib.replace,
            onDeleted: (id) {
              lib.remove(id);
              Future.delayed(const Duration(milliseconds: 400), lib.refresh);
            },
          )));
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.title, required this.child, this.bottom});
  final String title;
  final Widget child;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
            onPressed: () => Navigator.of(context).maybePop()),
        title:
            Text(title, overflow: TextOverflow.ellipsis, style: V3.tight(17)),
        bottom: bottom,
      ),
      body: child,
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.top = 0});
  final String text;
  final double top;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 12),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.muted, letterSpacing: 1.4)),
      );
}

class _Message extends StatelessWidget {
  const _Message({this.title, required this.text, this.action, this.onAction});
  final String? title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.info_outline,
            size: 40, color: V3.muted.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        if (title != null) ...[
          Text(title!, style: V3.tight(18), textAlign: TextAlign.center),
          const SizedBox(height: 6),
        ],
        Text(text,
            textAlign: TextAlign.center,
            style: V3.inter(16, color: V3.muted, height: 1.6)),
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

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon, {this.color = V3.green});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      );
}

/// A tappable card row with a leading widget, title, subtitle and chevron.
class _RowCard extends StatelessWidget {
  const _RowCard(
      {required this.leading,
      required this.title,
      this.subtitle = '',
      this.meta,
      this.onTap});
  final Widget leading;
  final String title, subtitle;
  final Widget? meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: V3.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: V3.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: V3.inter(17,
                              weight: FontWeight.w600, height: 1.3)),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(subtitle,
                            style: V3.inter(15, color: V3.muted, height: 1.4)),
                      ],
                      if (meta != null) ...[
                        const SizedBox(height: 6),
                        meta!,
                      ],
                    ]),
              ),
              const Icon(Icons.chevron_right, color: V3.muted, size: 26),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A development stage card: number, name, description, ages, count.
class _StageCard extends StatelessWidget {
  const _StageCard(
      {required this.number,
      required this.name,
      this.desc = '',
      this.ages = '',
      this.count = 0,
      required this.onTap});
  final int number, count;
  final String name, desc, ages;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _RowCard(
        onTap: onTap,
        leading: SizedBox(
          width: 44,
          child: Row(children: [
            Expanded(
              child: Text('$number',
                  textAlign: TextAlign.center,
                  style:
                      V3.tight(26, weight: FontWeight.w700, color: V3.green)),
            ),
            Container(width: 1, height: 36, color: V3.line),
          ]),
        ),
        title: name,
        subtitle: desc,
        meta: ages.isEmpty && count == 0
            ? null
            : Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                    if (ages.isNotEmpty) V3GameTag(ages, color: V3.green),
                    if (count > 0)
                      Text(resourceCount(count),
                          style: V3.inter(14, color: V3.muted)),
                  ]),
      ),
    );
  }
}

/// A horizontally scrolling row of filter chips.
class _ChipRow extends StatelessWidget {
  const _ChipRow(
      {required this.options, required this.selected, required this.onTap});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onTap;

  Widget _chip(String o, bool on) => Material(
        color: on ? V3.green : V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: on ? V3.green : V3.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onTap(o),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              widthFactor: 1,
              child: Text(o,
                  style: V3.inter(15,
                      weight: FontWeight.w600, color: on ? V3.bg : V3.text)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          for (final (i, o) in options.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            _chip(o, o == selected),
          ],
        ]),
      ),
    );
  }
}

/// Game cards for a list, hearts kept in step with the shared favourites.
List<Widget> _gameCards(BuildContext context, _Lib lib, List<V3Game> games,
    {bool hearts = true}) {
  return [
    for (final g in games)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: ListenableBuilder(
          listenable: lib.favs,
          builder: (context, _) => V3GameCard(
            game: g,
            clubName: lib.clubName,
            isFavourite: lib.favs.isFav(g.gameId),
            onTap: () => _openGame(context, lib, g),
            onFavourite: hearts
                ? () async {
                    final msg = await lib.favs.toggle(g.gameId);
                    if (context.mounted) {
                      _snack(context, msg, warn: msg.startsWith('Could'));
                    }
                  }
                : null,
          ),
        ),
      ),
  ];
}

// ------------------------------------------------------------ pathway

class _PathwayStages extends StatelessWidget {
  const _PathwayStages({required this.lib, required this.stages});
  final _Lib lib;
  final List<PathwayStage> stages;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) =>
          ListView(padding: const EdgeInsets.all(16), children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _RowCard(
            leading: const Icon(Icons.public, color: V3.green, size: 24),
            title: kPathwayLinkLabel,
            onTap: () => openGameVideo(kPathwayLinkUrl),
          ),
        ),
        const _Label('Development stages'),
        if (stages.isEmpty)
          const _Message(text: 'No stages found for this pathway.')
        else
          for (final (i, s) in stages.indexed)
            _StageCard(
              number: s.seq != 0 ? s.seq : i + 1,
              name: s.name,
              desc: s.desc,
              ages: s.agesLabel,
              count: stageResourceCount(s, lib.games),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _StagePage(lib: lib, stage: s))),
            ),
      ]),
    );
  }
}

class _StagePage extends StatefulWidget {
  const _StagePage({required this.lib, required this.stage});
  final _Lib lib;
  final PathwayStage stage;

  @override
  State<_StagePage> createState() => _StagePageState();
}

class _StagePageState extends State<_StagePage> {
  List<StageDetail>? _details;
  bool _failed = false;
  String _code = 'All', _type = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.lib.rapi.details(widget.stage.id);
      if (mounted) setState(() => _details = d);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
      _snack(context, 'Could not load stage — please try again', warn: true);
    }
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

  Widget _detailRow(StageDetail d) {
    final video = d.videoLink.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _RowCard(
        leading: _IconBox(video ? Icons.play_arrow : Icons.image_outlined,
            color: video ? kVideoBlue : V3.green),
        title: d.heading,
        subtitle: d.subheading,
        onTap: () => _openDetail(d),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lib = widget.lib, s = widget.stage;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final details = _details ?? const <StageDetail>[];
        final codes = stageCodes(s, details, lib.games);
        final sec = stageSections(s, details, lib.games, _code, _type);
        return _Scaffold(
          title: s.name,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(112),
            child: Column(children: [
              _ChipRow(
                  options: codes,
                  selected: _code,
                  onTap: (c) => setState(() => _code = c)),
              _ChipRow(
                  options: kStageTypes,
                  selected: _type,
                  onTap: (t) =>
                      setState(() => _type = nextTypeFilter(_type, t))),
            ]),
          ),
          child: _details == null && !_failed
              ? const Center(child: CircularProgressIndicator(color: V3.green))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (sec.playerPathways.isNotEmpty) ...[
                      const _Label(kPlayerPathways),
                      for (final d in sec.playerPathways) _detailRow(d),
                    ],
                    if (sec.sampleSessions.isNotEmpty) ...[
                      _Label(kSampleSessions,
                          top: sec.playerPathways.isEmpty ? 0 : 14),
                      for (final d in sec.sampleSessions) _detailRow(d),
                    ],
                    for (final (i, e) in sec.games.entries.indexed) ...[
                      _Label(kindSectionLabel(e.key),
                          top: i == 0 &&
                                  sec.playerPathways.isEmpty &&
                                  sec.sampleSessions.isEmpty
                              ? 0
                              : 14),
                      ..._gameCards(context, lib, e.value,
                          hearts: e.key != GameKind.skill),
                    ],
                    if (sec.isEmpty)
                      const _Message(text: 'No resources match this filter.'),
                  ],
                ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ no pathway

class _FallbackStages extends StatelessWidget {
  const _FallbackStages({required this.lib});
  final _Lib lib;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final stages = visibleFallbackStages(lib.games);
        return ListView(padding: const EdgeInsets.all(16), children: [
          const _Label('Select development stage'),
          if (stages.isEmpty) const _Message(text: 'No resources found.'),
          for (final s in stages)
            _StageCard(
              number: s.id,
              name: s.subtitle,
              ages: s.agesLabel,
              count: fallbackStageCount(s, lib.games),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => _FallbackGamesPage(lib: lib, stage: s))),
            ),
        ]);
      },
    );
  }
}

class _FallbackGamesPage extends StatefulWidget {
  const _FallbackGamesPage({required this.lib, required this.stage});
  final _Lib lib;
  final FallbackStage stage;

  @override
  State<_FallbackGamesPage> createState() => _FallbackGamesPageState();
}

class _FallbackGamesPageState extends State<_FallbackGamesPage> {
  String _sport = 'All', _type = 'All';

  @override
  Widget build(BuildContext context) {
    final lib = widget.lib, s = widget.stage;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final sports = fallbackSports(s, lib.games);
        final types = fallbackTypes(s, lib.games);
        final games = fallbackFiltered(s, lib.games, _sport, _type);
        return _Scaffold(
          title: s.subtitle,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(112),
            child: Column(children: [
              _ChipRow(
                  options: sports,
                  selected: _sport,
                  onTap: (v) => setState(() => _sport = v)),
              _ChipRow(
                  options: types,
                  selected: _type,
                  onTap: (v) => setState(() => _type = v)),
            ]),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: games.isEmpty
                ? const [_Message(text: 'No resources found for this filter.')]
                : _gameCards(context, lib, games),
          ),
        );
      },
    );
  }
}
