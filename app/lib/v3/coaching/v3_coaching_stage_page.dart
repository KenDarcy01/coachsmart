// One stage of the club's pathway, opened from the Coaching tab's landing
// view: "Stage N", its description and ages, Code and Type pills, the
// stage's pathway content (Player Pathways and Sample Sessions pictures),
// then its games by kind, each with heart and +, and the green plan bar.
//
// With no [stage] it is the "Other games" page: games that are in no stage.
import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../resources/v3_resources_models.dart';
import '../v3_theme.dart';
import 'v3_coaching_games_controller.dart';
import 'v3_coaching_games_models.dart';
import 'v3_coaching_games_widgets.dart';

class V3CoachingStagePage extends StatefulWidget {
  const V3CoachingStagePage(
      {super.key, required this.controller, this.stage, this.onOpenPlan});

  /// The Games view's state: games, hearts, the plan, Code and Type.
  final CoachingGamesController controller;

  /// The stage to show; null for "Other games".
  final CoachingStage? stage;

  /// The green bar's tap. Null: the bar does nothing. In pick mode the bar
  /// reads "Done" and pops this page with true instead.
  final void Function(BuildContext context)? onOpenPlan;

  @override
  State<V3CoachingStagePage> createState() => _V3CoachingStagePageState();
}

class _V3CoachingStagePageState extends State<V3CoachingStagePage> {
  CoachingGamesController get _c => widget.controller;
  CoachingStage? get _stage => widget.stage;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails({bool retry = false}) async {
    final s = _stage;
    if (s == null) return;
    final ok = await _c.loadDetails(s, retry: retry);
    if (!ok && mounted) {
      coachingSnack(context, _c, 'Could not load stage — please try again',
          warn: true);
    }
  }

  /// This page's games, before or after the Code and Type pills.
  List<V3Game> _games({bool filtered = true}) {
    final s = _stage;
    final code = filtered ? _c.code : null, kind = filtered ? _c.kind : null;
    return s == null
        ? otherGames(_c.games, _c.stages, code: code, kind: kind)
        : stageGames(_c.games, s, code: code, kind: kind);
  }

  List<StageDetail>? get _details =>
      _stage == null ? const [] : _c.details[_stage!.stage.id];

  List<WidgetBuilder> _rows() {
    final rows = <WidgetBuilder>[];
    var first = true;
    void label(String text) {
      final top = first ? 4.0 : 14.0;
      first = false;
      rows.add((_) => CoachingLabel(text, top: top));
    }

    final s = _stage;
    final blurb = s == null ? '' : stageBlurb(s.stage);
    if (blurb.isNotEmpty) {
      rows.add((_) => Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 12),
            child:
                Text(blurb, style: V3.inter(16, color: V3.muted, height: 1.4)),
          ));
    }

    // The stage's pathway content first, as the Resources stage page
    // showed it (pictures follow the code, not the type).
    var hasContent = false;
    final details = _details;
    if (details == null) {
      if (!_c.detailsFailed.contains(s!.stage.id)) {
        rows.add((_) => const CoachingSpinner());
      }
    } else {
      for (final cat in const [kPlayerPathways, kSampleSessions]) {
        final list = filteredDetails(details, cat, _c.code ?? 'All');
        if (list.isEmpty) continue;
        hasContent = true;
        label(cat);
        for (final d in list) {
          rows.add((_) => CoachingDetailRow(detail: d));
        }
      }
    }

    final games = _games();
    for (final (kind, list) in coachingSections(games, only: _c.kind)) {
      label(coachingKindLabel(kind));
      for (final g in list) {
        rows.add((_) => CoachingGameCard(game: g, controller: _c));
      }
    }
    if (games.isEmpty && !hasContent) {
      final picked = _c.code != null || _c.kind != null;
      rows.add((_) => CoachingEmpty(
          text: picked ? kNoMatchText : kNoStageGamesText,
          action: picked ? 'Clear filters' : null,
          onAction: _c.clearCodeAndKind));
    }
    return rows;
  }

  Widget _header() {
    final s = _stage;
    final heading = s == null ? '' : stageHeading(s.stage);
    if (heading.isEmpty) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(heading,
            style: V3.inter(17, weight: FontWeight.w600, height: 1.3)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _stage;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text(s?.label ?? kOtherGamesTitle, style: V3.tight(17)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([_c, _c.favs, _c.draft]),
        builder: (context, _) {
          final rows = _rows();
          final extraCodes = [
            for (final d in _details ?? const <StageDetail>[])
              if ((d.codeText ?? '').isNotEmpty) d.codeText!
          ];
          return Column(children: [
            _header(),
            CoachingPillRow(
                children: coachingCodeTypePills(
                    context, _c, _games(filtered: false), extraCodes)),
            Expanded(
              child: RefreshIndicator(
                color: V3.green,
                backgroundColor: V3.card,
                onRefresh: () => Future.wait([
                  _c.refresh(),
                  _c.favs.load(),
                  if (_details == null) _loadDetails(retry: true),
                ]),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => rows[i](context),
                ),
              ),
            ),
            CoachingPlanBar(
                controller: _c,
                onOpen: widget.onOpenPlan == null
                    ? null
                    : () => widget.onOpenPlan!(context),
                // Back to the plan builder: the Games view pops itself too.
                onDone: () => Navigator.of(context).pop(true)),
          ]);
        },
      ),
    );
  }
}
