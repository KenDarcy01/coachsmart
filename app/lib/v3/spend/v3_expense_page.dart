// v3 Add expense (Spend & gear, 2026-11-23). Snap the receipt and the
// `spend` function reads the amount, date and shop (Claude Haiku, about a
// third of a cent a receipt); the coach taps what it was for and sends it to
// the club. The event is picked from the receipt date.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../v3_theme.dart';
import '/v3/tracking/v3_track.dart';
import 'v3_spend_api.dart';
import 'v3_spend_models.dart';

class V3ExpensePage extends StatefulWidget {
  const V3ExpensePage({super.key, required this.teamId, required this.data});
  final int teamId;
  final SpendData data;

  @override
  State<V3ExpensePage> createState() => _V3ExpensePageState();
}

class _V3ExpensePageState extends State<V3ExpensePage> {
  final _amount = TextEditingController();
  final _shop = TextEditingController();
  final _note = TextEditingController();
  DateTime _day = DateTime.now();
  String? _category;
  String _payback = 'bank';
  int? _eventId;
  bool _eventTouched = false;

  Uint8List? _photo;
  String? _receiptPath;
  Map<String, dynamic>? _aiRead;
  bool _reading = false;
  bool _read = false; // the AI filled something in
  bool _sending = false;

  List<String> get _categories => widget.data.categories.isNotEmpty
      ? widget.data.categories
      : const [
          'Ref fee',
          'Pitch hire',
          'Travel',
          'Match day food',
          'Entry fee',
          'Equipment',
          'Other'
        ];

  @override
  void initState() {
    super.initState();
    _eventId = widget.data.eventOn(_day)?.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _shop.dispose();
    _note.dispose();
    super.dispose();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: V3.card2,
          content: Text(text, style: V3.inter(15, weight: FontWeight.w500))));

  void _setDay(DateTime d) {
    _day = d;
    if (!_eventTouched) _eventId = widget.data.eventOn(d)?.id;
  }

  Future<void> _pick() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined, color: V3.green),
            title: Text('Take a photo', style: V3.inter(16)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: V3.green),
            title: Text('Choose a photo', style: V3.inter(16)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (src == null) return;
    XFile? f;
    try {
      f = await ImagePicker()
          .pickImage(source: src, maxWidth: 1600, imageQuality: 72);
    } catch (_) {
      _snack('Could not open the camera or photos.');
      return;
    }
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = bytes;
      _receiptPath = null;
      _reading = true;
      _read = false;
    });
    V3Track.event('spend_receipt_read');
    try {
      final mime = (f.mimeType ?? '').startsWith('image/png')
          ? 'image/png'
          : 'image/jpeg';
      final r = await SpendApi.call({
        'action': 'read_receipt',
        'team_id': widget.teamId,
        'image': base64Encode(bytes),
        'mime': mime,
      });
      if (!mounted) return;
      final read =
          r['read'] is Map ? Map<String, dynamic>.from(r['read']) : null;
      setState(() {
        _receiptPath = r['receipt_path'] as String?;
        _aiRead = read;
        _reading = false;
        if (read != null) {
          final a = read['amount'];
          if (a is num && _amount.text.trim().isEmpty) {
            _amount.text = a.toStringAsFixed(2);
            _read = true;
          }
          final dt = DateTime.tryParse('${read['date']}');
          if (dt != null &&
              !dt.isAfter(DateTime.now().add(const Duration(days: 1))) &&
              dt.isAfter(DateTime.now().subtract(const Duration(days: 400)))) {
            _setDay(dt);
            _read = true;
          }
          final s = read['shop'];
          if (s is String && s.isNotEmpty && _shop.text.trim().isEmpty) {
            _shop.text = s;
            _read = true;
          }
          final c = read['category'];
          if (c is String && _categories.contains(c) && _category == null) {
            _category = c;
          }
        }
      });
      if (read == null || !_read) {
        _snack('Photo saved. Type the amount, the receipt was hard to read.');
      }
    } on SpendError catch (e) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _photo = null;
      });
      _snack(e.message);
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(now) ? now : _day,
      firstDate: now.subtract(const Duration(days: 400)),
      lastDate: now,
      builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: V3.green, surface: V3.card, onPrimary: V3.bg)),
          child: child!),
    );
    if (d != null) setState(() => _setDay(d));
  }

  Future<void> _pickEvent() async {
    final evs = widget.data.events;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            title: Text('Not for an event', style: V3.inter(16)),
            onTap: () => Navigator.pop(ctx, 0),
          ),
          for (final e in evs)
            ListTile(
              title: Text(e.label, style: V3.inter(16)),
              trailing: e.id == _eventId
                  ? const Icon(Icons.check, color: V3.green)
                  : null,
              onTap: () => Navigator.pop(ctx, e.id),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    setState(() {
      _eventTouched = true;
      _eventId = picked == 0 ? null : picked;
    });
  }

  double? get _amountValue {
    final v = double.tryParse(
        _amount.text.replaceAll('€', '').replaceAll(',', '.').trim());
    return v != null && v > 0 && v < 100000 ? v : null;
  }

  Future<void> _send() async {
    final amount = _amountValue;
    if (amount == null) return _snack('Type the amount.');
    if (_category == null) return _snack('Tap what it was for.');
    if (_reading) return _snack('Still reading the receipt…');
    setState(() => _sending = true);
    try {
      await SpendApi.call({
        'action': 'add_expense',
        'team_id': widget.teamId,
        'amount': amount,
        'spent_on': spendYmd(_day),
        'shop': _shop.text.trim(),
        'category': _category,
        'note': _note.text.trim(),
        'payback': _payback,
        'event_id': _eventId,
        'receipt_path': _receiptPath,
        'ai_read': _aiRead,
      });
      V3Track.event('spend_expense_sent', {'category': _category!});
      if (mounted) Navigator.pop(context, true);
    } on SpendError catch (e) {
      if (mounted) setState(() => _sending = false);
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.data.events.where((e) => e.id == _eventId).firstOrNull;
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
        title: Text('Add expense', style: V3.tight(20)),
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _receiptCard(),
                const SizedBox(height: 10),
                _field(
                  label: 'Amount',
                  ai: _read,
                  child: TextField(
                    key: const ValueKey('spend-amount'),
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,€]'))
                    ],
                    style: V3.inter(17, weight: FontWeight.w500),
                    cursorColor: V3.green,
                    decoration: _plain('€0.00'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                _field(
                  label: 'Date',
                  ai: _read,
                  onTap: _pickDay,
                  child: Text(spendDay(_day),
                      style: V3.inter(17, weight: FontWeight.w500)),
                ),
                _field(
                  label: 'Shop or who was paid',
                  ai: _read && _shop.text.isNotEmpty,
                  child: TextField(
                    controller: _shop,
                    style: V3.inter(17, weight: FontWeight.w500),
                    cursorColor: V3.green,
                    textCapitalization: TextCapitalization.words,
                    decoration: _plain('e.g. Dunnes, the referee'),
                  ),
                ),
                if (widget.data.events.isNotEmpty)
                  _field(
                    label: 'For event',
                    onTap: _pickEvent,
                    child: Text(ev?.label ?? 'Not for an event',
                        style: V3.inter(17,
                            weight: FontWeight.w500,
                            color: ev == null ? V3.muted : V3.text)),
                  ),
                _label('What was it for?'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in _categories)
                    _chip(
                        c, c == _category, () => setState(() => _category = c)),
                ]),
                _label('Pay me back by'),
                _segments(),
                const SizedBox(height: 10),
                _field(
                  label: 'Note for the club (optional)',
                  child: TextField(
                    controller: _note,
                    maxLines: 2,
                    minLines: 1,
                    style: V3.inter(16),
                    cursorColor: V3.green,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _plain('Anything the treasurer should know'),
                  ),
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
                key: const ValueKey('spend-send-expense'),
                style: FilledButton.styleFrom(
                    backgroundColor: V3.green,
                    foregroundColor: V3.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: V3.bg))
                    : Text('Send to the club',
                        style: V3.tight(16,
                            weight: FontWeight.w700, color: V3.bg)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _plain(String hint) => InputDecoration(
      isDense: true,
      border: InputBorder.none,
      contentPadding: const EdgeInsets.only(top: 3),
      hintText: hint,
      hintStyle: V3.inter(16, color: V3.barGrey));

  Widget _receiptCard() {
    final p = _photo;
    return GestureDetector(
      key: const ValueKey('spend-receipt'),
      onTap: _reading ? null : _pick,
      child: Container(
        height: p == null ? 150 : 200,
        decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: p != null && !_reading ? V3.green : V3.line,
              width: p != null && !_reading ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: p == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.photo_camera_outlined,
                    color: V3.green, size: 34),
                const SizedBox(height: 8),
                Text('Snap the receipt',
                    style: V3.tight(17, weight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('We fill in the amount, date and shop',
                    style: V3.inter(13, color: V3.muted)),
              ])
            : Stack(fit: StackFit.expand, children: [
                Image.memory(p, fit: BoxFit.cover),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: V3.bg, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_reading)
                        const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: V3.green))
                      else
                        Icon(_read ? Icons.check : Icons.photo_outlined,
                            color: V3.green, size: 14),
                      const SizedBox(width: 6),
                      Text(
                          _reading
                              ? 'Reading the receipt…'
                              : _read
                                  ? 'Read from receipt'
                                  : 'Tap to change',
                          style: V3.inter(12,
                              weight: FontWeight.w600, color: V3.green)),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }

  Widget _field(
      {required String label,
      required Widget child,
      bool ai = false,
      VoidCallback? onTap}) {
    final box = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ai ? V3.nextLine : V3.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: V3.inter(12, weight: FontWeight.w500, color: V3.muted)),
        const SizedBox(height: 3),
        child,
      ]),
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 0, 8),
        child: Text(t.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w600, color: V3.muted, letterSpacing: .8)),
      );

  Widget _chip(String t, bool on, VoidCallback tap) => GestureDetector(
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
              color: on ? V3.green : V3.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: on ? V3.green : V3.line)),
          child: Text(t,
              style: V3.inter(14,
                  weight: FontWeight.w500, color: on ? V3.bg : V3.text)),
        ),
      );

  Widget _segments() {
    const opts = [
      ['bank', 'Bank transfer'],
      ['cash', 'Cash'],
      ['none', 'No need, club paid'],
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        for (final o in opts)
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _payback = o[0]),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                    color: _payback == o[0] ? V3.card2 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(o[1],
                    textAlign: TextAlign.center,
                    style: V3.inter(13,
                        weight: FontWeight.w600,
                        color: _payback == o[0] ? V3.text : V3.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}
