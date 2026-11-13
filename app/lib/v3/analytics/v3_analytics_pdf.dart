// v3 Club Analytics PDF: the web page screenshots the full view (every list
// expanded) into a PDF; here the same content is laid out as a report with
// the pdf package and shared with Printing.sharePdf.
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'v3_analytics_models.dart';

class RepRow {
  const RepRow(this.left,
      {this.sub = '', this.right = '', this.bar, this.color = kAccent});
  final String left;
  final String sub;
  final String right;

  /// 0 to 1, drawn as a bar under the row.
  final double? bar;
  final Color color;
}

class RepSection {
  const RepSection(this.heading, {this.lines = const [], this.rows = const []});
  final String heading;
  final List<String> lines;
  final List<RepRow> rows;
}

class Report {
  const Report(this.title, this.sub, this.sections, this.fileBase);
  final String title;
  final String sub;
  final List<RepSection> sections;
  final String fileBase;
}

// ------------------------------------------------------------ report builders

String _trend(AnTrend? t) => t == null ? '' : ' · ${t.text}';

RepSection heroSection(AnCtx ctx, AnTotals t) => RepSection('', lines: [
      '${t.pct}% attendance',
      'Replied ${t.replied}% · ${plural(t.nr, 'no reply', 'no replies')}${_trend(trendLine(ctx, t.pct))}',
    ]);

List<String> splitLines(List<AnEvent> evs) {
  final tr = evs.where((e) => e.isTraining).toList();
  final ma = evs.where((e) => e.isMatch).toList();
  String line(List<AnEvent> l, String label, String unit, [String? pl]) {
    final t = totals(l);
    return '$label ${t.pct}% · ${fmtN(t.acc)} of ${fmtN(t.total)} · ${plural(l.length, unit, pl)}';
  }

  return [
    if (tr.isNotEmpty) line(tr, 'Training attendance', 'session'),
    if (ma.isNotEmpty) line(ma, 'Match availability', 'match', 'matches'),
  ];
}

List<String> codeLines(List<AnEvent> evs) {
  final codes = {
    for (final e in evs)
      if (e.code != null) e.code!
  }.toList()
    ..sort();
  if (codes.length < 2) return const [];
  return [
    for (final c in codes)
      () {
        final l = evs.where((e) => e.code == c).toList(), t = totals(l);
        return '$c ${t.pct}% · ${plural(l.length, 'event')} · replied ${t.replied}%';
      }()
  ];
}

RepSection monthsSection(AnCtx ctx) {
  final ms = months(ctx);
  if (ms.length < 2 || ctx.evs.isEmpty) return const RepSection('');
  return RepSection('Attendance by month', rows: [
    for (final m in ms)
      RepRow('${kMon[m.d.month - 1]} ${m.d.year}',
          right: m.pct == null ? '–' : '${m.pct}%',
          bar: m.pct == null ? null : m.pct! / 100,
          color: kAccent)
  ]);
}

RepRow eventRep(AnEvent e, bool showTeam) {
  final p = pctOf(e.acc, e.total);
  final d = e.date;
  return RepRow('${d.day} ${kMon[d.month - 1]} ${d.year} · ${eventTitle(e)}',
      sub: [if (e.code != null) e.code!, eventMeta(e, showTeam)]
          .where((s) => s.isNotEmpty)
          .join(' · '),
      right: '${e.acc} of ${e.total}',
      color: bandColor(p));
}

RepRow playerRep(PlayerStat p, String sort, bool showTeam) => RepRow(p.name,
    sub: playerBadges(p, sort, showTeam).map((b) => b.text).join(' · '),
    right: '${p.rate}%',
    bar: p.rate / 100,
    color: bandColor(p.rate));

Report teamsReport(AnData d, AnFilters f, AnCtx ctx, String sort, String sub) {
  final teams = teamRanking(ctx, sort);
  return Report(
      '${d.clubName} · Teams',
      sub,
      [
        RepSection('Teams', rows: [
          for (final tm in teams)
            RepRow(tm.name,
                sub: [
                  if (tm.tr.events > 0) 'Training ${tm.tr.pct}%',
                  if (tm.ma.events > 0) 'Matches ${tm.ma.pct}%',
                  plural(tm.players, 'player'),
                  plural(tm.evs.length, 'event'),
                  'Replied ${tm.t.replied}%',
                  if (trendText(tm.trend, ctx.r.prevLabel) != null)
                    trendText(tm.trend, ctx.r.prevLabel)!.text,
                ].join(' · '),
                right: '${tm.t.pct}%',
                bar: tm.t.pct / 100,
                color: bandColor(tm.t.pct))
        ])
      ],
      '${d.clubName} Teams');
}

Report teamPageReport(AnData d, AnTeam team, AnFilters f, AnCtx ctx,
    String playerSort, String sub) {
  final t = totals(ctx.evs);
  final stats = playerStats(ctx.evs);
  final list = sortPlayers(stats.values.toList(), playerSort);
  final roles = team.roles.where((r) => f.on['role']!.contains(r.role));
  final last10 = ctx.evs.take(10).toList().reversed;
  return Report(
      team.name,
      sub,
      [
        heroSection(ctx, t),
        RepSection('', lines: [
          'Last ${last10.length} events (players there): ${last10.map((e) => e.acc).join('  ')}',
          ...splitLines(ctx.evs),
          ...codeLines(ctx.evs),
          if (roles.isNotEmpty)
            'Squad: ${roles.map((r) => '${r.role} ${r.count}').join(' · ')}',
        ]),
        RepSection('Players',
            rows: [for (final p in list) playerRep(p, playerSort, false)]),
        monthsSection(ctx),
        RepSection('Events', rows: [
          for (final e in ctx.evs) eventRep(e, false),
        ]),
      ],
      '${team.name} team');
}

Report playersReport(AnData d, AnCtx ctx, String sort, String q, String sub) {
  final stats = playerStats(ctx.evs);
  movers(ctx, stats);
  final all = stats.values.toList();
  final (lo, mid, hi) = spread(all);
  final label = {for (final s in kPlayerSorts) s.$1: s.$2}[sort] ?? 'Lowest';
  return Report(
      '${d.clubName} · Players',
      sub,
      [
        RepSection('', lines: [
          '${plural(all.length, 'player')} · Average ${totals(ctx.evs).pct}%',
          'Under 50% · $lo     50–69% · $mid     70%+ · $hi',
        ]),
        RepSection('$label first', rows: [
          for (final p in playerList(all, q, sort)) playerRep(p, sort, true)
        ]),
      ],
      '${d.clubName} Players');
}

Report squadsReport(AnData d, AnCtx ctx, String sub) {
  final sm = SquadModel(d, ctx);
  final rows = sm.squadList;
  final places = rows.fold(0, (t, s) => t + s.places);
  final unpicked = sm.unpicked;
  final b = sm.buckets();
  final bMax = b.fold(1, (a, x) => x > a ? x : a);
  final most = sm.most;
  final maxPick = most.isEmpty ? 1 : most.first.total;
  return Report(
      '${d.clubName} · Match squads',
      sub,
      [
        RepSection('', lines: [
          '${sm.picked} of ${sm.poolN} players picked for at least one match squad',
          unpicked.isEmpty
              ? 'Everyone has been picked'
              : '${plural(unpicked.length, 'player')} not picked yet',
          '$places squad places across ${plural(sm.withPicks.length, 'match', 'matches')}',
          '${sm.multi} played 2+ squads · ${pctOf(sm.multi, sm.picked)}% of picked players',
        ]),
        RepSection('Squad split', rows: [
          for (final x in sm.donut(rows))
            RepRow(x.label,
                sub: x.team,
                right: '${x.v} · ${pctOf(x.v, places)}%',
                bar: places == 0 ? 0 : x.v / places,
                color: x.color)
        ]),
        RepSection('Squads', rows: [
          for (final s in rows)
            () {
              final top = stableSort(
                      s.members.entries.toList(), (a, b) => b.value - a.value)
                  .firstOrNull;
              return RepRow(sm.sqLabel(s.id),
                  sub:
                      '${plural(s.events.length, 'match', 'matches')}${top != null ? ' · most picked ${sm.nameOf(top.key)} ×${top.value}' : ''}',
                  right: plural(s.members.length, 'player'),
                  color: sm.sqHex(s.id));
            }()
        ]),
        RepSection('How often players are picked', rows: [
          for (var i = 0; i < kPickBuckets.length; i++)
            RepRow(kPickBuckets[i].$1,
                right: '${b[i]}', bar: b[i] / bMax, color: kPickBuckets[i].$2)
        ]),
        RepSection('Most picked', rows: [
          for (var i = 0; i < most.length; i++)
            RepRow('${i + 1}. ${most[i].name}',
                sub: sm
                    .ordered(most[i].m)
                    .map((e) => '${sm.sqName(e.key)} ×${e.value}')
                    .join('  '),
                right:
                    '${most[i].total}${most[i].of > 0 ? ' of ${most[i].of}' : ''}',
                bar: most[i].total / maxPick)
        ]),
        if (unpicked.isNotEmpty)
          RepSection('Not picked yet', rows: [
            for (final p in unpicked)
              RepRow(p.name,
                  sub: '${p.teams.join(', ')} · attendance ${p.rate}%',
                  right: '${p.rate}%',
                  color: bandColor(p.rate))
          ]),
      ],
      '${d.clubName} Match squads');
}

const kRespLabel = {
  'accepted': 'Going',
  'declined': 'Not going',
  'no_response': 'No reply',
};
const _respOrder = {'accepted': 0, 'declined': 1, 'no_response': 2};

/// Event sheet rows: going, then not going, then no reply, A to Z.
List<AnMember> eventMembers(AnEvent e, String resp) => stableSort(
        e.members.where((m) => resp == 'all' || m.response == resp).toList(),
        (a, b) {
      final c = (_respOrder[a.response] ?? 2) - (_respOrder[b.response] ?? 2);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

Report eventReport(AnData d, AnEvent e, String resp) => Report(
    eventTitle(e),
    eventSub(e),
    [
      RepSection('',
          lines: ['Going ${e.acc} · Not going ${e.dec} · No reply ${e.nr}']),
      RepSection('', rows: [
        for (final m in eventMembers(e, resp))
          RepRow(m.name,
              sub: [
                m.role,
                if (m.squadId != null) d.squads[m.squadId]?.name ?? ''
              ].where((s) => s.isNotEmpty).join(' · '),
              right: kRespLabel[m.response] ?? 'No reply',
              color: m.response == 'accepted'
                  ? kYes
                  : m.response == 'declined'
                      ? kNo
                      : kNone)
      ]),
    ],
    '${e.teamName} ${eventTitle(e)} ${e.date.day} ${kMon[e.date.month - 1]}');

/// Squad sheet rows: most picks first.
List<(int, String, int)> squadMembers(SquadModel sm, int id) {
  final sq = sm.squads[id];
  if (sq == null) return const [];
  return stableSort(
      [
        for (final en in sq.members.entries)
          (en.key, sm.nameOf(en.key), en.value)
      ],
      (a, b) => b.$3 != a.$3
          ? b.$3 - a.$3
          : a.$2.toLowerCase().compareTo(b.$2.toLowerCase()));
}

Report squadReport(AnData d, SquadModel sm, int id, String periodLabel) {
  final n = sm.squads[id]?.events.length ?? 0;
  return Report(
      sm.sqName(id),
      '${d.clubName} · $periodLabel',
      [
        RepSection('', rows: [
          for (final r in squadMembers(sm, id))
            RepRow(r.$2,
                right: '${r.$3} of $n',
                bar: n == 0 ? 0 : r.$3 / n,
                color: sm.sqHex(id))
        ])
      ],
      sm.sqName(id));
}

/// Roster sheet rows: the role's members A to Z with their attendance.
List<(AnRosterMember, PlayerStat?)> rosterRows(
    AnRoleGroup? role, Map<int, PlayerStat> stats) {
  return stableSort([
    for (final m in role?.members ?? const <AnRosterMember>[]) (m, stats[m.id])
  ], (a, b) => a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()));
}

Report rosterReport(
    AnTeam? team, String role, Map<int, PlayerStat> stats, String periodLabel) {
  final group = team?.roles.where((r) => r.role == role).firstOrNull;
  final title = '${team?.name ?? ''} · $role';
  return Report(
      title,
      periodLabel,
      [
        RepSection('', rows: [
          for (final r in rosterRows(group, stats))
            RepRow(r.$1.name,
                sub: r.$2 == null ? '' : plural(r.$2!.events, 'event'),
                right: r.$2 == null ? 'No events' : '${r.$2!.rate}%',
                color: r.$2 == null ? kNone : bandColor(r.$2!.rate))
        ])
      ],
      title);
}

// ------------------------------------------------------------------- render

PdfColor _pc(Color c) => PdfColor.fromInt(c.toARGB32());

const _bg = PdfColor.fromInt(0xFF111418);
const _card = PdfColor.fromInt(0xFF1E222B);
const _track = PdfColor.fromInt(0xFF252A35);
const _text = PdfColor.fromInt(0xFFF1F4F8);
const _muted = PdfColor.fromInt(0xFFA1A1A2);
const _accent = PdfColor.fromInt(0xFF87C232);

/// Helvetica only covers Latin-1, so arrows and dashes are swapped when the
/// Inter font can't be fetched.
String _latin(String s) => s
    .replaceAll('▲', '+')
    .replaceAll('▼', '-')
    .replaceAll('–', '-')
    .replaceAll('’', "'");

Future<Uint8List> buildReportPdf(Report r, DateTime now,
    {pw.Font? base, pw.Font? bold}) async {
  final doc = pw.Document(
      theme: base != null && bold != null
          ? pw.ThemeData.withFont(base: base, bold: bold)
          : null);
  final fix = base == null ? _latin : (String s) => s;
  pw.Widget row(RepRow x) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: const pw.BoxDecoration(
            color: _card,
            border: pw.Border(
                top: pw.BorderSide(color: PdfColor.fromInt(0xFF2E333E)))),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(children: [
                pw.Expanded(
                    child: pw.Text(fix(x.left),
                        style: pw.TextStyle(
                            color: _text,
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold))),
                pw.Text(fix(x.right),
                    style: pw.TextStyle(
                        color: _pc(x.color),
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
              ]),
              if (x.sub.isNotEmpty)
                pw.Text(fix(x.sub),
                    style: const pw.TextStyle(color: _muted, fontSize: 9)),
              if (x.bar != null)
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.LayoutBuilder(
                        builder: (ctx, c) => pw.Stack(children: [
                              pw.Container(
                                  height: 4, width: c!.maxWidth, color: _track),
                              pw.Container(
                                  height: 4,
                                  width: c.maxWidth * x.bar!.clamp(0.0, 1.0),
                                  color: _pc(x.color)),
                            ]))),
            ]),
      );

  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        buildBackground: (_) =>
            pw.FullPage(ignoreMargins: true, child: pw.Container(color: _bg))),
    build: (_) => [
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _accent, width: 2))),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                pw.Text(fix(r.title),
                    style: pw.TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text(fix(r.sub),
                    style: const pw.TextStyle(color: _muted, fontSize: 10)),
              ])),
          pw.RichText(
              text: pw.TextSpan(
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold),
                  children: const [
                pw.TextSpan(text: 'Coach', style: pw.TextStyle(color: _text)),
                pw.TextSpan(text: 'Smart', style: pw.TextStyle(color: _accent)),
              ])),
        ]),
      ),
      // Rows sit at the top level so long lists flow onto new pages.
      for (final s in r.sections)
        if (s.lines.isNotEmpty || s.rows.isNotEmpty) ...[
          if (s.heading.isNotEmpty)
            pw.Padding(
                padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
                child: pw.Text(fix(s.heading.toUpperCase()),
                    style: pw.TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.6))),
          for (final l in s.lines)
            pw.Container(
                color: _card,
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 10),
                child: pw.Text(fix(l),
                    style: const pw.TextStyle(color: _text, fontSize: 11))),
          for (final x in s.rows) row(x),
          pw.SizedBox(height: 6),
        ],
      pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Generated ${fmtDay(now)}',
              style: const pw.TextStyle(color: _muted, fontSize: 9))),
    ],
  ));
  return doc.save();
}
