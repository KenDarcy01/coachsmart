// v3 Match Stats: the native copy of webviews/match-stats-chart.html (the
// MatchStats web view). One event's score keeping: the session picker when
// more than one person kept score, a waiting screen until the score keeper
// starts, then the live score, both charts, the half by half table, our
// scorers and the timeline (newest first), with a PDF of the lot.
//
// Same data as the web page: list_match_stats_for_event and
// get_match_stats_session, kept live by the score keeper's `chart-<id>`
// realtime channel (timer_state broadcasts, match_stats_details and
// match_timer changes) with polling as the heartbeat. The page has no role
// gate of its own: the RPCs need a signed-in user and only return player
// names to members of the team. It has no editing either; scores are kept
// in the Match Timer.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_match_charts.dart';
import 'v3_match_stats_models.dart';

enum _Screen { loading, error, waiting, picker, chart }

class V3MatchStatsPage extends StatefulWidget {
  const V3MatchStatsPage({
    super.key,
    required this.eventId,
    this.teamId,
    this.matchStatsId,
    this.testData,
  });

  final int eventId;

  /// Passed by the old MatchStats route; the page does not need it.
  final int? teamId;

  /// Open one session straight away (the web page's match_stats_id).
  final int? matchStatsId;

  /// Widget tests pass the RPC results here instead of calling Supabase:
  /// {'list': [list_match_stats_for_event rows],
  ///  'sessions': {'<id>': get_match_stats_session result}}.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3MatchStatsPage> createState() => _V3MatchStatsPageState();
}

class _V3MatchStatsPageState extends State<V3MatchStatsPage>
    with WidgetsBindingObserver {
  _Screen _screen = _Screen.loading;
  String _error = '';
  List<MsSessionItem> _list = [];
  MsSession? _session;
  int? _sessionId;
  bool _exporting = false;
  final _shotKey = GlobalKey();

  RealtimeChannel? _channel;
  RealtimeChannel? _waitChannel;
  Timer? _waitPoll;
  Timer? _pickerPoll;
  Timer? _poll;
  Timer? _tick;
  bool _refreshScheduled = false;

  bool get _test => widget.testData != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopWaiting();
    _stopLive();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back in the app: catch up and re-join the channel (zombie socket).
    if (state == AppLifecycleState.resumed && _sessionId != null) {
      _scheduleRefresh();
      _subscribe(_sessionId!);
    }
  }

  // ------------------------------------------------------------------ data

  Future<List<MsSessionItem>> _fetchList() async {
    if (_test) return parseSessionList(widget.testData!['list']);
    final r = await SupaFlow.client.rpc('list_match_stats_for_event',
        params: {'p_event_id': widget.eventId});
    return parseSessionList(r);
  }

  Future<MsSession?> _fetchSession(int id) async {
    if (_test) {
      final s = widget.testData!['sessions'];
      return MsSession.fromJson(s is Map ? s['$id'] : null);
    }
    final r = await SupaFlow.client
        .rpc('get_match_stats_session', params: {'p_match_stats_id': id});
    return MsSession.fromJson(r);
  }

  String _why(Object e) =>
      e is PostgrestException ? e.message : 'unknown error';

  void _show(_Screen s, {String error = ''}) {
    if (!mounted) return;
    setState(() {
      _screen = s;
      _error = error;
    });
  }

  Future<void> _boot() async {
    if (!_test && SupaFlow.client.auth.currentUser == null) {
      _show(_Screen.error,
          error:
              'Your session has expired. Sign in again and re-open Match Stats.');
      return;
    }
    try {
      if (widget.matchStatsId != null) {
        await _loadSession(widget.matchStatsId!);
      } else {
        await _loadEventSessions();
      }
    } catch (e) {
      _show(_Screen.error,
          error:
              'Unexpected error: ${_why(e)}. Try going back and opening it again. If this persists, contact support.');
    }
  }

  Future<void> _loadEventSessions() async {
    List<MsSessionItem> list;
    try {
      list = await _fetchList();
    } catch (e) {
      _show(_Screen.error,
          error:
              'Could not fetch match sessions (${_why(e)}). Check your connection and try again.');
      return;
    }
    _list = list;
    if (list.isEmpty) {
      _show(_Screen.waiting);
      _startWaiting();
    } else if (list.length == 1) {
      await _loadSession(list.first.id);
    } else {
      _show(_Screen.picker);
      _startPickerRefresh();
    }
  }

  Future<void> _loadSession(int id) async {
    _stopWaiting();
    _sessionId = id;
    MsSession? s;
    try {
      s = await _fetchSession(id);
    } catch (e) {
      _show(_Screen.error,
          error:
              'Could not load match stats (${_why(e)}). Check your connection and try again.');
      return;
    }
    if (s == null) {
      _show(_Screen.error,
          error:
              'Match stats session not found. It may have been reset. Open the Match Timer in the app and try again.');
      return;
    }
    if (!mounted) return;
    setState(() {
      _session = s;
      _screen = _Screen.chart;
    });
    _startTick();
    _subscribe(id);
  }

  Future<void> _select(int id) async {
    _show(_Screen.loading);
    await _loadSession(id);
  }

  /// Debounced: a broadcast and a table change often arrive together.
  void _scheduleRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    Timer(const Duration(milliseconds: 300), () {
      _refreshScheduled = false;
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final id = _sessionId;
    if (id == null) return;
    try {
      final s = await _fetchSession(id);
      if (s == null || !mounted || _sessionId != id) return;
      s.timer = mergeRefresh(_session?.timer, s.timer);
      setState(() => _session = s);
      _startTick();
    } catch (_) {}
  }

  // ------------------------------------------------- waiting / picker poll

  Future<void> _checkForSessions() async {
    List<MsSessionItem> list;
    try {
      list = await _fetchList();
    } catch (_) {
      return;
    }
    if (list.isEmpty || !mounted || _screen != _Screen.waiting) return;
    _stopWaiting();
    _list = list;
    if (list.length == 1) {
      _show(_Screen.loading);
      await _loadSession(list.first.id);
    } else {
      _show(_Screen.picker);
      _startPickerRefresh();
    }
  }

  void _startWaiting() {
    if (_test) return;
    _waitChannel = SupaFlow.client
        .channel('waiting-${widget.eventId}')
        .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'match_stats',
            callback: (p) {
              if ('${p.newRecord['event_id']}' == '${widget.eventId}') {
                _checkForSessions();
              }
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'match_timer',
            callback: (p) {
              if ('${p.newRecord['event_id']}' == '${widget.eventId}') {
                _checkForSessions();
              }
            })
        .subscribe();
    _waitPoll =
        Timer.periodic(const Duration(seconds: 3), (_) => _checkForSessions());
  }

  void _startPickerRefresh() {
    if (_test) return;
    _pickerPoll?.cancel();
    _pickerPoll = Timer.periodic(const Duration(seconds: 10), (_) async {
      List<MsSessionItem> list;
      try {
        list = await _fetchList();
      } catch (_) {
        return;
      }
      if (list.isEmpty || !mounted || _screen != _Screen.picker) return;
      if (list.length == 1 && _sessionId == null) {
        _stopWaiting();
        _show(_Screen.loading);
        await _loadSession(list.first.id);
      } else {
        setState(() => _list = list);
      }
    });
  }

  void _stopWaiting() {
    if (_waitChannel != null) {
      SupaFlow.client.removeChannel(_waitChannel!);
      _waitChannel = null;
    }
    _waitPoll?.cancel();
    _waitPoll = null;
    _pickerPoll?.cancel();
    _pickerPoll = null;
  }

  // -------------------------------------------------------------- realtime

  void _subscribe(int id) {
    if (_test) return;
    if (_channel != null) SupaFlow.client.removeChannel(_channel!);
    _startPolling(const Duration(seconds: 5)); // until the channel joins
    final eventId = _session?.eventId;
    _channel = SupaFlow.client
        .channel('chart-$id')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'match_stats_details',
            callback: (p) {
              final rowId = p.newRecord['match_stats_id'] ??
                  p.oldRecord['match_stats_id'];
              if ('$rowId' == '$id') _scheduleRefresh();
            })
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'match_timer',
            callback: (p) {
              final ev = p.newRecord['event_id'];
              if (eventId != null && ev != null && '$ev' != '$eventId') return;
              _scheduleRefresh();
            })
        .onBroadcast(
            event: 'timer_state',
            callback: (payload) {
              final s = _session;
              if (s == null || !mounted) return;
              setState(() =>
                  s.timer = mergeBroadcast(s.timer, payload, DateTime.now()));
              _startTick();
              _scheduleRefresh();
            })
        .subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _startPolling(const Duration(seconds: 10)); // heartbeat
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        _startPolling(const Duration(seconds: 5));
      }
    });
  }

  void _startPolling(Duration d) {
    _poll?.cancel();
    _poll = Timer.periodic(d, (_) => _scheduleRefresh());
  }

  /// The live clock ticks every second until the session is finalised.
  void _startTick() {
    _tick?.cancel();
    _tick = null;
    if (_test || _session == null || _session!.finished) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopLive() {
    if (_channel != null) {
      SupaFlow.client.removeChannel(_channel!);
      _channel = null;
    }
    _poll?.cancel();
    _poll = null;
    _tick?.cancel();
    _tick = null;
  }

  /// Back from a session to the picker when several people kept score.
  bool get _backToPicker =>
      _screen == _Screen.chart &&
      _list.length > 1 &&
      widget.matchStatsId == null;

  void _goBack() {
    if (_backToPicker) {
      _stopLive();
      setState(() {
        _session = null;
        _sessionId = null;
        _screen = _Screen.picker;
      });
      _startPickerRefresh();
      return;
    }
    Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------------- PDF

  /// The web page screenshots its chart screen into a one-page PDF; this
  /// does the same with the native screen and shares it.
  Future<void> _exportPdf() async {
    final s = _session;
    final box = _shotKey.currentContext?.findRenderObject();
    if (s == null || box is! RenderRepaintBoundary || _exporting) return;
    setState(() => _exporting = true);
    try {
      final img = await box.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      final ratio = img.height / img.width;
      img.dispose();
      if (png == null) throw Exception('no image');
      // 210 mm wide like the web export; very long timelines get a wider
      // page so the height stays inside the PDF limit.
      var pageW = PdfPageFormat.a4.width;
      var pageH = pageW * ratio;
      if (pageH > 14000) {
        pageH = 14000;
        pageW = pageH / ratio;
      }
      final doc = pw.Document();
      doc.addPage(pw.Page(
          pageFormat: PdfPageFormat(pageW, pageH),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(pw.MemoryImage(png.buffer.asUint8List()),
              fit: pw.BoxFit.fill)));
      final w = walk(chartModel(s, DateTime.now()));
      await Printing.sharePdf(
          bytes: await doc.save(),
          filename:
              pdfFileName(s.title, s.oppName, w.us, w.opp, DateTime.now()));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('The PDF could not be made. Please try again.',
                textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
            backgroundColor: V3.amber));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_backToPicker,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: AppBar(
          backgroundColor: V3.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
              onPressed: _goBack),
          title: Text('Match Stats', style: V3.tight(17)),
          actions: [
            if (_screen == _Screen.chart)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: _exporting ? null : _exportPdf,
                  style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: V3.green),
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: V3.green))
                      : const Icon(Icons.download, size: 22),
                  label: Text(_exporting ? 'Making…' : 'PDF',
                      style: V3.inter(16,
                          weight: FontWeight.w700, color: V3.green)),
                ),
              ),
          ],
        ),
        body: switch (_screen) {
          _Screen.loading => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: V3.green),
                const SizedBox(height: 16),
                Text('Loading match chart…',
                    style: V3.inter(15, color: V3.muted)),
              ]),
            ),
          _Screen.error => _ErrorView(_error),
          _Screen.waiting => const _WaitingView(),
          _Screen.picker => _picker(),
          _Screen.chart => _chart(),
        },
      ),
    );
  }

  Widget _picker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text('Match Stats', style: V3.tight(26, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(pickerSubtitle(_list), style: V3.inter(15, color: V3.muted)),
        const SizedBox(height: 18),
        for (final s in _list) _SessionCard(s, onTap: () => _select(s.id)),
      ],
    );
  }

  Widget _chart() {
    final s = _session!;
    final now = DateTime.now();
    final m = chartModel(s, now);
    final w = walk(m);
    final clock = liveClock(s, now);
    final chip = leadChip(m);
    final live = !s.finished && s.timer.running;

    return RefreshIndicator(
      color: V3.green,
      backgroundColor: V3.card,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: RepaintBoundary(
          key: _shotKey,
          child: ColoredBox(
            color: V3.bg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(s.title.toUpperCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: V3.inter(13,
                                weight: FontWeight.w600,
                                color: V3.muted,
                                letterSpacing: 1.5))),
                    if (live) const _LiveBadge(),
                  ]),
                  const SizedBox(height: 12),
                  if (clock != null) ...[
                    _LiveClockCard(clock),
                    const SizedBox(height: 12),
                  ],
                  _ScoreBoard(m: m, w: w),
                  const SizedBox(height: 12),
                  _LeadChip(chip.$1, chip.$2),
                  if (m.events.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text('Waiting for the first score…',
                          textAlign: TextAlign.center,
                          style: V3.inter(15, color: V3.muted)),
                    )
                  else
                    ..._chartSection(m),
                  Padding(
                    padding: const EdgeInsets.only(top: 22, bottom: 4),
                    child: Text('TIMELINE',
                        style: V3.inter(13,
                            weight: FontWeight.w600,
                            color: V3.muted,
                            letterSpacing: 2)),
                  ),
                  for (final it in timeline(m)) _TimelineRow(it),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _chartSection(MatchModel full) {
    final m = full.scoresOnly();
    final w = walk(m);
    final (blUs, blOpp) = biggestLeads(m);
    final hs = halfScores(m);
    final stats = otherStats(m);
    final sc = scorers(m);
    return [
      _Card(children: [
        Text('Who was ahead', style: V3.tight(18, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Above the line ${m.usName} led, below it ${m.oppName} led',
            style: V3.inter(14, color: V3.muted)),
        const SizedBox(height: 8),
        V3MatchChart.lead(m),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child:
                _Kpi(blUs.label, '${poss(m.usName)} biggest lead', V3.green)),
        const SizedBox(width: 8),
        Expanded(
            child:
                _Kpi(blOpp.label, '${poss(m.oppName)} biggest lead', kOppRed)),
      ]),
      _Card(children: [
        Text('Scores over the match',
            style: V3.tight(18, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text('Total points for each team',
            style: V3.inter(14, color: V3.muted)),
        const SizedBox(height: 8),
        V3MatchChart.race(m),
      ]),
      _Table(head: (
        '',
        m.usName,
        m.oppName
      ), rows: [
        ('1st half', hs[1]!.$1, hs[1]!.$2, false),
        if (m.hasH2) ('2nd half', hs[2]!.$1, hs[2]!.$2, false),
        (m.finished ? 'Final' : 'Now', w.us, w.opp, true),
      ]),
      if (stats.isNotEmpty)
        _Table(head: (
          'Stats',
          m.usName,
          m.oppName
        ), rows: [
          for (final x in stats) (x.name, '${x.us}', '${x.opp}', false),
        ]),
      if (sc.any((r) => r.name.isNotEmpty))
        _Card(children: [
          Text('${m.usName} scorers',
              style: V3.tight(18, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (var i = 0; i < sc.length; i++)
            _ScorerRow(sc[i], last: i == sc.length - 1),
        ]),
    ];
  }
}

// ----------------------------------------------------------------- pieces

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.msg);
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, color: V3.amber, size: 40),
          const SizedBox(height: 12),
          Text('Unable to load chart', style: V3.tight(18)),
          const SizedBox(height: 8),
          Text(msg,
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted, height: 1.4)),
        ]),
      ),
    );
  }
}

class _WaitingView extends StatefulWidget {
  const _WaitingView();

  @override
  State<_WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends State<_WaitingView>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) =>
                  CustomPaint(painter: _OrbPainter(_c.value)),
            ),
          ),
          const SizedBox(height: 24),
          Text('WAITING FOR\nMATCH TO START',
              textAlign: TextAlign.center,
              style: V3.tight(28, weight: FontWeight.w700, height: 1.15)),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
                'The scorekeeper needs to open the Match Timer in CoachSmart. This screen will connect automatically when the match begins.',
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted, height: 1.55)),
          ),
          const SizedBox(height: 24),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: V3.green, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
                child: Text('LISTENING FOR SCOREKEEPER',
                    style: V3.inter(13,
                        weight: FontWeight.w600,
                        color: V3.green.withValues(alpha: .8),
                        letterSpacing: 1))),
          ]),
        ]),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (final phase in [0.0, 0.5]) {
      final p = (t + phase) % 1;
      final r = 25 + 35 * p;
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = V3.green.withValues(alpha: .25 * (1 - p)));
    }
    final pulse = 1 - .14 * math.sin(t * math.pi);
    canvas.drawCircle(c, 11 * pulse, Paint()..color = V3.green);
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.t != t;
}

class _SessionCard extends StatelessWidget {
  const _SessionCard(this.s, {required this.onTap});
  final MsSessionItem s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
              Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: Color(squadColourValue(s.squadColour)),
                      shape: BoxShape.circle)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: V3.inter(17, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(s.meta, style: V3.inter(14, color: V3.muted)),
                    ]),
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.isMine) const _Badge('Mine', V3.green),
                    if (s.finalised) const _Badge('Final', V3.muted),
                    if (s.live) const _Badge('Live', V3.amber),
                  ]),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: V3.muted, size: 26),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          border: Border.all(color: color.withValues(alpha: .35)),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: V3.inter(12, weight: FontWeight.w700, color: color)),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
          color: red.withValues(alpha: .08),
          border: Border.all(color: red.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 7,
            height: 7,
            decoration:
                const BoxDecoration(color: red, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('LIVE',
            style: V3.inter(12,
                weight: FontWeight.w700, color: red, letterSpacing: 1)),
      ]),
    );
  }
}

class _LiveClockCard extends StatelessWidget {
  const _LiveClockCard(this.c);
  final LiveClock c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (c.running) ...[
            Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: Color(0xFFEF4444), shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(c.half.toUpperCase(),
              style: V3.inter(13,
                  weight: FontWeight.w600,
                  color: V3.muted,
                  letterSpacing: 1.5)),
        ]),
        const SizedBox(height: 4),
        Text(c.time,
            style: V3.tight(56, weight: FontWeight.w700, height: 1.05).copyWith(
                fontFeatures: const [ui.FontFeature.tabularFigures()])),
        const SizedBox(height: 4),
        Text(c.sub,
            style: V3.inter(14, weight: FontWeight.w500, color: V3.muted)),
      ]),
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  const _ScoreBoard({required this.m, required this.w});
  final MatchModel m;
  final Walk w;

  @override
  Widget build(BuildContext context) {
    Widget team(String name, String score, int total, Color c) => Expanded(
          child: Column(children: [
            Text(name.toUpperCase(),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(13,
                    weight: FontWeight.w600, color: c, letterSpacing: 1)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(score,
                  style: V3.tight(48, weight: FontWeight.w700, color: c)),
            ),
            Text('($total)',
                style: V3.inter(20, weight: FontWeight.w600, color: V3.muted)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        team(m.usName, w.us, w.usT, V3.green),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text('VS',
              style: V3.inter(17, weight: FontWeight.w700, color: V3.muted)),
        ),
        team(m.oppName, w.opp, w.oppT, kOppRed),
      ]),
    );
  }
}

class _LeadChip extends StatelessWidget {
  const _LeadChip(this.text, this.tone);
  final String text;
  final LeadTone tone;

  @override
  Widget build(BuildContext context) {
    if (tone == LeadTone.none) return const SizedBox(height: 8);
    final c = switch (tone) {
      LeadTone.leading => V3.green,
      LeadTone.trailing => kOppRed,
      _ => V3.muted,
    };
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
            color: c.withValues(alpha: .1),
            border: Border.all(color: c.withValues(alpha: .35)),
            borderRadius: BorderRadius.circular(20)),
        child:
            Text(text, style: V3.inter(15, weight: FontWeight.w700, color: c)),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: V3.tight(22, weight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: V3.inter(13, color: V3.muted)),
      ]),
    );
  }
}

/// Three columns: label, us, them. The last row of the halves table is the
/// Final (or Now) score with ours in green.
class _Table extends StatelessWidget {
  const _Table({required this.head, required this.rows});
  final (String, String, String) head;
  final List<(String, String, String, bool)> rows;

  @override
  Widget build(BuildContext context) {
    final hd = V3.inter(12,
        weight: FontWeight.w600, color: V3.muted, letterSpacing: 1);
    Widget cell(String t, TextStyle st, {bool centre = true}) => Expanded(
        child: Text(t,
            textAlign: centre ? TextAlign.center : TextAlign.left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: st));
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            cell(head.$1.toUpperCase(), hd, centre: false),
            cell(head.$2.toUpperCase(), hd),
            cell(head.$3.toUpperCase(), hd),
          ]),
        ),
        for (final r in rows)
          Container(
            constraints: const BoxConstraints(minHeight: 46),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: V3.line))),
            child: Row(children: [
              cell(
                  r.$1,
                  V3.inter(16,
                      weight: r.$4 ? FontWeight.w700 : FontWeight.w400),
                  centre: false),
              cell(r.$2, V3.tight(22, color: r.$4 ? V3.green : V3.text)),
              cell(r.$3, V3.tight(22)),
            ]),
          ),
      ]),
    );
  }
}

class _ScorerRow extends StatelessWidget {
  const _ScorerRow(this.r, {required this.last});
  final Scorer r;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: BoxDecoration(
          border:
              last ? null : const Border(bottom: BorderSide(color: V3.line))),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          child: Text(r.name.isEmpty ? 'No player named' : r.name,
              style: V3.inter(16, color: r.name.isEmpty ? V3.muted : V3.text)),
        ),
        SizedBox(
            width: 70,
            child:
                Text(r.score, textAlign: TextAlign.right, style: V3.tight(21))),
        if (r.other.isNotEmpty)
          Expanded(
              child: Text(r.otherText,
                  textAlign: TextAlign.right,
                  style: V3.inter(13, color: V3.muted))),
      ]),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(this.it);
  final TlItem it;

  @override
  Widget build(BuildContext context) {
    switch (it.kind) {
      case TlKind.empty:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(it.label,
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted)),
        );
      case TlKind.run:
        return Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 0, 8),
          child: Text(it.label,
              style: V3.inter(14,
                  weight: FontWeight.w600,
                  color: it.ours ? V3.green : kOppRed)),
        );
      case TlKind.band:
        return Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: it.fullTime ? V3.green.withValues(alpha: .14) : V3.card2,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(
              child: Text(it.label.toUpperCase(),
                  style: V3.inter(14,
                      weight: FontWeight.w600,
                      color: it.fullTime ? V3.green : V3.muted,
                      letterSpacing: 1)),
            ),
            Text(it.score, style: V3.tight(20)),
          ]),
        );
      case TlKind.sub:
      case TlKind.event:
        final edge = it.kind == TlKind.sub
            ? const Color(0xFF5B8DEF)
            : it.ours
                ? V3.green
                : kOppRed;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: V3.card,
            gradient: it.goal
                ? LinearGradient(colors: [
                    edge.withValues(alpha: .16),
                    V3.card,
                  ], stops: const [
                    0,
                    .6
                  ])
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: edge),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                  child: Row(children: [
                    SizedBox(
                        width: 52,
                        child: Text(it.minute,
                            style: V3.inter(14,
                                weight: FontWeight.w700, color: V3.muted))),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(it.label, style: V3.inter(16)),
                                  if (it.tag != TlTag.none) _Tag(it.tag),
                                ]),
                            if (it.who.isNotEmpty)
                              Text(it.who,
                                  style: V3.inter(13, color: V3.muted)),
                          ]),
                    ),
                    if (it.score.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: it.score.split(' v ').first,
                            style: V3.tight(19)),
                        TextSpan(
                            text: '  v  ',
                            style: V3.inter(13, color: V3.muted)),
                        TextSpan(
                            text: it.score.split(' v ').last,
                            style: V3.tight(19)),
                      ])),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        );
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.tag);
  final TlTag tag;

  @override
  Widget build(BuildContext context) {
    final (text, bg, fg) = switch (tag) {
      TlTag.goalUs => ('GOAL', V3.green, V3.bg),
      TlTag.goalOpp => ('GOAL', kOppRed, Colors.white),
      TlTag.plus2 => ('+2', V3.amber, V3.bg),
      _ => ('CHECK', V3.amber, V3.bg),
    };
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child:
          Text(text, style: V3.inter(12, weight: FontWeight.w700, color: fg)),
    );
  }
}
