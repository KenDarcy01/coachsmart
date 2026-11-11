// v3 Score keeper: the Stats tab (half time and full time only). The charts,
// then the timeline (newest first), then a PDF of the lot. The numbers and
// charts come from v3/match_stats, the port of cs-match-charts.js.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../match_stats/v3_match_charts.dart';
import '../match_stats/v3_match_stats_models.dart';
import '../v3_theme.dart';
import 'sk_controller.dart';
import 'sk_models.dart';
import 'sk_widgets.dart';

class SkStatsView extends StatefulWidget {
  const SkStatsView({super.key, required this.ctl});
  final SkController ctl;

  @override
  State<SkStatsView> createState() => _SkStatsViewState();
}

class _SkStatsViewState extends State<SkStatsView> {
  final _shot = GlobalKey();
  bool _making = false;

  String _when() {
    final iso = widget.ctl.c!.eventDateTime;
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null ? '' : DateFormat('EEE d MMM y').format(d);
  }

  Future<void> _pdf() async {
    final ctl = widget.ctl;
    final box = _shot.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || _making) return;
    setState(() => _making = true);
    try {
      final img = await box.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final ratio = img.height / img.width;
      img.dispose();
      if (png == null) throw Exception('no image');
      // 210 mm wide like the web export; a very long timeline gets a wider
      // page so the height stays inside the PDF limit.
      var pageW = PdfPageFormat.a4.width;
      var pageH = pageW * ratio;
      if (pageH > 14000) {
        pageH = 14000;
        pageW = pageH / ratio;
      }
      final doc = pw.Document();
      doc.addPage(pw.Page(
          pageFormat: PdfPageFormat(pageW, pageH),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(png.buffer.asUint8List()),
              fit: pw.BoxFit.fill)));
      final w = ctl.totals();
      await Printing.sharePdf(
          bytes: await doc.save(),
          filename: skPdfName(ctl.us, ctl.opp, w.us, w.opp));
    } catch (_) {
      ctl.toast("Couldn't make the PDF. Try again.");
    } finally {
      if (mounted) setState(() => _making = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final s = ctl.s!;
    if (s.acts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Text('Nothing recorded yet.',
            textAlign: TextAlign.center, style: V3.inter(16, color: V3.muted)),
      );
    }
    final m = ctl.model();
    final w = walk(m);
    final tag = s.phase == 'ht'
        ? 'HT'
        : s.phase == 'play'
            ? null
            : 'FT';
    final label =
        [ctl.c!.teamName, _when()].where((x) => x.isNotEmpty).join(' · ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      SkButton(
        label: _making ? 'Making the PDF…' : 'Download PDF',
        icon: Icons.download,
        height: 56,
        onTap: _making ? null : _pdf,
      ),
      const SizedBox(height: 8),
      RepaintBoundary(
        key: _shot,
        child: ColoredBox(
          color: V3.bg,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (label.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(label.toUpperCase(),
                          textAlign: TextAlign.center, style: skCaps(size: 12)),
                    ),
                  SkBoard(us: m.usName, opp: m.oppName, w: w, tag: tag),
                  ...skChartSection(m),
                  Padding(
                    padding: const EdgeInsets.only(top: 22, bottom: 4),
                    child: Text('TIMELINE', style: skCaps()),
                  ),
                  for (final it in timeline(m)) SkTimelineRow(it),
                ]),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('To change a score, tap it in the list on the Score tab.',
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.muted)),
      ),
    ]);
  }
}

/// cs-match-charts.js chartSection: who was ahead, biggest leads, scores
/// over the match, the halves, other stats and our scorers.
List<Widget> skChartSection(MatchModel full) {
  final m = full.scoresOnly();
  final w = walk(m);
  final (blUs, blOpp) = biggestLeads(m);
  final hs = halfScores(m);
  final stats = otherStats(m);
  final sc = scorers(m);
  return [
    _Card(children: [
      Text('Who was ahead', style: V3.tight(18, weight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text('Above the line ${m.usName} led, below it ${m.oppName} led',
          style: V3.inter(14, color: V3.muted)),
      const SizedBox(height: 8),
      V3MatchChart.lead(m),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      Expanded(
          child: _Kpi(blUs.label, '${poss(m.usName)} biggest lead', V3.green)),
      const SizedBox(width: 8),
      Expanded(
          child: _Kpi(blOpp.label, '${poss(m.oppName)} biggest lead', kOppRed)),
    ]),
    _Card(children: [
      Text('Scores over the match',
          style: V3.tight(18, weight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text('Total points for each team', style: V3.inter(14, color: V3.muted)),
      const SizedBox(height: 8),
      V3MatchChart.race(m),
    ]),
    _Table(head: (
      '',
      m.usName,
      m.oppName
    ), rows: [
      ('1st half', hs[1]!.$1, hs[1]!.$2, false),
      if (m.hasH2) ('2nd half', hs[2]!.$1, hs[2]!.$2, false),
      (m.finished ? 'Final' : 'Now', w.us, w.opp, true),
    ]),
    if (stats.isNotEmpty)
      _Table(head: (
        'Stats',
        m.usName,
        m.oppName
      ), rows: [
        for (final x in stats) (x.name, '${x.us}', '${x.opp}', false),
      ]),
    if (sc.any((r) => r.name.isNotEmpty))
      _Card(children: [
        Text('${m.usName} scorers',
            style: V3.tight(18, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        for (var i = 0; i < sc.length; i++)
          _ScorerRow(sc[i], last: i == sc.length - 1),
      ]),
  ];
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: V3.tight(22, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: V3.inter(14, color: V3.muted)),
        ]),
      );
}

class _Table extends StatelessWidget {
  const _Table({required this.head, required this.rows});
  final (String, String, String) head;
  final List<(String, String, String, bool)> rows;

  @override
  Widget build(BuildContext context) {
    final hd = V3.inter(12,
        weight: FontWeight.w600, color: V3.muted, letterSpacing: 1);
    Widget cell(String t, TextStyle st, {bool centre = true}) => Expanded(
        child: Text(t,
            textAlign: centre ? TextAlign.center : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: st));
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            cell(head.$1.toUpperCase(), hd, centre: false),
            cell(head.$2.toUpperCase(), hd),
            cell(head.$3.toUpperCase(), hd),
          ]),
        ),
        for (final r in rows)
          Container(
            constraints: const BoxConstraints(minHeight: 46),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: V3.line))),
            child: Row(children: [
              cell(
                  r.$1,
                  V3.inter(16,
                      weight: r.$4 ? FontWeight.w700 : FontWeight.w400),
                  centre: false),
              cell(r.$2, V3.tight(22, color: r.$4 ? V3.green : V3.text)),
              cell(r.$3, V3.tight(22)),
            ]),
          ),
      ]),
    );
  }
}

class _ScorerRow extends StatelessWidget {
  const _ScorerRow(this.r, {required this.last});
  final Scorer r;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 46),
        decoration: BoxDecoration(
            border:
                last ? null : const Border(bottom: BorderSide(color: V3.line))),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: Text(r.name.isEmpty ? 'No player named' : r.name,
                style:
                    V3.inter(16, color: r.name.isEmpty ? V3.muted : V3.text)),
          ),
          SizedBox(
              width: 70,
              child: Text(r.score,
                  textAlign: TextAlign.right, style: V3.tight(21))),
          if (r.other.isNotEmpty)
            Expanded(
                child: Text(r.otherText,
                    textAlign: TextAlign.right,
                    style: V3.inter(13, color: V3.muted))),
        ]),
      );
}

/// One line of the timeline: a band (throw-in, half time, full time), a
/// score, a sub or a "scored 3 in a row" note.
class SkTimelineRow extends StatelessWidget {
  const SkTimelineRow(this.it, {super.key});
  final TlItem it;

  @override
  Widget build(BuildContext context) {
    switch (it.kind) {
      case TlKind.empty:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(it.label,
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted)),
        );
      case TlKind.run:
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 0, 8),
          child: Text(it.label,
              style: V3.inter(14,
                  weight: FontWeight.w600,
                  color: it.ours ? V3.green : kOppRed)),
        );
      case TlKind.band:
        return Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: it.fullTime ? V3.green.withValues(alpha: .14) : V3.card2,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
              child: Text(it.label.toUpperCase(),
                  style: V3.inter(14,
                      weight: FontWeight.w600,
                      color: it.fullTime ? V3.green : V3.muted,
                      letterSpacing: 1)),
            ),
            Text(it.score, style: V3.tight(20)),
          ]),
        );
      case TlKind.sub:
      case TlKind.event:
        final edge = it.kind == TlKind.sub
            ? const Color(0xFF5B8DEF)
            : it.ours
                ? V3.green
                : kOppRed;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: V3.card,
            gradient: it.goal
                ? LinearGradient(
                    colors: [edge.withValues(alpha: .16), V3.card],
                    stops: const [0, .6])
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: edge),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                  child: Row(children: [
                    SizedBox(
                        width: 52,
                        child: Text(it.minute,
                            style: V3.inter(14,
                                weight: FontWeight.w700, color: V3.muted))),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(it.label, style: V3.inter(16)),
                                  if (it.tag != TlTag.none) _Tag(it.tag),
                                ]),
                            if (it.who.isNotEmpty)
                              Text(it.who,
                                  style: V3.inter(13, color: V3.muted)),
                          ]),
                    ),
                    if (it.score.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: it.score.split(' v ').first,
                            style: V3.tight(19)),
                        TextSpan(
                            text: '  v  ',
                            style: V3.inter(13, color: V3.muted)),
                        TextSpan(
                            text: it.score.split(' v ').last,
                            style: V3.tight(19)),
                      ])),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        );
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.tag);
  final TlTag tag;

  @override
  Widget build(BuildContext context) {
    final (text, bg, fg) = switch (tag) {
      TlTag.goalUs => ('GOAL', V3.green, V3.bg),
      TlTag.goalOpp => ('GOAL', kOppRed, Colors.white),
      TlTag.plus2 => ('+2', V3.amber, V3.bg),
      _ => ('CHECK', V3.amber, V3.bg),
    };
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child:
          Text(text, style: V3.inter(12, weight: FontWeight.w700, color: fg)),
    );
  }
}
