// v3 team Spend & gear page (2026-11-23, thread "Explore coach expenses and
// gear orders"; Ken: "Build it. Only give me access for now"). Two big
// buttons (Add expense, Request gear), the team's budget bar and everything
// the team logged, each with its status from the club. The club approves on
// coachsmart.app/club/spend.html. Records only: the club pays back outside
// CoachSmart.
import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '../v3_theme.dart';
import '/v3/tracking/v3_track.dart';
import 'v3_spend_api.dart';
import 'v3_spend_models.dart';
import 'v3_expense_page.dart';
import 'v3_gear_page.dart';

class V3SpendPage extends StatefulWidget {
  const V3SpendPage(
      {super.key, required this.teamId, this.teamName = '', this.testData});
  final int teamId;
  final String teamName;

  /// Tests and screenshots only: the `team` reply instead of a live call.
  final Map<String, dynamic>? testData;

  @override
  State<V3SpendPage> createState() => _V3SpendPageState();
}

class _V3SpendPageState extends State<V3SpendPage> {
  SpendData? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.testData != null) {
      _d = SpendData.fromJson(widget.testData!);
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final r =
          await SpendApi.call({'action': 'team', 'team_id': widget.teamId});
      if (!mounted) return;
      setState(() {
        _d = SpendData.fromJson(r);
        _error = null;
      });
    } on SpendError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: V3.card2,
          content: Text(text, style: V3.inter(15, weight: FontWeight.w500))));

  Future<void> _addExpense() async {
    final d = _d;
    if (d == null) return;
    V3Track.event('spend_expense_opened');
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => V3ExpensePage(teamId: widget.teamId, data: d)));
    if (sent == true && mounted) {
      _snack('Sent to the club.');
      _load();
    }
  }

  Future<void> _requestGear() async {
    final d = _d;
    if (d == null) return;
    V3Track.event('spend_gear_opened');
    final sent = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => V3GearPage(teamId: widget.teamId, data: d)));
    if (sent == true && mounted) {
      _snack('Gear request sent to the club.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final name = d?.teamName.isNotEmpty == true ? d!.teamName : widget.teamName;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => context.safePop()),
        title: Text('Spend & gear', style: V3.tight(20)),
      ),
      body: d == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: V3.inter(15, color: V3.muted)))
                  : const CircularProgressIndicator(color: V3.green))
          : RefreshIndicator(
              color: V3.green,
              backgroundColor: V3.card,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  if (name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(name,
                          style: V3.inter(14, color: V3.muted),
                          textAlign: TextAlign.center),
                    ),
                  Row(children: [
                    Expanded(
                        child: _bigButton(
                            key: const ValueKey('spend-add-expense'),
                            icon: Icons.receipt_long_outlined,
                            title: 'Add expense',
                            sub: 'Snap a receipt',
                            onTap: _addExpense)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _bigButton(
                            key: const ValueKey('spend-request-gear'),
                            icon: Icons.sports_soccer_outlined,
                            title: 'Request gear',
                            sub: 'From the club list',
                            onTap: _requestGear)),
                  ]),
                  _label('Team budget ${d.season}'),
                  _budget(d),
                  _label('Recent'),
                  if (d.recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                          'Nothing yet. Add an expense or request gear and the club sees it straight away.',
                          style: V3.inter(14, color: V3.muted, height: 1.4)),
                    ),
                  for (final i in d.recent) _row(i),
                ],
              ),
            ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 0, 8),
        child: Text(t.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w600, color: V3.muted, letterSpacing: .8)),
      );

  Widget _bigButton(
          {Key? key,
          required IconData icon,
          required String title,
          required String sub,
          required VoidCallback onTap}) =>
      Material(
        key: key,
        color: V3.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: V3.line)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: V3.greenTint,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: V3.green, size: 22),
              ),
              const SizedBox(height: 10),
              Text(title, style: V3.tight(17, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub, style: V3.inter(12, color: V3.muted)),
            ]),
          ),
        ),
      );

  Widget _budget(SpendData d) {
    final over = d.budget != null && d.used > d.budget!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: V3.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Text(
                d.budget == null
                    ? '${spendEuro(d.used, short: true)} approved so far'
                    : '${spendEuro(d.used, short: true)} of ${spendEuro(d.budget!, short: true)} used',
                style: V3.inter(14, weight: FontWeight.w500)),
          ),
          if (d.budget != null)
            Text(
                over
                    ? '${spendEuro(-d.left!, short: true)} over'
                    : '${spendEuro(d.left!, short: true)} left',
                style: V3.tight(20,
                    weight: FontWeight.w700,
                    color: over ? V3.redText : V3.text)),
        ]),
        if (d.budget != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: d.usedShare,
                minHeight: 8,
                backgroundColor: V3.card2,
                color: over ? V3.red : V3.green),
          ),
        ],
        const SizedBox(height: 6),
        Text(
            [
              if (d.budget == null) 'No budget set by the club yet',
              if (d.waiting > 0)
                '${spendEuro(d.waiting, short: true)} waiting for the club',
            ].join(' · ').ifEmpty('Set by the club · counts approved items'),
            style: V3.inter(12, color: V3.muted)),
      ]),
    );
  }

  Widget _row(SpendItem i) {
    final e = i.expense, g = i.gear;
    final title = e != null
        ? (e.shop.isNotEmpty ? '${e.category}, ${e.shop}' : e.category)
        : g!.summary;
    final sub = e != null
        ? '${spendDay(e.spentOn)} · ${e.by}'
        : '${spendDay(g!.createdAt)} · Gear · ${g.by}';
    final pill = e?.pill ?? g!.pill;
    final amount = e?.amount ?? g!.total;
    return InkWell(
      onTap: () => _detail(i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: V3.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: V3.greenTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(
                e != null
                    ? Icons.receipt_long_outlined
                    : Icons.sports_soccer_outlined,
                color: V3.green,
                size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(15, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub, style: V3.inter(12, color: V3.muted)),
              const SizedBox(height: 5),
              _pill(pill),
            ]),
          ),
          const SizedBox(width: 8),
          if (amount > 0)
            Text(spendEuro(amount),
                style: V3.tight(15, weight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _pill(SpendStatus s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: s.tint, borderRadius: BorderRadius.circular(20)),
        child: Text(s.label,
            style: V3.inter(11, weight: FontWeight.w600, color: s.color)),
      );

  Future<void> _detail(SpendItem i) async {
    final e = i.expense, g = i.gear;
    final mine = e?.mine ?? g!.mine;
    final waiting = e?.waiting ?? g!.waiting;
    final note = e?.statusNote ?? g!.statusNote;
    final pill = e?.pill ?? g!.pill;
    final ev = e?.eventId == null
        ? null
        : _d?.events.where((x) => x.id == e!.eventId).firstOrNull;
    final take = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    e != null
                        ? '${spendEuro(e.amount)} · ${e.category}'
                        : 'Gear request${g!.total > 0 ? ' · ${spendEuro(g.total)}' : ''}',
                    style: V3.tight(20)),
                const SizedBox(height: 8),
                _pill(pill),
                const SizedBox(height: 12),
                if (e != null) ...[
                  _line('Date', spendDay(e.spentOn)),
                  if (e.shop.isNotEmpty) _line('Shop', e.shop),
                  if (ev != null) _line('Event', ev.label),
                  _line(
                      'Pay back',
                      {
                            'bank': 'Bank transfer',
                            'cash': 'Cash',
                            'none': 'No need, club paid'
                          }[e.payback] ??
                          e.payback),
                  _line('Receipt', e.hasReceipt ? 'Photo sent' : 'No photo'),
                  _line('Added by', e.by),
                  if (e.note.isNotEmpty) _line('Note', e.note),
                ],
                if (g != null) ...[
                  for (final l in g.lines)
                    _line('${l.qty} ×', l.name,
                        trailing: l.unitPrice == null
                            ? null
                            : spendEuro(l.unitPrice! * l.qty)),
                  _line('Asked by', '${g.by}, ${spendDay(g.createdAt)}'),
                  if (g.note.isNotEmpty) _line('Note', g.note),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: V3.card2,
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        Text('Club: $note', style: V3.inter(14, height: 1.35)),
                  ),
                ],
                if (mine && waiting) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: V3.line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                          'Take it back${e != null ? ' (you can add it again)' : ''}',
                          style: V3.inter(15,
                              weight: FontWeight.w600, color: V3.redText)),
                    ),
                  ),
                ],
              ]),
        ),
      ),
    );
    if (take != true || !mounted) return;
    try {
      await SpendApi.call({
        'action': 'withdraw',
        'kind': e != null ? 'expense' : 'gear',
        'id': e?.id ?? g!.id,
      });
      _snack('Taken back.');
      _load();
    } on SpendError catch (err) {
      _snack(err.message);
    }
  }

  Widget _line(String k, String v, {String? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 84, child: Text(k, style: V3.inter(14, color: V3.muted))),
          Expanded(child: Text(v, style: V3.inter(14, height: 1.3))),
          if (trailing != null) Text(trailing, style: V3.inter(14)),
        ]),
      );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
