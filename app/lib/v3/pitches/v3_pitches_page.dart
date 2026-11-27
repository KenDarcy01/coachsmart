// v3 Pitch planner page (Ken approved 2026-11-16, mock-ups in
// /mnt/project-files/coachsmart/pitch-allocation/). Opened as
// /pitches?club=<club_id>; branded with that club's crest and colours.
// Club officers (and SuperUsers) get the planner: on a laptop the day board
// with a side menu, on a phone the day by pitch. Other members of the club
// get the published plan, read-only.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../v3_crest_image.dart';
import '/v3/web/v3_club_pwa.dart';
import '/v3/web/v3_entry.dart';
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
import 'v3_pitch_insights.dart';
import 'v3_pitch_weekend.dart';
import 'v3_pitch_sheets.dart';

/// Shown in a frame on the club tools page (coachsmart.app/club/pitches.html).
bool get _inFrame => Uri.base.queryParameters['frame'] == '1';

// Fixtures first: the planner opens on it (Ken, 2026-11-16).
enum PitchTab {
  fixtures,
  board,
  weekend,
  availability,
  groups,
  insights,
  setup,
  published
}

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
    // Opened straight from a link (or the home-screen icon): the club's own
    // look. Reached from inside the app: the app look. (Router deep links
    // can always pop, so canPop() can't tell them apart.)
    if (v3EntryPath.startsWith('/pitches')) return false;
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

  /// Not signed in: the club's own sign-in screen (Ken, 2026-11-18), so a
  /// club admin with no team can use the planner as the club's app.
  bool _needSignIn = false;
  PitchClub? _brand;

  /// Club look in a browser: the tab, home-screen icon and name are the
  /// club's ("Clontarf Pitches").
  void _brandPage(PitchClub club) {
    if (PT.dark) return;
    final short = club.name
        .replaceAll(RegExp(r'\s+(GAA|CLG|GAC|LGFA|Camogie Club)$'), '')
        .trim();
    final hex =
        '#${(club.band.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    setClubPwa(name: '$short Pitches', icon: club.crest, colour: hex);
  }

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
    if (!widget.api.signedIn) {
      try {
        _brand = widget.clubId == null
            ? null
            : await widget.api.brand(widget.clubId!);
      } catch (_) {}
      if (!mounted) return;
      if (_brand != null) _brandPage(_brand!);
      setState(() {
        _needSignIn = true;
        _loaded = true;
      });
      return;
    }
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
    if (_club != null) _brandPage(_club!);
    setState(() => _loaded = true);
    V3Track.event('pitches_open', {'officer': _officer ? 1 : 0});
  }

  Future<void> _signOut() async {
    try {
      await widget.api.signOut();
    } catch (_) {}
    if (!mounted) return;
    _c?.dispose();
    setState(() {
      _c = null;
      _club = null;
      _error = null;
      _loaded = false;
    });
    _start();
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
    if (_needSignIn) {
      return PitchSignIn(
          club: _brand,
          api: widget.api,
          onSignedIn: () {
            setState(() {
              _needSignIn = false;
              _loaded = false;
            });
            _start();
          });
    }
    final club = _club;
    if (club == null) {
      return Scaffold(
        backgroundColor: PT.bg,
        appBar: AppBar(backgroundColor: PT.bg, foregroundColor: PT.text),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? 'Nothing to show.',
                textAlign: TextAlign.center,
                style: PT.inter(16, color: PT.muted)),
            const SizedBox(height: 16),
            TextButton(
                onPressed: _signOut,
                child: Text('Sign in with another account',
                    style: PT.inter(15, weight: FontWeight.w600))),
          ]),
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
          ],
          // The club's own app has no other way out (Ken, 2026-11-18).
          if (!PT.dark)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: onAccent(club.band)),
              color: PT.card,
              onSelected: (_) => _signOut(),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'out', child: Text('Sign out', style: PT.inter(15))),
              ],
            ),
        ],
      ),
      body: content,
      // Phone: three tabs only (Ken, 2026-11-18); set-up stays on the
      // laptop version.
      bottomNavigationBar: _officer
          ? NavigationBar(
              backgroundColor: PT.tabBar,
              indicatorColor: club.accent.withValues(alpha: 0.2),
              selectedIndex: _phoneTabs.indexOf(_tab).clamp(0, 3),
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
                      icon: Icon(Icons.grass, color: PT.muted),
                      selectedIcon: Icon(Icons.grass, color: club.accent),
                      label: 'Grass'),
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
    PitchTab.weekend,
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
      PitchTab.weekend => PitchWeekendView(c: c, wide: wide),
      PitchTab.insights => PitchInsightsView(c: c),
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
              PitchTab.insights => 'Insights',
              PitchTab.weekend => 'Grass',
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
        // Inside the club tools page (frame=1) its header already shows the
        // club and the way back, so no back arrow or club box here.
        if (!_inFrame) ...[
          Row(children: [
            IconButton(
                tooltip: 'Back',
                // In the club look the planner is a club admin tool: back
                // goes to the club's admin landing page, not into the app
                // (Ken 2026-11-27). Inside the app it just goes back.
                onPressed: () => PT.dark
                    ? Navigator.of(context).maybePop()
                    : launchUrl(
                        Uri.parse(
                            'https://coachsmart.app/club/?club=${club.clubId}'),
                        webOnlyWindowName: '_self'),
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
                              color:
                                  onAccent(club.band).withValues(alpha: 0.8))),
                    ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        if (officer) ...[
          nav(PitchTab.fixtures, Icons.sports_outlined, 'Fixtures',
              badge: changes),
          nav(PitchTab.board, Icons.view_week_outlined, 'Day board'),
          nav(PitchTab.weekend, Icons.grass, 'Grass'),
          nav(PitchTab.availability, Icons.event_available_outlined,
              'Availability'),
          nav(PitchTab.groups, Icons.groups_outlined, 'Groups'),
          nav(PitchTab.insights, Icons.insights_outlined, 'Insights'),
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

/// The club's own sign-in screen for the planner: crest, club colour, email
/// and password. For club admins who use the planner as the club's app.
class PitchSignIn extends StatefulWidget {
  const PitchSignIn(
      {super.key, this.club, required this.api, required this.onSignedIn});
  final PitchClub? club;
  final PitchApi api;
  final VoidCallback onSignedIn;
  @override
  State<PitchSignIn> createState() => _PitchSignInState();
}

class _PitchSignInState extends State<PitchSignIn> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _msg;

  Future<void> _go() async {
    if (_email.text.trim().isEmpty || _pw.text.isEmpty) {
      return setState(() => _msg = 'Enter your email and password.');
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final err = await widget.api.signIn(_email.text, _pw.text);
    if (!mounted) return;
    if (err != null) {
      return setState(() {
        _busy = false;
        _msg = err;
      });
    }
    widget.onSignedIn();
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      return setState(
          () => _msg = 'Enter your email first, then tap Forgot password.');
    }
    final err = await widget.api.sendReset(_email.text);
    if (!mounted) return;
    setState(() =>
        _msg = err ?? 'We\'ve emailed you a link to choose a new password.');
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;
    final band = club?.band ?? PT.text;
    final accent = club?.accent ?? PT.csGreen;
    return Scaffold(
      backgroundColor: PT.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                        decoration: BoxDecoration(
                            color: band,
                            borderRadius: BorderRadius.circular(18)),
                        child: Column(children: [
                          if (club != null && club.crest.isNotEmpty)
                            V3CrestImage(club.crest, size: 72),
                          const SizedBox(height: 10),
                          Text(club?.name ?? 'CoachSmart',
                              textAlign: TextAlign.center,
                              style: PT.tight(22, color: onAccent(band))),
                          Text('Pitch planner',
                              style: PT.inter(15,
                                  color:
                                      onAccent(band).withValues(alpha: 0.85))),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          style: PT.inter(16),
                          decoration: pitchInput('Email')),
                      const SizedBox(height: 10),
                      TextField(
                          controller: _pw,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _go(),
                          style: PT.inter(16),
                          decoration: pitchInput('Password')),
                      const SizedBox(height: 14),
                      PitchButton(_busy ? 'Signing in…' : 'Sign in',
                          accent: accent, onTap: _busy ? null : _go),
                      if (_msg != null) ...[
                        const SizedBox(height: 10),
                        Text(_msg!,
                            textAlign: TextAlign.center,
                            style: PT.inter(14, color: PT.muted)),
                      ],
                      const SizedBox(height: 6),
                      TextButton(
                          onPressed: _busy ? null : _reset,
                          child: Text('Forgot password?',
                              style: PT.inter(14, color: PT.muted))),
                      const SizedBox(height: 18),
                      Text('Powered by CoachSmart',
                          textAlign: TextAlign.center,
                          style: PT.inter(12, color: PT.faint)),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
