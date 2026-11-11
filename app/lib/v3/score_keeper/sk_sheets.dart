// v3 Score keeper: the slide-up sheets — how to, saving, the ⋯ menu, reset,
// change one entry, a sub, the half-time / full-time score check and
// making a sub. Each listens to the controller, so it stays current.
import 'package:flutter/material.dart';

import '../match_stats/v3_match_stats_models.dart';
import '../v3_theme.dart';
import 'sk_controller.dart';
import 'sk_models.dart';
import 'sk_widgets.dart';

Widget _live(SkController ctl, Widget Function() build) =>
    ListenableBuilder(listenable: ctl, builder: (_, __) => build());

Widget _sub(String t) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(t, style: V3.inter(16, color: V3.muted)),
    );

Widget _link(String t, VoidCallback onTap) => Center(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
        child: Text(t,
            style: V3.inter(15, color: V3.muted).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: V3.muted)),
      ),
    );

SkButton _close(BuildContext ctx, [String label = 'Close']) => SkButton(
    label: label,
    height: 54,
    tone: SkTone.soft,
    onTap: () => Navigator.of(ctx).pop());

// ----------------------------------------------------------------- how to

Future<void> showSkHowTo(BuildContext context, SkController ctl) {
  Widget sec(String t) => SkSec(t);
  Widget hi(String ic, String b, [String? s, Color? icColor]) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: V3.card2, borderRadius: BorderRadius.circular(10)),
            child: Text(ic,
                style: V3.inter(16,
                    weight: FontWeight.w700, color: icColor ?? V3.text)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b, style: V3.inter(16, weight: FontWeight.w500)),
              if (s != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(s, style: V3.inter(14, color: V3.muted)),
                ),
            ]),
          ),
        ]),
      );
  return showSkSheet<void>(context,
      title: 'How to use the score keeper',
      body: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sec('Scoring'),
              hi('+', 'Tap Goal, Point or 2 Pointer for the team that scored',
                  'Start the half first. Any other stat buttons your team has are further down: scroll to them'),
              sec('Fix a mistake'),
              hi('↶', 'Tap Undo on the bar that pops up after each tap',
                  'For a mis-tap you notice straight away'),
              hi('☰', 'Tap the score in the Latest list',
                  'Add the player, change it (Point ↔ Wide, or the other team), or use – / + to take one off or add another'),
              hi('✋', 'Press and hold a button to take one off',
                  'You feel a buzz when it works'),
              hi(
                  '✓',
                  "At half time and full time, check against the ref's score",
                  "Edit sets it to the ref's score, and shows in the timeline as a score check. You can still do it after the match is saved."),
              sec('Voice'),
              hi('🎙', 'Switch to Voice, hold the mic and say what happened',
                  '"Point Ciarán", "Goal number 11", "Wide for them", "Two pointer Clontarf". You can say a few in one go.'),
              hi('➕', 'Voice knows every stat, even ones with no button',
                  '"Free to us", "Free against Luke" (a free to them, given away by Luke), "Turnover Luke", "Luke lost it", "Point Murrough free" (a point from a free), "45", "Throw in". Only scores show on the Stats tab and the live screen.'),
              hi('⇄', 'Subs: "Sub 17 for 11"',
                  'Or use Make a sub in the ⋯ menu'),
              hi('?', 'It never stops to ask',
                  '"Point" on its own counts for ${ctl.us}. If it isn\'t sure of a name it picks the closest player and shows a ? on the card. Tap Change if it\'s wrong and it remembers for next time.'),
              sec('The clock'),
              hi('❚❚', 'Pause for stoppages, End half when the ref blows',
                  'The clock turns amber in injury time. If you forget, the half ends by itself when injury time is up'),
              sec('No signal?'),
              hi(
                  '●',
                  "Keep scoring. It's all saved on your phone",
                  'It uploads by itself when signal comes back. The pill at the top shows what is still waiting.',
                  V3.amber),
              hi('☀', 'The screen stays on until the match is saved',
                  'Tap the sun to turn that off'),
            ],
          ));
}

// ----------------------------------------------------------------- saving

Future<void> showSkSaving(BuildContext context, SkController ctl) {
  final s = ctl.s;
  final n = s?.pending ?? 0;
  final rej = s?.rejected.length ?? 0;
  return showSkSheet<void>(context,
      title: 'Saving',
      body: (ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sub(pillMessage(n, ctl.netState)),
              if (rej > 0)
                _sub(
                    '$rej entr${rej == 1 ? 'y was' : 'ies were'} turned down by the server and set aside.'),
              SkSheetButtons(
                left: _close(ctx),
                right: SkButton(
                    label: 'Try now',
                    height: 54,
                    tone: SkTone.green,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ctl.syncNow();
                    }),
              ),
            ],
          ));
}

// ------------------------------------------------------------------- menu

/// The ⋯ menu. Returns the item picked.
Future<String?> showSkMenu(BuildContext context, SkController ctl) {
  final s = ctl.s!, c = ctl.c!;
  final last = ctl.lastScore;
  final ll = last == null ? null : actLabel(s, c, last);
  final canSub = ctl.players.isNotEmpty && s.phase != 'setup';
  Widget mi(BuildContext ctx, String k, IconData ic, String b, String sub,
          {bool red = false, bool disabled = false}) =>
      Opacity(
        opacity: disabled ? .4 : 1,
        child: InkWell(
          onTap: disabled ? null : () => Navigator.of(ctx).pop(k),
          child: Container(
            constraints: const BoxConstraints(minHeight: 66),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: V3.line))),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: V3.card2, borderRadius: BorderRadius.circular(12)),
                child: Icon(ic, color: red ? skRed : V3.text, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b,
                          style: V3.inter(17,
                              weight: FontWeight.w500,
                              color: red ? skRed : V3.text)),
                      const SizedBox(height: 2),
                      Text(sub, style: V3.inter(14, color: V3.muted)),
                    ]),
              ),
            ]),
          ),
        ),
      );
  return showSkSheet<String>(context,
      body: (ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s.phase != 'done')
                mi(ctx, 'setup', Icons.settings_outlined, 'Match setup',
                    'Opposition, squad, half length, injury time'),
              mi(
                  ctx,
                  'undo',
                  Icons.undo,
                  'Undo last score',
                  last == null
                      ? 'Nothing to undo'
                      : '${ll!.$1} · ${ll.$2} · ${ctl.minute(last.half, last.sec)}',
                  disabled: last == null),
              if (canSub)
                mi(
                    ctx,
                    'sub',
                    Icons.swap_horiz,
                    'Make a sub',
                    s.subs.isNotEmpty
                        ? '${s.subs.length} made so far'
                        : 'Who came off and who went on'),
              if (s.phase != 'setup')
                mi(ctx, 'check', Icons.check, "Check against the ref's score",
                    "Set the score to the ref's"),
              if (s.phase != 'setup' && s.phase != 'play')
                mi(ctx, 'chart', Icons.show_chart, 'Stats',
                    'Charts, scorers and the timeline, with a PDF'),
              mi(
                  ctx,
                  'awake',
                  Icons.wb_sunny_outlined,
                  'Screen stays on',
                  ctl.awakeWanted
                      ? 'On for the whole match. Tap to turn off.'
                      : 'Off. Tap to keep the screen on.'),
              if (s.phase == 'done')
                mi(ctx, 'again', Icons.replay, 'Start a new record',
                    'Keeps this one, starts again from 0-00', red: true)
              else if (s.phase != 'setup')
                mi(ctx, 'reset', Icons.replay, 'Reset match',
                    'Clears the clock and every score',
                    red: true),
            ],
          ));
}

Future<void> confirmSkReset(
    BuildContext context, SkController ctl, bool again) async {
  final go = await showSkSheet<bool>(context,
      close: false,
      title: again ? 'Start a new record?' : 'Reset the match?',
      body: (ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sub(again
                  ? 'This match stays saved. A new record starts at 0-00 with the clock at zero.'
                  : "This clears the clock and every score for this match. It can't be undone."),
              SkSheetButtons(
                left: _close(ctx, 'Cancel'),
                right: SkButton(
                    label: again ? 'Start again' : 'Reset',
                    height: 54,
                    tone: SkTone.red,
                    onTap: () => Navigator.of(ctx).pop(true)),
              ),
            ],
          ));
  if (go == true) await ctl.resetMatch(again);
}

// ------------------------------------------------------------ edit entry

/// Change or remove one entry.
Future<void> showSkEdit(BuildContext context, SkController ctl, String id) {
  if (ctl.s?.acts.any((x) => x.id == id) != true) return Future.value();
  final extra = <SkAct>[]; // copies added with + (changes apply to them too)
  var showAll = false;
  return showSkSheet<void>(context,
      body: (ctx) => StatefulBuilder(
          builder: (ctx, set) => _live(ctl, () {
                final s = ctl.s!, c = ctl.c!;
                final a = s.acts.where((x) => x.id == id).firstOrNull;
                if (a == null) return const SizedBox(height: 40);
                final ids = [a.id, ...extra.map((x) => x.id)];
                void edit(Map<String, Object?> ch) => ctl.editActs(ids, ch);
                final (lt, ls) = actLabel(s, c, a);
                final t = c.typeById(a.st);
                final scoring = t.scoring;
                final isScore = a.k == 'score';
                final ourScore = isScore && (a.side == 'us' || !scoring);
                final r = ctl.players;
                final all = r.values.toList();
                int byName(SkPlayer x, SkPlayer y) => x.full.compareTo(y.full);
                final op = onPitch(s, c);
                final list = op != null && op.isNotEmpty
                    ? [...op]
                    : ([...all]..sort(byName));
                if (a.mem != null &&
                    !list.any((p) => p.id == a.mem) &&
                    r[a.mem] != null) {
                  list.insert(0, r[a.mem]!);
                }
                final rest = all
                    .where((p) => !list.any((q) => q.id == p.id))
                    .toList()
                  ..sort(byName);
                Widget shirt(SkPlayer p) => SkShirt(
                    number: p.number?.toString() ?? '·',
                    name: p.short,
                    selected: a.mem == p.id,
                    onTap: () {
                      edit({'mem': p.id});
                      // fix the spoken name for next time
                      if (a.heard != null) ctl.rememberName(a.heard, p.id);
                    });
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SkSheetHead('$lt · ${ctl.minute(a.half, a.sec)}',
                          sub: ls),
                      if (isScore) ...[
                        const SkSec('What was it?'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final x in c.types)
                            if (x.button || x.id == a.st)
                              SkChoice(
                                  label: x.name,
                                  on: x.id == a.st,
                                  onTap: () => edit({'st': x.id})),
                        ]),
                      ],
                      if (isScore && scoring && c.sourceTypes.isNotEmpty) ...[
                        const SkSec('From'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          SkChoice(
                              label: 'Play',
                              on: a.fr == null,
                              onTap: () => edit({'fr': null})),
                          for (final x in c.sourceTypes)
                            SkChoice(
                                label: x.name,
                                on: a.fr == x.id,
                                onTap: () => edit({'fr': x.id})),
                        ]),
                      ],
                      SkSec(
                          isScore && !scoring ? 'Whose ball?' : 'Which team?'),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        SkChoice(
                            label: ctl.us,
                            on: a.side == 'us',
                            onTap: () => edit({'side': 'us'})),
                        SkChoice(
                            label: ctl.opp,
                            on: a.side == 'opp',
                            red: true,
                            onTap: () => edit({'side': 'opp'})),
                      ]),
                      if (isScore)
                        Container(
                          margin: const EdgeInsets.only(top: 14),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('How many?',
                                        style: V3.inter(17,
                                            weight: FontWeight.w500)),
                                    Text(
                                        'Add another the same, or take one off',
                                        style: V3.inter(14, color: V3.muted)),
                                  ]),
                            ),
                            SkStepper(
                                value: 1 + extra.length,
                                label: t.name.toLowerCase(),
                                onPlus: () =>
                                    set(() => extra.add(ctl.copyAct(a))),
                                onMinus: () {
                                  if (extra.isNotEmpty) {
                                    set(() =>
                                        ctl.dropAct(extra.removeLast().id));
                                    return;
                                  }
                                  Navigator.of(ctx).pop();
                                  ctl.deleteAct(a.id);
                                }),
                          ]),
                        ),
                      if (ourScore && all.isNotEmpty) ...[
                        SkSec(a.side == 'opp'
                            ? 'Against which of ours?'
                            : 'Who?'),
                        SkShirtGrid(children: [
                          SkShirt(
                              number: '–',
                              name: 'No one',
                              selected: a.mem == null,
                              onTap: () {
                                edit({'mem': null});
                                if (a.heard != null) {
                                  ctl.rememberName(a.heard, null);
                                }
                              }),
                          for (final p in list) shirt(p),
                          if (showAll)
                            for (final p in rest) shirt(p),
                        ]),
                        if (rest.isNotEmpty && !showAll)
                          _link('Someone else (${rest.length} more)',
                              () => set(() => showAll = true)),
                      ],
                      SkSheetButtons(
                        left: SkButton(
                            label: 'Remove',
                            height: 54,
                            tone: SkTone.soft,
                            textColor: skRed,
                            onTap: () {
                              Navigator.of(ctx).pop();
                              ctl.deleteAct(a.id);
                            }),
                        right: SkButton(
                            label: 'Done',
                            height: 54,
                            tone: SkTone.green,
                            onTap: () => Navigator.of(ctx).pop()),
                      ),
                    ]);
              })));
}

Future<void> showSkSubEdit(BuildContext context, SkController ctl, String id) {
  final x = ctl.s?.subs.where((y) => y.id == id).firstOrNull;
  if (x == null) return Future.value();
  final on = ctl.nameOf(x.on), off = ctl.nameOf(x.off);
  return showSkSheet<void>(context,
      title: 'Sub · ${ctl.minute(x.half, x.sec)}',
      body: (ctx) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sub(
                  '${on.isEmpty ? '?' : on} on for ${off.isEmpty ? '?' : off}'),
              SkSheetButtons(
                left: SkButton(
                    label: 'Remove sub',
                    height: 54,
                    tone: SkTone.soft,
                    textColor: skRed,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ctl.deleteSub(x.id);
                    }),
                right: SkButton(
                    label: 'Done',
                    height: 54,
                    tone: SkTone.green,
                    onTap: () => Navigator.of(ctx).pop()),
              ),
            ],
          ));
}

// ------------------------------------------------------------ score check

/// Half-time / full-time: set the score to the ref's.
Future<void> showSkCorrect(BuildContext context, SkController ctl) {
  final c = ctl.c!;
  if (c.goalType == null || c.pointType == null) {
    ctl.toast('This team has no Goal and Point score types');
    return Future.value();
  }
  final Walk rec = ctl.totals();
  final v = {
    'us.g': rec.usG,
    'us.p': rec.usP,
    'opp.g': rec.oppG,
    'opp.p': rec.oppP
  };
  final was = Map.of(v);
  final ph = ctl.s!.phase;
  final label = ph == 'ht'
      ? 'half-time '
      : ph == 'ft' || ph == 'done'
          ? 'full-time '
          : '';
  return showSkSheet<void>(context,
      close: false,
      title: 'Correct the ${label}score',
      body: (ctx) => StatefulBuilder(builder: (ctx, set) {
            Widget row(String k, String name) {
              final d = v[k]! - was[k]!;
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: V3.line))),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(name,
                                style: V3.inter(17, weight: FontWeight.w500)),
                            if (d != 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: V3.amber.withValues(alpha: .15),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text('${d > 0 ? '+' : ''}$d',
                                    style: V3.inter(14,
                                        weight: FontWeight.w700,
                                        color: V3.amber)),
                              ),
                          ]),
                          Text('Recorded ${was[k]}',
                              style: V3.inter(14, color: V3.muted)),
                        ]),
                  ),
                  SkStepper(
                      value: v[k]!,
                      label: name.toLowerCase(),
                      onMinus: () =>
                          set(() => v[k] = (v[k]! - 1).clamp(0, 999)),
                      onPlus: () => set(() => v[k] = v[k]! + 1)),
                ]),
              );
            }

            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sub(
                      "Set it to the ref's score. Your recorded scores stay as they are, and the change shows in the timeline as a score check."),
                  SkSec(ctl.us),
                  row('us.g', 'Goals'),
                  row('us.p', 'Points'),
                  SkSec(ctl.opp, red: true),
                  row('opp.g', 'Goals'),
                  row('opp.p', 'Points'),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(children: [
                      Expanded(
                          child: Text('New score',
                              style: V3.inter(16, color: V3.muted))),
                      Text(
                          '${gaa(v['us.g']!, v['us.p']!)} v ${gaa(v['opp.g']!, v['opp.p']!)}',
                          style: skNum(30)),
                    ]),
                  ),
                  SkSheetButtons(
                    left: _close(ctx, 'Cancel'),
                    right: SkButton(
                        label: 'Save score',
                        height: 54,
                        tone: SkTone.green,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ctl.saveCorrection(rec, v['us.g']!, v['us.p']!,
                              v['opp.g']!, v['opp.p']!);
                        }),
                  ),
                ]);
          }));
}

// ------------------------------------------------------------------ subs

Future<void> showSkSubs(BuildContext context, SkController ctl,
    {int? off, int? on, SkAt? at}) {
  final s = ctl.s!, c = ctl.c!;
  final r = ctl.players;
  final op = onPitch(s, c);
  final when = at ?? ctl.stamp();
  var others = false;
  return showSkSheet<void>(context,
      title: 'Make a sub · ${ctl.minute(when.half, when.sec)}',
      body: (ctx) => StatefulBuilder(builder: (ctx, set) {
            final all = r.values.toList()
              ..sort((a, b) {
                final n = (a.number ?? 99) - (b.number ?? 99);
                return n != 0 ? n : a.full.compareTo(b.full);
              });
            final offList = op ?? all;
            final opIds = {for (final p in op ?? <SkPlayer>[]) p.id};
            final bench = op != null
                ? all
                    .where(
                        (p) => !opIds.contains(p.id) && (p.inLineup || others))
                    .toList()
                : all;
            Widget shirt(SkPlayer p, bool sel, VoidCallback f) => SkShirt(
                number: p.number?.toString() ?? '·',
                name: p.short,
                selected: sel,
                onTap: f);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sub(
                      'Pick who comes off, then who goes on. Or say "Sub 17 for 11" in Voice mode.'),
                  const SkSec('Coming off', red: true),
                  SkShirtGrid(children: [
                    for (final p in offList)
                      shirt(p, off == p.id, () => set(() => off = p.id)),
                  ]),
                  const SkSec('Going on'),
                  if (bench.isEmpty)
                    Text('No one on the bench',
                        style: V3.inter(14, color: V3.muted))
                  else
                    SkShirtGrid(children: [
                      for (final p in bench)
                        shirt(p, on == p.id, () => set(() => on = p.id)),
                    ]),
                  if (op != null &&
                      !others &&
                      all.any((p) => !opIds.contains(p.id) && !p.inLineup))
                    _link('Someone not in the line-up',
                        () => set(() => others = true)),
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                        color: V3.card2,
                        borderRadius: BorderRadius.circular(14)),
                    child: Text.rich(TextSpan(style: V3.inter(17), children: [
                      on != null
                          ? TextSpan(
                              text: '▲ ${r[on]?.short ?? '?'}',
                              style: V3.inter(17, color: V3.green))
                          : TextSpan(
                              text: '▲ on',
                              style: V3.inter(17, color: V3.muted)),
                      const TextSpan(text: '   ⇄   '),
                      off != null
                          ? TextSpan(
                              text: '▼ ${r[off]?.short ?? '?'}',
                              style: V3.inter(17, color: skRed))
                          : TextSpan(
                              text: '▼ off',
                              style: V3.inter(17, color: V3.muted)),
                    ])),
                  ),
                  SkSheetButtons(
                    left: _close(ctx, 'Cancel'),
                    right: Opacity(
                      opacity: on != null && off != null ? 1 : .4,
                      child: SkButton(
                          label: 'Make sub',
                          height: 54,
                          tone: SkTone.green,
                          onTap: () {
                            if (on == null || off == null) {
                              ctl.toast('Pick who comes off and who goes on');
                              return;
                            }
                            if (on == off) {
                              ctl.toast('Pick two different players');
                              return;
                            }
                            Navigator.of(ctx).pop();
                            ctl.makeSub(off!, on!, when);
                          }),
                    ),
                  ),
                ]);
          }));
}
