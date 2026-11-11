// v3 Coaching: one tab for games and session plans, replacing the Resources
// and Favourites tabs (proposal approved by Ken 2026-11-11).
//
//   Games | Plans    a two-part switch under the title
//   Games            V3CoachingGames: search, filters, heart, + to the plan
//   Plans            built by [plansBuilder] (the plans list lives in its
//                    own files); a placeholder until one is passed in
//
// The plan builder also opens this page with [pickMode] to add games: no
// switch, title "Add games", and a "Done" bar that pops the page.
import 'package:flutter/material.dart';

import '/app_state.dart';
import '../game_upload/v3_game_upload_page.dart';
import '../v3_theme.dart';
import 'v3_coaching_games.dart';
import 'v3_plan_draft.dart';

class V3CoachingPage extends StatefulWidget {
  const V3CoachingPage({
    super.key,
    this.initialTab = 0,
    this.plansBuilder,
    this.onOpenPlan,
    this.pickMode = false,
    this.draft,
    this.testData,
  });

  /// 0 = Games, 1 = Plans.
  final int initialTab;

  /// Builds the Plans half. Null: "Plans are coming soon".
  final Widget Function(BuildContext context)? plansBuilder;

  /// Tap on the green plan bar. Null: the bar does nothing.
  final void Function(BuildContext context)? onOpenPlan;

  /// Opened by the plan builder to add games.
  final bool pickMode;

  /// The plan in progress; [V3PlanDraft.instance] when null.
  final V3PlanDraft? draft;

  /// Offline data for widget tests (see [V3CoachingGames.testData]).
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3CoachingPage> createState() => _V3CoachingPageState();
}

class _V3CoachingPageState extends State<V3CoachingPage> {
  final _gamesKey = GlobalKey<V3CoachingGamesState>();
  late int _tab = widget.pickMode ? 0 : widget.initialTab.clamp(0, 1);

  /// Plans is built the first time it is shown, then kept.
  late bool _plansShown = _tab == 1;

  // Managers (role 100+) can add a game, as the Resources page's + did.
  List<Widget>? _actions() {
    if (widget.testData != null ||
        widget.pickMode ||
        _tab != 0 ||
        FFAppState().homePageEvents.highestRoleLevel < 100) {
      return null;
    }
    return [
      IconButton(
        tooltip: 'Add a game or drill',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.add, color: V3.green, size: 30),
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const V3GameUploadPage()));
          if (saved == true) _gamesKey.currentState?.refresh();
        },
      ),
      const SizedBox(width: 4),
    ];
  }

  void _setTab(int t) {
    if (t == _tab) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _tab = t;
      if (t == 1) _plansShown = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final games = V3CoachingGames(
      key: _gamesKey,
      draft: widget.draft,
      onOpenPlan: widget.onOpenPlan,
      pickMode: widget.pickMode,
      testData: widget.testData,
    );
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
        title: Text(widget.pickMode ? 'Add games' : 'Coaching',
            style: V3.tight(17)),
        actions: _actions(),
        bottom: widget.pickMode
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: _Switch(
                      labels: const ['Games', 'Plans'],
                      selected: _tab,
                      onTap: _setTab),
                ),
              ),
      ),
      body: widget.pickMode
          ? games
          : IndexedStack(index: _tab, children: [
              games,
              if (!_plansShown)
                const SizedBox.shrink()
              else if (widget.plansBuilder != null)
                Builder(builder: widget.plansBuilder!)
              else
                const _PlansSoon(),
            ]),
    );
  }
}

/// The Games | Plans switch: two halves, each 48 high.
class _Switch extends StatelessWidget {
  const _Switch(
      {required this.labels, required this.selected, required this.onTap});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: V3.card,
          border: Border.all(color: V3.line),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final (i, l) in labels.indexed)
          Expanded(
            child: Material(
              color: i == selected ? V3.green : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('coaching-tab-$i'),
                onTap: () => onTap(i),
                child: Center(
                  child: Text(l,
                      style: V3.inter(16,
                          weight: FontWeight.w700,
                          color: i == selected ? V3.bg : V3.text)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _PlansSoon extends StatelessWidget {
  const _PlansSoon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.event_note_outlined, color: V3.muted, size: 44),
          const SizedBox(height: 12),
          Text('Plans are coming soon',
              textAlign: TextAlign.center,
              style: V3.inter(18, weight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
