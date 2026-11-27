// v3 Home for someone who follows a club but is on no team (Ken,
// 2026-11-26, thread "Let members follow a club without a team"): the
// club's live scores, coming up for the whole club, the club partner and a
// way onto a team. Club news cards and fundraisers sit on top, as for
// everyone.
// Followers see club-level things only: no rosters, attendance or names
// (live scores show club names).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../matches/v3_matches_models.dart';
import '../sponsors/v3_sponsors.dart';
import '../v3_crest_image.dart';
import '../v3_theme.dart';
import 'v3_follow_api.dart';

// ── Results (get_club_home_results, Ken 2026-11-27) ─────────────────────

class ClubResult {
  ClubResult.fromJson(Map j)
      : clubId = j['club_id'] is num ? (j['club_id'] as num).toInt() : null,
        start = DateTime.tryParse('${j['start'] ?? ''}'),
        age = '${j['age'] ?? ''}',
        code = '${j['code'] ?? ''}',
        competition = '${j['competition'] ?? ''}',
        opposition = '${j['opposition'] ?? ''}',
        outcome = '${j['outcome'] ?? ''}',
        usScore = j['us_score'] == null ? '' : '${j['us_score']}',
        oppScore = j['opp_score'] == null ? '' : '${j['opp_score']}';

  final int? clubId;
  final DateTime? start;
  final String age, code, competition, opposition, outcome, usScore, oppScore;

  /// "U16 Football" (the scoreboard under it names both sides).
  String get team => [age, code].where((x) => x.isNotEmpty).join(' ');

  /// "U16 Football v Naomh Barrog"
  String get title =>
      '${[age, code].where((x) => x.isNotEmpty).join(' ')} v $opposition'
          .trim();

  /// "2-16 – 1-18", ours first.
  String get score => usScore.isEmpty ? '' : '$usScore – $oppScore';
}

class ClubResultsData {
  ClubResultsData.fromJson(Map j)
      : results = [
          if (j['results'] is List)
            for (final r in (j['results'] as List).whereType<Map>())
              ClubResult.fromJson(r)
        ],
        colours = {
          if (j['colours'] is Map)
            for (final e in (j['colours'] as Map).entries)
              if (int.tryParse('${e.key}') != null)
                int.parse('${e.key}'): '${e.value}'
        };
  static final empty = ClubResultsData.fromJson(const {});

  final List<ClubResult> results;

  /// club id -> primary colour '#rrggbb' (the diary icon band).
  final Map<int, String> colours;

  Color? colourOf(int? clubId) {
    final m =
        RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(colours[clubId] ?? '');
    if (m == null) return null;
    final c = Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
    final l = c.computeLuminance();
    return l > 0.02 && l < 0.85 ? c : null;
  }
}

class V3ClubHome extends StatelessWidget {
  const V3ClubHome({
    super.key,
    required this.clubs,
    required this.matches,
    required this.selectedClub,
    required this.onSelectClub,
    required this.greeting,
    required this.now,
    required this.bottomInset,
    required this.onOpenMatch,
    required this.onOpenMatches,
    this.onJoinTeam,
    this.topCards = const [],
    this.results,
    this.showResults = false,
    this.onShowResults,
  });

  /// Recent results for the Fixtures / Results pill; null while loading.
  final ClubResultsData? results;
  final bool showResults;
  final ValueChanged<bool>? onShowResults;

  /// Club news cards and fundraisers, built by Home as for everyone.
  final List<Widget> topCards;

  final List<FollowedClub> clubs;

  /// get_live_matches(14); null while loading.
  final LiveMatchesData? matches;

  /// 0 = All clubs.
  final int selectedClub;
  final ValueChanged<int> onSelectClub;
  final String greeting;
  final DateTime now;
  final double bottomInset;
  final void Function(LiveMatchRow m) onOpenMatch;
  final VoidCallback onOpenMatches;

  /// Followers on no team only; null hides the "On a team?" card.
  final VoidCallback? onJoinTeam;

  /// How many upcoming matches Home lists before "See all".
  static const upcomingOnHome = 8;

  bool get _multi => clubs.length > 1;

  FollowedClub? _club(int? id) {
    for (final c in clubs) {
      if (c.clubId == id) return c;
    }
    return null;
  }

  bool _inScope(LiveMatchRow m) {
    if (selectedClub != 0) return m.clubId == selectedClub;
    return clubs.any((c) => c.clubId == m.clubId);
  }

  @override
  Widget build(BuildContext context) {
    final d = matches;
    final live = d == null ? <LiveMatchRow>[] : d.live.where(_inScope).toList();
    final upcoming = <LiveMatchRow>[];
    if (d != null) {
      for (final (_, rows) in d.upcomingByDays(now)) {
        upcoming.addAll(rows.where(_inScope));
      }
    }
    final sponsorClub = selectedClub != 0
        ? selectedClub
        : clubs.map((c) => c.clubId).firstWhere(
            (id) => V3Sponsors.forClub(id, V3SponsorPlace.home) != null,
            orElse: () => 0);
    final sponsor = V3Sponsors.forClub(
        sponsorClub == 0 ? null : sponsorClub, V3SponsorPlace.home);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _header()),
        if (_multi) SliverToBoxAdapter(child: _chips()),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, 24 + bottomInset),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              ...topCards,
              if (d == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                      child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: V3.green))),
                )
              else ...[
                if (live.isNotEmpty) ...[
                  _section('Live now', 'All matches', onOpenMatches),
                  for (final m in live) _liveCard(m),
                ],
                _section(
                    showResults ? 'Recent results' : 'Coming up',
                    showResults || upcoming.isEmpty ? null : 'See all',
                    onOpenMatches),
                if (onShowResults != null) _pill(),
                if (showResults)
                  ..._resultsList()
                else if (upcoming.isEmpty)
                  _emptyCard('No club matches in the next two weeks.')
                else
                  _upcomingCard(upcoming.take(upcomingOnHome).toList()),
              ],
              if (sponsor != null)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: V3SponsorCard(
                      key: ValueKey('club-sponsor-${sponsor.id}'),
                      sponsor: sponsor,
                      place: V3SponsorPlace.home),
                ),
              if (onJoinTeam != null) ...[
                const SizedBox(height: 14),
                _joinCard(),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    if (!_multi && clubs.isNotEmpty) {
      final c = clubs.first;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(children: [
          V3CrestImage(c.crest,
              size: 48,
              fallback:
                  const Icon(Icons.shield_outlined, color: V3.green, size: 40)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V3.tight(24, weight: FontWeight.w700, height: 1.15)),
              const SizedBox(height: 2),
              Text(greeting, style: V3.inter(15, color: V3.muted)),
            ]),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Column(children: [
        Text(greeting,
            textAlign: TextAlign.center,
            style: V3.tight(26, weight: FontWeight.w700, height: 1.15)),
        const SizedBox(height: 4),
        Text('${clubs.length} clubs', style: V3.inter(15, color: V3.muted)),
      ]),
    );
  }

  Widget _chips() => SizedBox(
        height: 60,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          children: [
            _chip(0, 'All', null),
            for (final c in clubs) ...[
              const SizedBox(width: 8),
              _chip(c.clubId, FollowedClub.chipLabel(c, clubs), c.crest),
            ],
          ],
        ),
      );

  Widget _chip(int id, String label, String? crest) {
    final on = selectedClub == id;
    return Material(
      color: V3.card,
      shape: StadiumBorder(
          side: BorderSide(
              color: on ? V3.nextLine : Colors.transparent, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        // Tapping the picked club goes back to All.
        onTap: () => onSelectClub(on && id != 0 ? 0 : id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (crest != null) ...[
              V3CrestImage(crest, size: 22),
              const SizedBox(width: 7),
            ],
            Text(label,
                style: V3.inter(15,
                    weight: FontWeight.w600, color: on ? V3.text : V3.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _section(String title, String? link, VoidCallback onLink) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
        child: Row(children: [
          Expanded(
              child: Text(title, style: V3.tight(19, weight: FontWeight.w700))),
          if (link != null)
            TextButton(
              onPressed: onLink,
              style: TextButton.styleFrom(
                  foregroundColor: V3.green,
                  minimumSize: const Size(44, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 4)),
              child: Text('$link ›',
                  style:
                      V3.inter(14.5, weight: FontWeight.w600, color: V3.green)),
            ),
        ]),
      );

  Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: V3.inter(15, color: V3.muted)),
      );

  Widget _crestFor(LiveMatchRow m, double size) {
    final c = _club(m.clubId);
    return V3CrestImage(c?.crest ?? '',
        size: size, fallback: SizedBox(width: size, height: size));
  }

  Widget _liveCard(LiveMatchRow m) {
    final s = m.score;
    final clubName = m.clubName.isEmpty ? 'Us' : _short(m.clubName);
    Widget side(Widget badge, String name, String score) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            badge,
            const SizedBox(width: 10),
            Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(16, weight: FontWeight.w600))),
            Text(score, style: V3.tight(20, weight: FontWeight.w700)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onOpenMatch(m),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: V3.red, borderRadius: BorderRadius.circular(6)),
                  child: Text(m.phase == 'ht' ? 'HALF TIME' : 'LIVE',
                      style: V3.inter(11,
                          weight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      m.squadName.isEmpty
                          ? m.teamName
                          : '${m.teamName} · ${m.squadName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V3.inter(14, weight: FontWeight.w600)),
                ),
              ]),
              side(_crestFor(m, 26), clubName, s?.us.text ?? '–'),
              side(
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: V3.barGrey, shape: BoxShape.circle),
                    child: Text(_initials(m.opp),
                        style: V3.inter(10,
                            weight: FontWeight.w700, color: V3.text)),
                  ),
                  m.opp,
                  s?.opp.text ?? '–'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _upcomingCard(List<LiveMatchRow> rows) => Container(
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                  color: V3.line, height: 1, indent: 14, endIndent: 14),
            _upcomingRow(rows[i]),
          ],
        ]),
      );

  Widget _upcomingRow(LiveMatchRow m) {
    final t = m.eventDateTime;
    final today = t != null && sameDublinDay(t, now);
    final day = t == null ? '' : (today ? 'Today' : dayLabel(t));
    final where = m.venue.isNotEmpty ? m.venue : m.ha;
    return InkWell(
      onTap: () => onOpenMatch(m),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          _diary(t, results?.colourOf(m.clubId), today,
              Text(clockTime(t),
                  style:
                      V3.tight(15, weight: FontWeight.w700, color: V3.green))),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(15.5, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              // The date is in the diary icon, so just the place.
              Text(where.isEmpty ? day : where,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(13.5, color: V3.muted)),
            ]),
          ),
          if (_multi) ...[const SizedBox(width: 10), _crestFor(m, 24)],
        ]),
      ),
    );
  }

  // Fixtures / Results (Ken, 2026-11-27).
  Widget _pill() {
    Widget seg(String label, bool results) {
      final on = showResults == results;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: on ? null : () => onShowResults!(results),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: on ? V3.green : Colors.transparent,
                borderRadius: BorderRadius.circular(20)),
            child: Text(label,
                style: V3.inter(14,
                    weight: FontWeight.w700, color: on ? V3.bg : V3.muted)),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 230,
        height: 38,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(22)),
        child: Row(children: [seg('Fixtures', false), seg('Results', true)]),
      ),
    );
  }

  List<Widget> _resultsList() {
    final r = results;
    if (r == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: V3.green))),
        )
      ];
    }
    final rows = r.results
        .where((x) => selectedClub == 0 || x.clubId == selectedClub)
        .take(upcomingOnHome)
        .toList();
    if (rows.isEmpty) {
      return [_emptyCard('No results in the last two weeks.')];
    }
    return [
      Container(
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(
                  color: V3.line, height: 1, indent: 14, endIndent: 14),
            _resultRow(rows[i]),
          ],
        ]),
      ),
    ];
  }

  Widget _resultRow(ClubResult x) {
    final (label, bg, fg) = switch (x.outcome) {
      'won' => ('WON', V3.green, V3.bg),
      'drew' => ('DREW', V3.barGrey, V3.text),
      _ => ('LOST', V3.line, V3.muted),
    };
    final line = x.competition;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        _diary(
            x.start,
            results?.colourOf(x.clubId),
            false,
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(6)),
              child: Text(label,
                  style: V3.inter(10.5,
                      weight: FontWeight.w800, color: fg, letterSpacing: 0.8)),
            )),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.usScore.isEmpty ? x.title : x.team,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(15.5, weight: FontWeight.w600)),
            // Scoreboard: each side's name with its own score, the winner
            // in white (Ken, 2026-11-27: not clear which score was whose).
            if (x.usScore.isNotEmpty) ...[
              const SizedBox(height: 5),
              _scoreLine(_short(_club(x.clubId)?.name ?? 'Us'), x.usScore,
                  x.outcome != 'lost'),
              const SizedBox(height: 2),
              _scoreLine(x.opposition, x.oppScore, x.outcome != 'won'),
              const SizedBox(height: 3),
            ],
            const SizedBox(height: 2),
            Text(line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(13.5, color: V3.muted)),
          ]),
        ),
        if (_multi) ...[
          const SizedBox(width: 10),
          V3CrestImage(_club(x.clubId)?.crest ?? '',
              size: 24, fallback: const SizedBox(width: 24, height: 24)),
        ],
      ]),
    );
  }

  Widget _scoreLine(String name, String score, bool strong) => Row(children: [
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: V3.inter(14.5,
                  weight: strong ? FontWeight.w600 : FontWeight.w500,
                  color: strong ? V3.text : V3.muted)),
        ),
        const SizedBox(width: 10),
        Text(score,
            style: V3.tight(17,
                weight: FontWeight.w700,
                color: strong ? V3.text : V3.muted,
                height: 1.2)),
      ]);

  /// Diary icon (Ken, 2026-11-27): the day on a band in the club colour
  /// (green "TODAY" for today), the date and month under it, then [below]
  /// (the time, or WON / LOST / DREW).
  Widget _diary(DateTime? t, Color? band, bool today, Widget below) {
    final d = t == null ? null : dublin(t);
    final top = today ? 'TODAY' : (d == null ? '' : DateFormat('EEE').format(d));
    // Same club-colour band on today's card too (Ken, 2026-11-27).
    final b = band ?? V3.green;
    final onBand = b.computeLuminance() > 0.5 ? V3.bg : Colors.white;
    return SizedBox(
      width: 52,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(10)),
          child: Column(children: [
            Container(
              width: double.infinity,
              color: b,
              padding: const EdgeInsets.symmetric(vertical: 2.5),
              alignment: Alignment.center,
              child: Text(top.toUpperCase(),
                  style: V3.inter(10,
                      weight: FontWeight.w800,
                      color: onBand,
                      letterSpacing: 0.8)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(d == null ? '–' : '${d.day}',
                  style: V3.tight(21,
                      weight: FontWeight.w800,
                      color: V3.bg,
                      height: 1.05)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  d == null ? '' : DateFormat('MMM').format(d).toUpperCase(),
                  style: V3.inter(9.5,
                      weight: FontWeight.w700,
                      color: const Color(0xFF6B7280),
                      letterSpacing: 0.8)),
            ),
          ]),
        ),
        const SizedBox(height: 5),
        below,
      ]),
    );
  }

  Widget _joinCard() => Material(
        color: const Color(0xFF1B2614),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: V3.nextLine)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onJoinTeam,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: V3.green, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: V3.bg, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('On a team?',
                          style: V3.inter(16, weight: FontWeight.w700)),
                      Text('Enter the team code from your coach',
                          style: V3.inter(14, color: const Color(0xFFC7D2BB))),
                    ]),
              ),
              const Icon(Icons.chevron_right, color: V3.green),
            ]),
          ),
        ),
      );

  /// "Clontarf GAA" -> "Clontarf" on the score lines.
  static String _short(String club) => club
      .replaceAll(
          RegExp(r'\s+(GAA|RFC|FC|AFC|GFC|CLG)$', caseSensitive: false), '')
      .trim();

  static String _initials(String name) {
    final w = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    return w.take(2).map((x) => x[0].toUpperCase()).join();
  }
}
