// v3 Lineup: a native copy of webviews/team_selector.html. Pick a format,
// drag players from the squad strip onto pitch positions or the bench,
// then Save (a new lineup version) and Share (a PNG of the lineup). Teams
// with teams.teamsheet on also get the Irish teamsheet PDF.
// Ken (2026-10-15): keep drag and drop, keep manual Save and Share, club
// colours, autosave allowed (here: when leaving the page or the app goes to
// the background), sub names must not overlap, no shirt-number override,
// no player sheet.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../v3_theme.dart';
import 'v3_lineup_api.dart';
import 'v3_lineup_models.dart';
import 'v3_lineup_paint.dart';
import 'v3_teamsheet.dart';
import '/v3/tracking/v3_track.dart';

class V3LineupPage extends StatefulWidget {
  const V3LineupPage(
      {super.key,
      required this.eventId,
      required this.teamId,
      this.squadId,
      this.testData});

  final int eventId;
  final int teamId;

  /// The squad picked on the event page; null or 0 means every squad.
  final int? squadId;

  /// Widget tests pass the loaded data here instead of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3LineupPage> createState() => _V3LineupPageState();
}

class _V3LineupPageState extends State<V3LineupPage>
    with WidgetsBindingObserver {
  LineupData? _data;
  LineupBoard _board = LineupBoard();
  bool _loading = true;
  String? _error;
  bool _dirty = false;
  Future<bool>? _saving;
  String? _busy; // 'save', 'share' or 'teamsheet'
  bool _dragging = false;
  final _pitchKey = GlobalKey();
  final _shareKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Autosave when the app goes to the background.
    if (state == AppLifecycleState.paused) _persist(quiet: true);
  }

  Future<void> _load() async {
    try {
      final j = widget.testData ??
          await fetchLineupJson(
              eventId: widget.eventId,
              teamId: widget.teamId,
              squadId: widget.squadId);
      final d = LineupData.fromJson(j);
      if (!mounted) return;
      setState(() {
        _data = d;
        _board = d.initialBoard();
        _dirty = false;
        _loading = false;
      });
      if (!d.hasMessage) {
        await WidgetsBinding.instance.endOfFrame;
        _snack(d.hasSavedLineup && !_board.isEmpty
            ? 'Previous lineup loaded'
            : '${d.players.length} player${d.players.length != 1 ? 's' : ''} loaded');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error loading squad';
      });
    }
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 2500),
          content: Text(text,
              textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
          backgroundColor: warn ? V3.amber : V3.green));
  }

  void _change(void Function() f) {
    setState(() {
      f();
      _dirty = true;
    });
  }

  // ---------------------------------------------------------------- saving

  /// Saves the board as a new lineup version when it has changed since the
  /// last save. quiet skips the snack (autosave).
  Future<bool> _persist({bool quiet = false}) async {
    if (_saving != null) await _saving;
    if (_board.isEmpty || !_dirty) return true;
    final snap = _board.copy();
    _dirty = false;
    final run = () async {
      try {
        if (widget.testData == null) {
          await saveLineup(snap,
              eventId: widget.eventId,
              teamId: widget.teamId,
              squadId: widget.squadId);
        }
        if (!quiet) _snack('Lineup saved!');
        return true;
      } catch (_) {
        _dirty = true;
        if (!quiet) {
          _snack('Save failed. Please try again.', warn: true);
        }
        return false;
      }
    }();
    _saving = run;
    final ok = await run;
    _saving = null;
    return ok;
  }

  Future<void> _save() async {
    setState(() => _busy = 'save');
    if (!_dirty) {
      _snack('Lineup saved!');
    } else {
      await _persist();
    }
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _share() async {
    final d = _data!;
    setState(() => _busy = 'share');
    try {
      final ok = await _persist(quiet: true);
      if (!ok) _snack('Save failed — lineup image still generated', warn: true);
      final png = await renderLineupPng(d, _board);
      final name = lineupFileName(d.teamName);
      if (widget.testData != null) return;
      final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
      V3Track.event('teamsheet_shared');
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: name)],
        fileNameOverrides: [name],
        title: 'CoachSmart Lineup',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (_) {
      _snack('Could not generate — try again', warn: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _teamsheet() async {
    final d = _data!;
    setState(() => _busy = 'teamsheet');
    try {
      final ts = await fetchTeamsheet(
          eventId: widget.eventId,
          teamId: widget.teamId,
          squadId: widget.squadId,
          teamName: d.teamName,
          players: d.players);
      final bytes = await buildTeamsheetPdf(ts, DateTime.now());
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          settings: const RouteSettings(name: 'V3TeamsheetPage'),
          builder: (_) => V3TeamsheetPage(
              bytes: bytes, fileName: teamsheetFileName(d.teamName))));
    } catch (_) {
      _snack('Could not generate teamsheet', warn: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // ---------------------------------------------------------------- picking

  /// Tap an empty position or sub slot: pick from the players not placed.
  Future<void> _pick({int? pos, int? sub}) async {
    final d = _data!;
    final avail = [
      for (final p in d.players)
        if (!_board.onPitch(p.id)) p
    ];
    if (avail.isEmpty) {
      _snack('All players are on the pitch');
      return;
    }
    final title = pos != null
        ? 'Position $pos · ${positionLabel(_board.format, pos)}'
        : 'Sub $sub · No. ${subShirt(_board.format, sub!)}';
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: V3.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .7),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: V3.barGrey, borderRadius: BorderRadius.circular(3))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(title, style: V3.tight(20))),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final p in avail)
                  ListTile(
                    minTileHeight: 52,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: V3.green,
                        child: Text(_initials(p.name),
                            style: V3.inter(13,
                                weight: FontWeight.w800, color: V3.bg))),
                    title: Text(p.name,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(17, weight: FontWeight.w500)),
                    onTap: () => Navigator.pop(ctx, p.id),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _change(() {
      if (pos != null) _board.assign[pos] = picked;
      if (sub != null) _board.subs[sub] = picked;
    });
  }

  static String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((x) => x.isNotEmpty)
      .map((x) => x[0])
      .take(2)
      .join()
      .toUpperCase();

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final ready = d != null && !d.hasMessage;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _persist(quiet: true); // autosave on the way out
      },
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: AppBar(
          backgroundColor: V3.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
              icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
              onPressed: () => Navigator.of(context).maybePop()),
          title: Text('Lineup', style: V3.tight(17)),
          actions: [
            if (ready && d.teamsheet)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: _busy == null ? _teamsheet : null,
                  style: TextButton.styleFrom(
                      foregroundColor: V3.green,
                      minimumSize: const Size(44, 44)),
                  icon: _busy == 'teamsheet'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: V3.green))
                      : const Icon(Icons.description_outlined, size: 22),
                  label: Text('Teamsheet',
                      style: V3.inter(15,
                          weight: FontWeight.w600, color: V3.green)),
                ),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: V3.green))
            : _error != null || d!.hasMessage
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(_error ?? d!.message,
                            textAlign: TextAlign.center,
                            style: V3.inter(17, color: V3.muted))))
                : Column(children: [
                    _formats(),
                    _strip(d),
                    Expanded(child: _pitchArea(d)),
                    _bench(d),
                    _actions(),
                  ]),
      ),
    );
  }

  Widget _formats() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
        child: Row(children: [
          Text('FORMAT',
              style: V3.inter(13,
                  weight: FontWeight.w700,
                  color: V3.muted,
                  letterSpacing: 1.2)),
          const SizedBox(width: 12),
          for (final f in kFormats)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _Pill(
                  label: '$f',
                  on: _board.format == f,
                  onTap: () {
                    if (_board.format != f) _change(() => _board.setFormat(f));
                  },
                ),
              ),
            ),
        ]),
      );

  Widget _ghost(String name) => FractionalTranslation(
        translation: const Offset(-.5, -1.7),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
                color: V3.green,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x80000000),
                      blurRadius: 14,
                      offset: Offset(0, 4))
                ]),
            child: Text(name,
                style: V3.inter(15, weight: FontWeight.w700, color: V3.bg)),
          ),
        ),
      );

  /// Shared Draggable setup: the ghost sits above the finger and the drop
  /// spot is the finger itself.
  Widget _draggable(
      {required LineupDrag data,
      required String name,
      required Widget child,
      Widget? whenDragging,
      Axis? affinity}) {
    return Draggable<LineupDrag>(
      data: data,
      affinity: affinity,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _ghost(name),
      childWhenDragging: whenDragging ?? Opacity(opacity: .3, child: child),
      onDragStarted: () {
        HapticFeedback.selectionClick();
        setState(() => _dragging = true);
      },
      onDragEnd: (_) => setState(() => _dragging = false),
      onDraggableCanceled: (_, offset) {
        // A pitch player let go off the pitch comes off (as on the web).
        if (data.from != DragFrom.pos) return;
        final box = _pitchKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final r = box.localToGlobal(Offset.zero) & box.size;
        if (!r.contains(offset)) _change(() => _board.remove(data));
      },
      child: child,
    );
  }

  // Squad strip: drag a name down onto the pitch; drop a placed player
  // back here to take them off.
  Widget _strip(LineupData d) {
    return DragTarget<LineupDrag>(
      onWillAcceptWithDetails: (det) => det.data.from != DragFrom.strip,
      onAcceptWithDetails: (det) => _change(() => _board.remove(det.data)),
      builder: (ctx, cand, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 64,
        decoration: BoxDecoration(
            color: cand.isNotEmpty ? V3.greenTint : V3.card,
            border: Border(
                top: BorderSide(
                    color: cand.isNotEmpty ? V3.green : V3.line, width: 1),
                bottom: BorderSide(
                    color: cand.isNotEmpty ? V3.green : V3.line, width: 1))),
        child: d.players.isEmpty
            ? Center(
                child: Text('No players loaded',
                    style: V3.inter(15, color: V3.muted)))
            : ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < d.players.length; i++)
                    Center(child: _chip(d.players[i], i + 1)),
                ],
              ),
      ),
    );
  }

  Widget _chip(LineupPlayer p, int n) {
    final placed = _board.onPitch(p.id);
    final chip = Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
      decoration: BoxDecoration(
          color: V3.card2,
          border: Border.all(color: V3.line),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration:
              const BoxDecoration(color: V3.green, shape: BoxShape.circle),
          child: Text('$n',
              style: V3.inter(12, weight: FontWeight.w800, color: V3.bg)),
        ),
        const SizedBox(width: 8),
        Text(p.name, style: V3.inter(15, weight: FontWeight.w500)),
      ]),
    );
    if (placed) return Opacity(opacity: .3, child: chip);
    // Vertical affinity: sideways swipes still scroll the strip.
    return _draggable(
        data: LineupDrag(p.id, DragFrom.strip),
        name: p.name,
        affinity: Axis.vertical,
        child: chip);
  }

  Widget _pitchArea(LineupData d) {
    return LayoutBuilder(builder: (ctx, c) {
      var h = c.maxHeight - 16;
      var w = h * kPitchRatio;
      if (w > c.maxWidth - 16) {
        w = c.maxWidth - 16;
        h = w / kPitchRatio;
      }
      return Center(
          child: SizedBox(
              key: _pitchKey, width: w, height: h, child: _pitch(d, w, h)));
    });
  }

  Widget _pitch(LineupData d, double w, double h) {
    final gap = rowGap(_board.format, h);
    final jh = (gap * .56).clamp(26.0, 44.0);
    final jw = jh * .9;
    final room = gap - jh - 4;
    final nameW = w * .30 - 10;
    final hit = jh < 48 ? 48.0 : jh;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x8C000000),
                    blurRadius: 32,
                    offset: Offset(0, 8))
              ]),
          child: CustomPaint(painter: PitchPainter()),
        ),
      ),
      for (final pos in positionsFor(_board.format))
        Positioned(
          left: pos.x / 100 * w - (nameW + 10) / 2,
          top: dispY(pos.y) / 100 * h - hit / 2,
          width: nameW + 10,
          child: _position(d, pos, jw, jh, hit, room),
        ),
      if (_board.assign.isEmpty && !_dragging)
        Positioned(
          left: 0,
          right: 0,
          bottom: 10,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0x80000000),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('Drag players onto positions · Tap to assign',
                    style: V3.inter(12, color: const Color(0xCCFFFFFF))),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _position(LineupData d, LinePos pos, double jw, double jh, double hit,
      double room) {
    final id = _board.assign[pos.n];
    final pl = id == null ? null : d.player(id);
    final keeper = pos.n == 1;
    Widget jersey(bool filled, bool over) => SizedBox(
        width: jw,
        height: jh,
        child: CustomPaint(
            painter: JerseyPainter(pos.n,
                keeper: keeper, filled: filled, kit: d.kit, highlight: over)));

    final target = DragTarget<LineupDrag>(
      onAcceptWithDetails: (det) =>
          _change(() => _board.dropOnPosition(det.data, pos.n)),
      builder: (ctx, cand, _) {
        final over = cand.isNotEmpty;
        Widget face = AnimatedScale(
            scale: over ? 1.2 : 1,
            duration: const Duration(milliseconds: 120),
            child: jersey(pl != null, over));
        face = SizedBox(width: hit, height: hit, child: Center(child: face));
        if (pl == null) {
          return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _pick(pos: pos.n),
              child: face);
        }
        return Stack(clipBehavior: Clip.none, children: [
          _draggable(
              data: LineupDrag(pl.id, DragFrom.pos, pos.n),
              name: pl.name,
              whenDragging: SizedBox(
                  width: hit,
                  height: hit,
                  child: Center(child: jersey(false, false))),
              child: face),
          Positioned(
              right: (hit - jw) / 2 - 16,
              top: (hit - jh) / 2 - 16,
              child: _RemoveDot(
                  label: 'Take ${pl.name} off',
                  onTap: () => _change(() => _board.assign.remove(pos.n)))),
        ]);
      },
    );

    final fit = pl == null ? null : fitName(pl.name, room);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      target,
      Transform.translate(
        offset: Offset(0, -(hit - jh) / 2 + 1),
        child: pl == null
            ? IgnorePointer(
                child: Text(pos.l,
                    style: V3.inter(10,
                        weight: FontWeight.w600,
                        color: const Color(0xB3FFFFFF))))
            : IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(5, 1, 5, 2),
                  decoration: BoxDecoration(
                      color: const Color(0x8C000000),
                      borderRadius: BorderRadius.circular(5)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (final l in fit!.lines)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(l,
                            maxLines: 1,
                            style: V3.inter(fit.size,
                                weight: FontWeight.w700,
                                height: fit.lines.length == 2 && fit.size < 11
                                    ? 1.05
                                    : 1.2,
                                color: Colors.white)),
                      ),
                  ]),
                ),
              ),
      ),
    ]);
  }

  // Bench: five slots in equal columns; each name is cut to its own column
  // so names never overlap (Ken, 2026-10-15).
  Widget _bench(LineupData d) {
    return Container(
      color: V3.card,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 18),
          child: Text('SUBS',
              style: V3.inter(13,
                  weight: FontWeight.w700,
                  color: V3.muted,
                  letterSpacing: 1.2)),
        ),
        for (var n = 1; n <= kSubSlots; n++) Expanded(child: _subSlot(d, n)),
      ]),
    );
  }

  Widget _subSlot(LineupData d, int n) {
    final id = _board.subs[n];
    final pl = id == null ? null : d.player(id);
    final shirt = subShirt(_board.format, n);
    return DragTarget<LineupDrag>(
      onAcceptWithDetails: (det) =>
          _change(() => _board.dropOnSub(det.data, n)),
      builder: (ctx, cand, _) {
        final over = cand.isNotEmpty;
        final slot = Container(
          width: 50,
          height: 52,
          decoration: BoxDecoration(
            color: over ? V3.greenTint : V3.card2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
                color: over ? V3.green : V3.line, width: over ? 1.5 : 1),
          ),
          alignment: Alignment.center,
          child: pl == null
              ? Text('$shirt',
                  style: V3.inter(14, weight: FontWeight.w600, color: V3.muted))
              : SizedBox(
                  width: 36,
                  height: 40,
                  child: CustomPaint(
                      painter: JerseyPainter(shirt,
                          keeper: false, filled: true, kit: d.kit))),
        );
        Widget top = pl == null
            ? GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pick(sub: n),
                child: slot)
            : Stack(clipBehavior: Clip.none, children: [
                _draggable(
                    data: LineupDrag(pl.id, DragFrom.sub, n),
                    name: pl.name,
                    child: slot),
                Positioned(
                    right: -8,
                    top: -8,
                    child: _RemoveDot(
                        label: 'Take ${pl.name} off the bench',
                        onTap: () => _change(() => _board.subs.remove(n)))),
              ]);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          top,
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            child: Text(pl == null ? '' : shortName(pl.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: V3.inter(13, weight: FontWeight.w500, color: V3.text)),
          ),
        ]);
      },
    );
  }

  Widget _actions() {
    final empty = _board.isEmpty;
    final busy = _busy != null;
    return Container(
      color: V3.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: empty || busy ? null : _save,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: V3.green,
                      disabledForegroundColor: V3.muted.withValues(alpha: .5),
                      side: BorderSide(
                          color: empty ? V3.line : V3.green, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.check, size: 22),
                  label: Text(_busy == 'save' ? 'Saving…' : 'Save',
                      style: V3
                          .inter(17, weight: FontWeight.w700)
                          .copyWith(color: null)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                key: _shareKey,
                height: 50,
                child: FilledButton.icon(
                  onPressed: empty || busy ? null : _share,
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      disabledBackgroundColor: V3.card2,
                      disabledForegroundColor: V3.muted,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.ios_share, size: 22),
                  label: Text(_busy == 'share' ? 'Generating…' : 'Share',
                      style: V3
                          .inter(17, weight: FontWeight.w700)
                          .copyWith(color: null)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? V3.green : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: on ? V3.green : V3.line, width: 1.5),
          ),
          child: Text(label,
              style: V3.inter(17,
                  weight: FontWeight.w700, color: on ? V3.bg : V3.text)),
        ),
      );
}

/// Small red x on a placed player, with a 36px tap area.
class _RemoveDot extends StatelessWidget {
  const _RemoveDot({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Container(
                width: 20,
                height: 20,
                decoration:
                    const BoxDecoration(color: V3.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      );
}
