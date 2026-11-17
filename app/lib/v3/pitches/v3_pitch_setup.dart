// v3 Pitch planner, setup (mock-up pa-setup) and groups. Venues hold
// pitches; each pitch has the slots the club holds each week (the sheet's
// "Free" cells; anything else is "No slot") and "also called" names so old
// event locations and league venues land on it. Groups are a placeholder
// for every team at the club, on CoachSmart or not (Ken, 2026-11-16).
import 'package:flutter/material.dart';

import 'v3_pitch_theme.dart';
import 'v3_pitch_api.dart';
import 'v3_pitch_controller.dart';
import 'v3_pitch_models.dart';
import 'v3_pitch_sheets.dart';
import 'v3_pitch_board.dart' show codeColour;

class PitchSetupView extends StatefulWidget {
  const PitchSetupView({super.key, required this.c});
  final PitchController c;
  @override
  State<PitchSetupView> createState() => _PitchSetupViewState();
}

class _PitchSetupViewState extends State<PitchSetupView> {
  PitchSetup? _setup;
  String? _error;
  bool _busy = false;

  PitchController get c => widget.c;
  PitchApi get api => c.api;
  int get club => c.club.clubId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await api.setup(club);
      if (!mounted) return;
      setState(() {
        _setup = s;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = pitchErrorText(e));
    }
  }

  Future<void> _run(Future<void> Function() call, String done) async {
    setState(() => _busy = true);
    try {
      await call();
      await _load();
      c.load(force: true);
      if (mounted) pitchSnack(context, done);
    } catch (e) {
      if (mounted) pitchSnack(context, pitchErrorText(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _editVenue([Venue? v]) async {
    final name = TextEditingController(text: v?.name ?? '');
    final address = TextEditingController(text: v?.address ?? '');
    final pin = TextEditingController(text: v?.pin ?? '');
    var rented = v?.rented ?? false;
    final ok = await showPitchSheet<bool>(
        context,
        StatefulBuilder(
            builder: (ctx, set) => _SimpleSheet(
                  title: v == null ? 'Add a venue' : 'Edit ${v.name}',
                  children: [
                    TextField(
                        controller: name,
                        style: PT.inter(15),
                        decoration: pitchInput('Name', hint: "St Anne's Park")),
                    const SizedBox(height: 8),
                    TextField(
                        controller: address,
                        style: PT.inter(15),
                        decoration: pitchInput('Address (optional)')),
                    const SizedBox(height: 8),
                    TextField(
                        controller: pin,
                        style: PT.inter(15),
                        decoration: pitchInput('Map link (optional)',
                            hint: 'Goes onto events placed here')),
                    const SizedBox(height: 4),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: rented,
                        activeThumbColor: c.club.accent,
                        title:
                            Text('Rented / council pitch', style: PT.inter(15)),
                        subtitle: Text('Only the slots you set show as free',
                            style: PT.inter(13, color: PT.muted)),
                        onChanged: (x) => set(() => rented = x)),
                  ],
                  accent: c.club.accent,
                  onSave: () => Navigator.pop(ctx, true),
                )));
    if (ok != true || name.text.trim().isEmpty) return;
    await _run(
        () => api.saveVenue(club, {
              if (v != null) 'venue_id': v.venueId,
              'name': name.text.trim(),
              'address': address.text.trim(),
              'location_pin': pin.text.trim(),
              'rented': rented,
            }),
        'Venue saved.');
  }

  Future<void> _editPitch(Venue v, [Pitch? p]) async {
    final res = await showPitchSheet<Pitch>(
        context,
        _PitchEditor(
            accent: c.club.accent,
            pitch: p ?? Pitch(pitchId: 0, venueId: v.venueId, name: ''),
            title: p == null ? 'Add a pitch to ${v.name}' : 'Edit ${p.name}'));
    if (res == null || res.name.trim().isEmpty) return;
    await _run(() => api.savePitch(club, res.toJson()), '${res.name} saved.');
  }

  Future<void> _removePitch(Pitch p) => _run(
      () => api.savePitch(club, {...p.toJson(), 'is_active': false}),
      '${p.name} removed.');

  Future<void> _link(UnmatchedLocation u) async {
    final s = _setup!;
    final pitches = s.pitches;
    if (pitches.isEmpty) return pitchSnack(context, 'Add a pitch first.');
    final picked = await showPitchSheet<Pitch>(
        context,
        _SimpleSheet(
          title: 'Which pitch is "${u.location}"?',
          accent: c.club.accent,
          children: [
            Text('${u.events} event${u.events == 1 ? '' : 's'} use this name.',
                style: PT.inter(14, color: PT.muted)),
            const SizedBox(height: 8),
            for (final p in pitches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p.name, style: PT.inter(15)),
                subtitle: Text(p.venue, style: PT.inter(13, color: PT.muted)),
                onTap: () => Navigator.pop(context, p),
              )
          ],
        ));
    if (picked == null) return;
    await _run(
        () => api.savePitch(club, {
              ...picked.toJson(),
              'aliases': [...picked.aliases, u.location],
            }),
        '"${u.location}" now means ${picked.name}.');
  }

  Future<void> _editDurations() async {
    final d = _setup!.durations;
    final f = {
      'u12': TextEditingController(text: '${d.u12}'),
      'u16': TextEditingController(text: '${d.u16}'),
      'adult': TextEditingController(text: '${d.adult}'),
      'training': TextEditingController(text: '${d.training}'),
      'other': TextEditingController(text: '${d.other}'),
    };
    const labels = {
      'u12': 'Match, up to U12 (min)',
      'u16': 'Match, U13 to U16 (min)',
      'adult': 'Match, minor and adult (min)',
      'training': 'Training (min)',
      'other': 'Other (min)',
    };
    final ok = await showPitchSheet<bool>(
        context,
        _SimpleSheet(
            title: 'Default lengths',
            accent: c.club.accent,
            children: [
              for (final k in f.keys) ...[
                TextField(
                    controller: f[k],
                    keyboardType: TextInputType.number,
                    style: PT.inter(15),
                    decoration: pitchInput(labels[k]!)),
                const SizedBox(height: 8),
              ]
            ],
            onSave: () => Navigator.pop(context, true)));
    if (ok != true) return;
    int g(String k, int dflt) => int.tryParse(f[k]!.text.trim()) ?? dflt;
    await _run(
        () => api.saveDurations(
            club,
            PitchDurations(
                u12: g('u12', d.u12),
                u16: g('u16', d.u16),
                adult: g('adult', d.adult),
                training: g('training', d.training),
                other: g('other', d.other),
                changeover: d.changeover)),
        'Lengths saved.');
  }

  @override
  Widget build(BuildContext context) {
    final s = _setup;
    if (_error != null) {
      return Center(child: Text(_error!, style: PT.inter(15, color: PT.muted)));
    }
    if (s == null) {
      return const Center(child: CircularProgressIndicator(color: PT.muted));
    }
    final wide = MediaQuery.sizeOf(context).width >= kWide;
    final accent = c.club.accent;
    final venues =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final v in s.venues) _venueCard(v, wide),
      if (s.venues.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
              'Start with a venue (your club grounds, a council park, a rented astro), then add its pitches and the slots you hold.',
              style: PT.inter(15, color: PT.muted)),
        ),
      Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
              width: 200,
              child: PitchButton('+ Add a venue',
                  accent: accent,
                  compact: true,
                  onTap: _busy ? null : () => _editVenue()))),
    ]);
    final side =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _card(
        title: 'Event names to link',
        child: s.unmatched.isEmpty
            ? Text('Every event location matches a pitch.',
                style: PT.inter(14, color: PT.muted))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    'Locations coaches typed that match no pitch yet. Link one and those events show on the board.',
                    style: PT.inter(13.5, color: PT.muted)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final u in s.unmatched.take(20))
                    ActionChip(
                      backgroundColor: PT.bg,
                      side: const BorderSide(color: PT.line),
                      label: Text('${u.location} (${u.events})',
                          style: PT.inter(13)),
                      onPressed: _busy ? null : () => _link(u),
                    )
                ]),
              ]),
      ),
      const SizedBox(height: 12),
      _card(
        title: 'Default lengths',
        action: TextButton(
            onPressed: _busy ? null : _editDurations,
            child: Text('Edit', style: PT.inter(14, color: accent))),
        child: Column(children: [
          _kv('Match, up to U12', '${s.durations.u12} min'),
          _kv('Match, U13 to U16', '${s.durations.u16} min'),
          _kv('Match, minor and adult', '${s.durations.adult} min'),
          _kv('Training', '${s.durations.training} min'),
        ]),
      ),
    ]);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(wide ? 0 : 16, 0, wide ? 0 : 16, 24),
      child: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: venues),
              const SizedBox(width: 16),
              SizedBox(width: 380, child: side),
            ])
          : Column(children: [venues, const SizedBox(height: 16), side]),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(k, style: PT.inter(14, color: PT.muted))),
          Text(v, style: PT.inter(14, weight: FontWeight.w500)),
        ]),
      );

  Widget _card(
          {required String title, required Widget child, Widget? action}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: PT.card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: PT.tight(17))),
            if (action != null) action,
          ]),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Widget _venueCard(Venue v, bool wide) {
    final accent = c.club.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: PT.card, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.name, style: PT.tight(18)),
              Text(
                  [
                    if (v.address.isNotEmpty) v.address,
                    v.rented ? 'rented' : 'club grounds',
                    if (v.pin.isNotEmpty) 'map pin set',
                  ].join(' · '),
                  style: PT.inter(13, color: PT.muted)),
            ]),
          ),
          TextButton(
              onPressed: _busy ? null : () => _editVenue(v),
              child: Text('Edit', style: PT.inter(14, color: accent))),
        ]),
        const SizedBox(height: 6),
        for (final p in v.pitches)
          InkWell(
            onTap: _busy ? null : () => _editPitch(v, p),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: PT.line))),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: wide ? 150 : 110,
                    child: Text(p.name,
                        style: PT.inter(15, weight: FontWeight.w600))),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.subtitle, style: PT.inter(13.5)),
                        Text(_slotSummary(p),
                            style: PT.inter(12.5, color: PT.muted)),
                        if (p.aliases.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(spacing: 4, runSpacing: 4, children: [
                              for (final a in p.aliases)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: PT.card2,
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(a, style: PT.inter(11.5)),
                                )
                            ]),
                          ),
                      ]),
                ),
                IconButton(
                    tooltip: 'Remove',
                    onPressed: _busy ? null : () => _removePitch(p),
                    icon: const Icon(Icons.close, size: 18, color: PT.muted)),
              ]),
            ),
          ),
        const SizedBox(height: 4),
        TextButton(
            onPressed: _busy ? null : () => _editPitch(v),
            child: Text('+ Add a pitch', style: PT.inter(14, color: accent))),
      ]),
    );
  }

  String _slotSummary(Pitch p) {
    if (p.slots.isEmpty) return 'Open 08:00–22:00 every day';
    final parts = <String>[];
    for (var d = 1; d <= 7; d++) {
      final s = p.slots.where((x) => x.weekday == d).toList();
      if (s.isEmpty) continue;
      s.sort((a, b) => a.opens.compareTo(b.opens));
      parts.add(
          '${kWeekdays[d - 1]} ${s.length == 1 ? s.first.label : '${s.length} slots ${hhmm(s.first.opens)}–${hhmm(s.last.closes)}'}');
    }
    return parts.join(' · ');
  }
}

class _SimpleSheet extends StatelessWidget {
  const _SimpleSheet(
      {required this.title,
      required this.children,
      required this.accent,
      this.onSave});
  final String title;
  final List<Widget> children;
  final Color accent;
  final VoidCallback? onSave;
  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: PT.tight(20)),
                    const SizedBox(height: 12),
                    ...children,
                  ]),
            ),
          ),
          if (onSave != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(children: [
                Expanded(
                    child: PitchButton('Cancel',
                        onTap: () => Navigator.pop(context))),
                const SizedBox(width: 8),
                Expanded(
                    child: PitchButton('Save', accent: accent, onTap: onSave)),
              ]),
            ),
        ]),
      );
}

/// Edit a pitch: name, surface, lights, split, also-called names and slots.
class _PitchEditor extends StatefulWidget {
  const _PitchEditor(
      {required this.pitch, required this.title, required this.accent});
  final Pitch pitch;
  final String title;
  final Color accent;
  @override
  State<_PitchEditor> createState() => _PitchEditorState();
}

class _PitchEditorState extends State<_PitchEditor> {
  late Pitch p = widget.pitch;
  late final _name = TextEditingController(text: p.name);
  final _alias = TextEditingController();
  // Slot maker.
  final Set<int> _days = {1, 2, 3, 4, 5};
  final _from = TextEditingController(text: '17:00');
  final _to = TextEditingController(text: '21:10');
  final _each = TextEditingController(text: '50');

  void _addSlots() {
    final a = parseHhmm(_from.text), b = parseHhmm(_to.text);
    final each = int.tryParse(_each.text.trim()) ?? 0;
    if (a == null || b == null || b <= a) return;
    final add = <PitchSlot>[];
    for (final d in _days) {
      if (each <= 0) {
        add.add(PitchSlot(d, a, b));
      } else {
        for (var m = a; m + each <= b; m += each) {
          add.add(PitchSlot(d, m, m + each));
        }
      }
    }
    final keep = [
      for (final s in p.slots)
        if (!add.any((n) =>
            n.weekday == s.weekday && n.opens < s.closes && s.opens < n.closes))
          s
    ];
    setState(() => p = p.copyWith(slots: [...keep, ...add]));
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    Widget chips<T>(List<T> values, String Function(T) label,
            bool Function(T) on, void Function(T) tap) =>
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final v in values)
            GestureDetector(
              onTap: () => setState(() => tap(v)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                    color: on(v) ? accent.withValues(alpha: 0.16) : PT.bg,
                    border: Border.all(color: on(v) ? accent : PT.line),
                    borderRadius: BorderRadius.circular(18)),
                child: Text(label(v),
                    style: PT.inter(13,
                        weight: FontWeight.w600,
                        color: on(v) ? accent : PT.text)),
              ),
            )
        ]);

    return _SimpleSheet(
      title: widget.title,
      accent: accent,
      onSave: () => Navigator.pop(context, p.copyWith(name: _name.text.trim())),
      children: [
        TextField(
            controller: _name,
            style: PT.inter(15),
            decoration: pitchInput('Name', hint: 'Pitch 34, Club Astro')),
        const SizedBox(height: 12),
        chips<String>(
            const ['grass', 'astro', 'indoor', 'other'],
            (s) => s[0].toUpperCase() + s.substring(1),
            (s) => p.surface == s,
            (s) => p = p.copyWith(surface: s)),
        const SizedBox(height: 8),
        chips<int>(
            const [1, 2, 4],
            (s) => s == 1
                ? 'Whole pitch only'
                : s == 2
                    ? 'Halves'
                    : 'Quarters',
            (s) => p.split == s,
            (s) => p = p.copyWith(split: s)),
        const SizedBox(height: 4),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: p.floodlit,
            activeThumbColor: accent,
            title: Text('Floodlights', style: PT.inter(15)),
            onChanged: (x) => setState(() => p = p.copyWith(floodlit: x))),
        Text('Also called', style: PT.inter(14, color: PT.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final a in p.aliases)
            InputChip(
              backgroundColor: PT.bg,
              side: const BorderSide(color: PT.line),
              label: Text(a, style: PT.inter(13)),
              onDeleted: () => setState(
                  () => p = p.copyWith(aliases: [...p.aliases]..remove(a))),
            ),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _alias,
          style: PT.inter(15),
          decoration: pitchInput('Add a name', hint: 'P34, St Annes No 34'),
          onSubmitted: (v) {
            if (v.trim().isEmpty) return;
            setState(() {
              p = p.copyWith(aliases: [...p.aliases, v.trim()]);
              _alias.clear();
            });
          },
        ),
        const SizedBox(height: 16),
        Text('Slots the club holds',
            style: PT.inter(15, weight: FontWeight.w600)),
        Text('Leave empty for open 08:00–22:00 every day.',
            style: PT.inter(13, color: PT.muted)),
        const SizedBox(height: 8),
        for (var d = 1; d <= 7; d++)
          if (p.slots.any((s) => s.weekday == d))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 40,
                    child: Text(kWeekdays[d - 1],
                        style: PT.inter(13.5, color: PT.muted))),
                Expanded(
                  child: Wrap(spacing: 4, runSpacing: 4, children: [
                    for (final s
                        in (p.slots.where((x) => x.weekday == d).toList()
                          ..sort((a, b) => a.opens.compareTo(b.opens))))
                      InputChip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: PT.bg,
                        side: const BorderSide(color: PT.line),
                        label: Text(s.label, style: PT.inter(12)),
                        onDeleted: () => setState(() =>
                            p = p.copyWith(slots: [...p.slots]..remove(s))),
                      )
                  ]),
                ),
              ]),
            ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: PT.bg, borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Add slots', style: PT.inter(14, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            chips<int>(
                [1, 2, 3, 4, 5, 6, 7],
                (d) => kWeekdays[d - 1],
                _days.contains,
                (d) => _days.contains(d) ? _days.remove(d) : _days.add(d)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: _from,
                      style: PT.inter(15),
                      decoration: pitchInput('From'))),
              const SizedBox(width: 6),
              Expanded(
                  child: TextField(
                      controller: _to,
                      style: PT.inter(15),
                      decoration: pitchInput('To'))),
              const SizedBox(width: 6),
              Expanded(
                  child: TextField(
                      controller: _each,
                      keyboardType: TextInputType.number,
                      style: PT.inter(15),
                      decoration:
                          pitchInput('Each (min)', hint: '0 = one slot'))),
            ]),
            const SizedBox(height: 8),
            PitchButton('Add these slots', compact: true, onTap: _addSlots),
          ]),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ groups

class PitchGroupsView extends StatelessWidget {
  const PitchGroupsView({super.key, required this.c});
  final PitchController c;

  Future<void> _edit(BuildContext context, [PitchGroup? g]) async {
    final board = c.board!;
    final name = TextEditingController(text: g?.name ?? '');
    var code = g?.code ?? 'Football';
    int? team = g?.teamId;
    var sessions = g?.sessions ?? 2;
    final home0 = g == null ? null : c.homes[g.groupId];
    int? homePitch = home0?.pitchId;
    int? homeDay = home0?.day;
    final homeTime = TextEditingController(
        text: home0?.time == null ? '' : hhmm(home0!.time!));
    final taken = {
      for (final x in board.groups)
        if (x.teamId != null && x.groupId != g?.groupId) x.teamId
    };
    final ok = await showPitchSheet<bool>(
        context,
        StatefulBuilder(
            builder: (ctx, set) => _SimpleSheet(
                  title: g == null ? 'Add a group' : 'Edit ${g.name}',
                  accent: c.club.accent,
                  onSave: () => Navigator.pop(ctx, true),
                  children: [
                    TextField(
                        controller: name,
                        style: PT.inter(15),
                        decoration: pitchInput('Name',
                            hint: 'U14 Boys, Nursery, All Stars')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: code,
                      dropdownColor: PT.card2,
                      style: PT.inter(15),
                      decoration: pitchInput('Code (sets the colour)'),
                      items: [
                        for (final k in kGroupCodes)
                          DropdownMenuItem(value: k, child: Text(k)),
                      ],
                      onChanged: (v) => set(() => code = v ?? code),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: team,
                      isExpanded: true,
                      dropdownColor: PT.card2,
                      style: PT.inter(15),
                      decoration: pitchInput('CoachSmart team'),
                      items: [
                        DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Not on CoachSmart',
                                style: PT.inter(15, color: PT.muted))),
                        for (final t in board.teams)
                          if (!taken.contains(t.teamId))
                            DropdownMenuItem<int?>(
                                value: t.teamId,
                                child: Text(t.name,
                                    overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => set(() => team = v),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: Text('Training slots a week',
                              style: PT.inter(15, color: PT.muted))),
                      IconButton(
                          onPressed:
                              sessions > 0 ? () => set(() => sessions--) : null,
                          icon: const Icon(Icons.remove, color: PT.muted)),
                      Text('$sessions',
                          style: PT.inter(16, weight: FontWeight.w600)),
                      IconButton(
                          onPressed:
                              sessions < 7 ? () => set(() => sessions++) : null,
                          icon: const Icon(Icons.add, color: PT.muted)),
                    ]),
                    if (g != null) ...[
                      const SizedBox(height: 8),
                      Text('Home matches',
                          style: PT.inter(15, weight: FontWeight.w600)),
                      Text(
                          'Fill from defaults puts home matches here. League '
                          'fixtures keep their throw-in time.',
                          style: PT.inter(13, color: PT.muted)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        initialValue: homePitch,
                        isExpanded: true,
                        dropdownColor: PT.card2,
                        style: PT.inter(15),
                        decoration: pitchInput('Home pitch'),
                        items: [
                          DropdownMenuItem<int?>(
                              value: null,
                              child: Text('No default',
                                  style: PT.inter(15, color: PT.muted))),
                          for (final p in board.pitches)
                            DropdownMenuItem<int?>(
                                value: p.pitchId,
                                child: Text(p.name,
                                    overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => set(() => homePitch = v),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (var d = 1; d <= 7; d++)
                          ChoiceChip(
                            label: Text(kWeekdays[d - 1]),
                            selected: homeDay == d,
                            onSelected: (on) =>
                                set(() => homeDay = on ? d : null),
                          ),
                      ]),
                      const SizedBox(height: 8),
                      TextField(
                          controller: homeTime,
                          style: PT.inter(15),
                          decoration: pitchInput('Usual time',
                              hint: '11:00, for CoachSmart-only matches')),
                    ],
                  ],
                )));
    if (ok != true || name.text.trim().isEmpty) return;
    if (g != null) {
      final h = homePitch == null
          ? null
          : GroupHome(homePitch!, day: homeDay, time: parseHhmm(homeTime.text));
      final was = c.homes[g.groupId];
      if (h?.pitchId != was?.pitchId ||
          h?.day != was?.day ||
          h?.time != was?.time) {
        final err = await c.saveGroupHome(g.groupId, h);
        if (err != null && context.mounted) return pitchSnack(context, err);
      }
    }
    final err = await c.saveGroup({
      if (g != null) 'group_id': g.groupId,
      'name': name.text.trim(),
      'code': code,
      'team_id': team,
      'sessions': sessions,
    });
    if (context.mounted)
      pitchSnack(context, err ?? '${name.text.trim()} saved.');
  }

  @override
  Widget build(BuildContext context) {
    final board = c.board;
    if (board == null) return const SizedBox.shrink();
    final accent = c.club.accent;
    final linked = {for (final g in board.groups) g.teamId};
    final missing = board.teams
        .where((t) =>
            !linked.contains(t.teamId) &&
            !t.name.toLowerCase().contains('test'))
        .length;
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
              'One group per team that uses the pitches, on CoachSmart or not. '
              'Drag a group onto the board to give it a weekly training slot.',
              style: PT.inter(14, color: PT.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(
                width: 170,
                child: PitchButton('+ Add a group',
                    accent: accent,
                    compact: true,
                    onTap: () => _edit(context))),
            if (missing > 0)
              SizedBox(
                  width: 260,
                  child: PitchButton(
                      'Add $missing CoachSmart team${missing == 1 ? '' : 's'}',
                      compact: true, onTap: () async {
                    final err = await c.syncGroups();
                    if (context.mounted)
                      pitchSnack(context, err ?? 'Teams added as groups.');
                  })),
          ]),
          const SizedBox(height: 12),
          for (final g in board.groups)
            InkWell(
              onTap: () => _edit(context, g),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                    color: PT.card,
                    border: Border(
                        left:
                            BorderSide(color: codeColour(g.codeKey), width: 4)),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name,
                              style: PT.inter(15, weight: FontWeight.w600)),
                          Text(
                              '${g.code} · ${g.teamId == null ? 'not on CoachSmart' : g.teamName}',
                              style: PT.inter(12.5, color: PT.muted)),
                          if (c.homes[g.groupId] case final h?)
                            Text('Home: ${homeLabel(board, h)}',
                                style: PT.inter(12.5,
                                    weight: FontWeight.w600, color: PT.green)),
                        ]),
                  ),
                  PitchTag(
                      g.sessions == 0
                          ? '${g.booked} this week'
                          : '${g.booked} of ${g.sessions} this week',
                      colour: g.short ? PT.amberText : PT.green),
                ]),
              ),
            ),
        ]);
  }
}

/// "Pitch 21 · Sat 12:00".
String homeLabel(PitchBoard board, GroupHome h) => [
      board.pitch(h.pitchId)?.name ?? 'Pitch',
      [
        if (h.day != null) kWeekdays[h.day! - 1],
        if (h.time != null) hhmm(h.time!)
      ].join(' '),
    ].where((x) => x.isNotEmpty).join(' · ');
