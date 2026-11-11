// My Plans and Club Plans (the My Plans screen of webviews/favourites.html):
// open a saved plan, swipe to deactivate one of mine or take mine off the
// club list, and, when opened for an event, attach a plan to it.
import 'package:flutter/material.dart';

import '../v3_theme.dart';
import 'v3_fav_widgets.dart';
import 'v3_favourites_api.dart';
import 'v3_favourites_models.dart';
import 'v3_session_plan_page.dart';

/// Pops with 'build' when the coach taps Build New Plan (event mode).
class V3MyPlansPage extends StatefulWidget {
  const V3MyPlansPage(
      {super.key, this.eventId, this.api = const V3FavouritesApi()});

  /// Set when opened for an event: plans show Attach to Event, and the
  /// foot of the page offers Build New Plan.
  final int? eventId;
  final V3FavouritesApi api;

  @override
  State<V3MyPlansPage> createState() => _V3MyPlansPageState();
}

enum _Load { loading, ok, failed }

class _V3MyPlansPageState extends State<V3MyPlansPage> {
  int _tab = 0; // 0 mine, 1 club
  final _state = [_Load.loading, _Load.loading];
  final _plans = <List<SavedPlan>>[[], []];

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  Future<void> _load(int tab) async {
    setState(() => _state[tab] = _Load.loading);
    try {
      final r =
          await widget.api.plan(tab == 0 ? 'get_user_plans' : 'get_club_plans');
      if (!mounted) return;
      setState(() {
        _plans[tab] = parsePlans(r.data);
        _state[tab] = _Load.ok;
      });
    } catch (_) {
      if (mounted) setState(() => _state[tab] = _Load.failed);
    }
  }

  void _setTab(int t) {
    setState(() => _tab = t);
    _load(t);
  }

  void _snack(String t, {bool warn = false, bool success = false, int? ms}) {
    if (mounted) favSnack(context, t, warn: warn, success: success, ms: ms);
  }

  Future<void> _open(int planId) async {
    _snack('Loading plan…', ms: 0);
    try {
      final r = await widget.api.plan('get_plan', {'plan_id': planId});
      if (!mounted) return;
      favClearSnack(context);
      final plan = r.data['plan'];
      if (!r.ok || plan is! Map) {
        _snack(r.error ?? 'Failed to load plan.', warn: true);
        return;
      }
      await _push(Map<String, dynamic>.from(plan), r.data);
    } catch (_) {
      if (mounted) favClearSnack(context);
      _snack('Network error. Please try again.', warn: true);
    }
  }

  Future<void> _push(Map<String, dynamic> plan, Map d) async {
    final id = d['plan_id'];
    await Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'V3SessionPlanPage'),
      builder: (_) => V3SessionPlanPage(
        plan: plan,
        planId: id is int ? id : int.tryParse('${id ?? ''}'),
        isShared: d['club_id'] != null,
        isOwn: d['is_own'] != false,
        eventId: widget.eventId,
        api: widget.api,
      ),
    ));
    if (mounted) _load(_tab);
  }

  Future<void> _attach(int planId) async {
    final eventId = widget.eventId;
    if (eventId == null) {
      _snack('No event context', warn: true);
      return;
    }
    _snack('Attaching…', ms: 0);
    try {
      final p = await widget.api.plan('get_plan', {'plan_id': planId});
      if (!p.ok || p.data['plan'] is! Map) {
        _snack('Could not load plan', warn: true);
        return;
      }
      final planJson = Map<String, dynamic>.from(p.data['plan']);
      final r = await widget.api
          .plan('attach_plan', {'event_id': eventId, 'plan_json': planJson});
      if (!r.ok) {
        _snack(r.error ?? 'Attach failed', warn: true);
        return;
      }
      if (mounted) favClearSnack(context);
      // The saved copy has the event's player and coach counts, weather and
      // date.
      final newId = r.data['plan_id'];
      Map<String, dynamic> shown = r.data['plan_json'] is Map
          ? Map<String, dynamic>.from(r.data['plan_json'])
          : planJson;
      try {
        final s = await widget.api.plan('get_plan', {'plan_id': newId});
        if (s.data['plan'] is Map) {
          shown = Map<String, dynamic>.from(s.data['plan']);
        }
      } catch (_) {}
      if (!mounted) return;
      await _push(shown, {'plan_id': newId});
    } catch (_) {
      _snack('Network error', warn: true);
    }
  }

  Future<bool> _confirmDeactivate(SavedPlan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Deactivate this plan?', style: V3.tight(20)),
        content: Text(
            p.clubId != null
                ? "This plan is shared with your club. Deactivating will permanently remove it from your library and from your club's feed. This cannot be undone."
                : 'This plan will be permanently removed from your library. This cannot be undone.',
            style: V3.inter(16, color: V3.muted, height: 1.45)),
        actions: [
          TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: V3.inter(16, color: V3.muted))),
          TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Deactivate',
                  style: V3.inter(16,
                      weight: FontWeight.w700, color: V3.redText))),
        ],
      ),
    );
    if (ok != true) return false;
    _snack('Removing…', ms: 0);
    try {
      final r = await widget.api.plan('deactivate_plan', {'plan_id': p.planId});
      if (!r.ok || r.data['ok'] != true) {
        _snack(r.error ?? 'Could not deactivate', warn: true);
        return false;
      }
      _snack('Plan removed ✓', success: true);
      return true;
    } catch (_) {
      _snack('Network error', warn: true);
      return false;
    }
  }

  Future<bool> _removeFromClub(SavedPlan p) async {
    _snack('Removing…', ms: 0);
    try {
      final r = await widget.api
          .plan('set_plan_club', {'plan_id': p.planId, 'shared': false});
      if (!r.ok || r.data['ok'] != true) {
        _snack(r.error ?? 'Could not remove', warn: true);
        return false;
      }
      _snack('Removed from club ✓', success: true);
      return true;
    } catch (_) {
      _snack('Network error', warn: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: favAppBar(context, Text('Session Plans', style: V3.tight(18))),
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: V3.line))),
          child: Row(children: [
            _TabBtn('My Plans', _tab == 0, () => _setTab(0)),
            _TabBtn('Club Plans', _tab == 1, () => _setTab(1)),
          ]),
        ),
        Expanded(child: _list(_tab)),
      ]),
      bottomNavigationBar: widget.eventId == null
          ? null
          : FavBottomBar(children: [
              Expanded(
                  child: FavButton(
                      label: 'Build New Plan',
                      onPressed: () => Navigator.of(context).pop('build'))),
            ]),
    );
  }

  Widget _empty(String title, String body) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 50),
        child: Column(children: [
          Text(title,
              textAlign: TextAlign.center,
              style: V3.inter(18, weight: FontWeight.w600)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted, height: 1.5)),
          ],
        ]),
      );

  Widget _list(int tab) {
    final s = _state[tab];
    if (s == _Load.loading) return _empty('Loading…', '');
    if (s == _Load.failed) {
      return _empty('Failed to load', 'Check your connection.');
    }
    final plans = _plans[tab];
    if (plans.isEmpty) {
      return tab == 0
          ? _empty('No saved plans yet',
              'Build your first plan from the Favourites tab.')
          : _empty('No club plans yet',
              'Plans shared with your club will appear here.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final p = plans[i];
        final card = _PlanCard(
          plan: p,
          club: tab == 1,
          onTap: () => _open(p.planId),
          onAttach: widget.eventId != null ? () => _attach(p.planId) : null,
        );
        if (tab == 1 && !p.isOwn) return card;
        final mine = tab == 0;
        return Dismissible(
          key: ValueKey('$tab:${p.planId}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) =>
              mine ? _confirmDeactivate(p) : _removeFromClub(p),
          onDismissed: (_) => setState(() => plans.removeAt(i)),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 22),
            decoration: BoxDecoration(
                color: mine ? const Color(0xFFC0392B) : V3.amber,
                borderRadius: BorderRadius.circular(14)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(mine ? Icons.delete_outline : Icons.link_off,
                  color: Colors.white),
              const SizedBox(height: 4),
              Text(mine ? 'Deactivate' : 'Remove\nfrom Club',
                  textAlign: TextAlign.center,
                  style: V3.inter(13,
                      weight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          child: card,
        );
      },
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn(this.label, this.on, this.onTap);
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: on ? V3.green : Colors.transparent, width: 3))),
            child: Text(label,
                style: V3.inter(17,
                    weight: FontWeight.w600, color: on ? V3.text : V3.muted)),
          ),
        ),
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.plan, required this.club, this.onTap, this.onAttach});
  final SavedPlan plan;
  final bool club;
  final VoidCallback? onTap, onAttach;

  @override
  Widget build(BuildContext context) {
    final p = plan;
    return Material(
      color: V3.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: V3.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (club)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(p.isOwn ? 'You' : 'From ${p.createdBy}',
                    style:
                        V3.inter(14, weight: FontWeight.w600, color: V3.green)),
              ),
            Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(p.title,
                                style: V3.inter(17, weight: FontWeight.w600)),
                            if (!club && p.clubId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: V3.greenTint,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text('CLUB PLAN',
                                    style: V3.inter(12,
                                        weight: FontWeight.w700,
                                        color: V3.green)),
                              ),
                          ]),
                      const SizedBox(height: 3),
                      Text(planDate(p.createdAt),
                          style: V3.inter(15, color: V3.muted)),
                    ]),
              ),
              const Icon(Icons.chevron_right, color: V3.muted, size: 28),
            ]),
            if (onAttach != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FavButton(label: 'Attach to Event', onPressed: onAttach),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
