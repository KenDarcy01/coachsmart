// v3 Coaching: an event's "Session plan" button (proposal approved by Ken
// 2026-11-11). An event that already has a plan opens it in the one plan
// screen, with "Change plan" leading back to the choices. Otherwise a
// bottom sheet offers three starts:
//   Start a new plan            the plan builder, with the event filled in
//   Use a saved plan            pick one of mine or my club's; attach_plan
//                               puts a copy on the event
//   Repeat last session's plan  my most recent plan on an earlier event of
//                               the same team, copied with attach_plan
//                               (hidden when there is none)
// attach_plan refreshes the copy's players, weather, date and title for
// this event.
//
// There is no gate: a team without session plans switched on (and a coach
// without AI) still gets the simple plan; only the AI controls hide.
import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../match_report/v3_voice_sheet.dart';
import '../session_plan/v3_session_plan_api.dart';
import '../session_plan/v3_session_plan_models.dart';
import '../session_plan/v3_session_plan_page.dart';
import '../session_plan/v3_session_plan_widgets.dart';
import '../v3_theme.dart';
import 'v3_plan_api.dart';
import 'v3_plan_builder_page.dart';
import 'v3_plan_draft.dart';
import 'v3_plan_models.dart';
import 'v3_plans_view.dart';

enum _Start { existing, fresh, saved, repeat }

class _Choice {
  const _Choice(this.start, this.load, [this.last]);
  final _Start start;
  final SpLoad load;
  final PlanItem? last;
}

/// Opens the event's plan, or the three ways to start one.
///
/// [onAddGames] is the builder's "+ Add games" (the Games list in pick
/// mode). [choose] goes straight to the choices even when the event has a
/// plan ("Change plan"). The rest are for tests.
Future<void> openEventPlan(
  BuildContext context, {
  required int eventId,
  void Function(BuildContext context)? onAddGames,
  bool choose = false,
  V3PlanApi api = const V3PlanApi(),
  V3GamesApi gamesApi = const V3GamesApi(),
  V3PlanDraft? draft,
  V3Dictation? dictation,
}) async {
  final nav = Navigator.of(context);
  final pick = await showModalBottomSheet<_Choice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: V3.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _EventPlanSheet(eventId: eventId, api: api, choose: choose),
  );
  if (pick == null || !nav.mounted) return;

  void change(BuildContext ctx) {
    final n = Navigator.of(ctx);
    n.pop();
    openEventPlan(n.context,
        eventId: eventId,
        onAddGames: onAddGames,
        choose: true,
        api: api,
        gamesApi: gamesApi,
        draft: draft,
        dictation: dictation);
  }

  Future<void> showPlan(Map plan, String? planId) => nav.push(MaterialPageRoute(
      builder: (_) => V3SessionPlanPage.open(
            eventId: eventId,
            plan: deepCopy(plan),
            planId: planId,
            aiAllowed: pick.load.allowed != false,
            event: pick.load.event,
            squadName: pick.load.squadName,
            clubId: pick.load.clubId,
            onChangePlan: change,
            gamesApi: gamesApi,
            call: api.callOverride,
            userId: api.userIdOverride,
            dictation: dictation,
          )));

  /// Puts a copy of a saved plan on the event, then opens it.
  Future<void> attach(String planId) async {
    showDialog<void>(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
                color: V3.card, borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: V3.green),
              const SizedBox(height: 16),
              Text('Adding the plan…',
                  style:
                      V3.inter(17).copyWith(decoration: TextDecoration.none)),
            ]),
          ),
        ),
      ),
    );
    SpResult? r;
    try {
      r = await api.plan(
          {'action': 'attach_plan', 'event_id': eventId, 'plan_id': planId});
    } catch (_) {}
    if (!nav.mounted) return;
    nav.pop(); // the progress box
    final p = r?.map['plan_json'];
    if (r == null || !r.ok || p is! Map) {
      spSnack(
          nav.context,
          r == null
              ? 'Network error. Please try again.'
              : spErrorText(r.data, 'The plan could not be added. Try again.'),
          warn: true);
      return;
    }
    spPlansChanged.value++;
    await showPlan(p, r.map['plan_id']?.toString());
  }

  switch (pick.start) {
    case _Start.existing:
      await showPlan(pick.load.plan!, pick.load.planId);
    case _Start.fresh:
      (draft ?? V3PlanDraft.instance).setEvent(eventId);
      await nav.push(MaterialPageRoute(
          builder: (_) => V3PlanBuilderPage(
                eventId: eventId,
                draft: draft,
                onAddGames: onAddGames,
                onChangePlan: change,
                api: api,
                gamesApi: gamesApi,
                dictation: dictation,
              )));
    case _Start.saved:
      final id = await nav.push<String>(MaterialPageRoute(
          builder: (ctx) => Scaffold(
                backgroundColor: V3.bg,
                appBar: spAppBar(ctx, 'Use a saved plan'),
                body: V3PlansView(
                    api: api,
                    gamesApi: gamesApi,
                    onPick: (id) => Navigator.of(ctx).pop(id)),
              )));
      if (id != null && nav.mounted) await attach(id);
    case _Start.repeat:
      await attach(pick.last!.planId);
  }
}

class _EventPlanSheet extends StatefulWidget {
  const _EventPlanSheet(
      {required this.eventId, required this.api, required this.choose});
  final int eventId;
  final V3PlanApi api;
  final bool choose;

  @override
  State<_EventPlanSheet> createState() => _EventPlanSheetState();
}

class _EventPlanSheetState extends State<_EventPlanSheet> {
  SpLoad? _load;
  PlanItem? _last;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _failed = false);
    final api = widget.api;
    try {
      // My last plan for this team; the sheet works without it.
      final lastF = () async {
        try {
          final e = await api.event(widget.eventId);
          if (e == null) return null;
          return lastSessionPlan(eventPlanItems(await api.myPlanRows()), e);
        } catch (_) {
          return null;
        }
      }();
      final r = await api.plan(getBody(widget.eventId));
      if (!r.ok) throw Exception();
      final load = SpLoad.fromJson(r.map);
      if (!mounted) return;
      if (load.plan != null && !widget.choose) {
        Navigator.of(context).pop(_Choice(_Start.existing, load));
        return;
      }
      final last = await lastF;
      if (!mounted) return;
      setState(() {
        _load = load;
        _last = last;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _pick(_Start s) => Navigator.of(context).pop(_Choice(s, _load!, _last));

  @override
  Widget build(BuildContext context) {
    final load = _load;
    final e = load?.event;
    final sub = [
      if (e?.dateTime != null) planDay(e!.dateTime!),
      if ((e?.title ?? '').isNotEmpty) e!.title,
    ].join(' · ');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: V3.barGrey,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 14),
              Text('Session plan',
                  textAlign: TextAlign.center, style: V3.tight(21)),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: V3.inter(16, color: V3.muted)),
              ],
              const SizedBox(height: 18),
              if (_failed) ...[
                Text('This could not be loaded. Check your connection.',
                    textAlign: TextAlign.center,
                    style: V3.inter(16, color: V3.muted)),
                const SizedBox(height: 14),
                SpButton('Try again', outline: true, onPressed: _boot),
              ] else if (load == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child:
                      Center(child: CircularProgressIndicator(color: V3.green)),
                )
              else ...[
                if (load.plan != null) ...[
                  Text(
                      'This event has a plan. Starting again replaces it on '
                      'this event.',
                      textAlign: TextAlign.center,
                      style: V3.inter(15, color: V3.amberText, height: 1.4)),
                  const SizedBox(height: 14),
                ],
                _ChoiceButton(
                    key: const ValueKey('start-new'),
                    icon: Icons.add,
                    title: 'Start a new plan',
                    primary: true,
                    onTap: () => _pick(_Start.fresh)),
                const SizedBox(height: 10),
                _ChoiceButton(
                    key: const ValueKey('use-saved'),
                    icon: Icons.bookmark_border,
                    title: 'Use a saved plan',
                    sub: 'One of yours, or one shared with your club',
                    onTap: () => _pick(_Start.saved)),
                if (_last != null) ...[
                  const SizedBox(height: 10),
                  _ChoiceButton(
                      key: const ValueKey('repeat-last'),
                      icon: Icons.replay,
                      title: "Repeat last session's plan",
                      sub: planLine(_last!),
                      onTap: () => _pick(_Start.repeat)),
                ],
                const SizedBox(height: 16),
                Text(
                    'A new plan opens the builder with the event, length and '
                    'attending players filled in.',
                    textAlign: TextAlign.center,
                    style: V3.inter(15, color: V3.muted, height: 1.4)),
              ],
            ]),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton(
      {super.key,
      required this.icon,
      required this.title,
      this.sub = '',
      this.primary = false,
      required this.onTap});
  final IconData icon;
  final String title, sub;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.black87 : V3.text;
    return Material(
      color: primary ? V3.green : V3.bg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: primary ? V3.green : V3.line, width: 1.5)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(icon, color: primary ? Colors.black87 : V3.green, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style:
                            V3.inter(17, weight: FontWeight.w700, color: fg)),
                    if (sub.isNotEmpty)
                      Text(sub, style: V3.inter(15, color: V3.muted)),
                  ]),
            ),
            Icon(Icons.chevron_right,
                color: primary ? Colors.black87 : V3.muted),
          ]),
        ),
      ),
    );
  }
}
