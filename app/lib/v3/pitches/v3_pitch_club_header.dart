// v3 Pitch planner: the ClubSmart header shared by the club tools on
// coachsmart.app (website/club/shell.js), drawn here so the planner looks
// like the other club tools and the whole page scrolls (Ken 2026-11-27).
// Club look in a browser only; inside the app the planner keeps its own.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../v3_crest_image.dart';
import 'v3_pitch_models.dart';

const _site = 'https://coachsmart.app';
const _muted = Color(0xFF5D6573);
const _ink = Color(0xFF16191F);

double? _lum(String hex) {
  final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(hex);
  if (m == null) return null;
  final n = int.parse(m.group(1)!, radix: 16);
  double ch(int v) {
    final x = v / 255;
    return x <= .03928
        ? x / 12.92
        : math.pow((x + .055) / 1.055, 2.4).toDouble();
  }

  return .2126 * ch(n >> 16) + .7152 * ch((n >> 8) & 255) + .0722 * ch(n & 255);
}

Color _hex(String h) =>
    Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

/// The club colour, as the club tools pick it: the first club colour dark
/// enough to read on white, else near-black.
Color clubToolsAccent(Map? club) {
  bool ok(String? h) {
    final l = _lum(h ?? '');
    return l != null && l < .45;
  }

  final p = '${club?['primary_colour'] ?? ''}';
  final s = '${club?['secondary_colour'] ?? ''}';
  if (ok(p)) return _hex(p);
  if (ok(s)) return _hex(s);
  return const Color(0xFF1A1D23);
}

class ClubToolsHeader extends StatelessWidget {
  const ClubToolsHeader(
      {super.key,
      required this.club,
      required this.home,
      required this.onSignOut,
      this.pitchesUnread = 0});

  /// The planner's club (crest and name before club_home arrives).
  final PitchClub club;

  /// club_home(p_club) result, or null.
  final Map? home;
  final VoidCallback onSignOut;
  final int pitchesUnread;

  TextStyle _dm(double size,
          {FontWeight weight = FontWeight.w400, Color? colour}) =>
      GoogleFonts.dmSans(
          fontSize: size,
          fontWeight: weight,
          color: colour ?? _ink,
          height: 1.15);

  List<(String, IconData, String, String, int)> _items() {
    final t = (home?['tiles'] as Map?) ?? const {};
    final q = '?club=${club.clubId}';
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    final out = <(String, IconData, String, String, int)>[
      ('home', Icons.home_outlined, 'Home', '/club/$q', 0)
    ];
    if (t['dashboard'] != null) {
      out.add((
        'dashboard',
        Icons.show_chart,
        'Dashboard',
        '/club/dashboard.html$q&period=season',
        0
      ));
    }
    if (t['pitches'] != null) {
      out.add((
        'pitches',
        Icons.stadium_outlined,
        'Pitches',
        '/club/pitches.html$q',
        0
      ));
    }
    final nl = t['newsletter'];
    if (nl is Map) {
      final title = '${nl['title'] ?? ''}';
      out.add((
        'newsletter',
        Icons.newspaper_outlined,
        title.isEmpty ? 'Newsletter' : title,
        '/club/newsletter.html$q',
        nl['status'] == 'built' ? 1 : 0
      ));
    }
    if (t['messages'] != null) {
      out.add((
        'messages',
        Icons.campaign_outlined,
        'Messages',
        '/club/messages.html$q',
        0
      ));
    }
    if (t['sponsors'] != null) {
      out.add((
        'sponsors',
        Icons.star_outline,
        'Partners',
        '/club/sponsors.html$q',
        0
      ));
    }
    if (t['officers'] != null) {
      out.add((
        'officers',
        Icons.groups_outlined,
        'Officers',
        '/club/officers.html$q',
        0
      ));
    }
    final sp = t['spend'];
    if (sp is Map) {
      out.add((
        'spend',
        Icons.receipt_long_outlined,
        'Spend & gear',
        '/club/spend.html$q',
        n(sp['claims']) + n(sp['gear'])
      ));
    }
    final lo = t['lotto'];
    if (lo is Map) {
      out.add((
        'lotto',
        Icons.confirmation_number_outlined,
        'Lotto',
        '/lotto/admin.html?lotto=${lo['lotto_id']}',
        0
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width <= 760;
    final c = (home?['club'] as Map?) ?? const {};
    final accent = home == null
        ? clubToolsAccent({
            'primary_colour': club.primary,
            'secondary_colour': club.secondary
          })
        : clubToolsAccent(c);
    final name =
        '${c['club_name'] ?? ''}'.isNotEmpty ? '${c['club_name']}' : club.name;
    final crest =
        '${c['crest'] ?? ''}'.isNotEmpty ? '${c['crest']}' : club.crest;
    final first = '${(home?['me'] as Map?)?['first_name'] ?? ''}';
    final sub = ['ClubSmart', if (first.isNotEmpty) 'Hi $first'].join(' · ');
    final nav = home == null
        ? const <(String, IconData, String, String, int)>[]
        : _items();

    Widget tab((String, IconData, String, String, int) it) {
      final (key, icon, label, href, count) = it;
      final on = key == 'pitches';
      final shown = key == 'pitches' ? 0 : count;
      final fg = on ? accent : _muted;
      return Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Material(
          color: on
              ? Color.alphaBlend(accent.withValues(alpha: 0.09), Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: on
                ? null
                : () => launchUrl(Uri.parse('$_site$href'),
                    webOnlyWindowName: '_self'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: 7),
                Text(label,
                    style: _dm(phone ? 15 : 15.5,
                        weight: FontWeight.w600, colour: fg)),
                if (shown > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: accent, borderRadius: BorderRadius.circular(10)),
                    child: Text(shown > 99 ? '99+' : '$shown',
                        style: _dm(12,
                            weight: FontWeight.w600, colour: Colors.white)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      );
    }

    final side = phone ? 16.0 : 48.0;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: accent, width: 5))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: EdgeInsets.fromLTRB(side, phone ? 16 : 22, side,
                nav.length > 1 ? 0 : (phone ? 16 : 22)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    if (crest.isNotEmpty) ...[
                      V3CrestImage(crest, size: phone ? 46 : 56),
                      SizedBox(width: phone ? 12 : 16),
                    ],
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: _dm(phone ? 21 : 26,
                                    weight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(sub,
                                style: _dm(phone ? 14.5 : 16, colour: _muted)),
                          ]),
                    ),
                    if (home != null)
                      TextButton(
                        onPressed: onSignOut,
                        style: TextButton.styleFrom(foregroundColor: _ink),
                        child: Text('Sign out',
                            style: _dm(phone ? 15 : 16,
                                weight: FontWeight.w600, colour: _muted)),
                      ),
                  ]),
                  if (nav.length > 1)
                    Padding(
                      padding:
                          EdgeInsets.only(top: phone ? 10 : 14, bottom: 10),
                      child: Transform.translate(
                        offset: Offset(phone ? -6 : -10, 0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [for (final it in nav) tab(it)]),
                        ),
                      ),
                    ),
                ]),
          ),
        ),
      ),
    );
  }
}
