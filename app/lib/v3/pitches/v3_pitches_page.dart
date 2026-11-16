// v3 Pitch planner page (Ken approved 2026-11-16, mock-ups in
// /mnt/project-files/coachsmart/pitch-allocation/). Opened as
// /pitches?club=<club_id>; branded with that club's crest and colours.
// Club officers (and SuperUsers) get the planner: on a laptop the day board
// with a side menu, on a phone the day by pitch. Other members of the club
// get the published plan, read-only.
import 'package:flutter/material.dart';

import '../v3_crest_image.dart';
import '../v3_theme.dart';
import '/v3/tracking/v3_track.dart';
import 'v3_pitch_api.dart';
import 'v3_pitch_board.dart';
import 'v3_pitch_controller.dart';
import 'v3_pitch_mobile.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_published.dart';
import 'v3_pitch_setup.dart';
import 'v3_pitch_sheets.dart';

enum PitchTab { board, groups, setup, published }

class V3PitchesPage extends StatefulWidget {
  const V3PitchesPage(
      {super.key, this.clubId, this.api = const PitchApi(), this.today});

  static String routeName = 'V3Pitches';
  static String routePath = 'pitches';

  final int? clubId;
  final PitchApi api;

  /// Tests pin the date.
  final DateTime? today;

  @override
  State<V3PitchesPage> createState() => _V3PitchesPageState();
}

class _V3PitchesPageState extends State<V3PitchesPage> {
  List<PitchClub> _officerClubs = [];
  List<PitchClub> _memberClubs = [];
  PitchClub? _club;
  bool _officer = false;
  PitchController? _c;
  PitchTab _tab = PitchTab.board;
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
                    style: V3.tight(20)),
                const SizedBox(height: 6),
                Text(
                    'Club members see this week\'s pitches in the app, as it is now. '
                    'Keep moving things after; publish again to update what they see.',
                    style: V3.inter(15, color: V3.muted)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: PitchButton('Not yet',
                          onTap: () => Navigator.pop(context, false))),
                  const SizedBox(width: 8),
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
      return const Scaffold(
          backgroundColor: V3.bg,
          body: Center(child: CircularProgressIndicator(color: V3.muted)));
    }
    final club = _club;
    if (club == null) {
      return Scaffold(
        backgroundColor: V3.bg,
        appBar: AppBar(backgroundColor: V3.bg, foregroundColor: V3.text),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error ?? 'Nothing to show.',
              textAlign: TextAlign.center,
              style: V3.inter(16, color: V3.muted)),
        )),
      );
    }
    final content = _content(club, wide);
    if (wide) {
      return Scaffold(
        backgroundColor: V3.bg,
        body: SafeArea(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Side(
                club: club,
                officer: _officer,
                tab: _tab,
                clubs: _officerClubs,
                onTab: (t) => setState(() => _tab = t),
                onClub: (c) => setState(() {
                      _useClub(c, officer: true);
                      _tab = PitchTab.board;
                    })),
            Expanded(child: content),
          ]),
        ),
      );
    }
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: Color.lerp(club.band, V3.bg, 0.35),
        foregroundColor: V3.text,
        titleSpacing: 0,
        title: Row(children: [
          V3CrestImage(club.crest, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_officer ? 'Pitches' : '${club.name} pitches',
                overflow: TextOverflow.ellipsis, style: V3.tight(20)),
          ),
        ]),
        actions: [
          if (_officer && _tab == PitchTab.board && _c?.board != null) ...[
            IconButton(
                tooltip: 'Close a pitch',
                onPressed: () =>
                    showPitchSheet(context, ClosePitchSheet(c: _c!)),
                icon: const Icon(Icons.block, color: V3.text)),
            IconButton(
                tooltip: 'Publish week',
                onPressed: _publish,
                icon: Icon(Icons.campaign_outlined,
                    color: _c!.board!.changedSincePublish
                        ? club.accent
                        : V3.text)),
          ]
        ],
      ),
      body: content,
      bottomNavigationBar: _officer
          ? NavigationBar(
              backgroundColor: V3.tabBar,
              indicatorColor: club.accent.withValues(alpha: 0.2),
              selectedIndex: _tab.index,
              onDestinationSelected: (i) =>
                  setState(() => _tab = PitchTab.values[i]),
              labelTextStyle: WidgetStatePropertyAll(V3.inter(12)),
              destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.view_week_outlined, color: V3.muted),
                      label: 'Day'),
                  NavigationDestination(
                      icon: Icon(Icons.groups_outlined, color: V3.muted),
                      label: 'Groups'),
                  NavigationDestination(
                      icon: Icon(Icons.tune, color: V3.muted), label: 'Setup'),
                  NavigationDestination(
                      icon: Icon(Icons.visibility_outlined, color: V3.muted),
                      label: 'Published'),
                ])
          : null,
    );
  }

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
                      style: V3.inter(15, color: V3.muted)))
              : const CircularProgressIndicator(color: V3.muted));
    }
    final body = switch (_tab) {
      PitchTab.board => wide ? PitchDayBoard(c: c) : PitchPhoneDay(c: c),
      PitchTab.groups => PitchGroupsView(c: c),
      PitchTab.setup => PitchSetupView(c: c),
      PitchTab.published => const SizedBox.shrink(),
    };
    if (!wide) {
      return Stack(children: [
        Positioned.fill(child: body),
        if (c.busy || c.loading)
          const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2, color: V3.muted)),
      ]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(c),
        if (c.busy || c.loading)
          const LinearProgressIndicator(minHeight: 2, color: V3.muted)
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
        Text(_tab == PitchTab.groups ? 'Groups' : 'Pitches and venues',
            style: V3.tight(26)),
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
          Text(longDay(c.day), style: V3.tight(26)),
          Text(
              [
                '${board.pitches.length} pitch${board.pitches.length == 1 ? '' : 'es'}',
                '$n booking${n == 1 ? '' : 's'}',
                if (c.rolledNote != null) c.rolledNote!,
              ].join(' · '),
              style: V3.inter(13.5, color: V3.muted)),
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
      _hBtn('Close a pitch',
          () => showPitchSheet(context, ClosePitchSheet(c: c))),
      const SizedBox(width: 8),
      SizedBox(
        width: 190,
        child: PitchButton(pubLabel,
            compact: true,
            accent: pub == null || board.changedSincePublish ? accent : null,
            onTap: c.busy ? null : _publish),
      ),
    ]);
  }

  Widget _hBtn(String label, VoidCallback onTap) => Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
                border: Border.all(color: V3.line),
                borderRadius: BorderRadius.circular(10)),
            child: Text(label, style: V3.inter(13.5, weight: FontWeight.w600)),
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
      required this.onClub});
  final PitchClub club;
  final bool officer;
  final PitchTab tab;
  final List<PitchClub> clubs;
  final ValueChanged<PitchTab> onTab;
  final ValueChanged<PitchClub> onClub;

  @override
  Widget build(BuildContext context) {
    final accent = club.accent;
    Widget nav(PitchTab t, IconData icon, String label) {
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
                Icon(icon, size: 20, color: on ? accent : V3.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V3.inter(15,
                          weight: on ? FontWeight.w600 : FontWeight.w400,
                          color: on ? accent : V3.text)),
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
      decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: V3.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: V3.muted, size: 20)),
        ]),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [club.band, V3.bg]),
              borderRadius: BorderRadius.circular(12)),
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
                        style: V3.inter(15, weight: FontWeight.w700)),
                    Text(officer ? 'Pitch planner' : 'Pitches',
                        style: V3.inter(12.5, color: const Color(0xFFD6D9DE))),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (officer) ...[
          nav(PitchTab.board, Icons.view_week_outlined, 'Day board'),
          nav(PitchTab.groups, Icons.groups_outlined, 'Groups'),
          nav(PitchTab.setup, Icons.tune, 'Pitches and venues'),
          nav(PitchTab.published, Icons.visibility_outlined, 'Members\' view'),
        ],
        if (clubs.length > 1) ...[
          const SizedBox(height: 14),
          Text('Club', style: V3.inter(12, color: V3.muted)),
          for (final c in clubs)
            if (c.clubId != club.clubId)
              TextButton(
                  onPressed: () => onClub(c),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(c.name, style: V3.inter(14)))),
        ],
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text('Powered by CoachSmart',
              style: V3.inter(11.5, color: const Color(0xFF6B6F76))),
        ),
      ]),
    );
  }
}
