// v3 Coaching: the Plans half (a widget, not a page). Mine | Club pills,
// "+ New plan", and the coach's plans split into "On events" (each event's
// plan is its own copy) and "Reusable" (proposal approved by Ken
// 2026-11-11).
//
// * Mine, On events: my active plans that sit on an event, read straight
//   from session_plans (RLS lets the creator read them) with the event's
//   title, date and team.
// * Mine, Reusable: get_user_plans.
// * Club: get_club_plans. Another coach's plan opens read-only with
//   "Use This Plan".
// * Swipe a plan of mine to deactivate it (after a confirm); swipe my plan
//   on the Club list to take it off the club.
// * With [onPick] the view is a picker ("Use a saved plan" on an event):
//   only reusable plans show, and a tap previews the plan with "Use This
//   Plan".
import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../match_report/v3_voice_sheet.dart';
import '../session_plan/v3_session_plan_api.dart';
import '../session_plan/v3_session_plan_models.dart';
import '../session_plan/v3_session_plan_page.dart';
import '../session_plan/v3_session_plan_widgets.dart';
import '../v3_theme.dart';
import 'v3_plan_api.dart';
import 'v3_plan_models.dart';

class V3PlansView extends StatefulWidget {
  const V3PlansView({
    super.key,
    this.onNewPlan,
    this.onPick,
    this.api = const V3PlanApi(),
    this.gamesApi = const V3GamesApi(),
    this.dictation,
  });

  /// "+ New plan": opens the plan builder. Hidden when null.
  final void Function(BuildContext context)? onNewPlan;

  /// Picker mode: called with the plan id the coach chose to use.
  final void Function(String planId)? onPick;

  final V3PlanApi api;
  final V3GamesApi gamesApi;

  /// Tests pass a fake recogniser for the plan screen's voice panel.
  final V3Dictation? dictation;

  @override
  State<V3PlansView> createState() => _V3PlansViewState();
}

enum _Load { loading, ok, failed }

class _V3PlansViewState extends State<V3PlansView> {
  bool _club = false;
  _Load _mineState = _Load.loading;
  _Load? _clubState; // null: not asked for yet
  List<PlanItem> _onEvents = [], _reusable = [], _clubPlans = [];
  bool _eventsFailed = false;

  bool get _picking => widget.onPick != null;

  @override
  void initState() {
    super.initState();
    spPlansChanged.addListener(_plansChanged);
    _loadMine();
  }

  @override
  void dispose() {
    spPlansChanged.removeListener(_plansChanged);
    super.dispose();
  }

  /// A plan was saved, attached, shared or removed somewhere.
  void _plansChanged() {
    if (!mounted) return;
    _loadMine(quiet: true);
    if (_clubState != null) _loadClub(quiet: true);
  }

  Future<void> _loadMine({bool quiet = false}) async {
    if (!quiet) setState(() => _mineState = _Load.loading);
    final api = widget.api;
    try {
      final rowsF = api.myPlanRows().then<List<dynamic>?>((r) => r,
          onError: (_) => null); // the Reusable list still shows
      final r = await api.plan({'action': 'get_user_plans'});
      final rows = await rowsF;
      if (!mounted) return;
      if (!r.ok) {
        if (!quiet) setState(() => _mineState = _Load.failed);
        return;
      }
      setState(() {
        _reusable = reusablePlanItems(r.data, rows);
        _onEvents = eventPlanItems(rows);
        _eventsFailed = rows == null;
        _mineState = _Load.ok;
      });
    } catch (_) {
      if (mounted && !quiet) setState(() => _mineState = _Load.failed);
    }
  }

  Future<void> _loadClub({bool quiet = false}) async {
    if (!quiet) setState(() => _clubState = _Load.loading);
    try {
      final r = await widget.api.plan({'action': 'get_club_plans'});
      if (!mounted) return;
      if (!r.ok) {
        if (!quiet) setState(() => _clubState = _Load.failed);
        return;
      }
      setState(() {
        _clubPlans = clubPlanItems(r.data);
        _clubState = _Load.ok;
      });
    } catch (_) {
      if (mounted && !quiet) setState(() => _clubState = _Load.failed);
    }
  }

  void _setTab(bool club) {
    if (_club == club) return;
    setState(() => _club = club);
    if (club && _clubState == null) _loadClub();
  }

  Future<void> _refresh() => _club ? _loadClub() : _loadMine();

  void _snack(String text, {bool warn = false}) {
    if (mounted) spSnack(context, text, warn: warn);
  }

  // -------------------------------------------------------------- actions

  Future<void> _open(PlanItem p) async {
    final api = widget.api;
    if (_picking) {
      final use = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => SpPlanPreviewPage(
              call: api.call,
              userId: api.userId,
              summary: SpPlanSummary(planId: p.planId, title: p.title))));
      if (use == true && mounted) widget.onPick!(p.planId);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => V3SessionPlanPage.open(
              planId: p.planId,
              eventId: p.event?.eventId,
              gamesApi: widget.gamesApi,
              call: api.callOverride,
              userId: api.userIdOverride,
              dictation: widget.dictation,
              aiProbe: api.aiProbe,
            )));
  }

  Future<bool> _deactivate(PlanItem p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Deactivate this plan?', style: V3.tight(20)),
        content: Text(
            p.event != null
                ? 'This plan will be taken off the event and removed from '
                    'your plans. This cannot be undone.'
                : p.shared
                    ? 'This plan is shared with your club. Deactivating '
                        'removes it from your plans and from the club list. '
                        'This cannot be undone.'
                    : 'This plan will be removed from your plans. This '
                        'cannot be undone.',
            style: V3.inter(16, color: V3.muted, height: 1.45)),
        actions: [
          TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: V3.inter(16, color: V3.muted))),
          TextButton(
              key: const ValueKey('confirm-deactivate'),
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Deactivate',
                  style: V3.inter(16,
                      weight: FontWeight.w700, color: V3.redText))),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      final r = await widget.api
          .plan({'action': 'deactivate_plan', 'plan_id': p.planId});
      if (!r.ok || r.map['ok'] != true) {
        _snack(spErrorText(r.data, 'Could not deactivate'), warn: true);
        return false;
      }
      _snack('Plan removed ✓');
      return true;
    } catch (_) {
      _snack('Network error', warn: true);
      return false;
    }
  }

  Future<bool> _removeFromClub(PlanItem p) async {
    try {
      final r = await widget.api.plan(
          {'action': 'set_plan_club', 'plan_id': p.planId, 'shared': false});
      if (!r.ok || r.map['ok'] != true) {
        _snack(spErrorText(r.data, 'Could not remove'), warn: true);
        return false;
      }
      _snack('Removed from club ✓');
      return true;
    } catch (_) {
      _snack('Network error', warn: true);
      return false;
    }
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final newPlan = widget.onNewPlan;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          _pill('Mine', !_club, () => _setTab(false)),
          const SizedBox(width: 8),
          _pill('Club', _club, () => _setTab(true)),
        ]),
      ),
      if (newPlan != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SpButton('New plan',
              key: const ValueKey('new-plan'),
              icon: Icons.add,
              onPressed: () => newPlan(context)),
        ),
      Expanded(
        child: RefreshIndicator(
          color: V3.green,
          backgroundColor: V3.card,
          onRefresh: _refresh,
          child: _club ? _clubList() : _mineList(),
        ),
      ),
    ]);
  }

  Widget _pill(String label, bool on, VoidCallback onTap) => Semantics(
        button: true,
        selected: on,
        child: InkWell(
          key: ValueKey('pill-$label'),
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            height: 44,
            constraints: const BoxConstraints(minWidth: 76),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
                color: on ? V3.green : V3.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: on ? V3.green : V3.line)),
            child: Text(label,
                style: V3.inter(16,
                    weight: FontWeight.w700,
                    color: on ? Colors.black87 : V3.text)),
          ),
        ),
      );

  /// A message that still scrolls, so pull-to-refresh works.
  Widget _message(String title, String body, {VoidCallback? retry}) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: V3.inter(18, weight: FontWeight.w600)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted, height: 1.5)),
          ],
          if (retry != null) ...[
            const SizedBox(height: 18),
            Center(
                child: SpButton('Try again', outline: true, onPressed: retry)),
          ],
        ],
      );

  Widget _loading() => const Center(
      child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: V3.green)));

  Widget _mineList() {
    if (_mineState == _Load.loading) return _loading();
    if (_mineState == _Load.failed) {
      return _message('Your plans could not be loaded',
          'Check your connection and try again.',
          retry: _loadMine);
    }
    final events = _picking ? const <PlanItem>[] : _onEvents;
    if (events.isEmpty && _reusable.isEmpty && !_eventsFailed) {
      return _picking
          ? _message('No saved plans yet',
              'Plans you save without an event show here, ready to use again.')
          : _message(
              'No plans yet',
              widget.onNewPlan != null
                  ? 'Tap New plan to build one from your games.'
                  : 'Plans you make will show here.');
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
      children: [
        if (!_picking) ...[
          const _SectionLabel('On events'),
          if (_eventsFailed)
            const _Note('The plans on your events could not be loaded. '
                'Pull down to try again.')
          else if (events.isEmpty)
            const _Note('None yet. Open a training event and tap Session '
                'plan to put a plan on it.'),
          for (final p in events) _swipe(p, club: false),
        ],
        const _SectionLabel('Reusable'),
        if (_reusable.isEmpty)
          _Note(_picking
              ? 'None yet.'
              : 'None yet. A plan made without an event is kept here to use '
                  'again.'),
        for (final p in _reusable) _swipe(p, club: false),
      ],
    );
  }

  Widget _clubList() {
    final s = _clubState;
    if (s == null || s == _Load.loading) return _loading();
    if (s == _Load.failed) {
      return _message('Club plans could not be loaded',
          'Check your connection and try again.',
          retry: _loadClub);
    }
    if (_clubPlans.isEmpty) {
      return _message('No club plans yet',
          'Plans that coaches share with your club will show here.');
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
      children: [for (final p in _clubPlans) _swipe(p, club: true)],
    );
  }

  Widget _swipe(PlanItem p, {required bool club}) {
    final card = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _PlanCard(
          key: ValueKey('plan-${p.planId}'),
          title: p.title,
          line: club ? clubPlanLine(p) : planLine(p),
          onTap: () => _open(p)),
    );
    if (_picking || (club && !p.isOwn)) return card;
    return Dismissible(
      key: ValueKey('${club ? 'c' : 'm'}:${p.planId}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => club ? _removeFromClub(p) : _deactivate(p),
      onDismissed: (_) => setState(() {
        (club ? _clubPlans : (p.event != null ? _onEvents : _reusable))
            .removeWhere((x) => x.planId == p.planId);
        if (club) {
          _loadMine(quiet: true);
        } else if (_clubState != null) {
          _loadClub(quiet: true);
        }
      }),
      background: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: club ? V3.amber : const Color(0xFFC0392B),
              borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(club ? Icons.link_off : Icons.delete_outline,
                color: Colors.white),
            const SizedBox(height: 2),
            Text(club ? 'Remove\nfrom Club' : 'Deactivate',
                textAlign: TextAlign.center,
                style:
                    V3.inter(13, weight: FontWeight.w700, color: Colors.white)),
          ]),
        ),
      ),
      child: card,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w800, color: V3.green, letterSpacing: 1)),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Text(text, style: V3.inter(15, color: V3.muted, height: 1.45)),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {super.key, required this.title, required this.line, this.onTap});
  final String title, line;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: V3.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: V3.inter(17, weight: FontWeight.w600)),
                      if (line.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(line, style: V3.inter(15, color: V3.muted)),
                      ],
                    ]),
              ),
              const Icon(Icons.chevron_right, color: V3.muted, size: 28),
            ]),
          ),
        ),
      );
}
