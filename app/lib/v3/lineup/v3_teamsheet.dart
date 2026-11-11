// The Irish teamsheet PDF (teams.teamsheet on): the web page's
// generateTeamsheet + drawTeamsheet, built with the pdf package and shown
// in a preview with a Share button (the web page's overlay).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_lineup_models.dart';

class TsPerson {
  const TsPerson(this.irish, this.english, this.mem, [this.dob]);
  final String irish, english, mem;
  final String? dob; // players only
}

class TeamsheetData {
  const TeamsheetData({
    required this.clubIrish,
    required this.teamName,
    this.chairperson = '',
    this.secretary = '',
    this.crest,
    this.gaa,
    this.players = const [],
    this.managers = const [],
  });
  final String clubIrish, teamName, chairperson, secretary;
  final Uint8List? crest, gaa;
  final List<TsPerson> players, managers;
}

/// Date of birth as dd/mm/yyyy, 'blank' when unknown.
String tsDob(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? 'blank' : DateFormat('dd/MM/yyyy').format(d);
}

String teamsheetFileName(String teamName) =>
    'CoachSmart_${(teamName.isEmpty ? 'Team' : teamName).replaceAll(RegExp(r'[^\w-]+'), '_')}_teamsheet.pdf';

String tsStamp(DateTime t) => DateFormat('dd-MM-yyyy HH:mm').format(t);

/// The built-in PDF fonts only carry Latin-1; anything else would break the
/// page, so it is swapped for '?'.
String pdfSafe(String s) =>
    String.fromCharCodes(s.runes.map((r) => r <= 0xFF ? r : 0x3F));

String _s(dynamic v) => v == null ? '' : '$v';

Future<Uint8List?> _bytes(String url) async {
  if (url.isEmpty) return null;
  try {
    final r = await http.get(Uri.parse(url));
    return r.statusCode == 200 ? r.bodyBytes : null;
  } catch (_) {
    return null;
  }
}

/// translate-names edge function: English name -> Irish. Falls back to the
/// English name, as the web page does.
Future<Map<String, String>> _translate(List<String> names) async {
  final fb = {for (final n in names) n: n};
  if (names.isEmpty) return fb;
  try {
    final r = await SupaFlow.client.functions
        .invoke('translate-names', body: {'names': names});
    final d = r.data;
    if (d is! Map) return fb;
    return {for (final n in names) n: _s(d[n]).isEmpty ? n : _s(d[n])};
  } catch (_) {
    return fb;
  }
}

/// Everything the teamsheet needs, read the same way the web page reads it.
Future<TeamsheetData> fetchTeamsheet(
    {required int eventId,
    required int teamId,
    int? squadId,
    required String teamName,
    required List<LineupPlayer> players}) async {
  final sb = SupaFlow.client;
  final sq = (squadId ?? 0) > 0 ? squadId : null;
  final team = await sb
      .from('teams')
      .select(
          'team_name,clubs(club_name_translated,club_name,crest,chairperson,secretary,sport_id)')
      .eq('team_id', teamId);
  final club = team.isNotEmpty && team.first['clubs'] is Map
      ? team.first['clubs'] as Map
      : const {};
  var gaaUrl = '';
  try {
    final s =
        await sb.from('sport').select('sport_crest').eq('sport_name', 'GAA');
    if (s.isNotEmpty) gaaUrl = _s(s.first['sport_crest']);
  } catch (_) {}
  final imgs = await Future.wait([_bytes(_s(club['crest'])), _bytes(gaaUrl)]);

  final ids = players.map((p) => p.id).toList();
  final memMap = <int, Map>{};
  if (ids.isNotEmpty) {
    final rows = await sb
        .from('members')
        .select(
            'member_id,first_name,last_name,date_of_birth,membership_num,name_translated')
        .inFilter('member_id', ids);
    for (final m in rows) {
      memMap[m['member_id'] as int] = m;
    }
  }

  // Managers: role level 25 or 30, in the match day squad, attending.
  var mgrs = <Map>[];
  final ms = await sb
      .from('match_squads')
      .select('match_squad_id')
      .eq('event_id', eventId)
      .order('match_squad_id', ascending: false)
      .limit(1);
  if (ms.isNotEmpty) {
    var q = sb
        .from('match_squad_details')
        .select('id,member_id')
        .eq('match_squad_id', ms.first['match_squad_id']);
    if (sq != null) q = q.eq('squad_id', sq);
    final inSquad = latestMemberIds(await q.order('id', ascending: false));
    if (inSquad.isNotEmpty) {
      final roles = await sb
          .from('member_team_link')
          .select('member_id,member_team_role_link(roles(role_level))')
          .eq('team_id', teamId)
          .inFilter('member_id', inSquad);
      final coachIds = membersWithRoleLevel(roles, {25, 30}).toList();
      if (coachIds.isNotEmpty) {
        final att = await sb
            .from('event_attendance')
            .select('member_id,response_id,created_at')
            .eq('event_id', eventId)
            .inFilter('member_id', coachIds)
            .order('member_id')
            .order('created_at', ascending: false);
        final going = attendingMemberIds(att);
        if (going.isNotEmpty) {
          mgrs = List<Map>.from(await sb
              .from('members')
              .select(
                  'member_id,first_name,last_name,membership_num,name_translated')
              .inFilter('member_id', going)
              .order('last_name')
              .order('first_name'));
        }
      }
    }
  }

  // Irish names: stored name_translated first, translate the rest and
  // write them back (fire and forget, as the web page does).
  final missing = <int, String>{};
  for (final p in players) {
    final m = memMap[p.id];
    if (m != null && _s(m['name_translated']).isEmpty) {
      missing[p.id] = fullName(m);
    }
  }
  for (final m in mgrs) {
    if (_s(m['name_translated']).isEmpty) {
      missing[m['member_id'] as int] = fullName(m);
    }
  }
  final tr = await _translate(missing.values.toSet().toList());
  missing.forEach((id, name) {
    final t = tr[name];
    if (t != null && t != name) {
      sb
          .from('members')
          .update({'name_translated': t})
          .eq('member_id', id)
          .then((_) {}, onError: (_) {});
    }
  });
  String irish(String eng, dynamic stored) =>
      _s(stored).isNotEmpty ? _s(stored) : (tr[eng] ?? eng);

  return TeamsheetData(
    clubIrish: _s(club['club_name_translated']).isNotEmpty
        ? _s(club['club_name_translated'])
        : _s(club['club_name']).isNotEmpty
            ? _s(club['club_name'])
            : teamName,
    teamName: teamName,
    chairperson: _s(club['chairperson']),
    secretary: _s(club['secretary']),
    crest: imgs[0],
    gaa: imgs[1],
    players: [
      for (final p in players)
        TsPerson(
            irish(p.name, memMap[p.id]?['name_translated']),
            p.name,
            _s(memMap[p.id]?['membership_num']).isEmpty
                ? 'blank'
                : _s(memMap[p.id]?['membership_num']),
            tsDob(memMap[p.id]?['date_of_birth']))
    ],
    managers: [
      for (final m in mgrs)
        TsPerson(irish(fullName(m), m['name_translated']), fullName(m),
            _s(m['membership_num']).isEmpty ? 'blank' : _s(m['membership_num']))
    ],
  );
}

// ------------------------------------------------------------------- PDF

const _teal = PdfColor.fromInt(0xFF004A67);
const _detail = PdfColor.fromInt(0xFF7E8291);
const _lgrey = PdfColor.fromInt(0xFFCCCCCC);
const _dgrey = PdfColor.fromInt(0xFF333333);

pw.ImageProvider? _img(Uint8List? b) {
  if (b == null) return null;
  try {
    return pw.MemoryImage(b);
  } catch (_) {
    return null;
  }
}

/// A4 teamsheet, the same layout as the web page's drawTeamsheet.
Future<Uint8List> buildTeamsheetPdf(TeamsheetData d, DateTime now) async {
  const mm = PdfPageFormat.mm;
  final doc = pw.Document();
  pw.TextStyle st(double size, {bool bold = false, PdfColor color = _teal}) =>
      pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color);
  pw.Widget t(String s, pw.TextStyle style, {pw.TextAlign? align}) =>
      pw.Text(pdfSafe(s), style: style, textAlign: align, maxLines: 1);

  pw.Widget logo(Uint8List? b, double w, double h) {
    final i = _img(b);
    return pw.Container(
        width: w,
        height: h,
        decoration: i == null
            ? pw.BoxDecoration(border: pw.Border.all(color: _lgrey, width: .5))
            : null,
        child: i == null ? null : pw.Image(i, fit: pw.BoxFit.contain));
  }

  pw.Widget meta(String value, String label) => pw.Expanded(
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
            pw.SizedBox(
                height: 5 * mm,
                child: pw.Align(
                    alignment: pw.Alignment.bottomLeft,
                    child: t(value, st(11, bold: true)))),
            pw.SizedBox(height: 1 * mm),
            pw.Container(height: .5, color: _teal),
            pw.SizedBox(height: .8 * mm),
            t(label, st(7, color: _detail)),
          ]));

  pw.Widget pair(pw.Widget a, pw.Widget b) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3 * mm),
      child: pw.Row(children: [a, pw.SizedBox(width: 8 * mm), b]));

  pw.Widget box({bool tick = false}) => pw.Container(
      width: 3.8 * mm,
      height: 3.8 * mm,
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _dgrey, width: .9),
          borderRadius: pw.BorderRadius.circular(.8 * mm)),
      child: tick
          ? pw.CustomPaint(
              painter: (g, size) {
                g
                  ..setStrokeColor(PdfColors.black)
                  ..setLineWidth(1.1)
                  ..moveTo(.8 * mm, 1.9 * mm)
                  ..lineTo(1.6 * mm, .9 * mm)
                  ..lineTo(3.1 * mm, 3.0 * mm)
                  ..strokePath();
              },
              size: const PdfPoint(3.8 * mm, 3.8 * mm))
          : null);

  pw.Widget person(TsPerson? p, {required bool player}) => pw.Expanded(
      child: p == null
          ? pw.SizedBox()
          : pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (player) ...[
                pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 1.2 * mm),
                    child: box()),
                pw.SizedBox(width: 2 * mm),
                pw.Container(
                    width: 7 * mm,
                    margin: const pw.EdgeInsets.only(top: 4.3 * mm),
                    height: .6,
                    color: _teal),
                pw.SizedBox(width: 2 * mm),
              ] else
                pw.SizedBox(width: 3.8 * mm + 11 * mm),
              pw.Expanded(
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                    t(p.irish, st(10.5)),
                    t(
                        player
                            ? '${p.dob}   ${p.mem}   ${p.english}'
                            : '${p.mem}   ${p.english}',
                        st(8, color: _detail)),
                  ])),
            ]));

  List<pw.Widget> twoCols(List<TsPerson> list, {required bool player}) {
    final half = (list.length / 2).ceil();
    final l = list.sublist(0, half), r = list.sublist(half);
    return [
      for (var i = 0; i < half; i++)
        pw.Container(
            height: (player ? 8.5 : 8) * mm,
            child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  person(l[i], player: player),
                  pw.SizedBox(width: 8 * mm),
                  person(i < r.length ? r[i] : null, player: player),
                ])),
    ];
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 14 * mm,
        marginRight: 14 * mm,
        marginTop: 10 * mm,
        marginBottom: 10 * mm),
    footer: (ctx) =>
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      t('= neamhchláraithe', st(6.5, color: _lgrey)),
      t('Cruthaithe i gCoachSmart ag ${tsStamp(now)} (${ctx.pageNumber}/${ctx.pagesCount})',
          st(6.5, color: _lgrey)),
    ]),
    build: (ctx) => [
      pw.Row(children: [
        logo(d.crest, 28 * mm, 28 * mm),
        pw.Expanded(
            child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 4 * mm),
                child: pw.Text(pdfSafe(d.clubIrish),
                    textAlign: pw.TextAlign.center,
                    style: st(25, bold: true)))),
        logo(d.gaa, 26 * mm, 18 * mm),
      ]),
      pw.SizedBox(height: 4 * mm),
      pair(
          meta(d.chairperson, '(Cathaoirleach)'), meta(d.secretary, '(Rúnaí)')),
      pair(meta(d.teamName, '(Foireann)'), meta('', '(Freasúra)')),
      pair(meta('', '(Comórtas)'), meta('', '(Dáta)')),
      pw.SizedBox(height: 2 * mm),
      pw.Center(child: t('Imreoirí', st(16, bold: true))),
      pw.SizedBox(height: 2 * mm),
      pw.Row(children: [
        box(tick: true),
        pw.SizedBox(width: 2.5 * mm),
        t('= ag tosú (Starting)', st(8.5, color: _dgrey)),
      ]),
      pw.SizedBox(height: 3 * mm),
      ...twoCols(d.players, player: true),
      pw.SizedBox(height: 5 * mm),
      pw.Center(child: t('Bainisteoirí', st(16, bold: true))),
      pw.SizedBox(height: 3 * mm),
      ...twoCols(d.managers, player: false),
      pw.SizedBox(height: 12 * mm),
      pw.Row(children: [
        for (final (i, label) in [
          '(Sínithe ag an Rúnaí)',
          '(Sínithe ag an Réiteoir)'
        ].indexed) ...[
          if (i == 1) pw.SizedBox(width: 8 * mm),
          pw.Expanded(
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                pw.Container(height: .6, color: _teal),
                pw.SizedBox(height: 2.5 * mm),
                t(label, st(7.5, color: _detail)),
              ])),
        ],
      ]),
    ],
  ));
  return doc.save();
}

/// Preview and share, like the web page's teamsheet overlay.
class V3TeamsheetPage extends StatelessWidget {
  const V3TeamsheetPage(
      {super.key, required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
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
        title: Text('Teamsheet', style: V3.tight(17)),
      ),
      body: Column(children: [
        Expanded(
          child: PdfPreview(
            build: (_) async => bytes,
            useActions: false,
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            pdfFileName: fileName,
            scrollViewDecoration: const BoxDecoration(color: V3.bg),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: V3.green,
                    foregroundColor: V3.bg,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                onPressed: () =>
                    Printing.sharePdf(bytes: bytes, filename: fileName),
                icon: const Icon(Icons.ios_share),
                label: Text('Share teamsheet',
                    style: V3.inter(17, weight: FontWeight.w700, color: V3.bg)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
