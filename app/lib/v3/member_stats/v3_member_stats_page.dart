// v3 Member stats: one member's attendance and match selections, a native
// copy of webviews/member-analytics.html (the v2 app keeps the web page).
// Same RPC (get_member_analytics), same sections, filters and wording:
// period switch, code / event type / team filters, attendance ring with the
// last ten events, trainings and matches cards, a card per code, squad
// selections, coming up, attendance by month, matches and history lists,
// tap-to-focus on the graphics, and the PDF export. Charts are painted.
//
// Who can open it: the page itself has no role check (nor does the RPC);
// the v3 member page only shows the Statistics button to role level 20+.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_member_stats_models.dart';

// The web page's reply colours (yes / no / no reply), kept so the ring, dots
// and bars read the same as v2.
const _yes = Color(0xFF22C55E);
const _yesDim = Color(0x2422C55E);
const _no = Color(0xFFEF4444);
const _noDim = Color(0x24EF4444);
const _none = Color(0xFF4B5563);
const _noneDim = Color(0x594B5563);
const _greenDim = Color(0x2487C232);
const _text2 = Color(0xFFB0B8C8);

class V3MemberStatsPage extends StatefulWidget {
  const V3MemberStatsPage(
      {super.key, required this.memberId, this.testData, this.now});

  final int memberId;

  /// Widget tests pass the RPC result here instead of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  /// Widget tests pin "today".
  @visibleForTesting
  final DateTime? now;

  @override
  State<V3MemberStatsPage> createState() => _V3MemberStatsPageState();
}

class _V3MemberStatsPageState extends State<V3MemberStatsPage> {
  MemberStats? _data;
  bool _loading = true;
  String? _error;
  late Filters _f;
  late StatsView _view;
  StatsFocus? _focus;
  Reply? _hist; // null = All
  bool _moreMatches = false, _moreHistory = false;
  bool _exporting = false;
  final _shotKey = GlobalKey();
  final _focusKey = GlobalKey();

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dynamic r = widget.testData ??
          await SupaFlow.client.rpc('get_member_analytics',
              params: {'p_member_id': widget.memberId});
      if (!mounted) return;
      if (r is! Map) {
        setState(() {
          _error = 'No data returned.';
          _loading = false;
        });
        return;
      }
      final d = MemberStats.fromJson(r);
      setState(() {
        final keep = _data != null;
        _data = d;
        if (!keep) _f = Filters.initial(d.options);
        _error = null;
        _loading = false;
        _render();
      });
    } on PostgrestException catch (e) {
      _fail('Failed to load data: ${e.message}');
    } catch (e) {
      _fail('Failed to load data: $e');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _loading = false;
    });
  }

  /// Recompute after a period or filter change; clears any list focus.
  void _render() {
    _view = computeView(_data!, _f, _now);
    _focus = null;
  }

  void _change(VoidCallback fn) => setState(() {
        fn();
        _render();
      });

  void _setFocus(StatsFocus? f) {
    setState(() {
      _focus = (f != null && _focus?.key == f.key) ? null : f;
      _moreMatches = false;
      _moreHistory = false;
    });
    if (_focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final c = _focusKey.currentContext;
        if (c != null) {
          Scrollable.ensureVisible(c,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      });
    }
  }

  void _snack(String text, {bool warn = false, bool sticky = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: sticky
              ? const Duration(minutes: 1)
              : const Duration(milliseconds: 2500),
          content: Text(text,
              textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
          backgroundColor: warn ? V3.amber : V3.green));
  }

  // ------------------------------------------------------------------- PDF

  /// Like the web page: every Matches and History row shown, a name and
  /// filter line on top, the controls left out, cut into page-high slices.
  Future<void> _exportPdf() async {
    if (_exporting || _data == null) return;
    setState(() => _exporting = true);
    _snack('Preparing PDF…', sticky: true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      final box = _shotKey.currentContext?.findRenderObject();
      if (box is! RenderRepaintBoundary) throw Exception('no report');
      final w = box.size.width, h = box.size.height;
      // Keep the bitmap inside what the GPU can hold.
      final ratio = (16000 / h).clamp(1.0, 2.0);
      final img = await box.toImage(pixelRatio: ratio);
      const pad = 16.0, pageH = 1100.0;
      final doc = pw.Document();
      for (var y = 0.0; y < h; y += pageH) {
        final sliceH = (h - y).clamp(0.0, pageH);
        final png = await _slice(img, y * ratio, w * ratio, sliceH * ratio);
        doc.addPage(pw.Page(
            pageFormat: PdfPageFormat(w + pad * 2, sliceH + pad * 2),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Container(
                color: const PdfColor.fromInt(0xFF14181B),
                padding: const pw.EdgeInsets.all(pad),
                child: pw.Image(pw.MemoryImage(png), fit: pw.BoxFit.fill))));
      }
      img.dispose();
      final name = _data!.name;
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await Printing.sharePdf(
          bytes: await doc.save(),
          filename: pdfFileName(name),
          subject: name.isNotEmpty ? '$name – stats' : 'Player stats');
    } catch (_) {
      _snack('Could not create the PDF', warn: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<Uint8List> _slice(ui.Image img, double top, double w, double h) async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(
        img, Rect.fromLTWH(0, top, w, h), Rect.fromLTWH(0, 0, w, h), Paint());
    final part = await rec.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = await part.toByteData(format: ui.ImageByteFormat.png);
    part.dispose();
    if (bytes == null) throw Exception('no image');
    return bytes.buffer.asUint8List();
  }

  // --------------------------------------------------------------- filters

  Future<void> _openFilters() async {
    final o = _data!.options;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        void apply(VoidCallback fn) {
          _change(fn);
          setSheet(() {});
        }

        return ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: V3.card2,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: Text('Filters',
                              style: V3.tight(19, weight: FontWeight.w700))),
                      _textBtn('Clear', () {
                        apply(() {
                          for (final g in kFilterGroups) {
                            _f.reset(o, g.$1);
                          }
                        });
                      }),
                    ]),
                    for (final g in kFilterGroups)
                      if (o.of(g.$1).length >= 2) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: Text(g.$2.toUpperCase(),
                                  style: V3.inter(13,
                                      weight: FontWeight.w600,
                                      color: V3.muted,
                                      letterSpacing: 0.8))),
                          _textBtn(
                              'All',
                              () => apply(() => _f.on[g.$1] = {
                                    for (final p in o.of(g.$1)) p.$1
                                  })),
                          _textBtn('None', () => apply(() => _f.on[g.$1] = {})),
                        ]),
                        const SizedBox(height: 4),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final p in o.of(g.$1))
                            _filterPill(p.$2, _f.on[g.$1]!.contains(p.$1), () {
                              apply(() {
                                final s = _f.on[g.$1]!;
                                if (!s.remove(p.$1)) s.add(p.$1);
                              });
                            }),
                        ]),
                      ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: V3.green,
                            foregroundColor: V3.bg,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('Done',
                            style: V3.inter(17,
                                weight: FontWeight.w700, color: V3.bg)),
                      ),
                    ),
                  ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _textBtn(String t, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
                child: Text(t,
                    style: V3.inter(15,
                        weight: FontWeight.w600, color: V3.green))),
          ),
        ),
      );

  Widget _filterPill(String label, bool on, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
              color: on ? _greenDim : V3.card2,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: on ? V3.green : Colors.transparent)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: V3.inter(15,
                    weight: on ? FontWeight.w600 : FontWeight.w500,
                    color: on ? V3.green : _text2)),
          ]),
        ),
      );

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text(d != null && d.name.isNotEmpty ? d.name : 'Statistics',
            overflow: TextOverflow.ellipsis,
            style: V3.tight(17, weight: FontWeight.w600)),
        actions: [
          if (d != null && d.options.any)
            IconButton(
              tooltip: 'Filters',
              onPressed: _openFilters,
              icon: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.tune, color: V3.text, size: 26),
                if (_f.changed(d.options).isNotEmpty)
                  Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                              color: V3.green, shape: BoxShape.circle))),
              ]),
            ),
          if (d != null)
            IconButton(
              tooltip: 'Export PDF',
              onPressed: _exporting ? null : _exportPdf,
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: V3.green))
                  : const Icon(Icons.ios_share, color: V3.text, size: 24),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null
              ? _errorView(_error!)
              : RefreshIndicator(
                  color: V3.green,
                  backgroundColor: V3.card,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _periodSeg(),
                          _chips(),
                          RepaintBoundary(
                            key: _shotKey,
                            child: ColoredBox(color: V3.bg, child: _report()),
                          ),
                        ]),
                  ),
                ),
    );
  }

  Widget _errorView(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded, color: V3.amber, size: 40),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted)),
          ]),
        ),
      );

  Widget _seg<T>(List<(T, String)> items, T value, ValueChanged<T> onPick) =>
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: V3.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: V3.line)),
        child: Row(children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: it.$1 == value ? V3.card2 : Colors.transparent,
                      borderRadius: BorderRadius.circular(9)),
                  child: Text(it.$2,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: V3.inter(15,
                          weight: it.$1 == value
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: it.$1 == value ? V3.text : _text2)),
                ),
              ),
            ),
        ]),
      );

  Widget _periodSeg() {
    if (_exporting) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _seg<Period>(
          [for (final p in Period.values) (p, kPeriodLabels[p]!)],
          _f.period,
          (p) => _change(() => _f.period = p)),
    );
  }

  /// A chip per filter group that's off its default; tap to reset it.
  Widget _chips() {
    final o = _data!.options;
    final keys = _f.changed(o);
    if (keys.isEmpty || _exporting) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in keys)
          InkWell(
            onTap: () => _change(() => _f.reset(o, k)),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: V3.green)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: Text('${_f.label(o, k)} ✕',
                      overflow: TextOverflow.ellipsis,
                      style: V3.inter(14,
                          weight: FontWeight.w500, color: V3.green)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _report() {
    final d = _data!;
    final v = _view;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_exporting) _pdfHead(),
      _heroCard(),
      const SizedBox(height: 12),
      _splitCards(),
      ..._codeCards(d, v),
      ..._squadSection(d, v),
      ..._upcoming(v),
      ..._months(v),
      if (_focus != null && !_exporting)
        Padding(
          key: _focusKey,
          padding: const EdgeInsets.only(top: 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => _setFocus(null),
              borderRadius: BorderRadius.circular(99),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: V3.green, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Showing: ${_focus!.label} ✕',
                      style:
                          V3.inter(15, weight: FontWeight.w600, color: V3.bg)),
                ]),
              ),
            ),
          ),
        ),
      ..._matches(d, v),
      ..._history(d, v),
    ]);
  }

  Widget _pdfHead() {
    final d = _data!;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(d.name.isNotEmpty ? d.name : 'Player report',
            style: V3.tight(22, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(pdfSubtitle(d, _f, _view.range),
            style: V3.inter(14, color: _text2)),
        if (_focus != null)
          Text('Lists show: ${_focus!.label}',
              style: V3.inter(14, color: _text2)),
      ]),
    );
  }

  // ------------------------------------------------------------- sections

  Widget _card(Widget child,
          {VoidCallback? onTap, bool selected = false, Color? border}) =>
      Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: selected ? V3.green : (border ?? V3.line),
                width: selected ? 2 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      );

  Widget _heading(String t, {Widget? action}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 8),
        child: Row(children: [
          Expanded(
              child: Text(t, style: V3.tight(19, weight: FontWeight.w700))),
          if (action != null) action,
        ]),
      );

  Widget _empty(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(t,
            textAlign: TextAlign.center, style: V3.inter(15, color: V3.muted)),
      );

  Widget _heroCard() {
    final h = heroStats(_view);
    if (h == null) return _card(_empty('No events in this period yet'));
    return _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Semantics(
          label: '${h.rate}% attended',
          child: SizedBox(
              width: 104,
              height: 104,
              child: CustomPaint(painter: _RingPainter(h.rate))),
        ),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Attended ${h.went} of ${h.total}',
                style: V3.tight(18, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Replied to ${h.replied} of ${h.total}',
                style: V3.inter(15, color: _text2)),
            if (h.trend != null) ...[
              const SizedBox(height: 4),
              Text(h.trend!,
                  style: V3.inter(15,
                      weight: FontWeight.w600,
                      color: h.trendDir > 0
                          ? _yes
                          : h.trendDir < 0
                              ? V3.redText
                              : V3.muted)),
            ],
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Text('Last ${h.last.length} event${h.last.length != 1 ? 's' : ''}',
          style: V3.inter(14, color: _text2)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final r in h.last)
          Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  color: r == Reply.yes
                      ? _yes
                      : r == Reply.no
                          ? _no
                          : _none,
                  shape: BoxShape.circle)),
      ]),
    ]));
  }

  Widget _miniBar(int yes, int no, int total, {double height = 8}) => SizedBox(
        height: height,
        child: CustomPaint(
            size: Size.infinite,
            painter: _BarPainter([
              (total == 0 ? 0 : pct(yes, total) / 100, _yes),
              (total == 0 ? 0 : pct(no, total) / 100, _no),
            ], V3.card2)),
      );

  Widget _kpi(int? n, int total, String label, int yes, int no) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        n == null
            ? Text('–', style: V3.tight(28, weight: FontWeight.w700))
            : Text.rich(TextSpan(children: [
                TextSpan(
                    text: '$n', style: V3.tight(28, weight: FontWeight.w700)),
                TextSpan(
                    text: '/$total',
                    style:
                        V3.inter(17, weight: FontWeight.w500, color: V3.muted)),
              ])),
        const SizedBox(height: 2),
        Text(label, style: V3.inter(15, color: _text2)),
        const SizedBox(height: 10),
        _miniBar(yes, no, total),
      ]);

  /// Two cards side by side, or one full width.
  Widget _pair(List<Widget> cards) {
    if (cards.length == 1) return cards.first;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 12),
        Expanded(child: cards[1]),
      ]),
    );
  }

  Widget _grid(List<Widget> cards) => Column(children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          _pair(cards.sublist(i, (i + 2).clamp(0, cards.length))),
        ],
      ]);

  Widget _splitCards() {
    final v = _view;
    final t = v.trainings;
    final mPast = v.pastMatches;
    final tCard = _card(
        t.isEmpty
            ? _kpi(null, 0, 'Trainings attended', 0, 0)
            : _kpi(countReply(t, Reply.yes), t.length, 'Trainings attended',
                countReply(t, Reply.yes), countReply(t, Reply.no)),
        selected: _focus?.key == 'type:training',
        onTap: t.isNotEmpty ? () => _setFocus(StatsFocus.type(false)) : null);
    final mCard = _card(
        mPast.isEmpty
            ? _kpi(null, 0, 'Matches attended', 0, 0)
            : _kpi(
                countReply(mPast, Reply.yes),
                mPast.length,
                'Matches attended',
                countReply(mPast, Reply.yes),
                countReply(mPast, Reply.no)),
        selected: _focus?.key == 'type:match',
        onTap: v.matches.isNotEmpty
            ? () => _setFocus(StatsFocus.type(true))
            : null);
    // Only one of the two has data (e.g. filtered to matches): it fills the row.
    return _pair([
      if (t.isNotEmpty || v.matches.isEmpty) tCard,
      if (v.matches.isNotEmpty || t.isEmpty) mCard,
    ]);
  }

  Widget _codeName(String c) => Text(c.toUpperCase(),
      style: V3.inter(13,
          weight: FontWeight.w700, color: V3.green, letterSpacing: 0.8));

  /// One card per code; tapping a card filters the page to that code.
  List<Widget> _codeCards(MemberStats d, StatsView v) {
    final cards = codeCards(d, v);
    if (cards.isEmpty) return [];
    return [
      const SizedBox(height: 12),
      _grid([
        for (final c in cards)
          _card(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _codeName(c.code),
                const SizedBox(height: 6),
                Text(c.total > 0 ? '${pct(c.went, c.total)}%' : '–',
                    style: V3.tight(28, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Attended ${c.went} of ${c.total}',
                    style: V3.inter(15, color: _text2)),
                const SizedBox(height: 10),
                _miniBar(c.went, c.no, c.total),
                if (c.matches > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Selected ${c.picked}/${c.matches} match${c.matches != 1 ? 'es' : ''}',
                      style: V3.inter(14, color: _text2)),
                ],
              ]),
              onTap: () => _change(() => _f.on['code'] = {c.code})),
      ]),
    ];
  }

  List<Widget> _squadSection(MemberStats d, StatsView v) {
    final cards = squadCards(d, v);
    if (cards.isEmpty) return [];
    return [
      _heading('Squad selections'),
      _grid([
        for (final c in cards)
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _codeName(c.code),
            const SizedBox(height: 4),
            for (final (i, r) in c.rows.indexed)
              _squadRow(c, r, i, cards.length),
          ])),
      ]),
    ];
  }

  Widget _squadRow(SquadCard c, (String, int) r, int i, int codes) {
    final sel = _focus?.key == 'squad:${c.code}|${r.$1}';
    final share = pct(r.$2, c.total);
    return InkWell(
      onTap: () =>
          _setFocus(StatsFocus.squad(c.code, r.$1, showCode: codes > 1)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: sel ? V3.green : Colors.transparent, width: 2)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text(r.$1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(15, weight: FontWeight.w600))),
            const SizedBox(width: 8),
            Text.rich(TextSpan(style: V3.inter(15, color: _text2), children: [
              TextSpan(
                  text: '${r.$2}',
                  style: V3.inter(15, weight: FontWeight.w700)),
              TextSpan(text: ' · $share%'),
            ])),
          ]),
          const SizedBox(height: 6),
          SizedBox(
            height: 10,
            child: CustomPaint(
                size: Size.infinite,
                painter: _BarPainter([
                  (
                    share / 100,
                    i == 0 ? V3.green : V3.green.withValues(alpha: 0.6)
                  )
                ], V3.card2)),
          ),
        ]),
      ),
    );
  }

  List<Widget> _upcoming(StatsView v) {
    if (v.upcoming.isEmpty) return [];
    final needs = v.upcoming.any((e) => e.reply == Reply.none);
    return [
      _heading('Coming up'),
      _card(
          Column(children: [
            for (final (i, e) in v.upcoming.indexed)
              _row(
                  e,
                  eventTitle(e),
                  [typeLabel(e), dayTime(e.date!), e.homeAway],
                  e.reply == Reply.yes
                      ? _pill('Going', _yesDim, _yes)
                      : e.reply == Reply.no
                          ? _pill("Can't go", _noDim, V3.redText)
                          : _pill('Reply needed', _noneDim, _text2),
                  first: i == 0),
          ]),
          border: needs ? V3.amber.withValues(alpha: 0.5) : null),
    ];
  }

  List<Widget> _months(StatsView v) {
    final bars = monthBars(v, _now);
    if (bars.isEmpty) return [];
    return [
      _heading('Attendance by month'),
      _card(Semantics(
        label: [
          for (final b in bars)
            '${kMon[b.month - 1]} ${b.pct == null ? 'no events' : '${b.pct}%'}'
        ].join(', '),
        child: LayoutBuilder(builder: (ctx, box) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (t) {
              final i = (t.localPosition.dx / box.maxWidth * bars.length)
                  .floor()
                  .clamp(0, bars.length - 1);
              final b = bars[i];
              if (b.pct != null) _setFocus(StatsFocus.month(b));
            },
            child: SizedBox(
              height: 150,
              width: box.maxWidth,
              child: CustomPaint(
                  painter: _MonthPainter(
                      bars,
                      _focus?.kind == FocusKind.month ? _focus!.key : null,
                      V3.inter(13, color: _text2),
                      V3.inter(13, color: V3.muted))),
            ),
          );
        }),
      )),
    ];
  }

  Widget _moreBtn(int total, int limit, bool open, VoidCallback onTap) {
    if (total <= limit || _exporting) return const SizedBox.shrink();
    return _textBtn(open ? 'Show less' : 'See all $total', onTap);
  }

  List<Widget> _matches(MemberStats d, StatsView v) {
    final f = _focus;
    if (v.matches.isEmpty ||
        (f != null && f.kind == FocusKind.type && !f.match)) {
      return [];
    }
    final matches = f == null ? v.matches : f.matches(d, v.matches);
    final top = topSquad(matches);
    final list = _exporting || _moreMatches
        ? matches
        : matches.take(kMatchLimit).toList();
    return [
      _heading('Matches',
          action: _moreBtn(matches.length, kMatchLimit, _moreMatches,
              () => setState(() => _moreMatches = !_moreMatches))),
      _card(list.isEmpty
          ? _empty('No matches for this selection')
          : Column(children: [
              for (final (i, m) in list.indexed)
                _row(
                    m.e,
                    matchTitle(m),
                    matchMeta(m),
                    m.squad != null
                        ? (m.squad == top
                            ? _pill(m.squad!, _greenDim, V3.green)
                            : _pill(m.squad!, _noneDim, _text2))
                        : _pill('Not selected', _noneDim, _text2),
                    first: i == 0),
            ])),
    ];
  }

  List<Widget> _history(MemberStats d, StatsView v) {
    if (v.past.isEmpty) return [];
    final focused = _focus == null ? v.past : _focus!.events(d, v, v.past);
    final rows = _hist == null
        ? focused
        : focused.where((e) => e.reply == _hist).toList();
    final list =
        _exporting || _moreHistory ? rows : rows.take(kHistoryLimit).toList();
    return [
      _heading('History',
          action: _moreBtn(rows.length, kHistoryLimit, _moreHistory,
              () => setState(() => _moreHistory = !_moreHistory))),
      if (!_exporting)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _seg<Reply?>(const [
            (null, 'All'),
            (Reply.yes, 'Went'),
            (Reply.no, 'Missed'),
            (Reply.none, 'No reply'),
          ], _hist, (r) => setState(() => _hist = r)),
        ),
      _card(list.isEmpty
          ? _empty('Nothing here for this period')
          : Column(children: [
              for (final (i, e) in list.indexed)
                _row(
                    e,
                    eventTitle(e),
                    [typeLabel(e), e.homeAway],
                    e.reply == Reply.yes
                        ? _pill('Went', _yesDim, _yes)
                        : e.reply == Reply.no
                            ? _pill('Declined', _noDim, V3.redText)
                            : _pill('No reply', _noneDim, _text2),
                    first: i == 0),
            ])),
    ];
  }

  // ------------------------------------------------------------------ rows

  Widget _pill(String t, Color bg, Color fg) => Container(
        constraints: const BoxConstraints(maxWidth: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: V3.inter(14, weight: FontWeight.w600, color: fg)),
      );

  Widget _row(MsEvent e, String title, List<String?> parts, Widget pill,
      {bool first = false}) {
    final d = _data!;
    final (day, mon) = dateBlock(e.date!, _now);
    final m = meta(parts, title);
    final code = !d.multiCode
        ? null
        : e.code != null
            ? _codeTag(d.codeLabel(e.code)!, V3.green, _greenDim)
            : _codeTag('No code', _text2, _noneDim);
    return Container(
      padding: EdgeInsets.only(top: first ? 0 : 12, bottom: 12),
      decoration: BoxDecoration(
          border: first ? null : const Border(top: BorderSide(color: V3.line))),
      child: Row(children: [
        SizedBox(
          width: 46,
          child: Column(children: [
            Text(day,
                style: V3.tight(19, weight: FontWeight.w700, height: 1.1)),
            Text(mon, style: V3.inter(12, color: V3.muted)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(16, weight: FontWeight.w600)),
            if (m.isNotEmpty || code != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  if (code != null) code,
                  Expanded(
                    child: Text(m,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(14, color: _text2)),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        pill,
      ]),
    );
  }

  Widget _codeTag(String t, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(5)),
        child: Text(t.toUpperCase(),
            style: V3.inter(12,
                weight: FontWeight.w700, color: fg, letterSpacing: 0.4)),
      );
}

// ---------------------------------------------------------------- painters

/// The attendance ring: grey track, green arc from 12 o'clock, % inside.
class _RingPainter extends CustomPainter {
  _RingPainter(this.rate);
  final int rate;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final stroke = s * 4 / 36;
    final c = size.center(Offset.zero);
    final r = s * 15.5 / 36;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = V3.card2);
    if (rate > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -3.14159265 / 2,
          2 * 3.14159265 * rate.clamp(0, 100) / 100,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round
            ..color = V3.green);
    }
    final tp = TextPainter(
        text: TextSpan(
            text: '$rate%', style: V3.tight(s * 0.24, weight: FontWeight.w700)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.rate != rate;
}

/// A rounded track with segments laid end to end (fraction, colour).
class _BarPainter extends CustomPainter {
  _BarPainter(this.parts, this.track);
  final List<(double, Color)> parts;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.height / 2));
    canvas.drawRRect(rr, Paint()..color = track);
    canvas.save();
    canvas.clipRRect(rr);
    var x = 0.0;
    for (final (f, c) in parts) {
      final w = size.width * f.clamp(0.0, 1.0);
      if (w <= 0) continue;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), Paint()..color = c);
      x += w;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.track != track ||
      old.parts.length != parts.length ||
      [for (var i = 0; i < parts.length; i++) parts[i] != old.parts[i]]
          .contains(true);
}

/// Attendance by month: a bar per month with its % above and the month
/// below. Months well under the average are dimmer; with a month focused,
/// the others fade.
class _MonthPainter extends CustomPainter {
  _MonthPainter(this.bars, this.focusKey, this.pctStyle, this.labelStyle);
  final List<MonthBar> bars;
  final String? focusKey;
  final TextStyle pctStyle, labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 6.0, textH = 18.0, space = 4.0;
    final n = bars.length;
    final colW = (size.width - gap * (n - 1)) / n;
    final barTop = textH + space;
    final barBottom = size.height - textH - space;
    final barMax = barBottom - barTop;
    for (var i = 0; i < n; i++) {
      final b = bars[i];
      final x = i * (colW + gap);
      final sel = focusKey != null && b.key == focusKey;
      final faded = focusKey != null && !sel;
      void text(String t, TextStyle st, double y) {
        final tp = TextPainter(
            text: TextSpan(text: t, style: st),
            textDirection: TextDirection.ltr,
            maxLines: 1)
          ..layout(maxWidth: colW + gap);
        tp.paint(canvas, Offset(x + (colW - tp.width) / 2, y));
      }

      final hi = sel
          ? labelStyle.copyWith(color: V3.green, fontWeight: FontWeight.w700)
          : null;
      text(b.label, hi ?? labelStyle, size.height - textH);
      if (b.pct == null) {
        text('–', pctStyle, barBottom - textH - space);
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, barBottom - 3, colW, 3),
                const Radius.circular(2)),
            Paint()..color = V3.card2);
        continue;
      }
      final h = barMax * (b.pct!.clamp(2, 100)) / 100;
      var alpha = b.low ? 0.55 : 1.0;
      if (faded) alpha *= 0.35;
      canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, barBottom - h, colW, h),
              topLeft: const Radius.circular(5),
              topRight: const Radius.circular(5),
              bottomLeft: const Radius.circular(2),
              bottomRight: const Radius.circular(2)),
          Paint()..color = V3.green.withValues(alpha: alpha));
      text('${b.pct}%', hi ?? pctStyle, barBottom - h - textH - space);
    }
  }

  @override
  bool shouldRepaint(_MonthPainter old) =>
      old.focusKey != focusKey || old.bars != bars;
}
