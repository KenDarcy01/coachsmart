// v3 Score keeper: a native copy of webviews/score-keeper.html (the match
// score keeper). Same data, same rules, same wording; the web page stays
// for the old app.
//
//  - Setup: opposition, squad, a squad's own throw-in time and venue, half
//    length and injury time. Nothing can be scored before kick-off.
//  - Playing: only the clock, the score, the Tap/Voice switch and the
//    buttons (with the latest entries a scroll away). The screen stays on.
//  - Tap: one big button per stat (match_stat_type_team_link); tap adds
//    one, press and hold takes one off, Undo on the bar after each tap.
//  - Voice (accounts with get_my_ai_features() only, Ken 2026-10-16): hold
//    the mic and say it. The always-on mic sends a WAV clip to score-voice;
//    with AI off it's the phone's own dictation read on the phone.
//  - Every entry is saved on the phone and uploaded by sync_match_actions
//    with its own id, so nothing is lost with no signal.
//  - Half time / full time: "Does this match the ref's score?", the
//    Score/Stats tabs, charts, the timeline (newest first) and a PDF.
//  - The clock goes to followers through sync_match_actions' p_timer.
//
// Opened from the event page's Score button: V3ScoreKeeperPage(eventId:).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../match_report/v3_match_report_page.dart';
import '../match_report/v3_voice_sheet.dart' show V3Dictation;
import '../match_stats/v3_match_stats_models.dart' show Walk;
import '../v3_theme.dart';
import 'sk_controller.dart';
import 'sk_models.dart';
import 'sk_services.dart';
import 'sk_setup_form.dart';
import 'sk_sheets.dart';
import 'sk_stats_view.dart';
import 'sk_widgets.dart';

class V3ScoreKeeperPage extends StatefulWidget {
  const V3ScoreKeeperPage(
      {super.key,
      required this.eventId,
      this.testData,
      this.testBackend,
      this.testStore,
      this.testNow});

  final int eventId;

  /// Widget tests pass get_score_keeper_state's result here instead of
  /// calling Supabase (uploads are accepted in memory).
  @visibleForTesting
  final Map<String, dynamic>? testData;

  /// Widget tests can pass their own backend, store and clock.
  @visibleForTesting
  final SkBackend? testBackend;
  @visibleForTesting
  final SkStore? testStore;
  @visibleForTesting
  final int Function()? testNow;

  @override
  State<V3ScoreKeeperPage> createState() => _V3ScoreKeeperPageState();
}

class _V3ScoreKeeperPageState extends State<V3ScoreKeeperPage>
    with WidgetsBindingObserver {
  late final bool _test = widget.testData != null || widget.testBackend != null;
  late final SkController ctl = SkController(
    eventId: widget.eventId,
    backend: widget.testBackend ??
        (widget.testData != null
            ? SkMemoryBackend(widget.testData!)
            : const SupabaseSkBackend()),
    store: widget.testStore ?? (_test ? MemorySkStore() : PrefsSkStore()),
    device: SkDevice(quiet: _test),
    mic: SkMic(enabled: !_test),
    now: widget.testNow,
  );
  final _scroll = ScrollController();
  SkDraft? _draft;

  // Dictation (when the always-on mic isn't open)
  V3Dictation? _dict;
  bool _dictating = false;
  String _interim = '';
  SkAt? _micAt;

  // The toast bar
  OverlayEntry? _toastEntry;
  Timer? _toastTimer;
  final _toastShown = ValueNotifier<SkToast?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ctl.onToast = _toast;
    ctl.scrollTop.addListener(_toTop);
    ctl.boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _toastShown.dispose();
    _dict?.dispose();
    ctl.scrollTop.removeListener(_toTop);
    ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ctl.setForeground(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ctl.setForeground(false);
    }
  }

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // ----------------------------------------------------------------- toast

  void _toast(SkToast t) {
    if (!mounted) return;
    _toastTimer?.cancel();
    _toastShown.value = t;
    if (_toastEntry == null) {
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      _toastEntry =
          OverlayEntry(builder: (_) => _ToastBar(_toastShown, _hideToast));
      overlay.insert(_toastEntry!);
    }
    _toastTimer = Timer(
        Duration(milliseconds: t.action != null ? 5000 : 2800), _hideToast);
  }

  void _hideToast() {
    _toastTimer?.cancel();
    _toastShown.value = null;
  }

  // ------------------------------------------------------------------ nav

  Future<void> _back() async {
    _hideToast();
    await ctl.leave();
    if (mounted) Navigator.of(context).pop();
  }

  void _report() {
    ctl.keepAwake(false);
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => V3MatchReportPage(eventId: widget.eventId)));
  }

  Future<void> _menu() async {
    if (ctl.s == null) return;
    final k = await showSkMenu(context, ctl);
    if (!mounted || k == null) return;
    switch (k) {
      case 'setup':
        if (ctl.s!.phase != 'setup') await showSkSetupSheet(context, ctl);
      case 'undo':
        ctl.undoLast();
      case 'sub':
        await showSkSubs(context, ctl);
      case 'check':
        await showSkCorrect(context, ctl);
      case 'chart':
        ctl.setView('stats');
      case 'awake':
        ctl.keepAwake(!ctl.awakeWanted);
      case 'reset':
      case 'again':
        await confirmSkReset(context, ctl, k == 'again');
    }
  }

  // ------------------------------------------------------------------ mic

  Future<void> _micDown() async {
    if (ctl.audioDown()) return;
    if (_dictating || ctl.micUi != 'idle') return;
    if (!ctl.isStarted) return ctl.notStarted();
    _micAt = ctl.stamp();
    _interim = '';
    _dictating = true;
    ctl.vheard = '';
    ctl.setMicUi('preparing');
    final d = _dict ??= V3Dictation()
      ..onInterim = (t) {
        if (mounted) setState(() => _interim = t);
      }
      ..onError = (m) => ctl.toast(m);
    final ok = await d.start();
    if (!ok) {
      _dictating = false;
      ctl.setMicUi('idle');
      return;
    }
    if (_dictating) ctl.setMicUi('recording');
  }

  Future<void> _micUp() async {
    if (ctl.audioState == 'on' && ctl.micUi == 'recording' && !_dictating) {
      await ctl.audioUp();
      return;
    }
    if (!_dictating) return;
    _dictating = false;
    ctl.setMicUi('working');
    final text = await (_dict?.stop() ?? Future.value(''));
    _interim = '';
    await ctl.handleVoiceText(text, _micAt);
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ListenableBuilder(
        listenable: ctl,
        builder: (context, _) {
          final s = ctl.s;
          final ready = !ctl.loading && ctl.fatal == null && s != null;
          if (ready && s.phase != 'setup') _draft = null;
          return Scaffold(
            backgroundColor: V3.bg,
            appBar: _appBar(ready),
            body: !ready ? _notReady() : _main(),
            bottomNavigationBar: ready ? _foot() : null,
          );
        },
      ),
    );
  }

  PreferredSizeWidget _appBar(bool ready) {
    Widget ib(IconData ic, String tip, VoidCallback f, {Color? color}) =>
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Material(
            color: V3.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: f,
              child: Tooltip(
                message: tip,
                child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(ic, size: 22, color: color ?? V3.text)),
              ),
            ),
          ),
        );
    return AppBar(
      backgroundColor: V3.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, color: V3.green, size: 34),
          onPressed: _back),
      titleSpacing: 0,
      centerTitle: true,
      title: ready ? _pill() : null,
      actions: [
        if (ready) ...[
          ib(Icons.help_outline, 'How to', () => showSkHowTo(context, ctl)),
          ib(
              ctl.awakeWanted ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              ctl.awakeWanted ? 'Screen stays on' : 'Screen can sleep',
              ctl.toggleAwake,
              color: ctl.awakeWanted ? V3.green : V3.muted),
          ib(Icons.more_horiz, 'More', _menu),
        ],
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _pill() {
    final (txt, cls) = pillText(ctl.s, ctl.netState, ctl.syncing);
    final color = cls == 'wait' ? V3.amber : V3.green;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showSkSaving(context, ctl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(txt,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(15, weight: FontWeight.w600, color: color)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _notReady() {
    final f = ctl.fatal;
    if (f == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: V3.green),
          const SizedBox(height: 14),
          Text('Opening the match…', style: V3.inter(16, color: V3.muted)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(f.$1,
            textAlign: TextAlign.center,
            style: V3.tight(20, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(f.$2,
            textAlign: TextAlign.center, style: V3.inter(16, color: V3.muted)),
        if (ctl.fatalRetry) ...[
          const SizedBox(height: 20),
          SkButton(label: 'Try again', tone: SkTone.green, onTap: ctl.retry),
        ],
      ]),
    );
  }

  Widget _main() {
    final s = ctl.s!;
    // Chart and timeline are for half time and full time; while playing it's
    // just the clock, score and buttons
    final live = s.phase == 'setup' || s.phase == 'play';
    if (live && ctl.view != 'score') ctl.view = 'score';
    return Column(children: [
      if (!live)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _Segment(
            options: const [('score', 'Score'), ('stats', 'Stats')],
            value: ctl.view,
            onChanged: ctl.setView,
          ),
        ),
      Expanded(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children:
              ctl.view == 'stats' ? [SkStatsView(ctl: ctl)] : _scoreView(),
        ),
      ),
    ]);
  }

  List<Widget> _scoreView() {
    final s = ctl.s!;
    final ph = s.phase;
    return [
      if (ph == 'setup') SkSetupForm(ctl: ctl, draft: _draft ??= ctl.draft()),
      if (ph == 'play') ...[
        _Clock(ctl),
        const SizedBox(height: 14),
        SkBoard(us: ctl.us, opp: ctl.opp, w: ctl.totals()),
        if (ctl.voiceAllowed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Segment(
              green: true,
              options: const [('tap', 'Tap'), ('voice', 'Voice')],
              icons: const [Icons.touch_app_outlined, Icons.mic_none],
              value: ctl.mode,
              onChanged: ctl.setMode,
            ),
          ),
        if (!ctl.voiceAllowed || ctl.mode == 'tap') _tapPad() else _voicePad(),
      ],
      if (ph != 'setup' && ph != 'play') ..._phase(),
      if (ph != 'setup') ..._recent(),
    ];
  }

  // ----------------------------------------------------------------- tap

  Widget _tapPad() {
    final c = ctl.c!;
    if (c.btnTypes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Text('No score types set up for this team.',
            textAlign: TextAlign.center, style: V3.inter(16, color: V3.muted)),
      );
    }
    // Every stat gets the same full-size button; the scores come first and
    // the rest are a scroll away
    final all = c.padTypes;
    final dim = !ctl.isStarted;
    Widget col(String side) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Text((side == 'us' ? ctl.us : ctl.opp).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: skCaps(size: 12)),
            ),
            for (final t in all)
              SkBigButton(
                key: ValueKey('btn-$side-${t.id}'),
                label: t.name,
                value: t.value,
                count: countFor(ctl.s!, t.id, side),
                dim: dim,
                onTap: () => ctl.tapScore(t.id, side),
                onLongPress: () => ctl.takeOneOff(t.id, side),
              ),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        col('us'),
        const SizedBox(width: 10),
        col('opp'),
      ]),
    );
  }

  // --------------------------------------------------------------- voice

  Widget _voicePad() {
    final ui = ctl.micUi;
    final (Color bg, Color ring) = switch (ui) {
      'preparing' => (V3.amber, V3.amber),
      'recording' => (skRed, skRed),
      _ => (V3.green, V3.green),
    };
    final instr = switch (ui) {
      'preparing' => 'Starting… keep holding',
      'recording' => 'Listening… release when done',
      'working' => 'Working it out…',
      _ => 'Hold and say what happened',
    };
    final heard = ui == 'recording'
        ? (_interim.isEmpty ? 'Listening…' : _interim)
        : ui == 'working' || ui == 'preparing'
            ? ctl.vheard
            : ctl.vheard.isEmpty
                ? ''
                : '"${ctl.vheard}" · read by ${ctl.lastBy}';
    final aiTxt = !ctl.aiVoice
        ? ('AI reading: ', 'not on for this account', false)
        : (
            'AI ${ctl.audioState == 'on' ? 'listening' : 'reading'}: ',
            ctl.aiWanted ? 'On' : 'Off',
            ctl.aiWanted
          );
    return Opacity(
      opacity: ctl.isStarted ? 1 : .45,
      child: Column(children: [
        const SizedBox(height: 40),
        Semantics(
          button: true,
          label: 'Hold to talk',
          child: Listener(
            onPointerDown: (_) => _micDown(),
            onPointerUp: (_) => _micUp(),
            onPointerCancel: (_) => _micUp(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: ring.withValues(alpha: .14), spreadRadius: 14),
                  BoxShadow(
                      color: ring.withValues(alpha: .06), spreadRadius: 28),
                ],
              ),
              child: const Icon(Icons.mic_none, size: 58, color: V3.bg),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(instr, style: V3.inter(18, weight: FontWeight.w700)),
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.only(top: 10),
          child: Text(heard,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: V3
                  .inter(16,
                      color: ui == 'recording' && _interim.isEmpty
                          ? V3.muted
                          : V3.text)
                  .copyWith(fontStyle: FontStyle.italic)),
        ),
        Material(
          color: V3.card,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: ctl.toggleAi,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text.rich(TextSpan(
                  style: V3.inter(14, weight: FontWeight.w600, color: V3.muted),
                  children: [
                    TextSpan(text: aiTxt.$1),
                    TextSpan(
                        text: aiTxt.$2,
                        style: V3.inter(14,
                            weight: FontWeight.w700,
                            color: aiTxt.$3 ? V3.green : V3.muted)),
                    if (ctl.aiVoice) const TextSpan(text: ' · tap to switch'),
                  ])),
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final card in ctl.vcards) _vcard(card),
      ]),
    );
  }

  Widget _vcard(SkVCard card) {
    final s = ctl.s!, c = ctl.c!;
    Widget btn(String label, VoidCallback f,
            {SkTone tone = SkTone.soft, Color? fg}) =>
        Expanded(
            child: SkButton(
                label: label, height: 50, tone: tone, textColor: fg, onTap: f));
    Widget shell(Color edge, String title, String sub,
            {bool countdown = false, List<Widget> buttons = const []}) =>
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: edge),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title,
                            style: V3.inter(18, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(sub, style: V3.inter(15, color: V3.muted)),
                        if (countdown && card.ms != null) _Countdown(card, ctl),
                        if (buttons.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(children: [
                              buttons[0],
                              const SizedBox(width: 8),
                              if (buttons.length > 1) buttons[1],
                            ]),
                          ),
                      ]),
                ),
              ),
            ]),
          ),
        );
    switch (card.kind) {
      case 'act':
        final a = s.acts.where((x) => x.id == card.id).firstOrNull;
        if (a == null) return const SizedBox.shrink();
        final (lt, ls) = actLabel(s, c, a);
        final q = card.guess ? '?' : '';
        final who = a.mem != null
            ? (a.side == 'us'
                ? '${ctl.nameOf(a.mem)}$q · ${ctl.us}'
                : '${ctl.opp} · against ${ctl.nameOf(a.mem)}$q')
            : ls;
        return shell(a.side == 'opp' ? skRed : V3.green,
            '$lt · ${ctl.minute(a.half, a.sec)}', who,
            countdown: true,
            buttons: [
              btn('Undo', () {
                ctl.dropAct(a.id, buzz: false);
                ctl.dropCard(card);
              }),
              btn('Change', () {
                ctl.dropCard(card);
                showSkEdit(context, ctl, a.id);
              }),
            ]);
      case 'sub':
        final x = s.subs.where((y) => y.id == card.id).firstOrNull;
        if (x == null) return const SizedBox.shrink();
        return shell(V3.green, 'Sub · ${ctl.minute(x.half, x.sec)}',
            '${ctl.nameOf(x.on)} on for ${ctl.nameOf(x.off)}',
            countdown: true,
            buttons: [
              btn('Undo', () {
                ctl.deleteSub(x.id, quiet: true);
                ctl.dropCard(card);
              }),
              btn('Change', () {
                ctl.dropCard(card);
                ctl.deleteSub(x.id, quiet: true);
                showSkSubs(context, ctl,
                    off: x.off, on: x.on, at: SkAt(x.half, x.sec, false));
              }),
            ]);
      case 'subask':
        return shell(V3.amber, 'Sub: who was it?',
            'Heard ${card.onHeard.isEmpty ? '?' : card.onHeard} on for ${card.offHeard.isEmpty ? '?' : card.offHeard}. Pick them to make the sub.',
            buttons: [
              btn('Pick players', () {
                ctl.dropCard(card);
                showSkSubs(context, ctl,
                    off: card.offId, on: card.onId, at: card.subAt);
              }, tone: SkTone.green),
              btn('Forget it', () => ctl.dropCard(card), fg: skRed),
            ]);
      default:
        return shell(V3.amber, "Didn't catch that",
            '"${card.text}". Try "Point Ciarán" or "Wide for them".');
    }
  }

  // --------------------------------------------------------------- phase

  Widget _check() {
    final s = ctl.s!;
    final ok = s.checked[s.phase == 'ht' ? 1 : 2] == true;
    Widget pillBtn(String t, Color c, VoidCallback f) => Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Material(
            color: c.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: f,
              child: Container(
                constraints: const BoxConstraints(minHeight: 46, minWidth: 64),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(t,
                    style: V3.inter(16, weight: FontWeight.w700, color: c)),
              ),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
          color: V3.card2, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Text(
              ok
                  ? "✓ Matches the ref's score"
                  : "Does this match the ref's score?",
              style: V3.inter(16, color: ok ? V3.green : V3.text)),
        ),
        if (!ok) pillBtn('Yes', V3.green, ctl.markChecked),
        pillBtn('Edit', V3.amber, () => showSkCorrect(context, ctl)),
      ]),
    );
  }

  List<Widget> _phase() {
    final s = ctl.s!, c = ctl.c!;
    final Walk w = ctl.totals();
    final d = w.usT - w.oppT;
    final lead = leadText(s, c, w);
    Widget head(String label, String big, Color color) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 14),
          child: Column(children: [
            Text(label.toUpperCase(),
                textAlign: TextAlign.center, style: skCaps()),
            const SizedBox(height: 4),
            Text(big, style: skNum(72, color: color)),
          ]),
        );
    Widget table(String title, int h) {
      final rows = halfTable(s, c, h);
      if (rows.isEmpty) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(18)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: V3.inter(17, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  border: i == rows.length - 1
                      ? null
                      : const Border(bottom: BorderSide(color: V3.line))),
              child: Row(children: [
                Expanded(child: Text('${rows[i].$2}', style: V3.inter(17))),
                Text(rows[i].$1.toUpperCase(), style: skCaps(size: 12)),
                Expanded(
                    child: Text('${rows[i].$3}',
                        textAlign: TextAlign.right, style: V3.inter(17))),
              ]),
            ),
        ]),
      );
    }

    if (s.phase == 'ht') {
      final ended = s.clock.ended[1] ?? ctl.sec;
      return [
        head(
            'First half finished at ${fmtClock(ended)}', 'Half time', V3.amber),
        SkBoard(
            us: ctl.us,
            opp: ctl.opp,
            w: w,
            tag: 'HT',
            sub: lead,
            footer: _check()),
        table('First half', 1),
        _undoLink('Ended the half by mistake? Back to the clock'),
      ];
    }
    final top = head(d == 0 ? 'A draw' : lead, 'Full time', V3.text);
    if (s.phase == 'ft') {
      return [
        top,
        SkBoard(us: ctl.us, opp: ctl.opp, w: w, tag: 'FT', footer: _check()),
        table('The match', 0),
        _undoLink('Ended the match by mistake? Back to the clock'),
      ];
    }
    final n = s.acts.length, outN = s.out.length;
    final timerOk = s.timerVer == s.timerSent && !s.needSetup;
    Widget st(bool ok, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            SizedBox(
                width: 26,
                child: Text(ok ? '✓' : '…',
                    style: V3.inter(17,
                        weight: FontWeight.w700,
                        color: ok ? V3.green : V3.amber))),
            const SizedBox(width: 8),
            Expanded(child: Text(t, style: V3.inter(16))),
          ]),
        );
    return [
      top,
      SkBoard(us: ctl.us, opp: ctl.opp, w: w, tag: 'FT', footer: _check()),
      Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(18)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.isFinal ? 'Match saved' : 'Saving the match',
              style: V3.inter(17, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          st(
              outN == 0,
              outN > 0
                  ? '$outN of $n entries still to upload'
                  : '$n score${n == 1 ? '' : 's'} and stats uploaded'),
          st(timerOk,
              timerOk ? 'Clock and halves saved' : 'Clock still to upload'),
          st(s.isFinal,
              s.isFinal ? 'Match finished and saved' : 'Finishing the match'),
          if (!s.isFinal)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  'If you lose signal here, it finishes saving by itself next time the app has signal. You can close this screen.',
                  style: V3.inter(14, color: V3.muted)),
            ),
        ]),
      ),
    ];
  }

  Widget _undoLink(String t) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(
          child: TextButton(
            onPressed: ctl.backToClock,
            style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
            child: Text(t,
                textAlign: TextAlign.center,
                style: V3.inter(15, color: V3.muted).copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: V3.muted)),
          ),
        ),
      );

  // -------------------------------------------------------------- recent

  List<Widget> _recent() {
    final s = ctl.s!, c = ctl.c!;
    final play = s.phase == 'play';
    final waiting = {for (final o in s.out) '${o['id']}'};
    // (half, sec, ts, act or sub)
    final items = <(int, int, int, SkAct?, SkSub?)>[
      for (final a in s.acts) (a.half, a.sec, a.ts, a, null),
      for (final x in s.subs) (x.half, x.sec, x.ts, null, x),
    ];
    // While playing: newest entry first. After: match order, latest first.
    items.sort((x, y) {
      if (play) {
        final t = y.$3 - x.$3;
        if (t != 0) return t;
        return y.$1 != x.$1 ? y.$1 - x.$1 : y.$2 - x.$2;
      }
      if (y.$1 != x.$1) return y.$1 - x.$1;
      if (y.$2 != x.$2) return y.$2 - x.$2;
      return y.$3 - x.$3;
    });
    if (items.isEmpty) {
      if (play) return const [];
      return [
        _listCard([
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Text('Nothing recorded',
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted)),
          )
        ])
      ];
    }
    final r = ctl.players;
    Widget row(String id, String minute, String title, String sub,
            {bool opp = false,
            bool corr = false,
            required VoidCallback onTap}) =>
        InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              SizedBox(
                  width: 56,
                  child: Text(minute,
                      style: V3.inter(16,
                          weight: FontWeight.w600,
                          color: opp ? skRed : V3.muted))),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: V3.inter(17)),
                      Text(sub,
                          style:
                              V3.inter(14, color: corr ? V3.amber : V3.muted)),
                    ]),
              ),
              waiting.contains(id)
                  ? const Icon(Icons.schedule, color: V3.amber, size: 20)
                  : const Icon(Icons.check, color: V3.green, size: 22),
            ]),
          ),
        );
    final rows = <Widget>[];
    for (final it in items) {
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1, thickness: 1, color: V3.line));
      }
      final x = it.$5;
      if (x != null) {
        rows.add(row(x.id, ctl.minute(x.half, x.sec), 'Sub',
            '${(r[x.on]?.full ?? '').isEmpty ? '?' : r[x.on]!.full} on for ${(r[x.off]?.full ?? '').isEmpty ? '?' : r[x.off]!.full}',
            onTap: () => showSkSubEdit(context, ctl, x.id)));
        continue;
      }
      final a = it.$4!;
      final (t, sub) = actLabel(s, c, a);
      rows.add(row(a.id, ctl.minute(a.half, a.sec), t, sub,
          opp: a.side == 'opp',
          corr: a.isCorrection,
          onTap: () => showSkEdit(context, ctl, a.id)));
    }
    return [
      Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Row(children: [
          Expanded(
              child: Text(play ? 'LATEST' : 'EVERYTHING RECORDED',
                  style: skCaps(size: 12))),
          Text('${items.length}', style: skCaps(size: 12)),
        ]),
      ),
      _listCard(rows),
    ];
  }

  Widget _listCard(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(18)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  // ---------------------------------------------------------------- foot

  Widget _foot() {
    final s = ctl.s!;
    final ph = s.phase, h = s.clock.half;
    final buttons = <Widget>[];
    if (ph == 'setup') {
      buttons.add(SkButton(
          label: 'Ready',
          tone: SkTone.green,
          onTap: () {
            final d = _draft;
            if (d != null && ctl.applySetup(d)) _draft = null;
          }));
    } else if (ph == 'play') {
      final endLabel = 'End ${h == 1 ? 'half' : 'match'}';
      if (!s.clock.run && ctl.sec == 0) {
        buttons.add(ValueListenableBuilder<bool>(
          valueListenable: ctl.pulseStart,
          builder: (_, pulse, __) => SkButton(
              label: 'Start ${h == 1 ? '1st' : '2nd'} half',
              icon: Icons.play_arrow_rounded,
              tone: SkTone.green,
              pulse: pulse,
              onTap: ctl.startClock),
        ));
      } else if (s.clock.run) {
        buttons.add(SkButton(
            label: 'Pause',
            icon: Icons.pause_rounded,
            tone: SkTone.amber,
            onTap: ctl.pauseClock));
        buttons.add(SkButton(label: endLabel, onTap: () => ctl.endHalf()));
      } else {
        buttons.add(SkButton(
            label: 'Resume',
            icon: Icons.play_arrow_rounded,
            tone: SkTone.green,
            onTap: ctl.startClock));
        buttons.add(SkButton(label: endLabel, onTap: () => ctl.endHalf()));
      }
    } else if (ph == 'ht') {
      buttons.add(SkButton(
          label: 'Start 2nd half',
          icon: Icons.play_arrow_rounded,
          tone: SkTone.green,
          onTap: ctl.startSecondHalf));
    } else if (ph == 'ft') {
      buttons.add(
          SkButton(label: 'View stats', onTap: () => ctl.setView('stats')));
      buttons.add(SkButton(
          label: 'Save match', tone: SkTone.green, onTap: ctl.finishMatch));
    } else {
      buttons.add(
          SkButton(label: 'View stats', onTap: () => ctl.setView('stats')));
      buttons.add(
          SkButton(label: 'Match report', tone: SkTone.green, onTap: _report));
    }
    return Container(
      color: V3.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: buttons[i]),
            ]
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ pieces

/// The clock: half, match time, and a bar that turns amber in injury time.
class _Clock extends StatelessWidget {
  const _Clock(this.ctl);
  final SkController ctl;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ctl.tick,
      builder: (_, __, ___) {
        final s = ctl.s!;
        if (s.phase != 'play') return const SizedBox.shrink();
        final sec = ctl.sec, dur = s.halfLen, h = s.clock.half;
        final inj = sec > dur;
        final paused = !s.clock.run && sec > 0;
        final hn = h == 1 ? 'First half' : 'Second half';
        final injMax = s.injLen > 60 ? s.injLen : 60;
        final main = (sec / dur).clamp(0.0, 1.0) * (inj ? .8 : 1);
        final extra = inj ? ((sec - dur) / injMax).clamp(0.0, 1.0) * .2 : 0.0;
        final time = fmtClock((h - 1) * dur + sec);
        return Semantics(
          liveRegion: false,
          label: '$hn, $time${paused ? ', paused' : ''}',
          child: Column(children: [
            Text.rich(
              TextSpan(style: skCaps(), children: [
                TextSpan(text: '${hn.toUpperCase()} · '),
                if (inj)
                  TextSpan(
                      text: 'INJURY TIME +${fmtClock(sec - dur)}',
                      style: skCaps(color: V3.amber))
                else
                  TextSpan(
                      text:
                          '${(dur / 60).round()} MIN${paused ? ' · PAUSED' : ''}'),
              ]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Opacity(
              opacity: paused ? .55 : 1,
              child:
                  Text(time, style: skNum(84, color: inj ? V3.amber : V3.text)),
            ),
            const SizedBox(height: 10),
            FractionallySizedBox(
              widthFactor: .72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: 6,
                  color: V3.card2,
                  child: LayoutBuilder(
                    builder: (_, b) => Row(children: [
                      Container(width: b.maxWidth * main, color: V3.green),
                      Container(width: b.maxWidth * extra, color: V3.amber),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// Two-way switch: Score/Stats, or Tap/Voice (green when on).
class _Segment extends StatelessWidget {
  const _Segment(
      {required this.options,
      required this.value,
      required this.onChanged,
      this.icons,
      this.green = false});
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;
  final List<IconData>? icons;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: options[i].$1 == value,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(options[i].$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 48,
                  decoration: BoxDecoration(
                    color: options[i].$1 == value
                        ? (green ? V3.green : V3.card2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icons != null) ...[
                          Icon(icons![i],
                              size: 20,
                              color: options[i].$1 == value
                                  ? (green ? V3.bg : V3.text)
                                  : V3.muted),
                          const SizedBox(width: 7),
                        ],
                        Text(options[i].$2,
                            style: V3.inter(16,
                                weight: FontWeight.w600,
                                color: options[i].$1 == value
                                    ? (green ? V3.bg : V3.text)
                                    : V3.muted)),
                      ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// The bar under a voice card that runs down until the card goes.
class _Countdown extends StatelessWidget {
  const _Countdown(this.card, this.ctl);
  final SkVCard card;
  final SkController ctl;

  @override
  Widget build(BuildContext context) {
    final left = (card.ms! - (ctl.nowMs - card.at)).clamp(0, card.ms!);
    return Container(
      height: 4,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
          color: V3.card2, borderRadius: BorderRadius.circular(2)),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(card.key),
        tween: Tween(begin: left / card.ms!, end: 0),
        duration: Duration(milliseconds: left),
        builder: (_, v, __) => FractionallySizedBox(
          widthFactor: v,
          child: Container(
              decoration: BoxDecoration(
                  color: V3.green, borderRadius: BorderRadius.circular(2))),
        ),
      ),
    );
  }
}

/// The bar that pops up after each tap, with Undo where there's one.
class _ToastBar extends StatelessWidget {
  const _ToastBar(this.shown, this.hide);
  final ValueNotifier<SkToast?> shown;
  final VoidCallback hide;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + 92;
    return ValueListenableBuilder<SkToast?>(
      valueListenable: shown,
      builder: (_, t, __) => Positioned(
        left: 16,
        right: 16,
        bottom: bottom,
        child: IgnorePointer(
          ignoring: t == null,
          child: AnimatedOpacity(
            opacity: t == null ? 0 : 1,
            duration: const Duration(milliseconds: 180),
            child: AnimatedSlide(
              offset: t == null ? const Offset(0, .3) : Offset.zero,
              duration: const Duration(milliseconds: 180),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 448),
                  child: Material(
                    color: const Color(0xFF2C323D),
                    elevation: 8,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(children: [
                        Text('✓',
                            style: V3.inter(16,
                                weight: FontWeight.w700, color: V3.green)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(t?.msg ?? '', style: V3.inter(16)),
                          ),
                        ),
                        if (t?.action != null)
                          TextButton(
                            style: TextButton.styleFrom(
                                minimumSize: const Size(64, 44)),
                            onPressed: () {
                              final f = t.onAction;
                              hide();
                              f?.call();
                            },
                            child: Text(t!.action!,
                                style: V3.inter(16,
                                    weight: FontWeight.w700, color: V3.green)),
                          )
                        else
                          const SizedBox(height: 44),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
