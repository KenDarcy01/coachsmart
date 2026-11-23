// v3 Request gear (Spend & gear, 2026-11-23). The club's stock list grouped
// by category with a +/- counter per item, plus "Something else" lines typed
// by the coach, and a note for the equipment officer.
import 'package:flutter/material.dart';

import '../v3_theme.dart';
import '/v3/tracking/v3_track.dart';
import 'v3_spend_api.dart';
import 'v3_spend_models.dart';

class V3GearPage extends StatefulWidget {
  const V3GearPage({super.key, required this.teamId, required this.data});
  final int teamId;
  final SpendData data;

  @override
  State<V3GearPage> createState() => _V3GearPageState();
}

class _Other {
  final name = TextEditingController();
  int qty = 1;
}

class _V3GearPageState extends State<V3GearPage> {
  final Map<int, int> _qty = {};
  final List<_Other> _others = [];
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.items.isEmpty) _others.add(_Other());
  }

  @override
  void dispose() {
    _note.dispose();
    for (final o in _others) {
      o.name.dispose();
    }
    super.dispose();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: V3.card2,
          content: Text(text, style: V3.inter(15, weight: FontWeight.w500))));

  int get _count =>
      _qty.values.fold(0, (s, q) => s + q) +
      _others
          .where((o) => o.name.text.trim().isNotEmpty)
          .fold(0, (s, o) => s + o.qty);

  double get _total {
    var t = 0.0;
    for (final i in widget.data.items) {
      final q = _qty[i.id] ?? 0;
      if (q > 0 && i.unitPrice != null) t += q * i.unitPrice!;
    }
    return t;
  }

  Future<void> _send() async {
    if (_count == 0) return _snack('Pick at least one item.');
    setState(() => _sending = true);
    try {
      await SpendApi.call({
        'action': 'add_gear',
        'team_id': widget.teamId,
        'note': _note.text.trim(),
        'lines': [
          for (final e in _qty.entries)
            if (e.value > 0) {'item_id': e.key, 'qty': e.value},
          for (final o in _others)
            if (o.name.text.trim().isNotEmpty)
              {'name': o.name.text.trim(), 'qty': o.qty},
        ],
      });
      V3Track.event('spend_gear_sent', {'items': _count});
      if (mounted) Navigator.pop(context, true);
    } on SpendError catch (e) {
      if (mounted) setState(() => _sending = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<GearItem>>{};
    for (final i in widget.data.items) {
      groups.putIfAbsent(i.category, () => []).add(i);
    }
    final count = _count, total = _total;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.close, color: V3.green, size: 28),
            onPressed: () => Navigator.pop(context)),
        title: Text('Request gear', style: V3.tight(20)),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (widget.data.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                        'Your club hasn\'t set up a stock list yet. Type what you need below.',
                        style: V3.inter(14, color: V3.muted, height: 1.4)),
                  ),
                for (final g in groups.entries) ...[
                  _label(g.key),
                  for (final i in g.value) _item(i),
                ],
                _label('Something else'),
                for (final o in _others) _other(o),
                TextButton.icon(
                  onPressed: () => setState(() => _others.add(_Other())),
                  icon: const Icon(Icons.add, color: V3.green),
                  label: Text('Add something not on the list',
                      style: V3.inter(15,
                          weight: FontWeight.w600, color: V3.green)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                      color: V3.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: V3.line)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Note for the club (optional)',
                            style: V3.inter(12,
                                weight: FontWeight.w500, color: V3.muted)),
                        TextField(
                          controller: _note,
                          maxLines: 2,
                          minLines: 1,
                          style: V3.inter(16),
                          cursorColor: V3.green,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.only(top: 3),
                              hintText: 'e.g. two balls lost over the fence',
                              hintStyle: V3.inter(16, color: V3.barGrey)),
                        ),
                      ]),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('spend-send-gear'),
                style: FilledButton.styleFrom(
                    backgroundColor: V3.green,
                    disabledBackgroundColor: V3.card2,
                    foregroundColor: V3.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: _sending || count == 0 ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: V3.bg))
                    : Text(
                        count == 0
                            ? 'Pick what you need'
                            : 'Request $count item${count == 1 ? '' : 's'}${total > 0 ? ' · ${spendEuro(total, short: true)}' : ''}',
                        style: V3.tight(16,
                            weight: FontWeight.w700,
                            color: count == 0 ? V3.muted : V3.bg)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 8),
        child: Text(t.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w600, color: V3.muted, letterSpacing: .8)),
      );

  Widget _item(GearItem i) {
    final q = _qty[i.id] ?? 0;
    final sub = [
      if (i.unitPrice != null) spendEuro(i.unitPrice!, short: true),
      if (i.detail.isNotEmpty) i.detail,
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: q > 0 ? V3.green : V3.line)),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i.name, style: V3.inter(15, weight: FontWeight.w600)),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(sub, style: V3.inter(12, color: V3.muted)),
            ],
          ]),
        ),
        _stepper(q, (v) => setState(() => _qty[i.id] = v),
            key: ValueKey('gear-${i.id}')),
      ]),
    );
  }

  Widget _other(_Other o) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        decoration: BoxDecoration(
            color: V3.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: o.name.text.trim().isNotEmpty ? V3.green : V3.line)),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: o.name,
              style: V3.inter(15, weight: FontWeight.w600),
              cursorColor: V3.green,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'What do you need?',
                  hintStyle: V3.inter(15, color: V3.barGrey)),
            ),
          ),
          _stepper(o.qty, (v) => setState(() => o.qty = v < 1 ? 1 : v)),
        ]),
      );

  Widget _stepper(int q, ValueChanged<int> set, {Key? key}) => Container(
        key: key,
        decoration: BoxDecoration(
            border: Border.all(color: V3.line),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _step(Icons.remove, q > 0 ? () => set(q - 1) : null),
          SizedBox(
              width: 28,
              child: Text('$q',
                  textAlign: TextAlign.center,
                  style: V3.tight(15, weight: FontWeight.w700))),
          _step(Icons.add, q < 999 ? () => set(q + 1) : null),
        ]),
      );

  Widget _step(IconData icon, VoidCallback? tap) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon,
                size: 18, color: tap == null ? V3.barGrey : V3.green)),
      );
}
