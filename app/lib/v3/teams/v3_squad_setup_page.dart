// v3 Squad setup for one team (super users, Ken approved 2026-11-12;
// mockups app-v3/squad-setup/). Opened from the Team page ⋮ menu.
// Rows like the web Team setup page: colour, name, player count, pencil,
// drag to reorder, No Team fixed at the bottom, "+ Add a squad". The add /
// edit sheet is the create-team squad row (colour tile + name) with quick
// swatches. "Turn off" never deletes: players go to No Team and the squad
// moves to "Turned off" with a "Turn on" button (disable_team_squad /
// enable_team_squad). Player counts ignore the "-" code.
import 'package:flutter/material.dart';

import '../create_team/v3_create_team_models.dart'
    show colourFromHex, textOnHex, kSquadDefaults;
import '../create_team/v3_create_team_page.dart' show V3SquadColourSheet;
import '../v3_theme.dart';
import 'v3_squad_setup_models.dart';
import '/v3/v3_squads.dart';
import '/v3/tracking/v3_track.dart';

class V3SquadSetupPage extends StatefulWidget {
  const V3SquadSetupPage(
      {super.key, required this.teamId, this.api = const SquadSetupApi()});

  final int teamId;

  /// Tests pass a fake.
  final SquadSetupApi api;

  @override
  State<V3SquadSetupPage> createState() => _V3SquadSetupPageState();
}

class _V3SquadSetupPageState extends State<V3SquadSetupPage> {
  SquadSetup? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.load(widget.teamId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = squadErrorText(e));
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: V3.card2,
          content: Text(text, style: V3.inter(15, weight: FontWeight.w500))));

  /// Runs a change; the result is the new list. Errors go in a snack bar.
  Future<bool> _run(Future<SquadSetup> Function() call, {String? done}) async {
    setState(() => _busy = true);
    try {
      final d = await call();
      if (!mounted) return true;
      setState(() {
        _data = d;
        _busy = false;
      });
      if (done != null) _snack(done);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _busy = false);
      _snack(squadErrorText(e));
      return false;
    }
  }

  Future<void> _openSheet({SetupSquad? squad}) async {
    final d = _data;
    if (d == null || _busy) return;
    final used = {for (final s in d.movable) s.colour.toUpperCase()};
    final fresh = kSquadDefaults.firstWhere((c) => !used.contains(c),
        orElse: () => kSquadDefaults.first);
    final result = await showModalBottomSheet<_SheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _SquadSheet(
          squad: squad,
          colour: squad?.colour ?? fresh,
          others: [...d.squads, ...d.disabled]),
    );
    if (result == null || !mounted) return;
    if (result.turnOff) {
      await _confirmOff(squad!);
      return;
    }
    final ok = await _run(
        () => widget.api.save(
            widget.teamId, squad?.squadId, result.name, result.colour,
            grade: result.grade),
        done: squad == null
            ? '${result.name.trim()} added.'
            : '${result.name.trim()} saved.');
    if (ok) V3Track.event(squad == null ? 'squad_added' : 'squad_edited');
  }

  Future<void> _confirmOff(SetupSquad s) async {
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Grab(),
                Text('Turn off ${s.name}?', style: V3.tight(20)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: V3.redTint,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                      s.players == 0
                          ? '${s.name} stops showing when you create events or pick squads.'
                          : 'The ${s.players == 1 ? 'player' : '${s.players} players'} in ${s.name} become Unassigned. ${s.name} stops showing when you create events or pick squads.',
                      style: V3.inter(15,
                          color: const Color(0xFFF3C4C6), height: 1.45)),
                ),
                const SizedBox(height: 12),
                Text(
                    'Past events, match reports and stats keep the name ${s.name}. You can turn it back on later, but players will need to be placed again.',
                    style: V3.inter(14, color: V3.muted, height: 1.45)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('ss-confirm-off'),
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                        backgroundColor: V3.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text('Turn off ${s.name}',
                        style: V3.inter(16,
                            weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: V3.inter(16,
                          weight: FontWeight.w600, color: V3.muted)),
                ),
              ]),
        ),
      ),
    );
    if (yes != true || !mounted) return;
    final ok = await _run(() => widget.api.disable(widget.teamId, s.squadId),
        done: '${s.name} is turned off.');
    if (ok) V3Track.event('squad_turned_off');
  }

  Future<void> _turnOn(SetupSquad s) async {
    final ok = await _run(() => widget.api.enable(widget.teamId, s.squadId),
        done: '${s.name} is back on.');
    if (ok) V3Track.event('squad_turned_on');
  }

  Future<void> _reorder(int from, int to) async {
    final d = _data!;
    final list = [...d.movable];
    list.insert(to, list.removeAt(from));
    // Show the new order straight away.
    setState(() => _data = SquadSetup(
        teamName: d.teamName,
        clubName: d.clubName,
        squads: [...list, if (d.noTeam != null) d.noTeam!],
        disabled: d.disabled));
    final ok = await _run(() =>
        widget.api.reorder(widget.teamId, [for (final s in list) s.squadId]));
    if (!ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Squads', style: V3.tight(20)),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                    minHeight: 2,
                    color: V3.green,
                    backgroundColor: Colors.transparent))
            : null,
      ),
      body: d == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: V3.inter(15, color: V3.muted)),
                        TextButton(
                            onPressed: _load,
                            child: Text('Try again',
                                style: V3.inter(16,
                                    weight: FontWeight.w600, color: V3.green))),
                      ]),
                    )
                  : const CircularProgressIndicator(color: V3.green))
          : RefreshIndicator(
              color: V3.green,
              backgroundColor: V3.card,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 40),
                children: [
                  Text(
                      [
                        if (d.teamName.isNotEmpty) d.teamName,
                        if (d.clubName.isNotEmpty) d.clubName
                      ].join(' · '),
                      style: V3.inter(14, color: V3.muted)),
                  _section('Squads',
                      d.movable.length > 1 ? 'Drag to reorder' : null),
                  _activeCard(d),
                  if (d.disabled.isNotEmpty) ...[
                    _section('Turned off', 'Kept for old events'),
                    _card([for (final s in d.disabled) _offRow(s)]),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
                    child: Text(
                        'Turning a squad off makes its players Unassigned and hides it from new events. Past events, match reports and stats keep its name. You can turn it back on any time.',
                        style: V3.inter(13, color: V3.muted, height: 1.45)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, String? right) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
        child: Row(children: [
          Text(title.toUpperCase(),
              style: V3
                  .inter(13, weight: FontWeight.w700, color: V3.green)
                  .copyWith(letterSpacing: 0.8)),
          const SizedBox(width: 12),
          if (right != null)
            Expanded(
              child: Text(right,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      V3.inter(13, weight: FontWeight.w500, color: V3.muted)),
            ),
        ]),
      );

  Widget _card(List<Widget> rows) => Container(
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, color: V3.line),
            rows[i],
          ]
        ]),
      );

  Widget _activeCard(SquadSetup d) {
    final movable = d.movable;
    final noTeam = d.noTeam;
    return Container(
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: V3.dragProxy,
          itemCount: movable.length,
          onReorderItem: _busy ? (_, __) {} : _reorder,
          itemBuilder: (_, i) => Container(
            key: ValueKey('ss-row-${movable[i].squadId}'),
            color: V3.card,
            child: Column(children: [
              _row(movable[i], index: i, canDrag: movable.length > 1),
              const Divider(height: 1, thickness: 1, color: V3.line),
            ]),
          ),
        ),
        if (noTeam != null) ...[
          _row(noTeam),
          const Divider(height: 1, thickness: 1, color: V3.line),
        ],
        InkWell(
          key: const ValueKey('ss-add'),
          onTap: _busy ? null : () => _openSheet(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            child: Row(children: [
              Text('+ Add a squad',
                  style:
                      V3.inter(16, weight: FontWeight.w600, color: V3.green)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _row(SetupSquad s, {int? index, bool canDrag = false}) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(4, 11, 8, 11),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: canDrag && index != null
              ? ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator,
                      color: Color(0xFF6B7080), size: 22))
              : null,
        ),
        _swatch(s.colour),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v3SquadName(s.name),
                style: V3.inter(16, weight: FontWeight.w500)),
            const SizedBox(height: 1),
            Text(
                s.noTeam
                    ? (s.players == 0
                        ? 'Everyone is placed'
                        : '${playersLine(s.players)} not placed yet')
                    : [
                        if (s.grade.trim().isNotEmpty)
                          'Grade ${s.grade.trim()}',
                        playersLine(s.players),
                      ].join(' · '),
                style: V3.inter(13, color: V3.muted)),
          ]),
        ),
        if (!s.noTeam)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.edit_outlined, color: V3.muted, size: 21),
          ),
      ]),
    );
    if (s.noTeam) return body;
    return InkWell(
        key: ValueKey('ss-edit-${s.squadId}'),
        onTap: _busy ? null : () => _openSheet(squad: s),
        child: body);
  }

  Widget _offRow(SetupSquad s) => Padding(
        padding: const EdgeInsets.fromLTRB(34, 11, 12, 11),
        child: Row(children: [
          Opacity(opacity: 0.35, child: _swatch(s.colour)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name,
                  style:
                      V3.inter(16, weight: FontWeight.w500, color: V3.muted)),
              const SizedBox(height: 1),
              Text(disabledLine(s), style: V3.inter(13, color: V3.muted)),
            ]),
          ),
          OutlinedButton(
            key: ValueKey('ss-on-${s.squadId}'),
            onPressed: _busy ? null : () => _turnOn(s),
            style: OutlinedButton.styleFrom(
                foregroundColor: V3.green,
                side: const BorderSide(color: V3.green, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9))),
            child: Text('Turn on',
                style: V3.inter(13, weight: FontWeight.w600, color: V3.green)),
          ),
        ]),
      );

  Widget _swatch(String hex) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
            color: colourFromHex(hex),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12)),
      );
}

class _Grab extends StatelessWidget {
  const _Grab();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: V3.barGrey, borderRadius: BorderRadius.circular(3))),
      );
}

class _SheetResult {
  const _SheetResult(this.name, this.colour,
      {this.grade = '', this.turnOff = false});
  final String name;
  final String colour;
  final String grade;
  final bool turnOff;
}

/// Add or edit: colour tile + name (as creating a team), quick swatches,
/// Save, and for an existing squad "Turn this squad off".
class _SquadSheet extends StatefulWidget {
  const _SquadSheet(
      {required this.squad, required this.colour, required this.others});
  final SetupSquad? squad;
  final String colour;
  final List<SetupSquad> others;

  @override
  State<_SquadSheet> createState() => _SquadSheetState();
}

class _SquadSheetState extends State<_SquadSheet> {
  late final _name = TextEditingController(text: widget.squad?.name ?? '');
  late String _colour = widget.colour.toUpperCase();
  late String _grade = widget.squad?.grade.trim() ?? '';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isNew => widget.squad == null;

  Future<void> _custom() async {
    final label = _name.text.trim().isEmpty ? 'Squad' : _name.text.trim();
    final hex = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => V3SquadColourSheet(
          title: 'Colour for $label', label: label, colour: _colour),
    );
    if (hex != null && mounted) setState(() => _colour = hex.toUpperCase());
  }

  void _save() {
    final err = squadNameError(_name.text, widget.others,
        squadId: widget.squad?.squadId);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.pop(
        context, _SheetResult(_name.text.trim(), _colour, grade: _grade));
  }

  /// Grade is for reporting only: shown here (super users) and nowhere
  /// a coach or parent looks (Ken, 2026-11-12).
  Widget _gradeRow() {
    final options = ['', ...kSquadGrades];
    if (_grade.isNotEmpty && !options.contains(_grade)) options.add(_grade);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('GRADE · ONLY SUPER USERS SEE THIS',
          style: V3
              .inter(12, weight: FontWeight.w600, color: V3.muted)
              .copyWith(letterSpacing: 0.6)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in options)
          ChoiceChip(
            key: ValueKey('ss-grade-${g.isEmpty ? 'none' : g}'),
            label: Text(g.isEmpty ? 'None' : g),
            selected: _grade == g,
            showCheckmark: false,
            onSelected: (_) => setState(() => _grade = g),
            labelStyle: V3.inter(14,
                weight: FontWeight.w600, color: _grade == g ? V3.bg : V3.text),
            selectedColor: V3.green,
            backgroundColor: V3.card2,
            side: BorderSide.none,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final swatches = kSquadDefaults.take(7).toList();
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Grab(),
                Text(_isNew ? 'Add a squad' : 'Edit squad',
                    style: V3.tight(20)),
                const SizedBox(height: 4),
                Text(
                    _isNew
                        ? 'New squads start empty. Place players from the Team page.'
                        : 'Tap the colour to change it. Players and events stay as they are.',
                    style: V3.inter(14, color: V3.muted, height: 1.45)),
                const SizedBox(height: 14),
                Row(children: [
                  Semantics(
                    button: true,
                    label: 'Colour',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _custom,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                            color: colourFromHex(_colour),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.white24, width: 1.5)),
                        child: Icon(Icons.palette_outlined,
                            size: 20,
                            color: textOnHex(_colour).withValues(alpha: 0.75)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('ss-name'),
                      controller: _name,
                      autofocus: _isNew,
                      maxLength: 40,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _save(),
                      style: V3.inter(17),
                      cursorColor: V3.green,
                      decoration: InputDecoration(
                        hintText: 'Squad name',
                        hintStyle: V3.inter(17, color: V3.muted),
                        counterText: '',
                        filled: true,
                        fillColor: V3.card2,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 17),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: V3.line)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: V3.green, width: 1.5)),
                      ),
                    ),
                  ),
                ]),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child:
                        Text(_error!, style: V3.inter(14, color: V3.redText)),
                  ),
                const SizedBox(height: 14),
                Text('COLOUR',
                    style: V3
                        .inter(12, weight: FontWeight.w600, color: V3.muted)
                        .copyWith(letterSpacing: 0.6)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final c in swatches)
                    GestureDetector(
                      onTap: () => setState(() => _colour = c.toUpperCase()),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colourFromHex(c),
                          borderRadius: BorderRadius.circular(9),
                          border: c.toUpperCase() == _colour
                              ? Border.all(color: Colors.white, width: 2.5)
                              : null,
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: _custom,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: const SweepGradient(colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ]),
                        border: swatches
                                .map((c) => c.toUpperCase())
                                .contains(_colour)
                            ? null
                            : Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                _gradeRow(),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('ss-save'),
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: V3.green,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(_isNew ? 'Add squad' : 'Save',
                        style: V3.inter(16,
                            weight: FontWeight.w700, color: V3.bg)),
                  ),
                ),
                if (!_isNew) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      key: const ValueKey('ss-off'),
                      onPressed: () => Navigator.pop(
                          context,
                          _SheetResult(widget.squad!.name, _colour,
                              turnOff: true)),
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: V3.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: Text('Turn this squad off',
                          style: V3.inter(16,
                              weight: FontWeight.w700, color: V3.redText)),
                    ),
                  ),
                ],
              ]),
        ),
      ),
    );
  }
}
