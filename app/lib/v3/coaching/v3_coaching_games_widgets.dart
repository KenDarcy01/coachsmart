// Pieces shared by the Coaching tab's games views (the landing view and
// the stage page): pills and their pick sheets, the game card with heart
// and +, pathway content rows, the green plan bar, and the actions behind
// them (heart, add to plan, open a game, pick a Code or Type).
import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../resources/v3_resources_models.dart';
import '../v3_theme.dart';
import 'v3_coaching_games_controller.dart';
import 'v3_coaching_games_detail.dart';
import 'v3_coaching_games_models.dart';

// ------------------------------------------------------------ actions

/// A snack that floats clear of the plan bar and the phone's bottom inset.
void coachingSnack(BuildContext context, CoachingGamesController c, String text,
    {bool warn = false}) {
  if (!context.mounted) return;
  final barShown = c.pickMode || !c.draft.isEmpty;
  final bottom =
      MediaQuery.of(context).padding.bottom + (barShown ? 72 : 0) + 12;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottom),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
}

Future<void> coachingHeart(
    BuildContext context, CoachingGamesController c, V3Game g) async {
  final msg = await c.favs.toggle(g.gameId);
  if (!context.mounted) return;
  coachingSnack(context, c, msg, warn: msg.startsWith('Could'));
}

void coachingTogglePlan(
    BuildContext context, CoachingGamesController c, V3Game g) {
  if (!c.draft.contains(g.gameId) && c.draft.isFull) {
    coachingSnack(context, c, kPlanFullText, warn: true);
    return;
  }
  c.draft.toggle(g.gameId, g.name);
}

void coachingOpenGame(
    BuildContext context, CoachingGamesController c, V3Game g) {
  FocusScope.of(context).unfocus();
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => V3CoachingGameDetailPage(
            game: g,
            api: c.api,
            favourites: c.favs,
            draft: c.draft,
            myClubId: c.myClubId,
            onChanged: c.replaceGame,
            onDeleted: c.removeGame,
          )));
}

/// The Code sheet. [games] are the ones on offer here; [extra] adds codes
/// that only the stage's pathway content has.
Future<void> coachingPickCode(
    BuildContext context, CoachingGamesController c, List<V3Game> games,
    [Iterable<String> extra = const []]) async {
  final r = await showCoachingPickSheet<String>(context,
      title: 'Code',
      allLabel: 'All codes',
      groups: [
        CoachingSheetGroup(null, [
          for (final x in gameCodes(games, extra)) CoachingSheetOption(x, x)
        ])
      ],
      isSelected: (x) => x == c.code,
      noneSelected: c.code == null);
  if (r != null) c.setCode(r.value);
}

Future<void> coachingPickType(
    BuildContext context, CoachingGamesController c, List<V3Game> games) async {
  final r = await showCoachingPickSheet<GameKind>(context,
      title: 'Type',
      allLabel: 'All types',
      groups: [
        CoachingSheetGroup(null, [
          for (final k in gameKinds(games))
            CoachingSheetOption(k, coachingKindLabel(k))
        ])
      ],
      isSelected: (k) => k == c.kind,
      noneSelected: c.kind == null);
  if (r != null) c.setKind(r.value);
}

void coachingOpenDetail(BuildContext context, StageDetail d) {
  if (d.imageLink.isEmpty && d.videoLink.isNotEmpty) {
    openGameVideo(d.videoLink);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => V3ImageViewerPage(
          imageUrl: d.imageLink, title: d.heading, subtitle: d.subheading)));
}

// ------------------------------------------------------------ pieces

/// The Code and Type pills, as both views show them.
List<Widget> coachingCodeTypePills(
        BuildContext context, CoachingGamesController c, List<V3Game> games,
        [Iterable<String> extraCodes = const []]) =>
    [
      CoachingPill(
          key: const ValueKey('pill-code'),
          label: c.code ?? 'Code',
          sheet: true,
          on: c.code != null,
          onTap: () => coachingPickCode(context, c, games, extraCodes)),
      const SizedBox(width: 8),
      CoachingPill(
          key: const ValueKey('pill-type'),
          label: c.kind == null ? 'Type' : coachingKindLabel(c.kind!),
          sheet: true,
          on: c.kind != null,
          onTap: () => coachingPickType(context, c, games)),
    ];

/// A row of pills, left aligned even when they don't fill the row.
class CoachingPillRow extends StatelessWidget {
  const CoachingPillRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.centerLeft,
        height: 56,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: children),
        ),
      );
}

/// A game in a Coaching list: the shared game row's look (kind dot, name,
/// type / skill / club tags) with a heart and a + for the plan, and an
/// optional [stage] tag first ("Stage 1") on search and Saved results.
class CoachingGameCard extends StatelessWidget {
  const CoachingGameCard(
      {super.key,
      required this.game,
      required this.controller,
      this.stage = ''});
  final V3Game game;
  final CoachingGamesController controller;
  final String stage;

  @override
  Widget build(BuildContext context) {
    final c = controller, g = game;
    final kc = gameKindColor(g.kind);
    final typeColor = g.kind == GameKind.game ? V3.muted : kc;
    final tags = <Widget>[
      if (stage.isNotEmpty) V3GameTag(stage, color: V3.green),
      for (final t in g.types) V3GameTag(t, color: typeColor),
      for (final s in g.skills.take(2)) V3GameTag(s),
      if (g.clubId != null)
        V3GameTag(c.clubName.isNotEmpty ? c.clubName : 'Club',
            color: kVideoBlue),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: V3.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => coachingOpenGame(context, c, g),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
              child: Row(children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: kc, shape: BoxShape.circle)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name,
                            style: V3.inter(17,
                                weight: FontWeight.w600, height: 1.25)),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: tags),
                        ],
                      ]),
                ),
                // Skills can't be saved or planned: no heart, no +.
                if (!g.canFavourite)
                  const SizedBox(width: 10)
                else ...[
                  V3HeartButton(
                      on: c.favs.isFav(g.gameId),
                      onPressed: () => coachingHeart(context, c, g)),
                  CoachingPlanCircle(
                      on: c.draft.contains(g.gameId),
                      onPressed: () => coachingTogglePlan(context, c, g)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// A picture or video of a stage's pathway content.
class CoachingDetailRow extends StatelessWidget {
  const CoachingDetailRow({super.key, required this.detail});
  final StageDetail detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
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
          onTap: () => coachingOpenDetail(context, d),
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
}

/// The green bar: "N games in your plan · M min  Open ›", or in pick mode
/// "Done · N games in your plan". Hidden while the plan is empty, unless
/// picking.
class CoachingPlanBar extends StatelessWidget {
  const CoachingPlanBar(
      {super.key, required this.controller, this.onOpen, this.onDone});
  final CoachingGamesController controller;

  /// Tap outside pick mode. Null: the bar does nothing.
  final VoidCallback? onOpen;

  /// Tap in pick mode.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final draft = controller.draft, pick = controller.pickMode;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        if (!pick && draft.isEmpty) return const SizedBox.shrink();
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
                onTap: pick ? onDone : onOpen,
                child: SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                            pick
                                ? pickDoneText(draft.count)
                                : planBarText(draft.count, draft.totalMins),
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
}

/// The spinner shown while a list loads.
class CoachingSpinner extends StatelessWidget {
  const CoachingSpinner({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
          child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: V3.green, strokeWidth: 2.5))));
}

/// The + / tick circle on a game card: in or out of the plan being built.
class CoachingPlanCircle extends StatelessWidget {
  const CoachingPlanCircle(
      {super.key, required this.on, required this.onPressed});
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

class CoachingPill extends StatelessWidget {
  const CoachingPill(
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

class CoachingLabel extends StatelessWidget {
  const CoachingLabel(this.text, {super.key, this.top = 0});
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

class CoachingEmpty extends StatelessWidget {
  const CoachingEmpty(
      {super.key, required this.text, this.action, this.onAction});
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

class CoachingSheetOption<T> {
  const CoachingSheetOption(this.value, this.label, {this.subtitle = ''});
  final T value;
  final String label, subtitle;
}

class CoachingSheetGroup<T> {
  const CoachingSheetGroup(this.heading, this.options);
  final String? heading;
  final List<CoachingSheetOption<T>> options;
}

/// What a sheet returns: the value, or null inside for "All". (A null
/// result from the sheet itself means it was dismissed.)
class CoachingPicked<T> {
  const CoachingPicked(this.value);
  final T? value;
}

/// A quiet link out to a website (the club's pathway site).
class CoachingLinkRow extends StatelessWidget {
  const CoachingLinkRow({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
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

Future<CoachingPicked<T>?> showCoachingPickSheet<T>(
  BuildContext context, {
  required String title,
  required String allLabel,
  required List<CoachingSheetGroup<T>> groups,
  required bool Function(T) isSelected,
  required bool noneSelected,
}) {
  FocusScope.of(context).unfocus();
  Widget row(BuildContext ctx, String label, String subtitle, bool on,
          CoachingPicked<T> result) =>
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

  return showModalBottomSheet<CoachingPicked<T>>(
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
              row(ctx, allLabel, '', noneSelected, CoachingPicked<T>(null)),
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
                      CoachingPicked<T>(o.value)),
              ],
              const SizedBox(height: 8),
            ]),
          ),
        ]),
      ),
    ),
  );
}
