// Build Session Plan (the setup screen of webviews/favourites.html): length,
// optional player count, an optional focus typed or spoken, and the
// station rotation switch; Generate Plan asks generate-session-plan for a
// plan from the picked games.
import 'package:flutter/material.dart';

import '../match_report/v3_voice_sheet.dart';
import '../v3_theme.dart';
import 'v3_fav_widgets.dart';
import 'v3_favourites_api.dart';
import 'v3_favourites_models.dart';
import 'v3_my_plans_page.dart';
import 'v3_session_plan_page.dart';

class V3SessionSetupPage extends StatefulWidget {
  const V3SessionSetupPage({
    super.key,
    required this.gameIds,
    this.durationMins = 60,
    this.eventId,
    this.api = const V3FavouritesApi(),
    this.dictation,
  });

  /// The picked games, in session order (at most [kMaxGames]).
  final List<int> gameIds;
  final int durationMins;
  final int? eventId;
  final V3FavouritesApi api;

  @visibleForTesting
  final V3Dictation? dictation;

  @override
  State<V3SessionSetupPage> createState() => _V3SessionSetupPageState();
}

class _V3SessionSetupPageState extends State<V3SessionSetupPage> {
  late int _dur = widget.durationMins;
  int? _players;
  bool _rotate = true;
  final _notes = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _empty = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _openNotesVoice() async {
    FocusScope.of(context).unfocus();
    await showV3VoiceSheet(
      context,
      title: 'Anything to focus on?',
      subtitle: 'Optional. The plan is built around this and your games.',
      placeholder: 'e.g. U12s, lots of new players, finish with a match',
      text: _notes.text,
      submitLabel: 'Done',
      onSubmit: (text) async {
        _notes.text = text;
        return true;
      },
      onError: (m) => favSnack(context, m, warn: true),
      dictation: widget.dictation,
    );
  }

  Future<void> _generate() async {
    final ids = widget.gameIds;
    if (ids.isEmpty) {
      favSnack(context, 'Select at least one game');
      return;
    }
    if (ids.length > kMaxGames) {
      favSnack(context, 'You can pick up to $kMaxGames games');
      return;
    }
    FocusScope.of(context).unfocus();
    favClearSnack(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes = _notes.text.trim();
      final r = await widget.api.plan('generate', {
        'duration_mins': _dur,
        'game_ids': ids,
        'rotate_stations': _rotate,
        if (_players != null) 'player_count': _players,
        if (notes.isNotEmpty) 'session_notes': notes,
      });
      if (!mounted) return;
      final d = r.data;
      if (d['error'] == 'no_favourites') {
        setState(() {
          _loading = false;
          _empty = true;
        });
        return;
      }
      final plan = d['plan'];
      if (d['refusal'] == null && (!r.ok || plan is! Map)) {
        setState(() {
          _loading = false;
          _error =
              '${d['message'] ?? d['error'] ?? 'Generation failed. Please try again.'}';
        });
        return;
      }
      setState(() => _loading = false);
      final id = d['plan_id'];
      final planId = id is int ? id : int.tryParse('${id ?? ''}');
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => V3SessionPlanPage(
          plan: plan is Map ? Map<String, dynamic>.from(plan) : {},
          planId: planId,
          isDraft: planId == null,
          fromSetup: true,
          durationMins: _dur,
          refusal: d['refusal'] == null ? null : '${d['refusal']}',
          eventId: widget.eventId,
          api: widget.api,
          dictation: widget.dictation,
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Network error. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: favAppBar(
          context,
          Text(_loading ? 'Loading…' : 'Build Session Plan',
              style: V3.tight(18)),
          actions: [
            MyPlansPill(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => V3MyPlansPage(
                        api: widget.api, eventId: widget.eventId)))),
          ],
        ),
        body: _loading
            ? const FavStateView(
                loading: true, body: 'Generating your session plan…')
            : _empty
                ? const FavStateView(
                    icon: '⭐',
                    title: 'No Favourites Yet',
                    body:
                        'Head to the Games Library and add some favourites, then come back here.')
                : _error != null
                    ? FavStateView(
                        icon: '⚠️',
                        title: 'Something went wrong',
                        body: _error!)
                    : _form(),
        bottomNavigationBar: _loading || _empty
            ? null
            : FavBottomBar(children: [
                Expanded(
                    child: FavButton(
                        label: 'Back',
                        primary: false,
                        onPressed: () => _error != null
                            ? setState(() => _error = null)
                            : Navigator.of(context).maybePop())),
                Expanded(
                    child: FavButton(
                        label: 'Generate Plan', onPressed: _generate)),
              ]),
      ),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const FavFieldLabel('Session Duration'),
        _Stepper(
          label: 'Length of session',
          value: '$_dur min',
          onMinus: () => setState(() => _dur = adjustDuration(_dur, -5)),
          onPlus: () => setState(() => _dur = adjustDuration(_dur, 5)),
        ),
        const SizedBox(height: 18),
        const FavFieldLabel('Players (optional)'),
        _Stepper(
          label: 'Roughly how many',
          value: _players == null ? '—' : '$_players',
          onMinus: () => setState(() => _players = adjustPlayers(_players, -1)),
          onPlus: () => setState(() => _players = adjustPlayers(_players, 1)),
        ),
        const SizedBox(height: 18),
        const FavFieldLabel('Anything to focus on? (optional)'),
        Stack(children: [
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: null,
            style: V3.inter(16, height: 1.45),
            cursorColor: V3.green,
            decoration: InputDecoration(
              hintText: 'e.g. U12s, lots of new players, finish with a match',
              hintStyle: V3.inter(16, color: V3.muted),
              filled: true,
              fillColor: V3.card2,
              contentPadding: const EdgeInsets.fromLTRB(14, 12, 60, 12),
              enabledBorder: OutlineInputBorder(
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
              tooltip: 'Speak instead',
              style: IconButton.styleFrom(
                  backgroundColor: V3.green, minimumSize: const Size(44, 44)),
              icon: const Icon(Icons.mic_none, color: Colors.black87),
              onPressed: _openNotesVoice,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
            'Type it, or tap the mic to say it. Leave it blank to build from your games only.',
            style: V3.inter(14, color: V3.muted, height: 1.4)),
        const SizedBox(height: 18),
        const FavFieldLabel('Session Format'),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 14),
          decoration: BoxDecoration(
              color: V3.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: V3.line)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text('Rotate through stations',
                      style: V3.inter(17, weight: FontWeight.w500))),
              Switch(
                value: _rotate,
                activeTrackColor: V3.green,
                onChanged: (v) => setState(() => _rotate = v),
              ),
            ]),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                  'When on, players are split across the drill stations and rotate at intervals — not everyone performs the same activity at the same time. Warm-up and cool-down remain collective.',
                  style: V3.inter(14, color: V3.muted, height: 1.5)),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper(
      {required this.label,
      required this.value,
      required this.onMinus,
      required this.onPlus});
  final String label, value;
  final VoidCallback onMinus, onPlus;

  @override
  Widget build(BuildContext context) {
    Widget btn(String t, VoidCallback f, String tip) => Tooltip(
          message: tip,
          child: Material(
            color: V3.card2,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: f,
              child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(child: Text(t, style: V3.inter(24)))),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: V3.line)),
      child: Row(children: [
        Expanded(
            child: Text(label, style: V3.inter(17, weight: FontWeight.w500))),
        btn('−', onMinus, 'Less'),
        SizedBox(
          width: 76,
          child: Text(value,
              textAlign: TextAlign.center,
              style: V3.inter(18, weight: FontWeight.w700, color: V3.green)),
        ),
        btn('+', onPlus, 'More'),
      ]),
    );
  }
}
