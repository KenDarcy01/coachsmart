// v3 Session plan: the native copy of webviews/session-plan.html, the plan
// for one training event (or, with no event, a plan for the coach's own
// library).
//
// * Setup: attach a saved plan (mine or my club's), or generate a new one
//   from my favourite games: session length, rotate through stations, and
//   the games in order (drag to reorder, tap to view, untick to skip, heart
//   to remove, add more from the games library).
// * Plan: tap any text to edit, players / coaches / minutes, weather, the
//   session image, each section's minutes and start time, drill order,
//   "Change this plan" (the shared voice panel, AI revise), Save edits,
//   Share with Club (library plans only) and the PDF (phone share or the A4
//   overview with drill cards) shared with Printing.sharePdf.
// * Gate: when the team does not have session plans on (teams.session_plan,
//   or the user's ai_features) only an existing plan opens. The event page
//   shows the button to coaches (role 30+) only.
//
// V3SessionPlanPage.open is the ONE plan screen of the Coaching tab (Ken,
// 2026-11-11): it opens straight on a plan just built, on a saved plan by
// its id (a club plan from another coach is read-only until "Use This
// Plan"), or on an event's plan. It has no setup screen and no gate; when
// AI is not allowed it only hides "Tell me what to change" and "Change this
// part". Both ways in share the save pill, "Plan updated" with Undo and
// "Update this plan / Save as a new copy".
import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '/v3/games/v3_games.dart';
import '/v3/match_report/v3_voice_sheet.dart';
import '../v3_theme.dart';
import 'v3_session_plan_api.dart';
import 'v3_session_plan_models.dart';
import 'v3_session_plan_widgets.dart';

enum _Screen { loading, off, error, setup, plan }

class V3SessionPlanPage extends StatefulWidget {
  const V3SessionPlanPage({
    super.key,
    this.eventId,
    this.minutes = 60,
    this.gamesApi = const V3GamesApi(),
    this.testCall,
    this.testUserId,
    this.testDictation,
  })  : direct = false,
        plan = null,
        planId = null,
        isOwn = true,
        aiAllowed = true,
        event = null,
        squadName = '',
        clubId = null,
        onChangePlan = null,
        onSaved = null,
        aiProbe = null;

  /// The one plan screen: opens on [plan] (just built, or an event's plan),
  /// or loads the saved plan [planId] when [plan] is null.
  const V3SessionPlanPage.open({
    super.key,
    this.eventId,
    this.plan,
    this.planId,
    this.isOwn = true,
    this.aiAllowed,
    this.event,
    this.squadName = '',
    this.clubId,
    this.onChangePlan,
    this.onSaved,
    this.minutes = 60,
    this.gamesApi = const V3GamesApi(),
    SpCall? call,
    String? userId,
    V3Dictation? dictation,
    this.aiProbe,
  })  : direct = true,
        testCall = call,
        testUserId = userId,
        testDictation = dictation;

  /// The training event; null opens the coach's library mode. With
  /// [V3SessionPlanPage.open] and a [planId], the plan's own event is used.
  final int? eventId;

  /// True for [V3SessionPlanPage.open].
  final bool direct;

  /// The plan_json to show.
  final Map<String, dynamic>? plan;

  /// session_plans.plan_id; null for a plan that is not saved yet.
  final String? planId;

  /// False for another coach's club plan (read-only until "Use This Plan").
  /// Ignored when the plan is loaded by [planId]: the server says.
  final bool isOwn;

  /// Whether the AI controls show. Null asks the server: the event's
  /// session_plan_allowed, else the user's ai_features.
  final bool? aiAllowed;

  /// The event's details, when the caller already has them.
  final SpEvent? event;
  final String squadName;
  final int? clubId;

  /// Shows "Change plan" (event plans: back to the three choices).
  final void Function(BuildContext context)? onChangePlan;

  /// Called each time the plan is saved to the server.
  final VoidCallback? onSaved;

  /// Tests answer the ai_features question here.
  final Future<bool> Function()? aiProbe;

  /// Starting session length on the setup screen (web ?duration=).
  final int minutes;

  /// Favourites, coach notes and the game card PDF.
  final V3GamesApi gamesApi;

  /// Widget tests pass a fake edge function call here.
  @visibleForTesting
  final SpCall? testCall;
  @visibleForTesting
  final String? testUserId;
  @visibleForTesting
  final V3Dictation? testDictation;

  @override
  State<V3SessionPlanPage> createState() => _V3SessionPlanPageState();
}

class _V3SessionPlanPageState extends State<V3SessionPlanPage> {
  _Screen _screen = _Screen.loading;
  String _loadingText = 'Loading…';
  String _error = '';

  SpEvent? _event;
  String _squad = '';
  int? _clubId;
  List<SpFavourite> _favs = [];
  V3GameFavourites? _hearts;

  late int _minutes = clampSessionMinutes(widget.minutes);
  bool _rotate = true;

  Map<String, dynamic>? _plan;
  String? _planId;
  int _version = 0;
  bool _dirty = false;
  String? _refusal;

  late int? _eventId = widget.eventId;
  bool _ai = true, _own = true, _readOnly = false, _shared = false;
  ({Map<String, dynamic> plan, bool dirty})? _undo;
  SpChanges? _changes;
  List<V3Game>? _library;
  int? _libraryClub;
  final _scroll = ScrollController();

  bool _saving = false, _sharing = false, _imgBusy = false, _shareBusy = false;
  bool _revising = false;
  ValueNotifier<V3SheetNote?>? _sheetNote;

  String get _uid => widget.testUserId ?? spUserId();
  SpCall get _callFn => widget.testCall ?? spLiveCall;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _hearts?.removeListener(_heartsChanged);
    _hearts?.dispose();
    _scroll.dispose();
    _wake(false);
    super.dispose();
  }

  Future<SpResult> _call(Map<String, dynamic> body) =>
      _callFn(kSpFn, {...body, 'user_id': _uid});

  void _snack(String text, {bool warn = false}) {
    final n = _sheetNote;
    if (n != null) {
      n.value = V3SheetNote(text, error: warn);
      return;
    }
    if (mounted) spSnack(context, text, warn: warn);
  }

  void _wake(bool on) {
    if (widget.testCall != null) return;
    try {
      unawaited((on ? WakelockPlus.enable() : WakelockPlus.disable())
          .catchError((_) {}));
    } catch (_) {}
  }

  /// A heart removed elsewhere (the game page) drops it from the list.
  void _heartsChanged() {
    final ids = _hearts?.ids ?? const <int>{};
    final before = _favs.length;
    _favs = [
      for (final f in _favs)
        if (ids.contains(f.gameId)) f
    ];
    if (_favs.length != before && mounted) setState(() {});
  }

  // ------------------------------------------------------------------ load

  Future<void> _boot() async {
    if (_uid.isEmpty) {
      _fail('Missing user information.');
      return;
    }
    setState(() {
      _screen = _Screen.loading;
      _loadingText = 'Loading…';
    });
    if (widget.direct) {
      await _bootDirect();
      return;
    }
    try {
      final r = await _call(getBody(_eventId));
      if (!r.ok) {
        _fail(spErrorText(r.data, 'Failed to load.'));
        return;
      }
      final d = SpLoad.fromJson(r.map);
      _event = d.event;
      _squad = d.squadName;
      _clubId = d.clubId;
      _setFavs(filterByEventCode(d.favourites, d.event?.eventCode ?? ''));
      if (spIsOff(eventId: _eventId, load: d)) {
        setState(() => _screen = _Screen.off);
        return;
      }
      if (d.plan != null) {
        _showPlan(d.plan!, d.planId);
      } else {
        setState(() => _screen = _Screen.setup);
      }
    } catch (_) {
      _fail('Network error. Please check your connection and try again.');
    }
  }

  /// [V3SessionPlanPage.open]: the plan given, or the saved plan by its id;
  /// then whatever the caller did not pass (the event, whether AI is on).
  Future<void> _bootDirect() async {
    try {
      var plan = widget.plan == null ? null : deepCopy(widget.plan!);
      final planId = widget.planId;
      _own = widget.isOwn;
      _event = widget.event;
      _squad = widget.squadName;
      _clubId = widget.clubId;
      _shared = false;
      var ai = widget.aiAllowed;
      if (plan == null) {
        if (planId == null) {
          _fail('This plan could not be found.');
          return;
        }
        final r = await _call({'action': 'get_plan', 'plan_id': planId});
        final p = r.map['plan'];
        if (!r.ok || p is! Map) {
          _fail(spErrorText(r.data, 'This plan could not be loaded.'));
          return;
        }
        plan = deepCopy(p);
        _own = r.map['is_own'] != false;
        _shared = r.map['club_id'] != null;
        _eventId ??= int.tryParse('${r.map['event_id'] ?? ''}');
        _absorb(r.map);
      }
      if (_eventId != null && (ai == null || _event == null)) {
        try {
          final r = await _call(getBody(_eventId));
          if (r.ok) {
            final d = SpLoad.fromJson(r.map);
            _event ??= d.event;
            if (_squad.isEmpty) _squad = d.squadName;
            _clubId ??= d.clubId;
            ai ??= d.allowed != false;
          }
        } catch (_) {}
      }
      ai ??= await (widget.aiProbe ?? spAiFeatures)();
      _ai = ai;
      _readOnly = !_own;
      final shared = _shared;
      _showPlan(plan, planId);
      _shared = shared;
    } catch (_) {
      _fail('Network error. Please check your connection and try again.');
    }
  }

  void _setFavs(List<SpFavourite> favs) {
    _favs = favs;
    _hearts?.removeListener(_heartsChanged);
    _hearts?.dispose();
    final h = _hearts =
        V3GameFavourites(widget.gamesApi, favs.map((f) => f.gameId).toSet());
    // Every favourite, not only those for this code, so a heart in the
    // library never flips the wrong way.
    unawaited(h.load().then((_) {
      if (mounted && identical(h, _hearts)) h.addListener(_heartsChanged);
    }));
  }

  void _fail(String msg) {
    _wake(false);
    if (!mounted) return;
    setState(() {
      _error = msg;
      _screen = _Screen.error;
    });
  }

  void _showPlan(Map<String, dynamic> plan, String? planId,
      {bool dirty = false}) {
    _wake(false);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _planId = planId;
      _version++;
      _dirty = dirty;
      _refusal = null;
      _undo = null;
      _changes = null;
      _shared = false;
      _screen = _Screen.plan;
    });
  }

  // ------------------------------------------------------------ favourites

  Future<void> _unfavourite(SpFavourite f) async {
    final hearts = _hearts;
    if (hearts == null) return;
    final msg = await hearts.toggle(f.gameId);
    if (msg.startsWith('Could')) {
      _snack('Could not remove favourite — try again', warn: true);
      return;
    }
    if (!mounted) return;
    setState(() => _favs.removeWhere((x) => x.gameId == f.gameId));
  }

  Future<void> _openGame(int gameId) async {
    final hearts = _hearts;
    if (hearts == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: 'SpGamePage'),
        builder: (_) => SpGamePage(
            gameId: gameId,
            call: (fn, b) => _callFn(fn, b),
            userId: _uid,
            eventId: _eventId,
            api: widget.gamesApi,
            favourites: hearts)));
  }

  Future<void> _openGameByName(String name) async {
    final n = name.trim().toLowerCase();
    if (widget.direct) {
      await _openLibraryGame(n);
      return;
    }
    final f = _favs.where((x) => x.name.trim().toLowerCase() == n);
    if (f.isEmpty) {
      _snack('This game is not in your favourites');
      return;
    }
    await _openGame(f.first.gameId);
  }

  /// The one plan screen has no favourites list: the game is found by its
  /// name in the games the coach can see.
  Future<void> _openLibraryGame(String name) async {
    final api = widget.gamesApi;
    try {
      if (_library == null) {
        _libraryClub = await api.myClubId();
        _library = await api.games(_libraryClub);
      }
    } catch (_) {
      _snack('Could not open the game — try again', warn: true);
      return;
    }
    final hits = _library!.where((g) => g.name.trim().toLowerCase() == name);
    if (hits.isEmpty) {
      _snack('This game is not in the games list any more');
      return;
    }
    final hearts = _hearts ??= V3GameFavourites(api)..load();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => V3GameDetailPage(
            game: hits.first,
            api: api,
            favourites: hearts,
            myClubId: _libraryClub)));
  }

  Future<void> _addGames() async {
    final hearts = _hearts;
    if (hearts == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
        settings: const RouteSettings(name: 'SpAddGamesPage'),
        builder: (_) => SpAddGamesPage(
            api: widget.gamesApi,
            favourites: hearts,
            call: (fn, b) => _callFn(fn, b),
            userId: _uid,
            eventId: _eventId,
            eventCode: _event?.eventCode ?? '')));
    if (!mounted) return;
    // Pick up new favourites, keeping the order and ticks already set.
    try {
      final r = await _call(getBody(_eventId));
      if (!r.ok) return;
      final fresh = SpLoad.fromJson(r.map).favourites;
      final have = {for (final f in _favs) f.gameId: f};
      final next = <SpFavourite>[
        for (final f in _favs)
          if (fresh.any((x) => x.gameId == f.gameId)) f,
        for (final f in fresh)
          if (!have.containsKey(f.gameId)) f,
      ];
      if (mounted) setState(() => _favs = next);
    } catch (_) {}
  }

  // ------------------------------------------------------------- generate

  Future<void> _generate() async {
    final ids = [
      for (final f in _favs)
        if (f.checked) f.gameId
    ];
    if (ids.isEmpty) {
      _snack('Select at least one game', warn: true);
      return;
    }
    _wake(true);
    setState(() {
      _refusal = null;
      _screen = _Screen.loading;
      _loadingText = 'Generating your session plan…';
    });
    try {
      final r = await _call(generateBody(
          eventId: _eventId,
          planId: _planId,
          minutes: _minutes,
          gameIds: ids,
          rotate: _rotate));
      final d = r.map;
      if (d['error'] == 'no_favourites') {
        _wake(false);
        setState(() {
          _favs = [];
          _screen = _Screen.setup;
        });
        return;
      }
      if (d['refusal'] != null) {
        _wake(false);
        setState(() {
          _refusal = '${d['refusal']}';
          _screen = _Screen.setup;
        });
        return;
      }
      final plan = d['plan'];
      if (!r.ok || plan is! Map) {
        _fail(spErrorText(d, 'Generation failed. Please try again.'));
        return;
      }
      _absorb(d);
      final id = d['plan_id'] == null ? null : '${d['plan_id']}';
      // With no event the server returns an unsaved draft.
      _showPlan(deepCopy(plan), id ?? _planId, dirty: id == null);
    } catch (_) {
      _fail('Network error. Please try again.');
    }
  }

  void _absorb(Map d) {
    final ev = d['event'];
    if (ev is Map) _event = SpEvent.fromJson(ev);
    if (d.containsKey('squad_name')) _squad = '${d['squad_name'] ?? ''}';
    final br = d['branding'];
    if (br is Map && br['club_id'] != null) {
      _clubId = int.tryParse('${br['club_id']}');
    }
  }

  // --------------------------------------------------------------- attach

  Future<void> _pickSaved() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(
        settings: const RouteSettings(name: 'SpSavedPlansPage'),
        builder: (_) =>
            SpSavedPlansPage(call: (fn, b) => _callFn(fn, b), userId: _uid)));
    if (id == null || !mounted) return;
    final prev = _screen;
    setState(() {
      _screen = _Screen.loading;
      _loadingText = _eventId != null ? 'Attaching plan…' : 'Loading…';
    });
    try {
      if (_eventId == null) {
        // Library mode: open the plan itself (a club plan opens as a copy).
        final r = await _call({'action': 'get_plan', 'plan_id': id});
        final p = r.map['plan'];
        if (!r.ok || p is! Map) {
          _fail(spErrorText(r.data, 'Failed to load.'));
          return;
        }
        final own = r.map['is_own'] == true;
        _showPlan(deepCopy(p), own ? id : null, dirty: !own);
        _shared = own && r.map['club_id'] != null;
        return;
      }
      final r = await _call(
          {'action': 'attach_plan', 'event_id': _eventId, 'plan_id': id});
      final p = r.map['plan_json'];
      if (!r.ok || p is! Map) {
        _fail(spErrorText(r.data, 'Attach failed.'));
        return;
      }
      _showPlan(deepCopy(p), r.map['plan_id']?.toString());
      _snack('Plan attached ✓');
    } catch (_) {
      if (prev == _Screen.plan && _plan != null) {
        setState(() => _screen = _Screen.plan);
        _snack('Network error. Please try again.', warn: true);
      } else {
        _fail('Network error. Please try again.');
      }
    }
  }

  // ----------------------------------------------------------------- save

  /// Saves the plan as edited. Returns true when it is on the server.
  Future<bool> _persist() async {
    final plan = _plan;
    if (plan == null) return false;
    if (_planId == null) {
      final r = await _call({'action': 'save_plan', 'plan_json': plan});
      final id = r.map['plan_id'];
      if (!r.ok || id == null) return false;
      _planId = '$id';
    } else {
      final r = await _call(
          updateBody(eventId: _eventId, planId: _planId!, plan: plan));
      if (!r.ok || r.map['ok'] != true) return false;
    }
    _dirty = false;
    spPlansChanged.value++;
    widget.onSaved?.call();
    return true;
  }

  /// A plan already in the coach's plans (not an event's) asks whether to
  /// update it or keep it and save a new copy.
  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    var copy = false;
    if (_eventId == null && _planId != null) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: V3.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Save changes', style: V3.tight(20)),
                  const SizedBox(height: 6),
                  Text('This plan is already in your plans.',
                      style: V3.inter(16, color: V3.muted)),
                  const SizedBox(height: 18),
                  SpButton('Update this plan',
                      key: const ValueKey('save-update'),
                      onPressed: () => Navigator.of(ctx).pop('update')),
                  const SizedBox(height: 10),
                  SpButton('Save as a new copy',
                      key: const ValueKey('save-copy'),
                      outline: true,
                      onPressed: () => Navigator.of(ctx).pop('new')),
                ]),
          ),
        ),
      );
      if (choice == null || !mounted) return;
      copy = choice == 'new';
    }
    final prevId = _planId;
    setState(() => _saving = true);
    try {
      if (copy) _planId = null;
      final ok = await _persist();
      if (ok && copy) _shared = false;
      if (!ok) _planId = prevId;
      _snack(ok ? (copy ? 'Saved as a new plan ✓' : 'Saved ✓') : 'Save failed',
          warn: !ok);
    } catch (_) {
      _planId = prevId;
      _snack('Save failed', warn: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "Use This Plan" on another coach's club plan: it becomes the coach's
  /// own copy, saved when they tap Save.
  void _useThisPlan() {
    setState(() {
      _readOnly = false;
      _own = true;
      _planId = null;
      _shared = false;
      _dirty = true;
      _version++;
    });
    _snack('This is now your own copy. Save it to keep it.');
  }

  /// Web: inline edits are saved before the AI change and the PDF.
  Future<void> _saveQuietly() async {
    if (!_dirty || _planId == null) return;
    try {
      await _persist();
    } catch (_) {}
  }

  // --------------------------------------------------------------- revise

  /// [target] changes one section only ("Change this part").
  Future<void> _openRefine([SpSection? target]) async {
    final plan = _plan;
    if (_revising || _sheetNote != null || plan == null) return;
    FocusScope.of(context).unfocus();
    final note = _sheetNote = ValueNotifier<V3SheetNote?>(null);
    await showV3VoiceSheet(
      context,
      title: target != null
          ? 'Change: ${sectionName(plan, target.path)}'
          : 'Change this plan',
      subtitle: target != null
          ? 'Only this part of the plan will change.'
          : 'Say or type what you would like changed.',
      placeholder: target != null
          ? 'e.g. make it easier for U10s, bigger channel'
          : 'e.g. 15 mins on the warm-up, add more possession drills',
      submitLabel: 'Update',
      busyLabel: 'Updating…',
      onSubmit: (text) => _revise(text, target?.path),
      note: note,
      dictation: widget.testDictation,
    );
    _sheetNote = null;
    final last = note.value;
    if (last != null && mounted) spSnack(context, last.text, warn: last.error);
  }

  /// Returns false (keeps the panel open) when the update fails.
  Future<bool> _revise(String feedback, [String? target]) async {
    final text = feedback.trim();
    final plan = _plan;
    if (_revising || text.isEmpty || plan == null) return false;
    setState(() {
      _revising = true;
      _refusal = null;
    });
    _wake(true);
    try {
      await _saveQuietly();
      final prior = deepCopy(plan);
      final priorDirty = _dirty;
      final r = await _call(reviseBody(
          eventId: _eventId,
          planId: _planId,
          feedback: text,
          plan: plan,
          target: target));
      final d = r.map;
      if (d['refusal'] != null) {
        setState(() => _refusal = '${d['refusal']}');
        _sheetNote?.value = null;
        return true;
      }
      final next = d['plan'];
      if (!r.ok || next is! Map) {
        _snack(spErrorText(d, 'Update failed. Please try again.'), warn: true);
        return false;
      }
      _absorb(d);
      final id = d['plan_id'] == null ? null : '${d['plan_id']}';
      final saved = _eventId != null && id != null;
      final shared = _shared;
      final revised = deepCopy(next);
      final changes = diffPlans(prior, revised);
      _showPlan(revised, id ?? _planId, dirty: !saved);
      if (mounted) {
        setState(() {
          _shared = shared;
          // The event's plan is saved by the server as it changes, so an
          // undo leaves something to save.
          _undo = (plan: prior, dirty: saved || priorDirty);
          _changes = changes;
        });
        if (_scroll.hasClients && !changes.isEmpty) _scroll.jumpTo(0);
      }
      if (saved) spPlansChanged.value++;
      _snack(changes.isEmpty ? 'No changes were needed' : 'Plan updated ✓');
      return true;
    } catch (_) {
      _snack('Update failed — please try again', warn: true);
      return false;
    } finally {
      _wake(false);
      if (mounted) setState(() => _revising = false);
    }
  }

  void _undoChange() {
    final u = _undo;
    if (u == null) return;
    final shared = _shared;
    _showPlan(u.plan, _planId, dirty: u.dirty);
    _shared = shared;
    _snack('Change undone');
  }

  // ----------------------------------------------------------- plan edits

  /// The save pill turns to "Unsaved changes" on the first edit.
  void _touched() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  void _onText(String path, String v) {
    final plan = _plan;
    if (plan == null) return;
    setPath(plan, path, v.trim());
    _touched();
  }

  void _onNumber(String path, int? v) {
    final plan = _plan;
    if (plan == null) return;
    plan[path] = v;
    _touched();
  }

  Future<void> _editDuration(String path) async {
    final plan = _plan;
    if (plan == null) return;
    var mins = durationOf(plan, path);
    final label = planSections(plan)
        .firstWhere((s) => s.path == path,
            orElse: () => SpSection(path, 'SECTION', 'drill'))
        .label;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${_cap(label)} minutes', style: V3.tight(20)),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _stepBtn(
                    Icons.remove,
                    'Less',
                    mins > 1
                        ? () => set(() => mins = mins > 5 ? mins - 5 : mins - 1)
                        : null),
                SizedBox(
                  width: 120,
                  child: Text('$mins min',
                      key: const ValueKey('dur-value'),
                      textAlign: TextAlign.center,
                      style: V3.tight(28, weight: FontWeight.w800)),
                ),
                _stepBtn(Icons.add, 'More',
                    mins < 120 ? () => set(() => mins += 5) : null),
              ]),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: SpButton('Done',
                    onPressed: () => Navigator.of(ctx).pop(mins)),
              ),
            ]),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      setDuration(plan, path, picked);
      _version++;
      _dirty = true;
    });
  }

  static String _cap(String s) => s.isEmpty
      ? s
      : s
          .toLowerCase()
          .split(' ')
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');

  Widget _stepBtn(IconData icon, String tip, VoidCallback? onTap) => Material(
        color: V3.card2,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tip,
          iconSize: 30,
          constraints: const BoxConstraints(minWidth: 60, minHeight: 60),
          icon: Icon(icon, color: onTap == null ? V3.muted : V3.green),
          onPressed: onTap,
        ),
      );

  Future<void> _sectionMenu(SpSection s) async {
    final plan = _plan;
    if (plan == null) return;
    final i = s.drill;
    final n = spDrills(plan).length;
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          if (_ai)
            _menuItem(ctx, Icons.auto_awesome, 'Change this part', 'change',
                color: V3.green),
          if (i != null && i > 0)
            _menuItem(ctx, Icons.arrow_upward, 'Move up', 'up'),
          if (i != null && i < n - 1)
            _menuItem(ctx, Icons.arrow_downward, 'Move down', 'down'),
          if (i != null)
            _menuItem(ctx, Icons.delete_outline, 'Remove drill', 'remove',
                color: V3.redText),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == 'change') {
      await _openRefine(s);
      return;
    }
    if (i == null) return;
    setState(() {
      _undo = null;
      _changes = null;
      if (pick == 'up') moveDrill(plan, i, i - 1);
      if (pick == 'down') moveDrill(plan, i, i + 1);
      if (pick == 'remove') removeDrill(plan, i);
      _version++;
      _dirty = true;
    });
  }

  Widget _menuItem(BuildContext ctx, IconData icon, String label, String v,
          {Color color = V3.text}) =>
      ListTile(
        minTileHeight: 56,
        leading: Icon(icon, color: color),
        title: Text(label, style: V3.inter(17, color: color)),
        onTap: () => Navigator.of(ctx).pop(v),
      );

  // -------------------------------------------------------- session image

  Future<void> _pickImage() async {
    if (_planId == null) {
      _snack('Save the plan first', warn: true);
      return;
    }
    final XFile? f;
    try {
      f = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 2400);
    } catch (_) {
      _snack('Could not open your photos', warn: true);
      return;
    }
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      _snack('Image must be under 8 MB', warn: true);
      return;
    }
    final name = f.name.toLowerCase();
    final type = f.mimeType ??
        (name.endsWith('.png')
            ? 'image/png'
            : name.endsWith('.heic')
                ? 'image/heic'
                : name.endsWith('.webp')
                    ? 'image/webp'
                    : 'image/jpeg');
    if (!type.startsWith('image/')) {
      _snack('Please select an image file', warn: true);
      return;
    }
    setState(() => _imgBusy = true);
    _snack('Uploading…');
    try {
      final r = await _call({
        'action': 'upload_session_image',
        'plan_id': _planId,
        'file_data': base64Encode(bytes),
        'file_type': type,
      });
      if (!r.ok || r.map['url'] == null) {
        _snack(spErrorText(r.data, 'Upload failed'), warn: true);
        return;
      }
      setState(() => _plan?['session_image'] = '${r.map['url']}');
      _snack('Image added ✓');
    } catch (_) {
      _snack('Upload failed — please try again', warn: true);
    } finally {
      if (mounted) setState(() => _imgBusy = false);
    }
  }

  Future<void> _removeImage() async {
    if (_planId == null) return;
    setState(() => _imgBusy = true);
    try {
      final r =
          await _call({'action': 'remove_session_image', 'plan_id': _planId});
      if (!r.ok) {
        _snack('Remove failed', warn: true);
        return;
      }
      setState(() => _plan?.remove('session_image'));
      _snack('Image removed');
    } catch (_) {
      _snack('Remove failed — please try again', warn: true);
    } finally {
      if (mounted) setState(() => _imgBusy = false);
    }
  }

  // --------------------------------------------------------- club sharing

  bool _removing = false;

  Future<void> _removeFromSession() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        title: Text('Remove this plan?', style: V3.tight(20)),
        content: Text(
            'The session will have no plan. Plans saved in Coaching stay as '
            'they are.',
            style: V3.inter(15, color: V3.muted, height: 1.4)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: V3.inter(15, color: V3.text))),
          TextButton(
              key: const ValueKey('remove-plan-yes'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Remove',
                  style: V3.inter(15,
                      weight: FontWeight.w700, color: V3.redText))),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => _removing = true);
    try {
      final r = await _call({'action': 'deactivate_plan', 'plan_id': _planId});
      if (!mounted) return;
      if (!r.ok || r.map['ok'] != true) {
        _snack('Could not remove the plan', warn: true);
        return;
      }
      spPlansChanged.value++;
      _snack('Plan removed from this session');
      Navigator.of(context).maybePop();
    } catch (_) {
      _snack('Network error', warn: true);
    } finally {
      if (mounted) setState(() => _removing = false);
    }
  }

  Future<void> _shareWithClub(bool shared) async {
    if (_shareBusy) return;
    if (_planId == null || _dirty) {
      setState(() => _shareBusy = true);
      final ok = await _persist().catchError((_) => false);
      if (!mounted) return;
      setState(() => _shareBusy = false);
      if (!ok) {
        _snack('Could not update sharing', warn: true);
        return;
      }
    }
    setState(() => _shareBusy = true);
    try {
      final r = await _call(
          {'action': 'set_plan_club', 'plan_id': _planId, 'shared': shared});
      if (!r.ok || r.map['ok'] != true) {
        _snack('Could not update sharing', warn: true);
      } else if (shared && r.map['club_id'] == null) {
        _snack('No club found on your account', warn: true);
      } else {
        setState(() => _shared = shared);
        spPlansChanged.value++;
        _snack(shared ? 'Shared with club ✓' : 'Removed from club ✓');
      }
    } catch (_) {
      _snack('Network error', warn: true);
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  // ------------------------------------------------------------------ PDF

  Future<void> _sharePdfChoice() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Share the plan', style: V3.tight(20)),
            const SizedBox(height: 8),
            _pdfOption(ctx, Icons.phone_iphone, 'Phone version',
                'Easy to read on a phone; good for WhatsApp', 'mobile'),
            _pdfOption(ctx, Icons.description_outlined, 'A4 print version',
                'The overview page plus a card for each drill', 'a4'),
          ]),
        ),
      ),
    );
    if (format != null) await _exportPdf(format);
  }

  Widget _pdfOption(BuildContext ctx, IconData icon, String title, String sub,
          String v) =>
      ListTile(
        key: ValueKey('pdf-$v'),
        minTileHeight: 64,
        leading: Icon(icon, color: V3.green, size: 28),
        title: Text(title, style: V3.inter(17, weight: FontWeight.w600)),
        subtitle: Text(sub, style: V3.inter(14, color: V3.muted)),
        onTap: () => Navigator.of(ctx).pop(v),
      );

  Future<void> _exportPdf(String format) async {
    if (_plan == null || _sharing) return;
    FocusScope.of(context).unfocus();
    setState(() => _sharing = true);
    try {
      await _saveQuietly();
      final r = await _callFn(kSpPdfFn, {
        if (_planId != null && !_dirty)
          'plan_id': _planId
        else
          'plan_json': _plan,
        'user_id': _uid,
        'platform': 'mobile',
        'format': format,
      });
      final pdf = '${r.map['pdf'] ?? ''}';
      if (!r.ok || pdf.isEmpty) throw Exception();
      final name = '${r.map['filename'] ?? 'session-plan.pdf'}';
      await Printing.sharePdf(bytes: base64Decode(pdf), filename: name);
    } catch (_) {
      _snack('Could not generate PDF — please try again', warn: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final onPlan = _screen == _Screen.plan;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: spAppBar(context, 'Session plan', actions: [
        if (onPlan)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              key: const ValueKey('share-pdf'),
              onPressed: _sharing ? null : _sharePdfChoice,
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: V3.green))
                  : const Icon(Icons.ios_share, color: V3.green),
              label: Text('Share',
                  style:
                      V3.inter(16, weight: FontWeight.w700, color: V3.green)),
            ),
          ),
      ]),
      body: switch (_screen) {
        _Screen.loading => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: V3.green),
              const SizedBox(height: 18),
              Text(_loadingText,
                  textAlign: TextAlign.center,
                  style: V3.inter(17, color: V3.muted)),
            ]),
          ),
        _Screen.off => const SpStateView(
            icon: '📋',
            title: "Session plans aren't on for this team",
            body: 'Ask your club to switch on session plans for this team, '
                'then come back to build one.'),
        _Screen.error => SpStateView(
            icon: '⚠️',
            title: 'Something went wrong',
            body: _error,
            action: SpButton('Try again', outline: true, onPressed: _boot)),
        _Screen.setup => _setup(),
        _Screen.plan => _planView(),
      },
      bottomNavigationBar: onPlan && _readOnly
          ? Container(
              decoration: const BoxDecoration(
                  color: V3.bg,
                  border: Border(top: BorderSide(color: V3.line))),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: SpButton('Use This Plan',
                      key: const ValueKey('use-plan'), onPressed: _useThisPlan),
                ),
              ),
            )
          : null,
    );
  }

  // ----------------------------------------------------------- setup view

  Widget _setup() {
    final header = <Widget>[
      const SizedBox(height: 12),
      if (_plan != null) ...[
        SpButton('Back to the plan',
            key: const ValueKey('back-to-plan'),
            icon: Icons.assignment_outlined,
            onPressed: () => setState(() => _screen = _Screen.plan)),
        const SizedBox(height: 18),
      ],
      const SpLabel('Saved Plans'),
      SpButton(_eventId != null ? 'Attach a Saved Plan' : 'Open a Saved Plan',
          icon: Icons.note_add_outlined, outline: true, onPressed: _pickSaved),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          const Expanded(child: Divider(color: V3.line)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or generate a new one',
                style: V3.inter(15, color: V3.muted)),
          ),
          const Expanded(child: Divider(color: V3.line)),
        ]),
      ),
      if (_refusal != null) ...[_refusalBox(), const SizedBox(height: 14)],
      const SpLabel('Session Duration'),
      _box(Row(children: [
        Expanded(
            child: Text('Length of session',
                style: V3.inter(17, weight: FontWeight.w500))),
        _stepBtn(
            Icons.remove,
            'Shorter',
            _minutes > 15
                ? () =>
                    setState(() => _minutes = clampSessionMinutes(_minutes - 5))
                : null),
        SizedBox(
          width: 86,
          child: Text('$_minutes min',
              key: const ValueKey('session-minutes'),
              textAlign: TextAlign.center,
              style: V3.tight(19, weight: FontWeight.w700)),
        ),
        _stepBtn(
            Icons.add,
            'Longer',
            _minutes < 180
                ? () =>
                    setState(() => _minutes = clampSessionMinutes(_minutes + 5))
                : null),
      ])),
      const SizedBox(height: 18),
      const SpLabel('Session Format'),
      _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Rotate through stations',
                  style: V3.inter(17, weight: FontWeight.w500))),
          Switch(
              value: _rotate,
              activeThumbColor: V3.green,
              onChanged: (v) => setState(() => _rotate = v)),
        ]),
        const SizedBox(height: 4),
        Text(
            'When on, players are split across the drill stations and rotate '
            'at intervals — not everyone performs the same activity at the '
            'same time. Warm-up and cool-down remain collective.',
            style: V3.inter(15, color: V3.muted, height: 1.45)),
      ])),
      const SizedBox(height: 18),
      const SpLabel('Games — drag to reorder · tap to view · untick to skip'),
    ];
    final footer = Column(children: [
      if (_favs.isEmpty)
        _box(Column(children: [
          const Text('⭐', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          Text('No Favourites Yet',
              style: V3.tight(18, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              'Head to the Games Library and add some favourites, then come '
              'back to generate your session plan.',
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted, height: 1.45)),
        ])),
      const SizedBox(height: 12),
      SpButton('Add games from the library',
          icon: Icons.add, outline: true, onPressed: _addGames),
      const SizedBox(height: 120),
    ]);
    return Stack(children: [
      ReorderableListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        buildDefaultDragHandles: false,
        proxyDecorator: V3.dragProxy,
        header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: header),
        footer: footer,
        itemCount: _favs.length,
        onReorderItem: (from, to) => setState(() {
          final f = _favs.removeAt(from);
          _favs.insert(to, f);
        }),
        itemBuilder: (_, i) => _favRow(i),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          decoration: const BoxDecoration(
              color: V3.bg, border: Border(top: BorderSide(color: V3.line))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: SpButton('Generate Session Plan',
                    key: const ValueKey('generate'),
                    icon: Icons.auto_awesome,
                    onPressed: _favs.isEmpty ? null : _generate),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _box(Widget child) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
            color: V3.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V3.line)),
        child: child,
      );

  Widget _favRow(int i) {
    final f = _favs[i];
    return Padding(
      key: ValueKey('fav-${f.gameId}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: V3.line)),
        clipBehavior: Clip.antiAlias,
        child: Opacity(
          opacity: f.checked ? 1 : 0.55,
          child: Row(children: [
            ReorderableDragStartListener(
              index: i,
              child: const SizedBox(
                width: 44,
                height: 68,
                child: Icon(Icons.drag_indicator, color: V3.muted, size: 26),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: Checkbox(
                value: f.checked,
                activeColor: V3.green,
                checkColor: Colors.black,
                side: const BorderSide(color: V3.muted, width: 2),
                onChanged: (v) => setState(() => f.checked = v ?? false),
              ),
            ),
            const SizedBox(width: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: f.image.isEmpty
                    ? Container(
                        color: V3.card2,
                        child:
                            const Icon(Icons.image_outlined, color: V3.muted))
                    : CachedNetworkImage(
                        imageUrl: f.image,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                            color: V3.card2,
                            child: const Icon(Icons.image_outlined,
                                color: V3.muted)),
                      ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _openGame(f.gameId),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 68),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(f.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: V3.inter(17, weight: FontWeight.w600)),
                ),
              ),
            ),
            V3HeartButton(on: true, onPressed: () => _unfavourite(f)),
          ]),
        ),
      ),
    );
  }

  Widget _refusalBox() => Container(
        key: const ValueKey('refusal'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: V3.amberTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V3.amberLine)),
        child: Text(_refusal ?? '',
            style: V3.inter(16, color: V3.amberText, height: 1.45)),
      );

  // ------------------------------------------------------------ plan view

  Widget _planView() {
    final plan = _plan!;
    final starts = sectionStarts(plan, _event?.dateTime);
    final weather = plan['weather'];
    final image = '${plan['session_image'] ?? ''}';
    final edit = _readOnly
        ? null
        : SpPlanEdit(
            onText: _onText,
            onNumber: _onNumber,
            onDuration: _editDuration,
            onMenu: _sectionMenu,
            onOpenGame: _openGameByName,
            ai: _ai,
          );
    final onNumber = _readOnly ? null : _onNumber;
    final pill =
        spSavePill(saved: _planId != null, dirty: _dirty, readOnly: _readOnly);
    final changes = _changes;
    final change = widget.onChangePlan;
    final showBack = widget.direct ? change != null : true;
    final place = _event?.locationName ?? '';
    int? intOf(String k) => plan[k] is num
        ? (plan[k] as num).toInt()
        : int.tryParse('${plan[k] ?? ''}');
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (showBack || place.isNotEmpty) ...[
            Row(children: [
              if (showBack)
                TextButton.icon(
                  key: const ValueKey('change-plan'),
                  onPressed: () => widget.direct
                      ? change!(context)
                      : setState(() => _screen = _Screen.setup),
                  style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      backgroundColor: V3.card,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22))),
                  icon: const Icon(Icons.chevron_left, color: V3.green),
                  label: Text(
                      widget.direct
                          ? 'Change plan'
                          : (_eventId != null
                              ? 'Change Plan'
                              : 'Back to Setup'),
                      style: V3.inter(15,
                          weight: FontWeight.w600, color: V3.green)),
                ),
              const SizedBox(width: 10),
              if (place.isNotEmpty)
                Expanded(
                  child: Text('📍 $place',
                      textAlign: showBack ? TextAlign.right : TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: V3.inter(15, color: V3.muted)),
                ),
            ]),
            const SizedBox(height: 10),
          ],
          if (changes != null && !changes.isEmpty && _undo != null) ...[
            _changesBanner(changes),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Icon(_readOnly ? Icons.groups_outlined : Icons.edit_outlined,
                size: 18, color: V3.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  _readOnly
                      ? 'A club plan. Use it to make your own copy.'
                      : 'Tap any text below to edit',
                  style: V3.inter(15, color: V3.muted)),
            ),
            if (pill != null) _savePill(pill),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            SpStat(
                path: 'player_count',
                value: intOf('player_count'),
                label: 'Players',
                version: _version,
                onChanged: onNumber),
            const SizedBox(width: 8),
            SpStat(
                path: 'coach_count',
                value: intOf('coach_count'),
                label: 'Coaches',
                version: _version,
                onChanged: onNumber),
            const SizedBox(width: 8),
            SpStat(
                path: 'total_duration_mins',
                value: intOf('total_duration_mins') ?? _minutes,
                label: 'Minutes',
                version: _version,
                onChanged: onNumber),
          ]),
          if (weather is Map) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: V3.card, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Text(weatherIcon(weather),
                    style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WEATHER FORECAST',
                            style: V3.inter(12,
                                weight: FontWeight.w700,
                                color: V3.muted,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Text('${weather['summary'] ?? ''}',
                            style: V3.inter(16, height: 1.4)),
                      ]),
                ),
              ]),
            ),
          ],
          if (_squad.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: V3.card2, borderRadius: BorderRadius.circular(20)),
                child: Text('🏷 $_squad',
                    style: V3.inter(15, weight: FontWeight.w600)),
              ),
            ),
          ],
          if (_eventId != null && !_readOnly) ...[
            const SizedBox(height: 12),
            _sessionImage(image),
          ],
          ...spPlanCards(plan,
              version: _version,
              edit: edit,
              starts: starts,
              changed: changes?.paths ?? const {}),
          const SizedBox(height: 24),
          if (_ai && !_readOnly) ...[
            if (_refusal != null) ...[
              _refusalBox(),
              const SizedBox(height: 12)
            ],
            _voiceBar(),
            const SizedBox(height: 12),
          ],
          if (!_readOnly)
            SpButton(
                _saving
                    ? 'Saving…'
                    : (_planId == null ? 'Save plan' : 'Save edits'),
                key: const ValueKey('save'),
                outline: true,
                busy: _saving,
                onPressed: _save),
          // Take a plan off a session, e.g. one attached by mistake (Ken,
          // 2026-11-12). Saved plans in the library are not touched.
          if (!_readOnly && _eventId != null && _planId != null) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                key: const ValueKey('remove-plan'),
                onPressed: _removing ? null : _removeFromSession,
                style: TextButton.styleFrom(foregroundColor: V3.redText),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: Text('Remove plan from this session',
                    style: V3.inter(15,
                        weight: FontWeight.w600, color: V3.redText)),
              ),
            ),
          ],
          if (!_readOnly &&
              _eventId == null &&
              (widget.direct || _clubId != null)) ...[
            const SizedBox(height: 16),
            _box(Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Share with Club',
                          style: V3.inter(17, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('Make this plan visible to all coaches in your club',
                          style: V3.inter(14, color: V3.muted)),
                    ]),
              ),
              Switch(
                  key: const ValueKey('share-club'),
                  value: _shared,
                  activeThumbColor: V3.green,
                  onChanged: _shareBusy ? null : _shareWithClub),
            ])),
          ],
        ],
      ),
    );
  }

  Widget _savePill(String text) {
    final saved = text == 'Saved';
    final c = saved ? V3.green : V3.amber;
    return Container(
      key: const ValueKey('save-pill'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c, width: 1.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (saved) ...[
          Icon(Icons.check, size: 15, color: c),
          const SizedBox(width: 4),
        ],
        Text(text, style: V3.inter(14, weight: FontWeight.w600, color: c)),
      ]),
    );
  }

  Widget _changesBanner(SpChanges changes) {
    final n = changes.names.length;
    return Container(
      key: const ValueKey('changes'),
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
            const SizedBox(height: 2),
            Text(changes.names.join(', '),
                style: V3.inter(15, color: V3.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: const ValueKey('undo'),
          onPressed: _undoChange,
          style: TextButton.styleFrom(
              minimumSize: const Size(72, 44),
              shape: const StadiumBorder(
                  side: BorderSide(color: V3.green, width: 1.5))),
          child: Text('Undo',
              style: V3.inter(16, weight: FontWeight.w600, color: V3.green)),
        ),
      ]),
    );
  }

  Widget _sessionImage(String url) {
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(children: [
          CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              placeholder: (_, __) => Container(height: 180, color: V3.card2),
              errorWidget: (_, __, ___) =>
                  Container(height: 120, color: V3.card2)),
          Positioned(
            top: 6,
            right: 6,
            child: _imgBtn(Icons.close, 'Remove image', _removeImage),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: TextButton(
              onPressed: _imgBusy ? null : _pickImage,
              style: TextButton.styleFrom(
                  backgroundColor: Colors.black54,
                  minimumSize: const Size(44, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child:
                  Text('Change', style: V3.inter(15, weight: FontWeight.w700)),
            ),
          ),
        ]),
      );
    }
    return InkWell(
      onTap: _imgBusy ? null : _pickImage,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V3.line, width: 1.5)),
        child: Column(children: [
          _imgBusy
              ? const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(color: V3.green))
              : const Icon(Icons.add_photo_alternate_outlined,
                  color: V3.muted, size: 34),
          const SizedBox(height: 8),
          Text('Add session image',
              style: V3.inter(16, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Pitch layout, diagram or whiteboard',
              style: V3.inter(14, color: V3.muted)),
        ]),
      ),
    );
  }

  Widget _imgBtn(IconData icon, String tip, VoidCallback onTap) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tip,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Icon(icon, color: Colors.white),
          onPressed: _imgBusy ? null : onTap,
        ),
      );

  Widget _voiceBar() => Material(
        color: V3.card2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey('voice-rest'),
          borderRadius: BorderRadius.circular(16),
          onTap: _revising ? null : _openRefine,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: V3.green.withValues(alpha: 0.55), width: 1.5)),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CHANGE THIS PLAN',
                          style: V3.inter(13,
                              weight: FontWeight.w700,
                              color: V3.green,
                              letterSpacing: 0.9)),
                      const SizedBox(height: 4),
                      Text(_revising ? 'Updating…' : 'Tell me what to change…',
                          style: V3.inter(16, color: V3.muted, height: 1.4)),
                    ]),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                    color: V3.green, shape: BoxShape.circle),
                child: _revising
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black87))
                    : const Icon(Icons.mic_none_rounded,
                        color: Colors.black87, size: 26),
              ),
            ]),
          ),
        ),
      );
}
