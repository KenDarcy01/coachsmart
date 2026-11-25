// Club sponsors in v3 (2026-11-25, thread "Explore advertising in
// CoachSmart"). A club's officers add their sponsor on
// coachsmart.app/club/sponsors.html; v3 shows one card on Home, event screens
// and live scores, and counts it once it has been on screen for a second.
//
// Server rules (get_my_sponsors / sponsor_seen): drafts are shown only to the
// club's officers and super users and never counted; a child's own login gets
// no sponsors. Counts are totals per day, team and screen; nobody's activity
// is kept. Google Analytics gets sponsor_seen / sponsor_tap with ids only.

import 'dart:async';

import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '../tracking/v3_track.dart';
import '../v3_theme.dart';

class V3Sponsor {
  V3Sponsor.fromJson(Map j)
      : id = _i(j['sponsor_id']),
        clubId = _i(j['club_id']),
        name = '${j['name'] ?? ''}',
        tagline = '${j['tagline'] ?? ''}',
        linkUrl = '${j['link_url'] ?? ''}',
        logoUrl = '${j['logo_url'] ?? ''}',
        cardColour = _colour('${j['card_colour'] ?? ''}'),
        live = j['status'] == 'live',
        onHome = j['on_home'] != false,
        onEvents = j['on_events'] != false,
        onLive = j['on_live'] != false;

  final int id, clubId;
  final String name, tagline, linkUrl, logoUrl;
  final Color? cardColour;
  final bool live, onHome, onEvents, onLive;

  bool showsOn(V3SponsorPlace p) => switch (p) {
        V3SponsorPlace.home => onHome,
        V3SponsorPlace.event => onEvents,
        V3SponsorPlace.live => onLive,
      };

  static int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static Color? _colour(String s) {
    final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(s);
    return m == null ? null : Color(0xFF000000 | int.parse(m[1]!, radix: 16));
  }
}

enum V3SponsorPlace { home, event, live }

/// Loads the signed-in user's sponsors once and keeps them for the session.
class V3Sponsors {
  V3Sponsors._();

  static final notifier = ValueNotifier<int>(0);
  static List<V3Sponsor> _sponsors = const [];
  static final Map<int, int> _clubOfTeam = {};
  static Future<void>? _loading;
  static DateTime? _loadedAt;

  /// Fetches again when [force] or when the last load is over 30 minutes old.
  static Future<void> load({bool force = false}) {
    final fresh = _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 30);
    if (!force && fresh) return Future.value();
    return _loading ??= _fetch().whenComplete(() => _loading = null);
  }

  static Future<void> _fetch() async {
    try {
      final r = await SupaFlow.client.rpc('get_my_sponsors');
      final m = r is Map ? r : const {};
      _clubOfTeam.clear();
      for (final t in (m['teams'] as List? ?? const [])) {
        if (t is Map) {
          _clubOfTeam[V3Sponsor._i(t['team_id'])] = V3Sponsor._i(t['club_id']);
        }
      }
      _sponsors = [
        for (final s in (m['sponsors'] as List? ?? const []))
          if (s is Map) V3Sponsor.fromJson(s)
      ];
      _loadedAt = DateTime.now();
      notifier.value++;
    } catch (_) {
      // No sponsor card is better than a broken screen.
    }
  }

  static int? clubOfTeam(int? teamId) =>
      teamId == null ? null : _clubOfTeam[teamId];

  static V3Sponsor? forClub(int? clubId, V3SponsorPlace place) {
    if (clubId == null) return null;
    for (final s in _sponsors) {
      if (s.clubId == clubId && s.showsOn(place)) return s;
    }
    return null;
  }

  static V3Sponsor? forTeam(int? teamId, V3SponsorPlace place) =>
      forClub(clubOfTeam(teamId), place);

  /// When the team isn't one of the user's (a club-wide live match) and the
  /// user sees just one sponsor, that one.
  static V3Sponsor? onlyOne(V3SponsorPlace place) {
    final xs = [for (final s in _sponsors) if (s.showsOn(place)) s];
    return xs.length == 1 ? xs.first : null;
  }

  /// Home: the sponsor of the picked team's club, else of the first club
  /// that has one.
  static V3Sponsor? forHome(int? teamId) {
    final picked = forTeam(teamId, V3SponsorPlace.home);
    if (picked != null || (teamId != null && teamId > 0)) return picked;
    for (final s in _sponsors) {
      if (s.onHome) return s;
    }
    return null;
  }

  static void count(V3Sponsor s, V3SponsorPlace place, String kind,
      {int? eventId, int? teamId}) {
    if (s.live) {
      unawaited(SupaFlow.client.rpc('sponsor_seen', params: {
        'p_sponsor_id': s.id,
        'p_placement': place.name,
        'p_kind': kind,
        'p_event_id': eventId,
        'p_team_id': teamId,
      }).then((_) {}, onError: (_) {}));
    }
    V3Track.event(kind == 'tap' ? 'sponsor_tap' : 'sponsor_seen', {
      'sponsor_id': s.id,
      'placement': place.name,
      'club_id': s.clubId,
      'team_id': teamId,
      'event_id': eventId,
      'draft': !s.live,
    });
  }
}

/// The sponsor card. Counts one view per time it appears, once at least half
/// of it has been on screen for a second.
class V3SponsorCard extends StatefulWidget {
  const V3SponsorCard({
    super.key,
    required this.sponsor,
    required this.place,
    this.eventId,
    this.teamId,
  });

  final V3Sponsor sponsor;
  final V3SponsorPlace place;
  final int? eventId, teamId;

  @override
  State<V3SponsorCard> createState() => _V3SponsorCardState();
}

class _V3SponsorCardState extends State<V3SponsorCard> {
  Timer? _tick;
  int _visibleMs = 0;
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _check());
  }

  @override
  void didUpdateWidget(V3SponsorCard old) {
    super.didUpdateWidget(old);
    if (old.sponsor.id != widget.sponsor.id ||
        old.eventId != widget.eventId ||
        old.teamId != widget.teamId) {
      _counted = false;
      _visibleMs = 0;
      _tick ??=
          Timer.periodic(const Duration(milliseconds: 250), (_) => _check());
    }
  }

  void _check() {
    if (!mounted || _counted) return;
    final box = context.findRenderObject();
    final route = ModalRoute.of(context);
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    if (route != null && !route.isCurrent) {
      _visibleMs = 0;
      return;
    }
    final screen = MediaQuery.sizeOf(context);
    final top = box.localToGlobal(Offset.zero).dy;
    final h = box.size.height;
    final shown = (top + h).clamp(0.0, screen.height) - top.clamp(0.0, screen.height);
    if (h > 0 && shown >= h / 2) {
      _visibleMs += 250;
      if (_visibleMs >= 1000) {
        _counted = true;
        _tick?.cancel();
        _tick = null;
        V3Sponsors.count(widget.sponsor, widget.place, 'view',
            eventId: widget.eventId, teamId: widget.teamId);
      }
    } else {
      _visibleMs = 0;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _tap() {
    final s = widget.sponsor;
    V3Sponsors.count(s, widget.place, 'tap',
        eventId: widget.eventId, teamId: widget.teamId);
    if (s.linkUrl.isNotEmpty) launchURL(s.linkUrl);
  }

  String get _label => widget.place == V3SponsorPlace.live
      ? 'Live scores sponsored by'
      : 'Club partner';

  @override
  Widget build(BuildContext context) {
    final s = widget.sponsor;
    final bg = s.cardColour ?? V3.card;
    final edge = Color.alphaBlend(Colors.white.withValues(alpha: 0.12), bg);
    return Semantics(
      button: s.linkUrl.isNotEmpty,
      label: '$_label ${s.name}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _tap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: edge),
            ),
            child: Row(children: [
              if (s.logoUrl.isNotEmpty) ...[
                Container(
                  width: 100,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Image.network(s.logoUrl,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V3.inter(10.5,
                                  weight: FontWeight.w700, color: V3.green)
                              .copyWith(letterSpacing: 1.2)),
                      const SizedBox(height: 3),
                      Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V3.inter(15, weight: FontWeight.w700)),
                      if (s.tagline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(s.tagline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: V3.inter(12.5,
                                color: V3.text.withValues(alpha: 0.72))),
                      ],
                    ]),
              ),
              if (s.linkUrl.isNotEmpty)
                const Icon(Icons.chevron_right, color: V3.green),
            ]),
          ),
        ),
      ),
    );
  }
}
