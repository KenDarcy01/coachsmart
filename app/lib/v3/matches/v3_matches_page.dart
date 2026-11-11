// v3 Matches: every match in the user's clubs today, live now, results from
// the last 12 hours and matches they follow. Native copy of
// webviews/matches.html (the old app keeps the web page). A row per squad
// when an event has more than one squad playing. Tap a row for the live
// page; tap a bell to follow.
import 'dart:async';

import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_live_shared.dart';
import 'v3_match_live_page.dart';
import 'v3_matches_models.dart';

class V3MatchesPage extends StatefulWidget {
  const V3MatchesPage({super.key, this.testData, this.testNow});

  /// Widget tests pass the get_live_matches result here instead of calling
  /// Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  /// Widget tests fix "now" (server time).
  @visibleForTesting
  final DateTime? testNow;

  @override
  State<V3MatchesPage> createState() => _V3MatchesPageState();
}

class _V3MatchesPageState extends State<V3MatchesPage> {
  LiveMatchesData? _data;
  bool _failed = false;
  String? _tab; // live | today | following
  LivePulse? _pulse;
  Timer? _tick;

  bool get _test => widget.testData != null;

  /// Server time now.
  DateTime get _now =>
      widget.testNow ?? DateTime.now().subtract(_data?.skew ?? Duration.zero);

  @override
  void initState() {
    super.initState();
    if (_test) {
      _data =
          LiveMatchesData.fromJson(widget.testData!, phoneNow: widget.testNow);
      return;
    }
    _pulse = LivePulse(
        onChange: _load,
        fast: const Duration(seconds: 15),
        slow: const Duration(seconds: 30));
    _pulse!.subscribe(const []);
    _pulse!.refresh();
    // Keep the live minutes ticking
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          _tab == 'live' &&
          (_data?.matches.any((m) => m.phase == 'play') ?? false)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await SupaFlow.client.rpc('get_live_matches');
      final d = LiveMatchesData.fromJson(r is Map ? r : const {});
      if (!mounted) return;
      setState(() {
        _data = d;
        _failed = false;
      });
      _pulse?.subscribe(d.eventIds);
    } catch (_) {
      if (mounted && _data == null) setState(() => _failed = true);
    }
  }

  Future<void> _refresh() async {
    if (_test) return;
    await _load();
  }

  Future<void> _bell(LiveMatchRow m) async {
    await liveBell(context,
        eventId: m.eventId,
        sub: '${m.teamName} v ${m.opp}',
        follow: m.follow, onChange: (f, msg) {
      if (!mounted) return;
      setState(() => _data?.setFollow(m.eventId, f));
      liveSnack(context, msg);
    }, onError: () {
      if (mounted) {
        liveSnack(context, "Couldn't save. Check your signal.", warn: true);
      }
    });
  }

  Future<void> _open(LiveMatchRow m) async {
    await Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3MatchLivePage'),
        builder: (_) =>
            V3MatchLivePage(eventId: m.eventId, squad: m.squadKey)));
    if (mounted && !_test) _pulse?.refresh(); // follows changed there
  }

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
            tooltip: 'Back',
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 34),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Matches', style: V3.tight(18, weight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: V3.green,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: _body(),
        ),
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
        child: Text(text,
            textAlign: TextAlign.center,
            style: V3.inter(16, color: V3.muted, height: 1.5)),
      );

  List<Widget> _body() {
    final d = _data;
    if (d == null) {
      return [
        _failed
            ? _empty("Couldn't load matches.\nCheck your signal and try again.")
            : const Padding(
                padding: EdgeInsets.only(top: 80),
                child:
                    Center(child: CircularProgressIndicator(color: V3.green)))
      ];
    }
    if (d.hasError) return [_empty('Please sign in again.')];
    final now = _now;
    final live = d.live;
    final today = d.today(now);
    final fol = d.following;
    final results = d.results;
    _tab ??= live.isNotEmpty || results.isNotEmpty ? 'live' : 'today';

    final out = <Widget>[_tabs(live.length)];
    Widget section(String title, List<LiveMatchRow> list) => list.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 0),
                child: Text(title,
                    style: V3.inter(14,
                        weight: FontWeight.w600, color: V3.muted))),
            _card(list, now),
          ]);
    if (_tab == 'live') {
      out.add(live.isNotEmpty
          ? _card(live, now)
          : _empty('No matches live right now.'));
      out.add(section(
          'Coming up today', today.where((m) => m.phase == 'pre').toList()));
      out.add(section('Results', results));
    } else if (_tab == 'today') {
      out.add(today.isNotEmpty
          ? _card(today, now)
          : _empty('No matches in your club today.'));
    } else {
      out.add(fol.isNotEmpty
          ? _card(fol, now)
          : _empty(
              "You're not following any upcoming matches.\nTap a bell to follow one."));
      out.add(section('Results', results.where((m) => m.follow.on).toList()));
    }
    out.add(Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
      child: Text(
          'Tap a bell to follow a match and get every score. Tap a green bell to change to half and full time only, or stop.',
          style: V3.inter(14, color: V3.muted, height: 1.45)),
    ));
    return out;
  }

  Widget _tabs(int liveCount) {
    Widget seg(String key, String label) {
      final on = _tab == key;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tab = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: on ? V3.card2 : Colors.transparent,
                borderRadius: BorderRadius.circular(10)),
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(15,
                    weight: FontWeight.w600, color: on ? V3.text : V3.muted)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        seg('live', 'Live now${liveCount > 0 ? ' · $liveCount' : ''}'),
        seg('today', 'Today'),
        seg('following', 'Following'),
      ]),
    );
  }

  Widget _card(List<LiveMatchRow> list, DateTime now) => Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < list.length; i++)
            _row(list[i], now, last: i == list.length - 1),
        ]),
      );

  Widget _row(LiveMatchRow m, DateTime now, {required bool last}) {
    Widget? pill;
    if (m.phase == 'play') {
      pill = PhasePill(
          'live', 'LIVE ${(m.timer ?? const LiveTimer()).minuteOf(now)}',
          size: 11);
    } else if (m.phase == 'ht') {
      pill = const PhasePill('ht', 'HALF TIME', size: 11);
    } else if (m.done) {
      pill = const PhasePill('ft', 'FULL TIME', size: 11);
    }
    final place = m.place;
    final sub = m.started
        ? Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
                if (pill != null) pill,
                if (place.isNotEmpty)
                  Text(place, style: V3.inter(14, color: V3.muted)),
              ])
        : Text(
            'Throw-in ${clockTime(m.eventDateTime)}${place.isNotEmpty ? ' · $place' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: V3.inter(14, color: V3.muted));
    final right = m.started && m.score != null
        ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(m.score!.us.gaa, style: scoreStyle(24)),
            Text('v ${m.score!.opp.gaa}', style: V3.inter(13, color: V3.muted)),
          ])
        : Text(m.eventDateTime == null ? '' : untilLabel(m.eventDateTime!, now),
            style: V3.inter(15, weight: FontWeight.w600, color: V3.muted));
    return InkWell(
      onTap: () => _open(m),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        decoration: BoxDecoration(
            border:
                last ? null : const Border(bottom: BorderSide(color: V3.line))),
        child: Row(children: [
          LiveBellButton(on: m.follow.on, onTap: () => _bell(m)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (m.multi) ...[
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: m.colour,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24))),
                  const SizedBox(width: 6),
                ],
                Expanded(
                    child: Text(m.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(16, weight: FontWeight.w600))),
              ]),
              const SizedBox(height: 4),
              sub,
            ]),
          ),
          const SizedBox(width: 10),
          right,
        ]),
      ),
    );
  }
}
