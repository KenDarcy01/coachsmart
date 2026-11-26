// v3 Home for someone who follows a club but is on no team (Ken,
// 2026-11-26, thread "Let members follow a club without a team"): the
// club's live scores, coming up for the whole club, the club partner and a
// way onto a team. Club news cards and fundraisers sit on top, as for
// everyone.
// Followers see club-level things only: no rosters, attendance or names
// (live scores show club names).
import 'package:flutter/material.dart';

import '../matches/v3_matches_models.dart';
import '../sponsors/v3_sponsors.dart';
import '../v3_crest_image.dart';
import '../v3_theme.dart';
import 'v3_follow_api.dart';

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
  });

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
                _section('Coming up', upcoming.isEmpty ? null : 'See all',
                    onOpenMatches),
                if (upcoming.isEmpty)
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
          SizedBox(
            width: 54,
            child: Text(clockTime(t),
                style: V3.tight(17, weight: FontWeight.w700, color: V3.green)),
          ),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(15.5, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(where.isEmpty ? day : '$day · $where',
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
