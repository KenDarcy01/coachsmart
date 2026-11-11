// v3 event Payments (the FlutterFlow PaymentTransactions page): three
// totals, Paid / Not paid tabs with counts, and a button that sends a
// payment reminder to the people looking after the players who have not
// paid (send_event_payment_reminders, a new SECURITY DEFINER function).
import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_payments_models.dart';
import '../teams/v3_team_models.dart' show V3Avatar;
import '/v3/tracking/v3_track.dart';

class V3PaymentsPage extends StatefulWidget {
  const V3PaymentsPage(
      {super.key, required this.eventId, this.title, this.testData});

  final int eventId;

  /// Title shown in the app bar when the caller already knows it.
  final String? title;

  /// Widget tests pass the data here instead of calling Supabase.
  @visibleForTesting
  final PaymentsData? testData;

  @override
  State<V3PaymentsPage> createState() => _V3PaymentsPageState();
}

class _V3PaymentsPageState extends State<V3PaymentsPage> {
  PaymentsData? _data;
  bool _loading = true;
  bool _sending = false;
  int? _refunding; // payment id being refunded
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.testData != null) {
      setState(() {
        _data = widget.testData;
        _loading = false;
      });
      return;
    }
    try {
      final id = widget.eventId;
      final paidRows = await SupaFlow.client
          .rpc('get_event_payment_details_v2', params: {'p_event_id': id});
      final unpaidRows = await SupaFlow.client
          .rpc('get_accepted_unpaid_members', params: {'p_event_id': id});
      // Refunded payments; older backends without the function just show none.
      List refundRows = const [];
      try {
        final r = await SupaFlow.client
            .rpc('get_event_refunds', params: {'p_event_id': id});
        if (r is List) refundRows = r;
      } catch (_) {}
      final ev = await EventsTable()
          .queryRows(queryFn: (q) => q.eq('event_id', id).limit(1));
      if (!mounted) return;
      setState(() {
        _data = PaymentsData.fromJson(
          paidRows: paidRows is List ? paidRows : const [],
          unpaidRows: unpaidRows is List ? unpaidRows : const [],
          refundRows: refundRows,
          price: ev.isNotEmpty ? (ev.first.paymentAmount ?? 0) : 0,
          title: widget.title ??
              (ev.isNotEmpty ? (ev.first.eventTitle ?? '') : ''),
        );
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Payments could not be loaded.';
      });
    }
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  Future<void> _remind() async {
    final d = _data;
    if (d == null || d.unpaid.isEmpty || _sending) return;
    final n = d.unpaid.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Send payment reminders?', style: V3.tight(20)),
        content: Text(
            n == 1
                ? 'The person looking after the 1 player who has not paid gets a notification asking them to pay.'
                : 'The people looking after the $n players who have not paid get a notification asking them to pay.',
            style: V3.inter(15, color: V3.muted, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: V3.inter(15, color: V3.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: V3.green, foregroundColor: V3.bg),
              child: Text('Send',
                  style: V3.inter(15, weight: FontWeight.w700, color: V3.bg))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _sending = true);
    try {
      V3Track.event('payment_reminder_sent', {'event_id': widget.eventId});
      final r = await SupaFlow.client.rpc('send_event_payment_reminders',
          params: {'p_event_id': widget.eventId});
      if (r is Map && r['success'] == false) {
        throw Exception(r['message']);
      }
      final sent = r is Map ? (r['sent'] ?? 0) : 0;
      _snack(sent == 0
          ? 'Nobody to remind: no app user is linked to those players.'
          : sent == 1
              ? 'Reminder sent to 1 person'
              : 'Reminders sent to $sent people');
    } catch (_) {
      _snack('Could not send the reminders. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Refund one player's payment through Stripe (refund-event-payment). Team
  // admins only; the function checks that too.
  Future<void> _refund(PaidRow r) async {
    if (_refunding != null) return;
    final who = r.paidBy.isEmpty ? '' : ' to ${r.paidBy}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Refund ${euro(r.amount)}$who?', style: V3.tight(20)),
        content: Text(
            'This refunds the payment for ${r.memberName} through Stripe. '
            'It goes back to the card they paid with, usually within 5 to 10 '
            "days. Stripe keeps its fee. This can't be undone.",
            style: V3.inter(15, color: V3.muted, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: V3.inter(15, color: V3.muted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: V3.red, foregroundColor: Colors.white),
              child: Text('Refund',
                  style: V3.inter(15,
                      weight: FontWeight.w700, color: Colors.white))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _refunding = r.paymentId);
    try {
      V3Track.event('payment_refunded', {'event_id': widget.eventId});
      final res = await SupaFlow.client.functions
          .invoke('refund-event-payment', body: {'paymentId': r.paymentId});
      final data = res.data;
      if (data is Map && data['success'] == true) {
        _snack('Refunded ${euro(r.amount)} for ${r.memberName}');
        await _load();
      } else {
        throw Exception(data is Map ? data['error'] : null);
      }
    } on FunctionException catch (e) {
      final d = e.details;
      _snack(
          d is Map && d['error'] is String
              ? d['error'] as String
              : 'The refund did not go through. Please try again.',
          warn: true);
    } catch (_) {
      _snack('The refund did not go through. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _refunding = null);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final title = (widget.title ?? d?.title ?? '').trim();
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
        title: Text(title.isEmpty ? 'Payments' : title,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: V3.tight(20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null || d == null
              ? Center(
                  child: Text(_error ?? 'Payments could not be loaded.',
                      style: V3.inter(15, color: V3.muted)))
              : RefreshIndicator(
                  color: V3.green,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    children: [
                      _kpis(d),
                      _tabs(d),
                      if (_tab == 0) _paidList(d) else _unpaidList(d),
                    ],
                  ),
                ),
    );
  }

  Widget _kpis(PaymentsData d) => Row(children: [
        _kpi('Collected', euro(d.collected), V3.green),
        const SizedBox(width: 8),
        _kpi('To the club', euro(d.toClub), V3.text),
        const SizedBox(width: 8),
        _kpi('Still to pay', euro(d.stillToPay), V3.text),
      ]);

  Widget _kpi(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: V3.inter(12, color: V3.muted)),
            const SizedBox(height: 2),
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style:
                        V3.tight(22, weight: FontWeight.w700, color: color))),
          ]),
        ),
      );

  Widget _tabs(PaymentsData d) => Container(
        margin: const EdgeInsets.only(top: 12, bottom: 12),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: V3.card2, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          _tabItem(0, 'Paid', d.paid.length, V3.green),
          _tabItem(1, 'Not paid', d.unpaid.length, V3.amber),
        ]),
      );

  Widget _tabItem(int i, String label, int count, Color on) {
    final sel = _tab == i;
    final c = sel ? on : V3.muted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = i),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
              color: sel ? V3.card : Colors.transparent,
              borderRadius: BorderRadius.circular(9)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('$count',
                style: V3.tight(15,
                    weight: FontWeight.w700,
                    color: sel ? on : V3.text,
                    height: 1.1)),
            Text(label,
                style: V3.inter(13,
                    weight: FontWeight.w600, color: c, height: 1.15)),
          ]),
        ),
      ),
    );
  }

  // Tap a paid player to refund them. A player paid for twice gets a tag so
  // the extra payment is easy to spot. Refunded payments are listed below.
  Widget _paidList(PaymentsData d) {
    if (d.paid.isEmpty && d.refunded.isEmpty) {
      return Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
          child: Text('No payments yet.',
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (d.paid.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('Tap a payment to refund it.',
              style: V3.inter(13.5, color: V3.muted, height: 1.45)),
        ),
        _card([
          for (final r in d.paid)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _refund(r),
              child: _row(
                r.memberName,
                r.subtitle,
                tag: d.paidTwice(r) ? 'Paid twice' : null,
                trailing: _refunding == r.paymentId
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: V3.green))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                            Text(euro(r.amount),
                                style: V3.tight(15, weight: FontWeight.w600)),
                            Text('net ${euro(r.net)}',
                                style: V3.inter(12, color: V3.muted)),
                          ]),
              ),
            ),
        ]),
      ],
      if (d.refunded.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
          child: Text('REFUNDED',
              style: V3.inter(13,
                  weight: FontWeight.w700, color: V3.muted, letterSpacing: .8)),
        ),
        _card([
          for (final r in d.refunded)
            _row(
              r.memberName,
              r.paidBy.isEmpty ? r.subtitle : '${r.subtitle} to ${r.paidBy}',
              trailing: Text(euro(r.amount),
                  style: V3
                      .tight(15, weight: FontWeight.w600, color: V3.muted)
                      .copyWith(decoration: TextDecoration.lineThrough)),
            ),
        ]),
      ],
    ]);
  }

  Widget _unpaidList(PaymentsData d) {
    if (d.unpaid.isEmpty) {
      return Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
          child: Text('Everyone attending has paid.',
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
            'Attending players with no payment yet. ${euro(d.price)} each.',
            style: V3.inter(13.5, color: V3.muted, height: 1.45)),
      ),
      _card([
        for (final r in d.unpaid)
          _row(
            r.memberName,
            r.role,
            trailing: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: V3.card2, borderRadius: BorderRadius.circular(9)),
              child: Text('Not paid',
                  style: V3.inter(12,
                      weight: FontWeight.w600, color: V3.amberText)),
            ),
          ),
      ]),
      const SizedBox(height: 14),
      SizedBox(
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _sending ? null : _remind,
          style: OutlinedButton.styleFrom(
              foregroundColor: V3.green,
              side: const BorderSide(color: V3.green, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          icon: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: V3.green))
              : const Icon(Icons.notifications_outlined, size: 20),
          label: Text(d.remindLabel,
              style: V3.inter(16, weight: FontWeight.w700, color: V3.green)),
        ),
      ),
    ]);
  }

  Widget _card(List<Widget> rows) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: V3.line),
            rows[i],
          ],
        ]),
      );

  Widget _row(String name, String sub,
          {required Widget trailing, String? tag}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          V3Avatar(nameInitials(name), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: V3.inter(16, weight: FontWeight.w500)),
              if (tag != null) ...[
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: V3.card2, borderRadius: BorderRadius.circular(8)),
                  child: Text(tag,
                      style: V3.inter(12,
                          weight: FontWeight.w600, color: V3.amberText)),
                ),
              ],
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(sub, style: V3.inter(13, color: V3.muted)),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          trailing,
        ]),
      );
}
