// v3 Pitch planner page (Ken approved 2026-11-16, mock-ups in
// /mnt/project-files/coachsmart/pitch-allocation/). Opened as
// /pitches?club=<club_id>; branded with that club's crest and colours.
// Club officers (and SuperUsers) get the planner: on a laptop the day board
// with a side menu, on a phone the day by pitch. Other members of the club
// get the published plan, read-only.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../v3_crest_image.dart';
import 'v3_pitch_theme.dart';
import '/v3/tracking/v3_track.dart';
import 'v3_pitch_api.dart';
import 'v3_pitch_availability.dart';
import 'v3_pitch_board.dart';
import 'v3_pitch_controller.dart';
import 'v3_pitch_mobile.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_published.dart';
import 'v3_pitch_setup.dart';
import 'v3_pitch_fixtures.dart';
import 'v3_pitch_sheets.dart';

// Fixtures first: the planner opens on it (Ken, 2026-11-16).
enum PitchTab { fixtures, board, availability, groups, setup, published }

/// The planner is a light page so the club's colours and crest sit on
/// white (Ken, 2026-11-16); the rest of v3 stays dark.
class V3PitchesPage extends StatelessWidget {
  const V3PitchesPage(
      {super.key,
      this.clubId,
      this.look,
      this.api = const PitchApi(),
      this.today});

  static String routeName = 'V3Pitches';
  static String routePath = 'pitches';

  final int? clubId;
  final PitchApi api;

  /// 'app' (black CoachSmart look) or 'club' (light, club colours). Left
  /// out: the app look when opened from inside CoachSmart (there is a page
  /// to go back to, or it is the installed app), the club look when opened
  /// straight from a link (Ken, 2026-11-18).
  final String? look;

  /// Tests pin the date.
  final DateTime? today;

  static bool appLook(BuildContext context, String? look) {
    if (look == 'app') return true;
    if (look == 'club') return false;
    if (!kIsWeb) return true;
    return Navigator.of(context).canPop();
  }

  @override
  Widget build(BuildContext context) {
    PT.dark = appLook(context, look);
    return Theme(
        data: PT.theme(PT.dark ? PT.csGreen : PT.text),
        child: _PitchesBody(clubId: clubId, api: api, today: today));
  }
}

class _PitchesBody extends StatefulWidget {
  const _PitchesBody({this.clubId, required this.api, this.today});
  final int? clubId;
  final PitchApi api;
  final DateTime? today;

  @override
  State<_PitchesBody> createState() => _V3PitchesPageState();
}

class _V3PitchesPageState extends State<_PitchesBody> {
  List<PitchClub> _officerClubs = [];
  List<PitchClub> _memberClubs = [];
  PitchClub? _club;
  bool _officer = false;
  PitchController? _c;
  PitchTab _tab = PitchTab.fixtures;
  String? _error;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _officerClubs = await widget.api.clubs();
    } catch (_) {
      _officerClubs = [];
    }
    try {
      _memberClubs = await widget.api.memberClubs();
    } catch (_) {
      _memberClubs = [];
    }
    if (!mounted) return;
    PitchClub? pick(List<PitchClub> l) {
      for (final c in l) {
        if (c.clubId == widget.clubId) return c;
      }
      return widget.clubId == null && l.isNotEmpty ? l.first : null;
    }

    final o = pick(_officerClubs);
    if (o != null) {
      _useClub(o, officer: true);
    } else {
      final m = pick(_memberClubs);
      if (m != null) {
        _club = m;
        _officer = false;
        _tab = PitchTab.published;
      } else {
        _error = widget.clubId == null
            ? 'Your club hasn\'t published a pitch plan yet.'
            : 'This pitch plan is only for members of the club.';
      }
    }
    setState(() => _loaded = true);
    V3Track.event('pitches_open', {'officer': _officer ? 1 : 0});
  }

  void _useClub(PitchClub club, {required bool officer}) {
    _c?.dispose();
    _club = club;
    _officer = officer;
    _c = PitchController(club, api: widget.api, today: widget.today)
      ..addListener(() {
        if (mounted) setState(() {});
      })
      ..load();
  }

  Future<void> _publish() async {
    final c = _c!;
    final m = c.monday;
    final yes = await showPitchSheet<bool>(
        context,
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Publish the week of ${m.day} ${kMonths[m.month - 1]}?',
                    style: PT.tight(20)),
                SizedBox(height: 6),
                Text(
                    'Club members see this week\'s pitches in the app, as it is now. '
                    'Keep moving things after; publish again to update what they see.',
                    style: PT.inter(15, color: PT.muted)),
                SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: PitchButton('Not yet',
                          onTap: () => Navigator.pop(context, false))),
                  SizedBox(width: 8),
                  Expanded(
                      child: PitchButton('Publish',
                          accent: c.club.accent,
                          onTap: () => Navigator.pop(context, true))),
                ]),
              ]),
        ));
    if (yes != true) return;
    final err = await c.publish();
    if (!mounted) return;
    pitchSnack(context, err ?? 'Published. Members can see the week now.');
    if (err == null) V3Track.event('pitches_published');
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kWide;
    if (!_loaded) {
      return Scaffold(
          backgroundColor: PT.bg,
          body: Center(child: CircularProgressIndicator(color: PT.muted)));
    }
    final club = _club;
    if (club == null) {
      return Scaffold(
        backgroundColor: PT.bg,
        appBar: AppBar(backgroundColor: PT.bg, foregroundColor: PT.text),
        body: Center(
            child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(_error ?? 'Nothing to show.',
              textAlign: TextAlign.center,
              style: PT.inter(16, color: PT.muted)),
        )),
      );
    }
    final content = _content(club, wide);
    if (wide) {
      return Scaffold(
        backgroundColor: PT.bg,
        body: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Side(
                club: club,
                officer: _officer,
                tab: _tab,
                changes: _c?.unreadChanges ?? 0,
                clubs: _officerClubs,
                onTab: (t) => setState(() => _tab = t),
                onClub: (c) => setState(() {
                      _useClub(c, officer: true);
                      _tab = PitchTab.fixtures;
                    })),
            Expanded(child: content),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: PT.bg,
      appBar: AppBar(
        backgroundColor: club.band,
        foregroundColor: onAccent(club.band),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(children: [
          V3CrestImage(club.crest, size: 30),
          SizedBox(width: 10),
          Expanded(
            child: Text(_officer ? 'Pitches' : '${club.name} pitches',
                overflow: TextOverflow.ellipsis,
                style: PT.tight(20, color: onAccent(club.band))),
          ),
        ]),
        actions: [
          if (_officer && _tab == PitchTab.board && _c?.board != null) ...[
            IconButton(
                tooltip: 'New booking',
                onPressed: () => showPitchSheet(context,
                    BookingSheet(c: _c!, at: atMinutes(_c!.day, 18 * 60))),
                icon: Icon(Icons.add, color: onAccent(club.band))),
            IconButton(
                tooltip: 'Close a pitch',
                onPressed: () =>
                    showPitchSheet(context, ClosePitchSheet(c: _c!)),
                icon: Icon(Icons.block, color: onAccent(club.band))),
            IconButton(
                tooltip: 'Publish week',
                onPressed: _publish,
                icon: Icon(Icons.campaign_outlined,
                    color: _c!.board!.changedSincePublish
                        ? PT.amber
                        : onAccent(club.band))),
          ]
        ],
      ),
      body: content,
      // Phone: three tabs only (Ken, 2026-11-18); set-up stays on the
      // laptop version.
      bottomNavigationBar: _officer
          ? NavigationBar(
              backgroundColor: PT.tabBar,
              indicatorColor: club.accent.withValues(alpha: 0.2),
              selectedIndex: _phoneTabs.indexOf(_tab).clamp(0, 2),
              onDestinationSelected: (i) =>
                  setState(() => _tab = _phoneTabs[i]),
              labelTextStyle: WidgetStatePropertyAll(PT.inter(12)),
              destinations: [
                  NavigationDestination(
                      icon: Icon(Icons.checklist, color: PT.muted),
                      selectedIcon: Icon(Icons.checklist, color: club.accent),
                      label: 'To do'),
                  NavigationDestination(
                      icon: Icon(Icons.view_week_outlined, color: PT.muted),
                      selectedIcon:
                          Icon(Icons.view_week_outlined, color: club.accent),
                      label: 'Day'),
                  NavigationDestination(
                      icon: Icon(Icons.visibility_outlined, color: PT.muted),
                      selectedIcon:
                          Icon(Icons.visibility_outlined, color: club.accent),
                      label: 'Published'),
                ])
          : null,
    );
  }

  static const _phoneTabs = [
    PitchTab.fixtures,
    PitchTab.board,
    PitchTab.published
  ];

  Widget _content(PitchClub club, bool wide) {
    if (!_officer || _tab == PitchTab.published) {
      return PitchPublishedView(
          club: club,
          api: widget.api,
          today: widget.today,
          padding: wide ? const EdgeInsets.fromLTRB(24, 20, 24, 20) : null);
    }
    final c = _c!;
    if (c.board == null) {
      return Center(
          child: c.error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(c.error!,
                      textAlign: TextAlign.center,
                      style: PT.inter(15, color: PT.muted)))
              : CircularProgressIndicator(color: PT.muted));
    }
    final body = switch (_tab) {
      PitchTab.board => wide ? PitchDayBoard(c: c) : PitchPhoneDay(c: c),
      PitchTab.fixtures => wide
          ? PitchFixturesView(c: c)
          : PitchFixturesView(c: c, todo: true, onPublish: _publish),
      PitchTab.availability => PitchAvailabilityView(c: c),
      PitchTab.groups => PitchGroupsView(c: c),
      PitchTab.setup => PitchSetupView(c: c),
      PitchTab.published => const SizedBox.shrink(),
    };
    if (!wide) {
      return Stack(children: [
        Positioned.fill(child: body),
        if (c.busy || c.loading)
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2, color: PT.muted)),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(c),
        if (c.busy || c.loading)
          LinearProgressIndicator(minHeight: 2, color: PT.muted)
        else
          const SizedBox(height: 2),
        const SizedBox(height: 12),
        Expanded(child: body),
      ]),
    );
  }

  Widget _header(PitchController c) {
    final board = c.board!;
    final accent = c.club.accent;
    if (_tab != PitchTab.board) {
      return Row(children: [
        Text(
            switch (_tab) {
              PitchTab.groups => 'Groups',
              PitchTab.fixtures => 'Fixtures',
              PitchTab.availability => 'Availability',
              _ => 'Pitches and venues'
            },
            style: PT.tight(26)),
        const Spacer(),
      ]);
    }
    final n = board.bookingsOn(c.day).where((b) => b.confirmed).length;
    final pub = board.publishedAt;
    final pubLabel = pub == null
        ? 'Publish week'
        : board.changedSincePublish
            ? 'Publish changes'
            : 'Published ${pub.day}/${pub.month} ${timeOf(pub)}';
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(longDay(c.day), style: PT.tight(26)),
          Text(
              [
                '${board.pitches.length} pitch${board.pitches.length == 1 ? '' : 'es'}',
                '$n booking${n == 1 ? '' : 's'}',
                if (c.rolledNote != null) c.rolledNote!,
              ].join(' · '),
              style: PT.inter(13.5, color: PT.muted)),
        ]),
      ),
      _hBtn('‹', () => c.shiftDays(-1)),
      const SizedBox(width: 6),
      _hBtn('Today', () => c.pickDay(c.today)),
      const SizedBox(width: 6),
      _hBtn('›', () => c.shiftDays(1)),
      const SizedBox(width: 6),
      _hBtn('Pick a date', () async {
        final d = await showDatePicker(
            context: context,
            initialDate: c.day,
            firstDate: DateTime(c.day.year - 1),
            lastDate: DateTime(c.day.year + 2));
        if (d != null) c.pickDay(d);
      }),
      const SizedBox(width: 14),
      _hBtn(
          '+ New booking',
          () => showPitchSheet(
              context, BookingSheet(c: c, at: atMinutes(c.day, 18 * 60)))),
      const SizedBox(width: 8),
      _hBtn('Close a pitch',
          () => showPitchSheet(context, ClosePitchSheet(c: c))),
      const SizedBox(width: 8),
      if (pub == null || board.changedSincePublish)
        SizedBox(
          width: 190,
          child: PitchButton(pubLabel,
              compact: true, accent: accent, onTap: c.busy ? null : _publish),
        )
      else
        // Published and unchanged: say when, and keep a clear button to
        // send it again (Ken, 2026-11-17).
        Tooltip(
          message: pubLabel,
          child: OutlinedButton.icon(
            onPressed: c.busy ? null : _publish,
            style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent, width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Republish',
                      style:
                          PT.inter(14, weight: FontWeight.w700, color: accent)),
                  Text('✓ $pubLabel', style: PT.inter(11.5, color: PT.muted)),
                ]),
          ),
        ),
    ]);
  }

  Widget _hBtn(String label, VoidCallback onTap) => Material(
        color: PT.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
                border: Border.all(color: PT.line),
                borderRadius: BorderRadius.circular(10)),
            child: Text(label, style: PT.inter(13.5, weight: FontWeight.w600)),
          ),
        ),
      );
}

class _Side extends StatelessWidget {
  const _Side(
      {required this.club,
      required this.officer,
      required this.tab,
      required this.clubs,
      required this.onTab,
      required this.onClub,
      this.changes = 0});
  final PitchClub club;
  final bool officer;
  final PitchTab tab;
  final int changes;
  final List<PitchClub> clubs;
  final ValueChanged<PitchTab> onTab;
  final ValueChanged<PitchClub> onClub;

  @override
  Widget build(BuildContext context) {
    final accent = club.accent;
    Widget nav(PitchTab t, IconData icon, String label, {int badge = 0}) {
      final on = tab == t;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: on ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onTab(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                Icon(icon, size: 20, color: on ? accent : PT.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PT.inter(15,
                          weight: on ? FontWeight.w600 : FontWeight.w400,
                          color: on ? accent : PT.text)),
                ),
                if (badge > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: PT.red, borderRadius: BorderRadius.circular(10)),
                    child: Text('$badge',
                        style: PT.inter(12,
                            weight: FontWeight.w700, color: Colors.white)),
                  ),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
          color: PT.card, border: Border(right: BorderSide(color: PT.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back, color: PT.muted, size: 20)),
        ]),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: club.band, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            V3CrestImage(club.crest, size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PT.inter(15,
                            weight: FontWeight.w700,
                            color: onAccent(club.band))),
                    Text(officer ? 'Pitch planner' : 'Pitches',
                        style: PT.inter(12.5,
                            color: onAccent(club.band).withValues(alpha: 0.8))),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (officer) ...[
          nav(PitchTab.fixtures, Icons.sports_outlined, 'Fixtures',
              badge: changes),
          nav(PitchTab.board, Icons.view_week_outlined, 'Day board'),
          nav(PitchTab.availability, Icons.event_available_outlined,
              'Availability'),
          nav(PitchTab.groups, Icons.groups_outlined, 'Groups'),
          nav(PitchTab.setup, Icons.tune, 'Pitches and venues'),
          nav(PitchTab.published, Icons.visibility_outlined, 'Members\' view'),
        ],
        // No club picker: the ?club= link decides the club and its
        // branding (Ken, 2026-11-17).
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text('Powered by CoachSmart',
              style: PT.inter(11.5, color: PT.faint)),
        ),
      ]),
    );
  }
}
