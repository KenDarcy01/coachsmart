// v3 Coaching: the ONE plan builder ("New plan"), opened from the Plans
// list, the green "N games in your plan" bar and an event's Session plan
// button (proposal approved by Ken 2026-11-11).
//
// * For: the event (title, day, time, team) or "No event · reusable plan".
// * Length, Players, an optional focus (typed or spoken) and, for the AI
//   plan, "Rotate through stations".
// * Games, in order: the shared draft (V3PlanDraft). Drag to reorder, step
//   the minutes, remove; "+ Add games" hands over to the Games list.
// * "Write the plan for me" (AI allowed only) asks generate-session-plan
//   for a plan from the games; "Keep it simple" builds the plan on the
//   phone (games, order, minutes, the games' own words) and saves it with
//   attach_plan (event) or save_plan. Both open the one plan screen.
import 'dart:async';

import 'package:flutter/material.dart';

import '../games/v3_games.dart';
import '../match_report/v3_voice_sheet.dart';
import '../session_plan/v3_session_plan_api.dart';
import '../session_plan/v3_session_plan_models.dart';
import '../session_plan/v3_session_plan_page.dart';
import '../session_plan/v3_session_plan_widgets.dart';
import '../v3_theme.dart';
import 'v3_plan_api.dart';
import 'v3_plan_draft.dart';
import 'v3_plan_models.dart';

class V3PlanBuilderPage extends StatefulWidget {
  const V3PlanBuilderPage({
    super.key,
    this.eventId,
    this.draft,
    this.onAddGames,
    this.onChangePlan,
    this.api = const V3PlanApi(),
    this.gamesApi = const V3GamesApi(),
    this.dictation,
  });

  /// The event the plan is for; null uses the draft's event, if any.
  final int? eventId;

  /// The plan in progress; the app's one draft when null.
  final V3PlanDraft? draft;

  /// "+ Add games": opens the Games list in pick mode. Hidden when null.
  final void Function(BuildContext context)? onAddGames;

  /// Passed to the plan screen of an event plan ("Change plan").
  final void Function(BuildContext context)? onChangePlan;

  final V3PlanApi api;

  /// The coach's saved games (the AI plan is written from saved games).
  final V3GamesApi gamesApi;

  /// Tests pass a fake recogniser for the voice panel.
  final V3Dictation? dictation;

  @override
  State<V3PlanBuilderPage> createState() => _V3PlanBuilderPageState();
}

class _V3PlanBuilderPageState extends State<V3PlanBuilderPage> {
  late final V3PlanDraft _draft = widget.draft ?? V3PlanDraft.instance;

  int _length = 60;
  bool _lengthTouched = false;
  int? _players;
  bool _playersTouched = false;
  bool _rotate = true;
  final _notes = TextEditingController();

  /// Whether "Write the plan for me" shows; null while that is loading.
  bool? _ai;
  PlanEvent? _event;
  SpEvent? _spEvent;
  String _squad = '';
  int? _clubId;
  bool _eventLoading = false;

  /// The event the page last loaded details for (-1: nothing loaded yet).
  int? _contextFor = -1;

  /// 'ai' or 'simple' while that button is working.
  String? _busy;
  String? _error;
  String? _failed; // the action "Try again" repeats
  bool _done = false;

  int? get _eventId => widget.eventId ?? _draft.eventId;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_draftChanged);
    unawaited(_draft.load().then((_) => _draftChanged()));
    _loadContext();
  }

  @override
  void dispose() {
    _draft.removeListener(_draftChanged);
    _notes.dispose();
    super.dispose();
  }

  void _draftChanged() {
    if (!mounted || _done) return;
    if (_eventId != _contextFor) _loadContext();
    setState(() {});
  }

  /// The event's details, how many are attending and whether AI is on.
  Future<void> _loadContext() async {
    final id = _eventId;
    if (id == _contextFor) return;
    _contextFor = id;
    final api = widget.api;
    if (id == null) {
      setState(() {
        _event = null;
        _spEvent = null;
        _eventLoading = false;
      });
      final ai = await api.aiFeatures().catchError((_) => false);
      if (mounted && _contextFor == id) setState(() => _ai = ai);
      return;
    }
    setState(() => _eventLoading = true);
    Future<void> meta() async {
      bool? ai;
      try {
        final r = await api.plan(getBody(id));
        if (r.ok) {
          final d = SpLoad.fromJson(r.map);
          // The team's switch or the coach's own AI switch (null: allowed).
          ai = d.allowed != false;
          _spEvent = d.event;
          _squad = d.squadName;
          _clubId = d.clubId;
        }
      } catch (_) {}
      ai ??= await api.aiFeatures().catchError((_) => false);
      if (mounted && _contextFor == id) setState(() => _ai = ai);
    }

    Future<void> event() async {
      try {
        final e = await api.event(id);
        if (!mounted || _contextFor != id || e == null) return;
        setState(() {
          _event = e;
          final len = e.lengthMins;
          if (!_lengthTouched && len != null) _length = len;
        });
      } catch (_) {}
    }

    Future<void> attending() async {
      try {
        final n = await api.attending(id);
        if (!mounted || _contextFor != id || n == null) return;
        if (!_playersTouched) setState(() => _players = n);
      } catch (_) {}
    }

    await Future.wait([meta(), event(), attending()]);
    if (mounted && _contextFor == id) setState(() => _eventLoading = false);
  }

  String get _eventTitle {
    final t = _event?.title ?? '';
    return t.isNotEmpty ? t : (_spEvent?.title ?? '');
  }

  // -------------------------------------------------------------- actions

  Future<void> _openNotesVoice() async {
    FocusScope.of(context).unfocus();
    await showV3VoiceSheet(
      context,
      title: 'Anything to focus on?',
      subtitle: 'Optional. Say what you want from the session.',
      placeholder: 'e.g. U12s, lots of new players, finish with a match',
      text: _notes.text,
      submitLabel: 'Done',
      onSubmit: (text) async {
        _notes.text = text;
        return true;
      },
      onError: (m) => spSnack(context, m, warn: true),
      dictation: widget.dictation,
    );
  }

  void _fail(String action, String message) {
    if (!mounted) return;
    setState(() {
      _busy = null;
      _failed = action;
      _error = message;
    });
  }

  bool _start(String action) {
    if (_busy != null || _draft.isEmpty) return false;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = action;
      _error = null;
      _failed = null;
    });
    return true;
  }

  /// The plan writer only reads the coach's saved games, so games added
  /// with + that are not saved yet are saved first (after asking).
  Future<bool> _saveGamesForAi() async {
    final Set<int> saved;
    try {
      saved = await widget.gamesApi.favouriteIds();
    } catch (_) {
      return true; // can't tell; let the server decide
    }
    final missing = [
      for (final g in _draft.games)
        if (!saved.contains(g.gameId)) g
    ];
    if (missing.isEmpty || !mounted) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
            missing.length == 1 ? 'Save this game first?' : 'Save these games?',
            style: V3.tight(20)),
        content: Text(
            'The plan is written from your saved games. '
            '${missing.map((g) => g.name).join(', ')} '
            '${missing.length == 1 ? "isn't" : "aren't"} saved yet. '
            'Saving adds ${missing.length == 1 ? 'it' : 'them'} to your '
            'Saved games.',
            style: V3.inter(16, color: V3.muted, height: 1.45)),
        actions: [
          TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: V3.inter(16, color: V3.muted))),
          TextButton(
              key: const ValueKey('save-games'),
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Save and carry on',
                  style:
                      V3.inter(16, weight: FontWeight.w700, color: V3.green))),
        ],
      ),
    );
    if (ok != true) return false;
    for (final g in missing) {
      await widget.gamesApi.toggleFavourite(g.gameId);
    }
    return true;
  }

  /// "Write the plan for me".
  Future<void> _write() async {
    if (!_start('ai')) return;
    final eventId = _eventId;
    try {
      final bool ready;
      try {
        ready = await _saveGamesForAi();
      } catch (_) {
        _fail('ai', 'Your games could not be saved. Please try again.');
        return;
      }
      if (!ready) {
        if (mounted) setState(() => _busy = null);
        return;
      }
      final notes = _notes.text.trim();
      final r = await widget.api.plan({
        ...generateBody(
            eventId: eventId,
            planId: null,
            minutes: _length,
            gameIds: [for (final g in _draft.games) g.gameId],
            rotate: _rotate),
        if (_players != null) 'player_count': _players,
        if (notes.isNotEmpty) 'session_notes': notes,
      });
      final d = r.map;
      if (d['refusal'] != null) {
        _fail('ai', '${d['refusal']}');
        return;
      }
      final plan = d['plan'];
      if (!r.ok || plan is! Map) {
        _fail(
            'ai',
            d['error'] == 'no_favourites'
                ? 'The plan is written from your saved games, and none were '
                    'found. Save your games (the heart) and try again.'
                : spErrorText(
                    d, 'The plan could not be written. Please try again.'));
        return;
      }
      final ev = d['event'];
      if (ev is Map) _spEvent = SpEvent.fromJson(ev);
      if (d['squad_name'] != null) _squad = '${d['squad_name']}';
      final br = d['branding'];
      if (br is Map) _clubId = int.tryParse('${br['club_id'] ?? ''}');
      final id = d['plan_id'] == null ? null : '${d['plan_id']}';
      final shown = deepCopy(plan);
      await _keepPlayers(shown, id, eventId);
      await _openPlan(shown, id, eventId);
    } catch (_) {
      _fail('ai', 'Network error. Please try again.');
    }
  }

  /// "Keep it simple": no AI; the games, their order and minutes.
  Future<void> _simple() async {
    if (!_start('simple')) return;
    final eventId = _eventId;
    final api = widget.api;
    try {
      final games = _draft.games;
      final details = <int, V3Game>{};
      try {
        for (final g
            in await api.gamesByIds([for (final g in games) g.gameId])) {
          details[g.gameId] = g;
        }
      } catch (_) {
        _fail('simple',
            'Your games could not be loaded. Check your connection and try again.');
        return;
      }
      var plan = buildSimplePlan(
          title: eventId != null ? _eventTitle : '',
          games: games,
          details: details,
          players: _players,
          notes: _notes.text);
      final String? id;
      if (eventId != null) {
        // attach_plan fills in the event's players, weather, date and title.
        final r = await api.plan(
            {'action': 'attach_plan', 'event_id': eventId, 'plan_json': plan});
        final p = r.map['plan_json'];
        if (!r.ok || p is! Map || r.map['plan_id'] == null) {
          _fail('simple',
              spErrorText(r.data, 'The plan could not be saved. Try again.'));
          return;
        }
        plan = deepCopy(p);
        id = '${r.map['plan_id']}';
      } else {
        final r = await api.plan({'action': 'save_plan', 'plan_json': plan});
        if (!r.ok || r.map['plan_id'] == null) {
          _fail('simple',
              spErrorText(r.data, 'The plan could not be saved. Try again.'));
          return;
        }
        id = '${r.map['plan_id']}';
      }
      await _keepPlayers(plan, id, eventId);
      await _openPlan(plan, id, eventId);
    } catch (_) {
      _fail('simple', 'Network error. Please try again.');
    }
  }

  /// For an event the server counts the players itself; a number the coach
  /// set by hand wins.
  Future<void> _keepPlayers(
      Map<String, dynamic> plan, String? planId, int? eventId) async {
    final n = _players;
    if (!_playersTouched || n == null || eventId == null) return;
    if ('${plan['player_count']}' == '$n') return;
    plan['player_count'] = n;
    if (planId == null) return;
    try {
      await widget.api
          .plan(updateBody(eventId: eventId, planId: planId, plan: plan));
    } catch (_) {}
  }

  /// Opens the plan screen. A plan that is already saved empties the draft
  /// and takes the builder's place; an unsaved AI plan (no event) keeps the
  /// builder underneath until the coach saves it.
  Future<void> _openPlan(
      Map<String, dynamic> plan, String? planId, int? eventId) async {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final api = widget.api;
    var savedLater = false;
    final saved = planId != null;
    final event = _spEvent ??
        (_event == null
            ? null
            : SpEvent(
                title: _event!.title,
                dateTime: _event!.start,
                teamName: _event!.teamName));
    final route = MaterialPageRoute<void>(
        builder: (_) => V3SessionPlanPage.open(
              eventId: eventId,
              plan: plan,
              planId: planId,
              aiAllowed: _ai ?? false,
              event: eventId == null ? null : event,
              squadName: eventId == null ? '' : _squad,
              clubId: _clubId,
              minutes: _length,
              onChangePlan: eventId == null ? null : widget.onChangePlan,
              onSaved: saved
                  ? null
                  : () {
                      savedLater = true;
                      _done = true;
                      _draft.clear();
                    },
              gamesApi: widget.gamesApi,
              call: api.callOverride,
              userId: api.userIdOverride,
              dictation: widget.dictation,
              aiProbe: api.aiProbe,
            ));
    if (saved) {
      _done = true;
      _draft.clear();
      spPlansChanged.value++;
      await nav.pushReplacement(route);
      return;
    }
    setState(() => _busy = null);
    await nav.push(route);
    if (savedLater && mounted) await nav.maybePop();
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final games = _draft.games;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: spAppBar(context, 'New plan'),
        body: ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          buildDefaultDragHandles: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _header(games)),
          footer: _footer(games),
          itemCount: games.length,
          // The draft's move() takes the list's raw drop index.
          onReorderItem: (from, to) {
            if (_busy == null) _draft.move(from, to > from ? to + 1 : to);
          },
          itemBuilder: (_, i) => _gameRow(i, games[i]),
        ),
        bottomNavigationBar: _bottomBar(games.isNotEmpty),
      ),
    );
  }

  Widget _box(Widget child, {EdgeInsets? padding}) => Container(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
            color: V3.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V3.line)),
        child: child,
      );

  Widget _step(String key, IconData icon, String tip, VoidCallback? onTap) =>
      Material(
        color: V3.card2,
        borderRadius: BorderRadius.circular(10),
        child: IconButton(
          key: ValueKey(key),
          tooltip: tip,
          iconSize: 24,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: Icon(icon,
              color: onTap == null ? V3.muted.withValues(alpha: 0.4) : V3.text),
          onPressed: onTap,
        ),
      );

  Widget _stepper(String id, String label, String value,
          {VoidCallback? onMinus, VoidCallback? onPlus, String? sub}) =>
      _box(Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: V3.inter(17, weight: FontWeight.w500)),
            if (sub != null)
              Text(sub, style: V3.inter(14, color: V3.muted, height: 1.35)),
          ]),
        ),
        _step('$id-minus', Icons.remove, 'Less', onMinus),
        SizedBox(
          width: 84,
          child: Text(value,
              key: ValueKey('$id-value'),
              textAlign: TextAlign.center,
              style: V3.inter(18, weight: FontWeight.w700, color: V3.green)),
        ),
        _step('$id-plus', Icons.add, 'More', onPlus),
      ]));

  List<Widget> _header(List<PlanDraftGame> games) {
    final eventId = _eventId;
    final busy = _busy != null;
    final line = minutesLine(_draft.totalMins, _length);
    return [
      const SpLabel('For'),
      _forCard(eventId),
      const SizedBox(height: 18),
      const SpLabel('Length'),
      _stepper('length', 'Length of session', '$_length min',
          onMinus: busy || _length <= 15
              ? null
              : () => setState(() {
                    _lengthTouched = true;
                    _length = stepLength(_length, -1);
                  }),
          onPlus: busy || _length >= 180
              ? null
              : () => setState(() {
                    _lengthTouched = true;
                    _length = stepLength(_length, 1);
                  })),
      const SizedBox(height: 18),
      const SpLabel('Players'),
      _stepper('players', eventId != null ? 'Attending' : 'Roughly how many',
          _players == null ? '—' : '$_players',
          sub: eventId != null && !_playersTouched && _players != null
              ? 'Counted from the replies so far'
              : null,
          onMinus: busy || _players == null
              ? null
              : () => setState(() {
                    _playersTouched = true;
                    _players = stepPlayers(_players, -1);
                  }),
          onPlus: busy || (_players ?? 0) >= 60
              ? null
              : () => setState(() {
                    _playersTouched = true;
                    _players = stepPlayers(_players, 1);
                  })),
      const SizedBox(height: 18),
      const SpLabel('Anything to focus on? (optional)'),
      Stack(children: [
        TextField(
          key: const ValueKey('notes'),
          controller: _notes,
          enabled: !busy,
          minLines: 2,
          maxLines: null,
          style: V3.inter(16, height: 1.45),
          cursorColor: V3.green,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g. U12s, lots of new players, finish with a match',
            hintStyle: V3.inter(16, color: V3.muted),
            filled: true,
            fillColor: V3.card,
            contentPadding: const EdgeInsets.fromLTRB(14, 12, 64, 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: V3.line)),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: V3.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: V3.green.withValues(alpha: 0.45))),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: IconButton.filled(
            tooltip: 'Say it instead',
            style: IconButton.styleFrom(
                backgroundColor: V3.green, minimumSize: const Size(44, 44)),
            icon: const Icon(Icons.mic_none, color: Colors.black87),
            onPressed: busy ? null : _openNotesVoice,
          ),
        ),
      ]),
      if (_ai == true) ...[
        const SizedBox(height: 18),
        _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Rotate through stations',
                    style: V3.inter(17, weight: FontWeight.w500))),
            Switch(
                key: const ValueKey('rotate'),
                value: _rotate,
                activeThumbColor: V3.green,
                onChanged: busy ? null : (v) => setState(() => _rotate = v)),
          ]),
          Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            child: Text(
                'For "Write the plan for me". When on, players are split '
                'across the games and rotate, so not everyone does the same '
                'thing at once.',
                style: V3.inter(14, color: V3.muted, height: 1.45)),
          ),
        ])),
      ],
      const SizedBox(height: 22),
      const SpLabel('Games, in order'),
      if (games.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: line.text,
                  style: V3.inter(16,
                      weight: FontWeight.w700,
                      color: line.over ? V3.amberText : V3.text)),
              TextSpan(
                  text: ' · ${line.hint}',
                  style:
                      V3.inter(16, color: line.over ? V3.amberText : V3.muted)),
            ]),
            key: const ValueKey('minutes-line'),
          ),
        ),
    ];
  }

  Widget _forCard(int? eventId) {
    if (eventId == null) {
      return _box(
          Row(children: [
            const Icon(Icons.bookmark_border, color: V3.muted),
            const SizedBox(width: 12),
            Expanded(
                child: Text('No event · reusable plan',
                    style: V3.inter(17, weight: FontWeight.w500))),
          ]),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16));
    }
    final title = _eventTitle;
    final line = _event?.line ??
        [
          if (_spEvent?.dateTime != null) planDay(_spEvent!.dateTime!),
          if (_spEvent?.dateTime != null) planClock(_spEvent!.dateTime!),
          if ((_spEvent?.teamName ?? '').isNotEmpty) _spEvent!.teamName,
        ].join(' · ');
    return _box(
        Row(children: [
          const Icon(Icons.event_outlined, color: V3.green),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  title.isNotEmpty
                      ? title
                      : (_eventLoading ? 'Loading the event…' : 'Your event'),
                  style: V3.inter(17, weight: FontWeight.w600)),
              if (line.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(line, style: V3.inter(15, color: V3.muted)),
              ],
            ]),
          ),
          // An event left on the draft from earlier can be taken off.
          if (widget.eventId == null)
            IconButton(
              key: const ValueKey('clear-event'),
              tooltip: 'Not for this event',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.close, color: V3.muted),
              onPressed: _busy != null ? null : () => _draft.setEvent(null),
            ),
        ]),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12));
  }

  Widget _gameRow(int i, PlanDraftGame g) {
    final busy = _busy != null;
    return Padding(
      key: ValueKey('game-${g.gameId}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: V3.line)),
        clipBehavior: Clip.antiAlias,
        child: Row(children: [
          ReorderableDragStartListener(
            index: i,
            enabled: !busy,
            child: const SizedBox(
              width: 48,
              height: 104,
              child: Tooltip(
                message: 'Hold and drag to move',
                child: Icon(Icons.drag_handle, color: V3.muted, size: 28),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name.isEmpty ? 'Game' : g.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(17, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(children: [
                      _step(
                          'minus-${g.gameId}',
                          Icons.remove,
                          'Less time',
                          busy || g.mins <= 5
                              ? null
                              : () => _draft.setMins(
                                  g.gameId, stepGameMins(g.mins, -1))),
                      SizedBox(
                        width: 78,
                        child: Text('${g.mins} min',
                            key: ValueKey('mins-${g.gameId}'),
                            textAlign: TextAlign.center,
                            style: V3.inter(17,
                                weight: FontWeight.w700, color: V3.green)),
                      ),
                      _step(
                          'plus-${g.gameId}',
                          Icons.add,
                          'More time',
                          busy || g.mins >= 120
                              ? null
                              : () => _draft.setMins(
                                  g.gameId, stepGameMins(g.mins, 1))),
                    ]),
                  ]),
            ),
          ),
          IconButton(
            key: ValueKey('remove-${g.gameId}'),
            tooltip: 'Remove from the plan',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close, color: V3.muted),
            onPressed: busy ? null : () => _draft.remove(g.gameId),
          ),
        ]),
      ),
    );
  }

  Widget _footer(List<PlanDraftGame> games) {
    final add = widget.onAddGames;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (games.isEmpty)
        _box(
            Column(children: [
              Text('No games yet',
                  style: V3.inter(17, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                  add != null
                      ? 'Add the games you want to play, then put them in order.'
                      : 'Go to Games and tap + on the games you want to play.',
                  textAlign: TextAlign.center,
                  style: V3.inter(15, color: V3.muted, height: 1.45)),
            ]),
            padding: const EdgeInsets.all(18)),
      if (add != null) ...[
        const SizedBox(height: 8),
        if (_draft.isFull)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('A plan holds up to $kPlanMaxGames games.',
                textAlign: TextAlign.center,
                style: V3.inter(15, color: V3.muted)),
          )
        else
          SpButton('Add games',
              key: const ValueKey('add-games'),
              icon: Icons.add,
              outline: true,
              onPressed: _busy != null ? null : () => add(context)),
      ],
    ]);
  }

  Widget _bottomBar(bool hasGames) {
    final busy = _busy;
    return Container(
      decoration: const BoxDecoration(
          color: V3.bg, border: Border(top: BorderSide(color: V3.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Container(
                    key: const ValueKey('builder-error'),
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    decoration: BoxDecoration(
                        color: V3.amberTint,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: V3.amberLine)),
                    child: Row(children: [
                      Expanded(
                        child: Text(_error!,
                            style:
                                V3.inter(15, color: V3.amberText, height: 1.4)),
                      ),
                      TextButton(
                        key: const ValueKey('retry'),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(64, 44)),
                        onPressed: busy != null
                            ? null
                            : (_failed == 'ai' ? _write : _simple),
                        child: Text('Try again',
                            style: V3.inter(15,
                                weight: FontWeight.w700, color: V3.text)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                ],
                if (!hasGames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Add at least one game to make a plan.',
                        textAlign: TextAlign.center,
                        style: V3.inter(15, color: V3.muted)),
                  ),
                if (_ai == true) ...[
                  SpButton(
                      busy == 'ai'
                          ? 'Writing your plan…'
                          : 'Write the plan for me',
                      key: const ValueKey('write-plan'),
                      icon: Icons.auto_awesome,
                      busy: busy == 'ai',
                      onPressed: hasGames && busy == null ? _write : null),
                  const SizedBox(height: 8),
                ],
                Opacity(
                  opacity: hasGames ? 1 : 0.5,
                  child: SpButton(
                      busy == 'simple' ? 'Saving your plan…' : 'Keep it simple',
                      key: const ValueKey('keep-simple'),
                      outline: _ai == true,
                      busy: busy == 'simple',
                      onPressed: hasGames && busy == null ? _simple : null),
                ),
              ]),
        ),
      ),
    );
  }
}
