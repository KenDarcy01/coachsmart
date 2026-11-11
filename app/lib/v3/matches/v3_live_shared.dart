// Shared by the v3 Matches list and live match pages (the native copy of
// webviews/cs-live.js): live updates (Realtime on live_pulse plus polling as
// a backup), following a match and its alert choices, and small widgets.
import 'dart:async';

import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_matches_models.dart';
import '/v3/tracking/v3_track.dart';

// ───────────────────────────────────────────────────────────── live updates

/// Realtime on live_pulse (a counter per match that the database bumps on
/// every change), plus polling: [fast] while Realtime is not connected,
/// [slow] once it is. [onChange] re-reads; calls never overlap.
class LivePulse with WidgetsBindingObserver {
  LivePulse(
      {required this.onChange,
      this.fast = const Duration(seconds: 6),
      this.slow = const Duration(seconds: 20)}) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Future<void> Function() onChange;
  final Duration fast, slow;
  static int _seq = 0;

  final List<RealtimeChannel> _channels = [];
  final Set<RealtimeChannel> _joined = {};
  Timer? _timer;
  bool _busy = false, _again = false, _paused = false, _disposed = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  List<int> _ids = const [];

  bool get _live => _channels.isNotEmpty && _joined.length == _channels.length;

  void refresh() {
    if (_disposed) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    _last = DateTime.now();
    Future.sync(onChange).catchError((_) {}).whenComplete(() {
      _busy = false;
      if (_again && !_disposed) {
        _again = false;
        Future.delayed(const Duration(milliseconds: 300), refresh);
      }
    });
  }

  void _poll() {
    _timer?.cancel();
    if (_disposed) return;
    final live = _live;
    _timer = Timer.periodic(live ? slow : fast, (_) {
      if (_paused) return;
      final gap = DateTime.now().difference(_last);
      if (gap > (live ? const Duration(seconds: 3) : Duration.zero)) refresh();
    });
  }

  /// Listen to these events (the list changes as matches come and go).
  void subscribe(List<int> ids) {
    if (_disposed) return;
    final same = ids.length == _ids.length && ids.toSet().containsAll(_ids);
    if (same && _timer != null) return;
    _ids = List.of(ids);
    _removeChannels();
    _poll();
    if (ids.isEmpty) return;
    final client = SupaFlow.client;
    // One channel per match (an in.() filter would quote the ids)
    for (final id in ids.take(25)) {
      late final RealtimeChannel ch;
      ch = client
          .channel('v3-pulse-$id-${++_seq}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_pulse',
            filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'event_id',
                value: id),
            callback: (_) => refresh(),
          )
          .subscribe((status, _) {
        final was = _live;
        if (status == RealtimeSubscribeStatus.subscribed) {
          _joined.add(ch);
        } else {
          _joined.remove(ch);
        }
        if (_live != was) _poll();
      });
      _channels.add(ch);
    }
  }

  void _removeChannels() {
    for (final ch in _channels) {
      try {
        SupaFlow.client.removeChannel(ch);
      } catch (_) {}
    }
    _channels.clear();
    _joined.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) refresh();
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _removeChannels();
  }
}

// ───────────────────────────────────────────────────────────── following

Future<LiveFollow> _setFollow(int eventId, String? level,
    {bool kickoff = true, bool names = true}) async {
  V3Track.event(level == null ? 'live_match_unfollowed' : 'live_match_followed',
      {'event_id': eventId, 'level': level});
  final r = await SupaFlow.client.rpc('set_live_follow', params: {
    'p_event_id': eventId,
    'p_level': level,
    'p_kickoff': kickoff,
    'p_names': names,
  });
  return LiveFollow.fromJson(r is Map ? r : const {});
}

/// The bell on a match: follow straight away (every score), or, once
/// following, open the choices to change or stop.
Future<void> liveBell(BuildContext context,
    {required int eventId,
    required String sub,
    required LiveFollow follow,
    required void Function(LiveFollow f, String message) onChange,
    required VoidCallback onError}) async {
  if (!follow.on) {
    try {
      onChange(await _setFollow(eventId, 'all'),
          "Following: you'll get every score. Tap the bell to change.");
    } catch (_) {
      onError();
    }
    return;
  }
  final ch = await showAlertSheet(context, sub: sub, follow: follow);
  if (ch == null) return;
  try {
    final nf = ch.level == 'off'
        ? await _setFollow(eventId, null)
        : await _setFollow(eventId, ch.level,
            kickoff: ch.kickoff, names: ch.names);
    onChange(
        nf,
        ch.level == 'off'
            ? 'Stopped following this match'
            : "Saved. You'll get ${levelLabel(ch.level).toLowerCase()}.");
  } catch (_) {
    onError();
  }
}

/// The alert choices sheet. Returns the choice, or null when dismissed.
Future<LiveFollow?> showAlertSheet(BuildContext context,
    {required String sub, required LiveFollow follow}) {
  var level = follow.level;
  var kickoff = follow.kickoff;
  var names = follow.names;
  return showModalBottomSheet<LiveFollow>(
    context: context,
    backgroundColor: V3.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
      Widget row(String title, String small, Widget end, VoidCallback onTap,
              {bool last = false}) =>
          InkWell(
            onTap: () => set(onTap),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  border: last
                      ? null
                      : const Border(bottom: BorderSide(color: V3.line))),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title, style: V3.inter(17, weight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(small,
                          style: V3.inter(14, color: V3.muted, height: 1.3)),
                    ])),
                const SizedBox(width: 12),
                end,
              ]),
            ),
          );
      Widget radio(bool on) => Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: on ? V3.green : V3.barGrey, width: on ? 7 : 2)),
          );
      Widget toggle(bool on, ValueChanged<bool> f) => Switch(
          value: on,
          onChanged: (v) => set(() => f(v)),
          activeTrackColor: V3.green,
          activeThumbColor: Colors.white);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: V3.barGrey,
                          borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              Text('Alerts for this match', style: V3.tight(21)),
              const SizedBox(height: 2),
              Text(sub.isEmpty ? 'Sent to your phone as they happen' : sub,
                  style: V3.inter(14, color: V3.muted)),
              const SizedBox(height: 4),
              for (final (k, t, s) in alertLevels)
                row(t, s, radio(level == k), () => level = k, last: k == 'off'),
              const SizedBox(height: 14),
              Text('ALSO',
                  style: V3.inter(12,
                      weight: FontWeight.w700,
                      color: V3.green,
                      letterSpacing: 1.5)),
              row(
                  'Throw-in alerts',
                  'Start of each half',
                  toggle(kickoff, (v) => kickoff = v),
                  () => kickoff = !kickoff),
              row('Name the scorer', 'When the coach names a player',
                  toggle(names, (v) => names = v), () => names = !names,
                  last: true),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.pop(ctx,
                      LiveFollow(level: level, kickoff: kickoff, names: names)),
                  child: Text('Save',
                      style:
                          V3.inter(17, weight: FontWeight.w700, color: V3.bg)),
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}

// ───────────────────────────────────────────────────────────── widgets

/// Bell button: green when following. At least 44px.
class LiveBellButton extends StatelessWidget {
  const LiveBellButton({super.key, required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: on ? 'Alerts on' : 'Follow',
        child: Material(
          color: on ? V3.greenTint : V3.card2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(
                    on
                        ? Icons.notifications_active
                        : Icons.notifications_none_rounded,
                    size: 24,
                    color: on ? V3.green : V3.muted)),
          ),
        ),
      );
}

/// A blinking dot for LIVE.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 7, this.color = Colors.white});
  final double size;
  final Color color;
  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity:
              _c.value < .5 ? 1 - _c.value * 1.5 : .25 + (_c.value - .5) * 1.5,
          child: Container(
              width: widget.size,
              height: widget.size,
              decoration:
                  BoxDecoration(color: widget.color, shape: BoxShape.circle)),
        ),
      );
}

/// LIVE 41' / HALF TIME / FULL TIME / NOT STARTED pills.
class PhasePill extends StatelessWidget {
  const PhasePill(this.kind, this.text, {super.key, this.size = 12});

  /// live, ht, ft, up (amber text), or plain.
  final String kind;
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      'live' => (V3.red, Colors.white),
      'ht' => (V3.amber, V3.bg),
      'up' => (V3.amberTint, V3.amberText),
      _ => (V3.card2, V3.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (kind == 'live') ...[
          const LiveDot(),
          const SizedBox(width: 6),
        ],
        Text(text,
            style: V3.inter(size,
                weight: FontWeight.w800, color: fg, letterSpacing: 1)),
      ]),
    );
  }
}

/// Big score digits (the web page uses Bebas Neue; v3 uses Inter Tight).
TextStyle scoreStyle(double size, {Color color = V3.text}) =>
    V3.tight(size, weight: FontWeight.w700, color: color, height: 1.05);

void liveSnack(BuildContext context, String text, {bool warn = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
      content: Text(text,
          textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
      backgroundColor: warn ? V3.amber : V3.green));
}
