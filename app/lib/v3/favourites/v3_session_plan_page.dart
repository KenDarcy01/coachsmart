// A generated or saved session plan (the plan screen of
// webviews/favourites.html): tap any text to edit it, change the whole plan
// or one section with the shared voice panel, undo the last change, save
// (new, update or a copy), add to or remove from the club, and export the
// PDF for a phone or A4.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../games/v3_games.dart' show openGameVideo, youtubeIdOf, youtubeThumb;
import '../match_report/v3_voice_sheet.dart';
import '../v3_theme.dart';
import 'v3_fav_widgets.dart';
import 'v3_favourites_api.dart';
import 'v3_favourites_models.dart';
import 'v3_my_plans_page.dart';

const _warm = Color(0xFFF59E0B);
const _cool = Color(0xFF60A5FA);

class V3SessionPlanPage extends StatefulWidget {
  const V3SessionPlanPage({
    super.key,
    required this.plan,
    this.planId,
    this.isDraft = false,
    this.isOwn = true,
    this.isShared = false,
    this.fromSetup = false,
    this.durationMins = 60,
    this.refusal,
    this.eventId,
    this.api = const V3FavouritesApi(),
    this.dictation,
  });

  /// The plan_json.
  final Map<String, dynamic> plan;

  /// session_plans.plan_id; null for an unsaved draft.
  final int? planId;
  final bool isDraft, isOwn, isShared;

  /// Opened from Build Session Plan: shows "Back to Setup".
  final bool fromSetup;

  /// The setup's length, shown when the plan has no total.
  final int durationMins;

  /// The AI declined the request (shown above the refine box).
  final String? refusal;

  /// Passed on to My Plans (Attach to Event).
  final int? eventId;
  final V3FavouritesApi api;

  /// Tests pass a fake recogniser for the voice panel.
  @visibleForTesting
  final V3Dictation? dictation;

  @override
  State<V3SessionPlanPage> createState() => _V3SessionPlanPageState();
}

class _V3SessionPlanPageState extends State<V3SessionPlanPage> {
  late Map<String, dynamic> _plan = copyPlan(widget.plan);
  late int? _planId = widget.planId;
  late bool _isDraft = widget.isDraft;
  late bool _isOwn = widget.isOwn;
  late bool _isShared = widget.isShared;
  bool _dirty = false;
  ({Map<String, dynamic> plan, bool dirty})? _undo;
  PlanChanges? _changes;
  late String? _refusal = widget.refusal;
  int _v = 0; // bumps when the plan is redrawn, so edit boxes reload
  bool _pdfBusy = false, _saving = false, _sharing = false;
  ValueNotifier<V3SheetNote?>? _sheetNote;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String t, {bool warn = false, bool success = false, int? ms}) {
    if (!mounted) return;
    final n = _sheetNote;
    if (n != null && ms != 0) {
      n.value = V3SheetNote(t, error: warn);
      return;
    }
    favSnack(context, t, warn: warn, success: success, ms: ms);
  }

  String get _title {
    final t = '${_plan['session_title'] ?? ''}'.trim();
    return t.isEmpty ? 'Session Plan' : t;
  }

  /// opts.keepState: keep save state and undo (a revision or an undo).
  void _render(Map<String, dynamic> plan,
      {bool keepState = false, PlanChanges? changes}) {
    setState(() {
      _plan = plan;
      _v++;
      if (!keepState) {
        _dirty = false;
        _undo = null;
      }
      _changes = changes;
    });
    if (changes != null && changes.list.isNotEmpty && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _edit(String path, String text) {
    setPlanPath(_plan, path, text.trim());
    if (!_dirty || path == 'session_title') setState(() => _dirty = true);
  }

  // ------------------------------------------------------------ revisions

  Future<bool> _revise(
      String feedback, ({String path, String name})? target) async {
    final prior = copyPlan(_plan);
    try {
      final r = await widget.api.plan('revise_plan', {
        'feedback': feedback,
        'existing_plan': prior,
        if (target != null) 'target': target.path,
      });
      final d = r.data;
      if (!mounted) return true;
      if (d['refusal'] != null) {
        setState(() => _refusal = '${d['refusal']}');
        favClearSnack(context);
        return true;
      }
      final next = d['plan'];
      if (!r.ok || next is! Map) {
        _snack('${d['message'] ?? d['error'] ?? 'Update failed.'}', warn: true);
        return false;
      }
      _undo = (plan: prior, dirty: _dirty);
      _dirty = true;
      final plan = Map<String, dynamic>.from(next);
      final changes = diffPlans(prior, plan);
      _render(plan, keepState: true, changes: changes);
      if (changes.list.isEmpty) {
        _snack('No changes were needed', success: true);
      }
      return true;
    } catch (_) {
      _snack('Update failed — please try again', warn: true);
      return false;
    }
  }

  Future<void> _openRefine([({String path, String name})? target]) async {
    if (_sheetNote != null) return;
    FocusScope.of(context).unfocus();
    final note = _sheetNote = ValueNotifier<V3SheetNote?>(null);
    await showV3VoiceSheet(
      context,
      title: target != null ? 'Change: ${target.name}' : 'Change this plan',
      subtitle: target != null
          ? 'Only this part of the plan will change.'
          : 'Say or type what you would like changed.',
      placeholder: target != null
          ? 'e.g. make it easier for U10s, bigger channel'
          : 'e.g. 15 mins on the warm-up, more possession drills',
      submitLabel: 'Update',
      busyLabel: 'Updating…',
      onSubmit: (text) {
        if (_refusal != null) setState(() => _refusal = null);
        return _revise(text, target);
      },
      onError: (m) => _snack(m, warn: true),
      note: note,
      dictation: widget.dictation,
    );
    _sheetNote = null;
    final last = note.value;
    if (last != null && mounted) _snack(last.text, warn: last.error);
  }

  void _askChange(String path) =>
      _openRefine((path: path, name: sectionName(_plan, path)));

  void _undoRevision() {
    final u = _undo;
    if (u == null) return;
    _undo = null;
    _dirty = u.dirty;
    _render(u.plan, keepState: true);
    _snack('Change undone', success: true);
  }

  // ---------------------------------------------------------- save / share

  Future<Map<String, dynamic>?> _saveCall(
      String action, Map<String, dynamic> body, String okMsg) async {
    setState(() => _saving = true);
    _snack('Saving…', ms: 0);
    try {
      final r = await widget.api.plan(action, body);
      if (!mounted) return null;
      favClearSnack(context);
      if (!r.ok || r.error != null) {
        _snack(r.error ?? 'Could not save', warn: true);
        return null;
      }
      _snack(okMsg, success: true);
      return r.data;
    } catch (_) {
      if (mounted) favClearSnack(context);
      _snack('Network error — could not save', warn: true);
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A plan already in My Plans asks whether to update it or save a copy.
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_isOwn && _planId != null && !_isDraft) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: V3.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetGrab(),
                  Text('Save changes', style: V3.tight(19)),
                  const SizedBox(height: 6),
                  Text('This plan is already in My Plans.',
                      style: V3.inter(16, color: V3.muted)),
                  const SizedBox(height: 18),
                  FavButton(
                      label: 'Update this plan',
                      onPressed: () => Navigator.pop(ctx, 'update')),
                  const SizedBox(height: 10),
                  FavButton(
                      label: 'Save as a new copy',
                      primary: false,
                      onPressed: () => Navigator.pop(ctx, 'new')),
                ]),
          ),
        ),
      );
      if (choice == 'update') await _updateSaved();
      if (choice == 'new') await _saveNew();
      return;
    }
    await _saveNew();
  }

  Future<void> _saveNew() async {
    final plan = copyPlan(_plan);
    final d = await _saveCall('save_plan', {'plan_json': plan}, 'Plan saved ✓');
    final id = d?['plan_id'];
    if (id == null || !mounted) return;
    setState(() {
      _planId = id is int ? id : int.tryParse('$id');
      _isDraft = false;
      _dirty = false;
      _isOwn = true;
      _isShared = false;
    });
  }

  Future<void> _updateSaved() async {
    final plan = copyPlan(_plan);
    final d = await _saveCall('update_plan',
        {'plan_id': _planId, 'plan_json': plan}, 'Plan updated ✓');
    if (d == null || !mounted) return;
    setState(() => _dirty = false);
  }

  Future<void> _setClub(bool shared) async {
    if (_planId == null) {
      if (shared) _snack('Save the plan first before sharing', warn: true);
      return;
    }
    setState(() => _sharing = true);
    _snack(shared ? 'Sharing…' : 'Removing…', ms: 0);
    try {
      final r = await widget.api
          .plan('set_plan_club', {'plan_id': _planId, 'shared': shared});
      if (!mounted) return;
      favClearSnack(context);
      if (!r.ok || r.data['ok'] != true) {
        _snack(r.error ?? (shared ? 'Share failed' : 'Could not remove'),
            warn: true);
        return;
      }
      if (!shared) {
        setState(() => _isShared = false);
        _snack('Removed from club ✓', success: true);
      } else if (r.data['club_id'] != null) {
        setState(() => _isShared = true);
        _snack('Shared with your club ✓', success: true);
      } else {
        _snack('No club found on your account', warn: true);
      }
    } catch (_) {
      if (mounted) favClearSnack(context);
      _snack('Network error', warn: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _exportPdf() async {
    FocusScope.of(context).unfocus();
    final layout = await pickPdfLayout(context, 'Export PDF');
    if (layout == null || !mounted) return;
    if (_isDraft) {
      _snack('Exporting draft — this plan is not saved yet', warn: true);
    }
    setState(() => _pdfBusy = true);
    try {
      final (bytes, name) =
          await widget.api.planPdf(copyPlan(_plan), layout: layout);
      await sharePdfBytes(bytes, name);
    } catch (_) {
      _snack('Could not generate PDF — please try again', warn: true);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  void _openMyPlans() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            V3MyPlansPage(api: widget.api, eventId: widget.eventId)));
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final bar = planBar(
        planId: _planId,
        isDraft: _isDraft,
        isOwn: _isOwn,
        isShared: _isShared,
        isDirty: _dirty);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: favAppBar(
          context,
          Text(_title, overflow: TextOverflow.ellipsis, style: V3.tight(18)),
          actions: [
            if (bar.pill != null) _SavePill(bar.pill!),
            const SizedBox(width: 6),
            MyPlansPill(onTap: _openMyPlans, compact: true),
          ],
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(bottom: 16),
          children: _content(),
        ),
        bottomNavigationBar: _footer(bar),
      ),
    );
  }

  List<Widget> _content() {
    final p = _plan;
    final chg = _changes;
    final out = <Widget>[];
    if (widget.fromSetup) {
      out.add(Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ActionChip(
            onPressed: () => Navigator.of(context).maybePop(),
            backgroundColor: V3.card,
            side: const BorderSide(color: V3.line, width: 1.5),
            shape: const StadiumBorder(),
            avatar: const Icon(Icons.chevron_left, color: V3.green, size: 22),
            label: Text('Back to Setup',
                style: V3.inter(15, weight: FontWeight.w600, color: V3.muted)),
          ),
        ),
      ));
    }
    if (chg != null && chg.list.isNotEmpty && _undo != null) {
      final n = chg.list.length;
      out.add(Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
            color: V3.greenTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V3.green.withValues(alpha: 0.35))),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Plan updated · $n change${n == 1 ? '' : 's'}',
                  style: V3.inter(16, weight: FontWeight.w600)),
              Text(chg.list.join(', '), style: V3.inter(14, color: V3.muted)),
            ]),
          ),
          TextButton(
            onPressed: _undoRevision,
            style: TextButton.styleFrom(
                minimumSize: const Size(64, 44),
                shape: const StadiumBorder(
                    side: BorderSide(color: V3.green, width: 1.5))),
            child: Text('Undo',
                style: V3.inter(15, weight: FontWeight.w600, color: V3.green)),
          ),
        ]),
      ));
    }
    out.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(children: [
        const Icon(Icons.edit_outlined, size: 15, color: V3.muted),
        const SizedBox(width: 6),
        Text('Tap any text to edit', style: V3.inter(14, color: V3.muted)),
      ]),
    ));
    // Plan name
    out.add(Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: V3.green)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FavFieldLabel('Plan Name', color: V3.green),
        _Ed(
          key: ValueKey('$_v:session_title'),
          text: '${p['session_title'] ?? ''}',
          style: V3.tight(20, weight: FontWeight.w700),
          onChanged: (t) => _edit('session_title', t),
        ),
      ]),
    ));
    final objective = '${p['session_objective'] ?? ''}';
    if (objective.trim().isNotEmpty) {
      out.add(_sHdr('FOCUS', null, V3.green,
          changed: chg?.has('session_objective') == true, wasDur: null));
      out.add(Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: V3.greenTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: chg?.has('session_objective') == true
                    ? V3.green
                    : V3.green.withValues(alpha: 0.18))),
        child: _Ed(
          key: ValueKey('$_v:session_objective'),
          text: objective,
          style:
              V3.inter(16, height: 1.5).copyWith(fontStyle: FontStyle.italic),
          onChanged: (t) => _edit('session_objective', t),
        ),
      ));
    }
    final players = p['player_count'], coaches = p['coach_count'];
    if (_truthy(players) || _truthy(coaches)) {
      out.add(Container(
        color: V3.card2,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          _Stat(_truthy(players) ? '$players' : '—', 'Players'),
          const SizedBox(width: 8),
          _Stat(_truthy(coaches) ? '$coaches' : '—', 'Coaches'),
          const SizedBox(width: 8),
          _Stat('${p['total_duration_mins'] ?? widget.durationMins}', 'Mins'),
        ]),
      ));
    }
    void phase(String key, String label, Color dot) {
      final s = p[key];
      if (s is! Map) return;
      out.add(_sHdr(label, minsOf(s), dot,
          path: key,
          changed: chg?.has(key) == true,
          wasDur: chg?.changed[key]));
      out.add(_phaseCard(s, key, null, chg?.has(key) == true));
    }

    phase('pre_session', 'PRE-SESSION', _warm);
    phase('warm_up', 'WARM UP', _warm);
    final station = '${p['station_setup'] ?? ''}'.trim();
    if (station.isNotEmpty) {
      final c = chg?.has('station_setup') == true;
      out.add(_sHdr('STATION SETUP', null, V3.green, changed: c));
      out.add(Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: V3.card2,
          borderRadius: BorderRadius.circular(14),
          border: Border(
              left: const BorderSide(color: V3.green, width: 3),
              top: BorderSide(color: c ? V3.green : V3.line),
              right: BorderSide(color: c ? V3.green : V3.line),
              bottom: BorderSide(color: c ? V3.green : V3.line)),
        ),
        child: Text(station, style: V3.inter(16, height: 1.55)),
      ));
    }
    final drills = p['drills'] is List ? p['drills'] as List : const [];
    for (var i = 0; i < drills.length; i++) {
      final d = drills[i];
      if (d is! Map) continue;
      final key = 'drills.$i';
      out.add(_sHdr('DRILL ${i + 1}', minsOf(d), V3.green,
          path: key,
          changed: chg?.has(key) == true,
          wasDur: chg?.changed[key]));
      out.add(_phaseCard(d, key, i + 1, chg?.has(key) == true));
    }
    phase('cool_down', 'COOL DOWN', _cool);
    phase('post_session', 'POST-SESSION', _cool);
    return out;
  }

  static bool _truthy(dynamic v) =>
      v != null && v != 0 && v != '' && v != false && '$v' != '0';

  Widget _sHdr(String label, int? dur, Color dot,
      {String? path, bool changed = false, int? wasDur}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 9),
        Expanded(
          child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(label,
                    style: V3.inter(13,
                        weight: FontWeight.w700,
                        color: V3.muted,
                        letterSpacing: 1)),
                if (changed) _Pill('Changed', fg: V3.bg, bg: V3.green),
                if (changed && wasDur != null)
                  Text('$wasDur min',
                      style: V3
                          .inter(13, color: V3.muted)
                          .copyWith(decoration: TextDecoration.lineThrough)),
              ]),
        ),
        if (path != null)
          TextButton.icon(
            onPressed: () => _askChange(path),
            style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10)),
            icon: const Icon(Icons.auto_awesome, size: 16, color: V3.green),
            label: Text('Change',
                style: V3.inter(14, weight: FontWeight.w600, color: V3.green)),
          ),
        if (dur != null && dur != 0) ...[
          const SizedBox(width: 4),
          _Pill('$dur min', fg: V3.green, bg: V3.greenTint),
        ],
      ]),
    );
  }

  Widget _phaseCard(Map s, String pp, int? drillNum, bool changed) {
    final name = textOf(s, 'game_name');
    final image = textOf(s, 'game_image');
    final video = textOf(s, 'game_video');
    final setup = textOf(s, 'setup');
    final desc = textOf(s, 'description');
    final pts = pointsOf(s['coaching_points']);
    final variation = textOf(s, 'variation');
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Text(t.toUpperCase(),
              style: V3.inter(13,
                  weight: FontWeight.w700,
                  color: V3.muted,
                  letterSpacing: 0.8)),
        );
    Widget ed(String attr, String text) => _Ed(
          key: ValueKey('$_v:$pp.$attr'),
          text: text,
          style: V3.inter(16, height: 1.5),
          onChanged: (t) => _edit('$pp.$attr', t),
        );
    final yt = video.isEmpty ? null : youtubeIdOf(video);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: changed ? V3.green : V3.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (name.isNotEmpty || drillNum != null)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: V3.line))),
            child: Row(children: [
              if (drillNum != null) ...[
                CircleAvatar(
                    radius: 13,
                    backgroundColor: V3.green,
                    child: Text('$drillNum',
                        style: V3.inter(13,
                            weight: FontWeight.w700, color: V3.bg))),
                const SizedBox(width: 10),
              ],
              if (name.isNotEmpty)
                Expanded(
                    child: Text(name,
                        style: V3.inter(17, weight: FontWeight.w600))),
            ]),
          ),
        if (image.isNotEmpty)
          CachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.fitWidth,
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        if (video.isNotEmpty)
          InkWell(
            onTap: () => openGameVideo(video),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: Colors.black),
                if (yt != null)
                  CachedNetworkImage(
                      imageUrl: youtubeThumb(yt),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const SizedBox.shrink()),
                const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 64)),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (setup.isNotEmpty) ...[label('Setup'), ed('setup', setup)],
            if (desc.isNotEmpty) ...[
              label('How to Play'),
              ed('description', desc)
            ],
            if (pts.isNotEmpty) ...[
              label('Coaching Points'),
              for (var i = 0; i < pts.length; i++)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 6),
                    child: Text('•',
                        style: V3.inter(18, color: V3.green, height: 1.2)),
                  ),
                  Expanded(child: ed('coaching_points.$i', pts[i])),
                ]),
            ],
            if (variation.isNotEmpty) ...[
              label('Variations'),
              ed('variation', variation)
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _footer(PlanBar bar) {
    return Container(
      decoration: const BoxDecoration(
          color: V3.card, border: Border(top: BorderSide(color: V3.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_refusal != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: V3.amberTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: V3.amberLine)),
                child: Text(_refusal!,
                    style: V3.inter(15, color: V3.amberText, height: 1.45)),
              ),
            VoiceRestBox(
                label: 'Change this plan',
                placeholder: 'Tell me what to change…',
                onTap: () => _openRefine()),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FavButton(
                    label: 'Export PDF',
                    icon: Icons.ios_share,
                    busy: _pdfBusy,
                    onPressed: _exportPdf),
              ),
              if (bar.save) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FavButton(
                      label: 'Save Plan',
                      icon: Icons.save_outlined,
                      busy: _saving,
                      onPressed: _save),
                ),
              ],
              if (bar.share) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FavButton(
                      label: 'Add to Club',
                      icon: Icons.share_outlined,
                      primary: false,
                      busy: _sharing,
                      onPressed: () => _setClub(true)),
                ),
              ],
              if (bar.remove) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FavButton(
                      label: 'Remove from Club',
                      icon: Icons.link_off,
                      primary: false,
                      busy: _sharing,
                      onPressed: () => _setClub(false)),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Text the coach can tap and edit in place.
class _Ed extends StatefulWidget {
  const _Ed(
      {super.key,
      required this.text,
      required this.style,
      required this.onChanged});
  final String text;
  final TextStyle style;
  final ValueChanged<String> onChanged;

  @override
  State<_Ed> createState() => _EdState();
}

class _EdState extends State<_Ed> {
  late final _c = TextEditingController(text: widget.text.trim());

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: c));
    return TextField(
      controller: _c,
      onChanged: widget.onChanged,
      maxLines: null,
      style: widget.style,
      cursorColor: V3.green,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        enabledBorder: b(V3.green.withValues(alpha: 0.28)),
        focusedBorder: b(V3.green.withValues(alpha: 0.6)),
        filled: true,
        fillColor: Colors.transparent,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
              color: V3.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: V3.line)),
          child: Column(children: [
            Text(value,
                style: V3.tight(34, weight: FontWeight.w700, color: V3.green)),
            const SizedBox(height: 3),
            Text(label.toUpperCase(),
                style: V3.inter(13,
                    weight: FontWeight.w600,
                    color: V3.muted,
                    letterSpacing: 0.6)),
          ]),
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.fg, required this.bg});
  final String text;
  final Color fg, bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child:
            Text(text, style: V3.inter(13, weight: FontWeight.w600, color: fg)),
      );
}

class _SavePill extends StatelessWidget {
  const _SavePill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final saved = text == 'Saved';
    final c = saved ? V3.green : V3.amber;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c, width: 1.5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (saved) ...[
            Icon(Icons.check, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Text(text, style: V3.inter(13, weight: FontWeight.w600, color: c)),
        ]),
      ),
    );
  }
}
