// A game opened from the Coaching tab: the shared V3GameDetailPage (heart,
// PDF card, My Notes, edit / delete rules) with an "Add to plan" button
// pinned underneath. A wrapper, because the shared page has no slot for it.
import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../v3_theme.dart';
import 'v3_coaching_games_models.dart';
import 'v3_plan_draft.dart';

class V3CoachingGameDetailPage extends StatefulWidget {
  const V3CoachingGameDetailPage({
    super.key,
    required this.game,
    required this.api,
    required this.favourites,
    required this.draft,
    this.myClubId,
    this.onChanged,
    this.onDeleted,
  });

  final V3Game game;
  final V3GamesApi api;
  final V3GameFavourites favourites;
  final V3PlanDraft draft;
  final int? myClubId;
  final ValueChanged<V3Game>? onChanged;
  final ValueChanged<int>? onDeleted;

  @override
  State<V3CoachingGameDetailPage> createState() =>
      _V3CoachingGameDetailPageState();
}

class _V3CoachingGameDetailPageState extends State<V3CoachingGameDetailPage> {
  late V3Game _g = widget.game;

  void _toggle() {
    final d = widget.draft;
    if (!d.contains(_g.gameId) && d.isFull) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(kPlanFullText,
                textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
            backgroundColor: V3.amber));
      return;
    }
    d.toggle(_g.gameId, _g.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      body: V3GameDetailPage(
        game: widget.game,
        api: widget.api,
        favourites: widget.favourites,
        myClubId: widget.myClubId,
        onChanged: (g) {
          _g = g;
          widget.onChanged?.call(g);
        },
        onDeleted: (id) {
          widget.draft.remove(id);
          widget.onDeleted?.call(id);
        },
      ),
      // Skills can't go in a plan (no heart, no +), as in the list.
      bottomNavigationBar: !_g.canFavourite
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: ListenableBuilder(
                  listenable: widget.draft,
                  builder: (context, _) {
                    final inPlan = widget.draft.contains(_g.gameId);
                    return SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: inPlan ? V3.greenTint : V3.green,
                            side: inPlan
                                ? const BorderSide(color: V3.green)
                                : BorderSide.none,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        onPressed: _toggle,
                        child: Text(inPlan ? 'In your plan ✓' : 'Add to plan',
                            style: V3.inter(17,
                                weight: FontWeight.w700,
                                color: inPlan ? V3.green : V3.bg)),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }
}
