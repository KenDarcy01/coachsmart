// v3 live match: the clock, score, last score, who's ahead chart, stats and
// timeline for one match, updating by itself. Native copy of
// webviews/match-live.html (the old app and share links keep the web page).
//
// When more than one squad plays under one event it opens on Both (a card
// per squad with its own venue, time, opposition and live score or
// countdown) with a tab per squad for the full live view; swipe or tap to
// flick between them. A single match looks as before.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_live_shared.dart';
import 'v3_match_charts.dart';
import 'v3_matches_models.dart';

class V3MatchLivePage extends StatefulWidget {
  const V3MatchLivePage(
      {super.key,
      required this.eventId,
      this.squad,
      this.testData,
      this.testBySquad,
      this.testNow});

  final int eventId;

  /// Squad (group key) to open on; null opens on Both when several squads
  /// play, else the one match.
  final int? squad;

  /// Widget tests pass the get_live_match_v2 result here instead of calling
  /// Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  /// Widget tests: the result for a picked squad.
  @visibleForTesting
  final Map<int, Map<String, dynamic>>? testBySquad;

  /// Widget tests fix "now" (server time).
  @visibleForTesting
  final DateTime? testNow;

  @override
  State<V3MatchLivePage> createState() => _V3MatchLivePageState();
}

class _V3MatchLivePageState extends State<V3MatchLivePage> {
  LiveMatchData? _data;
  int _failures = 0;
  late int? _view = widget.squad; // null until the first load, kBoth, a key
  String? _tab; // live | stats | timeline (null = pick for the phase)
  Set<int>? _seen; // action ids already shown, so new scores can flash
  int? _flashId;
  DateTime _flashUntil = DateTime.fromMillisecondsSinceEpoch(0);
  int _loadSeq = 0;
  bool _switching = false;
  bool _awake = false;
  LivePulse? _pulse;
  Timer? _tick;
  final _scroll = ScrollController();

  bool get _test => widget.testData != null;
  DateTime get _now =>
      widget.testNow ?? DateTime.now().subtract(_data?.skew ?? Duration.zero);
  bool get _both => (_data?.multi ?? false) && _view == kBoth;

  @override
  void initState() {
    super.initState();
    if (!_test) {
      _pulse = LivePulse(onChange: _load);
      _pulse!.subscribe([widget.eventId]);
    }
    _load();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pulse?.dispose();
    _scroll.dispose();
    if (_awake && !_test) {
      WakelockPlus.disable().catchError((_) {});
    }
    super.dispose();
  }

  void _onTick() {
    final d = _data;
    if (!mounted || d == null || d.hasError) return;
    var redraw = false;
    if (_flashId != null && DateTime.now().isAfter(_flashUntil)) {
      _flashId = null;
      redraw = true;
    }
    if (_both) {
      // countdowns and live minutes on the cards
      redraw = redraw ||
          DateTime.now().second % 15 == 0 ||
          d.squads.any((x) => x.phase == 'pre');
    } else if (d.phase == 'play' || d.phase == 'pre') {
      redraw = true;
    }
    if (redraw) setState(() {});
  }

  Future<void> _load() async {
    final seq = ++_loadSeq;
    final want = _view == kBoth ? null : _view;
    try {
      Map r;
      if (_test) {
        r = (want == null ? null : widget.testBySquad?[want]) ??
            widget.testData!;
      } else {
        final x = await SupaFlow.client.rpc('get_live_match_v2',
            params: {'p_event_id': widget.eventId, 'p_squad': want});
        r = x is Map ? x : const {};
      }
      if (seq != _loadSeq || !mounted) return; // the squad changed meanwhile
      final d = LiveMatchData.fromJson(r);
      final first = _data == null;
      final wasDone = _data?.done ?? false;
      setState(() {
        _failures = 0;
        _switching = false;
        _view = d.nextView(_view);
        // At full time the stats are what people want
        if (!first && !wasDone && d.done) _tab = 'stats';
        _noteNewScores(d, first);
        _data = d;
      });
      _keepAwake();
    } catch (_) {
      if (seq != _loadSeq || !mounted) return;
      setState(() {
        _failures++;
        _switching = false;
      });
    }
  }

  void _noteNewScores(LiveMatchData d, bool first) {
    if (d.hasError) return;
    final ids = {for (final a in d.actions) a.id};
    if (_seen != null && !first) {
      final fresh =
          d.actions.where((a) => !_seen!.contains(a.id) && d.scoring(a));
      if (fresh.isNotEmpty) {
        _flashId = fresh.last.id;
        _flashUntil = DateTime.now().add(const Duration(seconds: 25));
        if (!_test) HapticFeedback.mediumImpact();
      }
    }
    _seen = ids;
  }

  /// Keep the screen on while the match is being played.
  void _keepAwake() {
    final d = _data;
    if (d == null || d.hasError || _test) return;
    final on = _both
        ? d.squads.any((x) => isLivePhase(x.phase))
        : isLivePhase(d.phase);
    if (on == _awake) return;
    _awake = on;
    WakelockPlus.toggle(enable: on).catchError((_) {});
  }

  void _pick(int v) {
    if (v == _view) return;
    final d = _data;
    setState(() {
      _view = v;
      _tab = null;
      _seen = null;
      _flashId = null;
      // Not loaded yet: show the tab as picked and a short wait
      _switching = v != kBoth && d?.squad != null && d!.squad!.key != v;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  void _swipe(DragEndDetails e) {
    final d = _data;
    final v = e.primaryVelocity ?? 0;
    if (d == null || !d.multi || v.abs() < 300) return;
    final order = [kBoth, ...d.squads.map((q) => q.key)];
    final i = order.indexOf(_view ?? kBoth), j = i + (v < 0 ? 1 : -1);
    if (i >= 0 && j >= 0 && j < order.length) _pick(order[j]);
  }

  Future<void> _alerts() async {
    final d = _data;
    if (d == null || d.hasError) return;
    await liveBell(context,
        eventId: d.event.eventId,
        sub: '${d.event.teamName} v ${d.oppName}',
        follow: d.follow, onChange: (f, msg) {
      if (!mounted) return;
      setState(() => d.follow = f);
      liveSnack(context, msg);
    }, onError: () {
      if (mounted) {
        liveSnack(context, "Couldn't save. Check your signal.", warn: true);
      }
    });
  }

  Future<void> _share() async {
    final d = _data;
    if (d == null || d.hasError) return;
    String url;
    try {
      final tok = await SupaFlow.client
          .rpc('get_live_share_link', params: {'p_event_id': d.event.eventId});
      // Always the coachsmart.app address, so anyone can open it
      url = LiveMatchData.shareUrl('$tok', d.multi ? _view : null);
    } catch (_) {
      if (mounted) {
        liveSnack(context, "Couldn't make a link. Check your signal.",
            warn: true);
      }
      return;
    }
    final text = '${d.shareText(_view)} $url';
    try {
      if (kIsWeb) throw UnsupportedError('web');
      await SharePlus.instance.share(ShareParams(
          text: text, subject: '${d.event.teamName} v ${d.oppName}'));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) liveSnack(context, 'Link copied. Paste it into a message.');
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final ok = d != null && !d.hasError;
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
        title: ok && !_switching ? _status(d) : null,
        actions: [
          if (ok) ...[
            _iconBtn(
                d.follow.on
                    ? Icons.notifications_active
                    : Icons.notifications_none_rounded,
                'Alerts',
                _alerts,
                on: d.follow.on),
            const SizedBox(width: 8),
            _iconBtn(Icons.ios_share, 'Share', _share),
            const SizedBox(width: 12),
          ],
        ],
      ),
      bottomNavigationBar: ok
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: V3.card2,
                        foregroundColor: V3.text,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15))),
                    onPressed: _share,
                    icon: const Icon(Icons.ios_share, size: 20),
                    label: Text(
                        d.done && !_both ? 'Share result' : 'Share link',
                        style: V3.inter(17, weight: FontWeight.w700)),
                  ),
                ),
              ),
            )
          : null,
      body: _bodyFor(d),
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap,
          {bool on = false}) =>
      Material(
        color: on ? V3.greenTint : V3.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Tooltip(
            message: tip,
            child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon, size: 22, color: on ? V3.green : V3.muted)),
          ),
        ),
      );

  Widget _status(LiveMatchData d) {
    if (_both) {
      final n = d.squads.where((x) => isLivePhase(x.phase)).length;
      return n > 0 ? PhasePill('live', '$n LIVE') : const SizedBox.shrink();
    }
    return switch (d.phase) {
      'play' => const PhasePill('live', 'LIVE'),
      'ht' => const PhasePill('ht', 'HALF TIME'),
      'ft' || 'done' => const PhasePill('ft', 'FULL TIME'),
      _ => const PhasePill('ft', 'NOT STARTED'),
    };
  }

  Widget _message(String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text,
              textAlign: TextAlign.center,
              style: V3.inter(16, color: V3.muted, height: 1.5)),
        ),
      );

  Widget _bodyFor(LiveMatchData? d) {
    if (d == null) {
      return _failures > 0
          ? _message(
              "Couldn't load the match.\nCheck your signal and try again.")
          : const Center(child: CircularProgressIndicator(color: V3.green));
    }
    if (d.hasError) return _message(d.errorText);
    final List<Widget> children;
    if (_switching) {
      final x = d.squads.where((q) => q.key == _view);
      children = [
        Padding(
          padding: const EdgeInsets.only(top: 70),
          child: Text('Loading ${x.isEmpty ? '' : x.first.short}…',
              textAlign: TextAlign.center,
              style: V3.inter(16, color: V3.muted)),
        )
      ];
    } else if (_both) {
      children = _bothView(d);
    } else if (d.phase == 'pre') {
      children = _preView(d);
    } else {
      children = _matchView(d);
    }
    return Column(children: [
      if (d.multi) _squadStrip(d),
      Expanded(
        child: GestureDetector(
          onHorizontalDragEnd: _swipe,
          child: RefreshIndicator(
            color: V3.green,
            onRefresh: _load,
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              children: children,
            ),
          ),
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------- squads

  Widget _dot(Color c, {double size = 10}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24)));

  Widget _squadStrip(LiveMatchData d) {
    final n = d.squads.where((x) => isLivePhase(x.phase)).length;
    Widget btn(int key, Widget label, Widget small) {
      final on = _view == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? V3.card2 : V3.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: on ? V3.green : Colors.transparent, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _pick(key),
            child: Container(
              constraints: const BoxConstraints(minWidth: 92, minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [label, const SizedBox(height: 2), small]),
            ),
          ),
        ),
      );
    }

    Text small(String t, Color c) => Text(t,
        style:
            V3.inter(12, weight: FontWeight.w700, color: c, letterSpacing: .5));
    Widget mini(LiveSquad x) {
      if (x.phase == 'play') return small('● LIVE', V3.redText);
      if (x.phase == 'ht') return small('HT', V3.amberText);
      if (isDonePhase(x.phase)) return small('FT', V3.muted);
      return small(clockTime(x.throwInAt), V3.amberText);
    }

    return SizedBox(
      height: 70,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
        children: [
          btn(
              kBoth,
              Text(d.squads.length == 2 ? 'Both' : 'All',
                  style: V3.inter(16, weight: FontWeight.w700)),
              small(n > 0 ? '$n LIVE' : '${d.squads.length} matches',
                  n > 0 ? V3.redText : V3.muted)),
          for (final x in d.squads)
            btn(
                x.key,
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _dot(d.colourOf(x)),
                  const SizedBox(width: 6),
                  Text(x.short, style: V3.inter(16, weight: FontWeight.w700)),
                ]),
                mini(x)),
        ],
      ),
    );
  }

  List<Widget> _bothView(LiveMatchData d) {
    final ev = d.event;
    final day = ev.eventStart == null ? '' : dayLabel(ev.eventStart!);
    return [
      const SizedBox(height: 4),
      Text(
          '${ev.teamName}${ev.eventTitle.isNotEmpty ? ' · ${ev.eventTitle}' : ''}',
          textAlign: TextAlign.center,
          style: V3.inter(18, weight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text([if (day.isNotEmpty) day, '${d.squads.length} matches'].join(' · '),
          textAlign: TextAlign.center, style: V3.inter(14, color: V3.muted)),
      if (_failures > 0) _offline('No signal. Showing the last scores we got.'),
      for (final x in d.ordered) _squadCard(d, x),
      _followCard(d),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
        child: Text(
            'Tap a match for the full live view. Swipe left or right to flick between them.',
            textAlign: TextAlign.center,
            style: V3.inter(14, color: V3.muted, height: 1.4)),
      ),
    ];
  }

  Widget _squadCard(LiveMatchData d, LiveSquad x) {
    final now = _now;
    final us = d.usName, opp = x.opp;
    final s = x.score ?? LiveScore.zero;
    final started = x.phase != 'pre';
    final done = isDonePhase(x.phase);
    final when = started
        ? (done
            ? clockTime(x.kickedOffAt ?? x.throwInAt)
            : 'started ${clockTime(x.kickedOffAt)}')
        : '';
    final where = [if (x.venue.isNotEmpty) x.venue, if (when.isNotEmpty) when]
        .join(' · ');
    final Widget pill = switch (x.phase) {
      'play' => PhasePill(
          'live', 'LIVE ${(x.timer ?? const LiveTimer()).minuteOf(now)}',
          size: 11),
      'ht' => const PhasePill('ht', 'HALF TIME', size: 11),
      'ft' || 'done' => const PhasePill('ft', 'FULL TIME', size: 11),
      _ => PhasePill('up', 'STARTS ${clockTime(x.throwInAt)}', size: 11),
    };
    Widget body;
    if (!started) {
      final left =
          x.throwInAt == null ? Duration.zero : x.throwInAt!.difference(now);
      body = left.inSeconds > 60
          ? Column(children: [
              const SizedBox(height: 8),
              Text(untilCaps(left), style: scoreStyle(40)),
              Text('until throw-in', style: V3.inter(14, color: V3.muted)),
            ])
          : Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                  'Due to start. It goes live when the coach starts the clock.',
                  textAlign: TextAlign.center,
                  style: V3.inter(14, color: V3.muted)),
            );
    } else {
      final diff = s.diff;
      InlineSpan line;
      final bold = V3.inter(14, weight: FontWeight.w700, color: V3.green);
      final boldOpp = V3.inter(14, weight: FontWeight.w700, color: V3.redText);
      if (done) {
        line = diff == 0
            ? TextSpan(text: 'Draw', style: bold)
            : TextSpan(
                text: '${diff > 0 ? '$us won' : '$opp won'} by ${diff.abs()}',
                style: diff < 0 ? boldOpp : bold);
      } else if (x.last != null) {
        final l = x.last!;
        final what =
            l.value == 3 ? 'Goal' : (l.type.isEmpty ? 'Score' : l.type);
        final who = l.side == 'us' ? '' : ' $opp';
        final lead = diff == 0
            ? 'Level'
            : '${diff > 0 ? us : opp} lead by ${diff.abs()}';
        final mn = minuteLabelFor(
            (x.timer ?? const LiveTimer()).durationSeconds, l.half, l.second);
        line = TextSpan(children: [
          TextSpan(text: '$what$who', style: l.side == 'opp' ? boldOpp : bold),
          TextSpan(text: ' · $mn · $lead'),
        ]);
      } else {
        line = const TextSpan(text: 'No scores yet');
      }
      Widget side(String n, ScoreLine v) => Expanded(
            child: Column(children: [
              Text(n.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(12,
                      weight: FontWeight.w600,
                      color: V3.muted,
                      letterSpacing: 1)),
              Text(v.gaa, style: scoreStyle(40)),
            ]),
          );
      body = Column(children: [
        const SizedBox(height: 8),
        Row(children: [
          side(us, s.us),
          Text('v', style: scoreStyle(22, color: V3.muted)),
          side(opp, s.opp),
        ]),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: V3.card2, borderRadius: BorderRadius.circular(10)),
          child: Text.rich(line, style: V3.inter(14)),
        ),
      ]);
    }
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pick(x.key),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _dot(d.colourOf(x)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('${x.short} v $opp',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(16, weight: FontWeight.w700))),
                const SizedBox(width: 8),
                pill,
              ]),
              if (where.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    const Icon(Icons.place_outlined, size: 16, color: V3.muted),
                    const SizedBox(width: 4),
                    Expanded(
                        child:
                            Text(where, style: V3.inter(14, color: V3.muted))),
                  ]),
                ),
              body,
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(done ? 'See stats ›' : 'Open ${x.short} ›',
                      style: V3.inter(14,
                          weight: FontWeight.w700, color: V3.green)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- one match

  Widget _meta(LiveMatchData d) {
    final ev = d.event;
    String text;
    if (d.multi) {
      text =
          '${ev.teamName} ${d.squad?.short ?? ''} v ${d.oppName}${ev.locationName.isNotEmpty ? ' · ${ev.locationName}' : ''}';
    } else {
      final ha = ev.homeAway.isEmpty
          ? ''
          : ' · ${ev.homeAway[0].toUpperCase()}${ev.homeAway.substring(1).toLowerCase()}';
      text = '${ev.teamName} v ${d.oppName}$ha';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Text(text,
          textAlign: TextAlign.center, style: V3.inter(15, color: V3.muted)),
    );
  }

  Widget _board(LiveMatchData d) {
    final pre = d.phase == 'pre';
    final s = d.score ?? LiveScore.zero;
    final diff = s.diff;
    final (midText, midBg, midFg) = pre
        ? ('v', V3.card2, V3.muted)
        : diff == 0
            ? (d.done ? 'DRAW' : 'Level', V3.card2, V3.muted)
            : d.done
                ? (
                    '${diff > 0 ? 'WON' : 'LOST'} by ${diff.abs()}',
                    diff > 0 ? V3.greenTint : V3.redTint,
                    diff > 0 ? V3.green : V3.redText
                  )
                : (
                    '${diff > 0 ? '▲' : '▼'} ${diff.abs()}',
                    diff > 0 ? V3.greenTint : V3.redTint,
                    diff > 0 ? V3.green : V3.redText
                  );
    Widget side(String n, ScoreLine x) => Expanded(
          child: Column(children: [
            Text(n.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(13,
                    weight: FontWeight.w600,
                    color: V3.muted,
                    letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(pre ? '–' : x.gaa, style: scoreStyle(48)),
            if (!pre) Text('${x.t} pts', style: V3.inter(14, color: V3.muted)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        side(d.usName, s.us),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: midBg, borderRadius: BorderRadius.circular(99)),
          child: Text(midText,
              style: V3.inter(13, weight: FontWeight.w700, color: midFg)),
        ),
        side(d.oppName, s.opp),
      ]),
    );
  }

  Widget _card(Widget child, {EdgeInsets? padding}) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: child,
      );

  Widget _followCard(LiveMatchData d) {
    final on = d.follow.on;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _alerts,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              LiveBellButton(on: on, onTap: _alerts),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          on
                              ? "You're following this match"
                              : 'Follow this match',
                          style: V3.inter(17, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(on ? d.follow.label : 'Get an alert for every score',
                          style: V3.inter(14, color: V3.muted)),
                    ]),
              ),
              Text(on ? 'Change' : 'Follow',
                  style:
                      V3.inter(15, weight: FontWeight.w700, color: V3.green)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _offline(String text) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text,
            textAlign: TextAlign.center,
            style: V3.inter(14, color: V3.amberText)),
      );

  List<Widget> _preView(LiveMatchData d) {
    final at = d.event.eventDateTime;
    final left = at?.difference(_now);
    final when = at == null ? '' : whenLabel(at);
    Widget? cd;
    if (left != null) {
      cd = left > Duration.zero
          ? Column(children: [
              Text('THROW-IN IN',
                  style: V3.inter(13,
                      weight: FontWeight.w600,
                      color: V3.muted,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(countdown(left), style: scoreStyle(56)),
              const SizedBox(height: 4),
              Text(when, style: V3.inter(14, color: V3.muted)),
            ])
          : Column(children: [
              Text('Due to start',
                  style: V3.inter(17, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('$when. It goes live here when the coach starts the clock.',
                  textAlign: TextAlign.center,
                  style: V3.inter(14, color: V3.muted, height: 1.45)),
            ]);
    }
    return [
      _meta(d),
      _board(d),
      if (cd != null) _card(SizedBox(width: double.infinity, child: cd)),
      _followCard(d),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('This screen goes live by itself',
            style: V3.inter(16, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
            'When the coach starts the clock in the score keeper, the clock, score, chart and every score appear here as they happen. No need to refresh.',
            style: V3.inter(14, color: V3.muted, height: 1.45)),
      ])),
    ];
  }

  Widget _clock(LiveMatchData d) {
    if (d.phase == 'ht' || d.done) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(d.phase == 'ht' ? 'HALF TIME' : 'FULL TIME',
            textAlign: TextAlign.center,
            style: V3.inter(13,
                weight: FontWeight.w600, color: V3.muted, letterSpacing: 2)),
      );
    }
    final tm = d.timer;
    final dur = tm.durationSeconds, h = tm.currentHalf;
    final sec = tm.halfSeconds(_now);
    final inj = sec > dur, run = tm.running;
    final hn = h == 1 ? 'FIRST HALF' : 'SECOND HALF';
    final lbl = V3.inter(13,
        weight: FontWeight.w600, color: V3.muted, letterSpacing: 2);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(children: [
        Text.rich(
            TextSpan(children: [
              TextSpan(text: hn),
              if (inj)
                TextSpan(
                    text: ' · +${fmtClock(sec - dur)}',
                    style: lbl.copyWith(
                        color: V3.amber, fontWeight: FontWeight.w800))
              else if (!run)
                const TextSpan(text: ' · PAUSED'),
            ]),
            textAlign: TextAlign.center,
            style: lbl),
        Opacity(
          opacity: run ? 1 : .55,
          child: Text(fmtClock((h - 1) * dur + sec),
              style: scoreStyle(64, color: inj ? V3.amber : V3.text)),
        ),
      ]),
    );
  }

  Widget _lastScore(LiveMatchData d, MatchModel m) {
    final acts = d.scoringActions;
    Widget box(String letter, Color bg, Color fg) => Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Text(letter, style: scoreStyle(24, color: fg)),
        );
    if (acts.isEmpty) {
      return _card(
          padding: const EdgeInsets.all(12),
          Row(children: [
            box('–', V3.card2, V3.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('No scores yet',
                        style: V3.inter(16, weight: FontWeight.w700)),
                    Text('They appear here as they happen',
                        style: V3.inter(14, color: V3.muted)),
                  ]),
            ),
          ]));
    }
    final a = acts.last;
    final t = d.typeOf(a.type);
    final isNew = a.id == _flashId && DateTime.now().isBefore(_flashUntil);
    final opp = a.side == 'opp';
    final who = !opp ? (a.member.isNotEmpty ? a.member : d.usName) : d.oppName;
    final s = d.score ?? LiveScore.zero;
    final diff = s.diff;
    final lead = diff == 0
        ? 'Level'
        : '${diff > 0 ? d.usName : d.oppName} lead by ${diff.abs()}';
    final letter = t?.value == 3 ? 'G' : (t?.value == 2 ? '2' : 'P');
    final c = opp ? V3.red : V3.green;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: V3.card,
        gradient: isNew
            ? LinearGradient(
                colors: [c.withValues(alpha: .28), c.withValues(alpha: .06)])
            : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isNew ? c.withValues(alpha: .45) : V3.line, width: 1),
      ),
      child: Row(children: [
        box(letter, c, opp ? Colors.white : V3.bg),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${t?.value == 3 ? 'GOAL' : ((t?.name.isNotEmpty ?? false) ? t!.name : 'Score')} · $who',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(16, weight: FontWeight.w700)),
            Text(
                '${m.minuteLabel(a.half, a.second)}${isNew ? ' · just now' : ''} · $lead',
                style: V3.inter(14, color: V3.muted)),
          ]),
        ),
      ]),
    );
  }

  Widget _recent(LiveMatchData d, MatchModel m) {
    final runs = m.walk().where((r) => !r.e.correction).toList();
    if (runs.isEmpty) return const SizedBox.shrink();
    final rows = runs.reversed.take(5).toList();
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      Column(children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: V3.line))),
            child: Row(children: [
              SizedBox(
                  width: 50,
                  child: Text(m.minuteLabel(rows[i].e.half, rows[i].e.second),
                      style: V3.inter(14,
                          weight: FontWeight.w700, color: V3.muted))),
              Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: rows[i].e.side == 'opp' ? V3.red : V3.green,
                      shape: BoxShape.circle)),
              Expanded(
                child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: rows[i].e.name),
                      if (rows[i].e.side == 'us' && rows[i].e.member.isNotEmpty)
                        TextSpan(
                            text: '  ${rows[i].e.member}',
                            style: V3.inter(14, color: V3.muted))
                      else if (rows[i].e.side == 'opp')
                        TextSpan(
                            text: '  ${d.oppName}',
                            style: V3.inter(14, color: V3.muted)),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(16)),
              ),
              Text('${rows[i].us.gaa} · ${rows[i].opp.gaa}',
                  style: scoreStyle(19)),
            ]),
          ),
      ]),
    );
  }

  Widget _tabs() {
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
                style: V3.inter(15,
                    weight: FontWeight.w600, color: on ? V3.text : V3.muted)),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(13)),
      child: Row(children: [
        seg('live', 'Live'),
        seg('stats', 'Stats'),
        seg('timeline', 'Timeline'),
      ]),
    );
  }

  Widget _note(String text) => _card(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            textAlign: TextAlign.center, style: V3.inter(15, color: V3.muted)),
      ));

  List<Widget> _matchView(LiveMatchData d) {
    final m = d.model(_now);
    final done = d.done;
    _tab ??= done ? 'stats' : 'live';
    final hasScores = d.scoringActions.isNotEmpty;
    final List<Widget> body;
    if (_tab == 'live') {
      body = hasScores
          ? [
              _card(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                          child: Text("Who's ahead",
                              style: V3.inter(16, weight: FontWeight.w700)),
                        ),
                        LeadChart(m),
                      ])),
              _recent(d, m),
            ]
          : [_note('The chart starts with the first score.')];
    } else if (_tab == 'stats') {
      body = d.actions.isNotEmpty
          ? [ChartSection(m)]
          : [_note('Nothing recorded yet.')];
    } else {
      body = [TimelineSection(m)];
    }
    return [
      _meta(d),
      _clock(d),
      _board(d),
      if (!done) _lastScore(d, m),
      if (_failures > 0) _offline('No signal. Showing the last score we got.'),
      _tabs(),
      ...body,
      if (!done && !d.follow.on) _followCard(d),
    ];
  }
}
