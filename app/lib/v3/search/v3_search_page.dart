// v3 Search events (the FlutterFlow SearchPage): pick a team, narrow by
// type, code, dates and opposition, then a list of matching events with
// their reply counts. Data: get_user_event_create_detail for the chips and
// get_events_list for the results, same as v2. New here: the chips follow
// the selected team (v2 always used the first team), the default team is
// pre-selected, and an optional date range.
import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_search_models.dart';

class V3SearchPage extends StatefulWidget {
  const V3SearchPage({super.key, this.testTeams, this.testResults});

  /// Widget tests pass the teams and the result rows here.
  @visibleForTesting
  final List<Map<String, dynamic>>? testTeams;
  @visibleForTesting
  final List<Map<String, dynamic>>? testResults;

  @override
  State<V3SearchPage> createState() => _V3SearchPageState();
}

class _V3SearchPageState extends State<V3SearchPage> {
  List<CreateTeamsStruct> _teams = [];
  CreateTeamsStruct? _team;
  int _typeId = 0, _codeId = 0;
  DateTime? _from, _to;
  final _opp = TextEditingController();
  bool _loading = true, _searching = false, _searched = false;
  String? _error;
  List<SearchEvent> _results = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opp.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      Map body;
      if (widget.testTeams != null) {
        body = {'create_teams': widget.testTeams};
      } else {
        final r = await SupaFlow.client.rpc('get_user_event_create_detail',
            params: {'p_user_id': currentUserUid});
        body = r is Map ? r : const {};
      }
      final teams = (body['create_teams'] as List? ?? [])
          .map(CreateTeamsStruct.maybeFromMap)
          .whereType<CreateTeamsStruct>()
          .toList()
        ..sort((a, b) => a.teamName.compareTo(b.teamName));
      final def = int.tryParse('${body['default_team_id'] ?? ''}') ?? 0;
      CreateTeamsStruct? t;
      for (final x in teams) {
        if (x.teamId == def) t = x;
      }
      t ??= teams.length == 1 ? teams.first : null;
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _team = t;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Your teams could not be loaded.';
      });
    }
  }

  void _pickTeam(CreateTeamsStruct t) => setState(() {
        _team = t;
        if (!t.eventTypes.any((x) => x.id == _typeId)) _typeId = 0;
        if (!t.eventCodes.any((x) => x.id == _codeId)) _codeId = 0;
      });

  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
                primary: V3.green, onPrimary: V3.bg, surface: V3.card)),
        child: child!,
      ),
    );
    if (d == null) return;
    setState(() => from ? _from = d : _to = d);
  }

  Future<void> _search() async {
    final t = _team;
    if (t == null) {
      _snack('Pick a team first.', warn: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final f = SearchFilters(
          teamId: t.teamId,
          typeId: _typeId,
          codeId: _codeId,
          opposition: _opp.text,
          from: _from,
          to: _to);
      dynamic r;
      if (widget.testResults != null) {
        r = widget.testResults;
      } else {
        r = await SupaFlow.client.rpc('get_events_list', params: f.toParams());
      }
      if (!mounted) return;
      setState(() {
        _results = [
          for (final j in (r is List ? r : const []))
            if (j is Map) SearchEvent.fromJson(j)
        ];
        _searched = true;
      });
    } catch (_) {
      _snack('The search did not go through. Please try again.', warn: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _open(SearchEvent e) async {
    await context.pushNamed(V3EventPage.routeName, queryParameters: {
      'eventID': serializeParam(e.eventId, ParamType.int)!,
      'fromSearch': serializeParam(true, ParamType.bool)!,
    });
  }

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
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
        title: Text('Search events', style: V3.tight(20)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: V3.green))
          : _error != null
              ? Center(
                  child: Text(_error!, style: V3.inter(15, color: V3.muted)))
              : GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: [
                      _label('Team'),
                      _chips([
                        for (final t in _teams)
                          (
                            t.teamName,
                            _team?.teamId == t.teamId,
                            () => _pickTeam(t)
                          )
                      ]),
                      if (_team != null && _team!.eventTypes.isNotEmpty) ...[
                        _label('Type'),
                        _chips([
                          (
                            'Any',
                            _typeId == 0,
                            () => setState(() => _typeId = 0)
                          ),
                          for (final x in _team!.eventTypes)
                            (
                              x.name,
                              _typeId == x.id,
                              () => setState(() => _typeId = x.id)
                            )
                        ]),
                      ],
                      if (_team != null && _team!.eventCodes.length > 1) ...[
                        _label('Code'),
                        _chips([
                          (
                            'Any',
                            _codeId == 0,
                            () => setState(() => _codeId = 0)
                          ),
                          for (final x in _team!.eventCodes)
                            (
                              x.name,
                              _codeId == x.id,
                              () => setState(() => _codeId = x.id)
                            )
                        ]),
                      ],
                      _label('Dates'),
                      Row(children: [
                        Expanded(child: _dateChip('From', _from, true)),
                        const SizedBox(width: 8),
                        Expanded(child: _dateChip('To', _to, false)),
                      ]),
                      _label('Opposition'),
                      TextField(
                        controller: _opp,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _search(),
                        style: V3.inter(16),
                        decoration: InputDecoration(
                          hintText: 'Any opposition',
                          hintStyle: V3.inter(16, color: V3.muted),
                          filled: true,
                          fillColor: V3.card,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: V3.line, width: 1.5)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: V3.green, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _searching ? null : _search,
                          style: FilledButton.styleFrom(
                              backgroundColor: V3.green,
                              disabledBackgroundColor:
                                  V3.green.withValues(alpha: .45),
                              foregroundColor: V3.bg,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          icon: _searching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: V3.bg))
                              : const Icon(Icons.search, size: 20),
                          label: Text('Search',
                              style: V3.inter(16,
                                  weight: FontWeight.w700, color: V3.bg)),
                        ),
                      ),
                      if (_searched) ...[
                        const SizedBox(height: 18),
                        Text(
                            _results.isEmpty
                                ? 'No events match.'
                                : '${_results.length} ${_results.length == 1 ? 'event' : 'events'}',
                            style: V3.inter(13,
                                weight: FontWeight.w700,
                                color: V3.green,
                                letterSpacing: .8)),
                        const SizedBox(height: 8),
                        for (final e in _results) _card(e),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
        child: Text(s.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: .8)),
      );

  Widget _chips(List<(String, bool, VoidCallback)> items) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in items)
            GestureDetector(
              onTap: c.$3,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: c.$2 ? V3.green : V3.card2,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(c.$1,
                    style: V3.inter(13.5,
                        weight: FontWeight.w600,
                        color: c.$2 ? V3.bg : V3.text)),
              ),
            ),
        ],
      );

  Widget _dateChip(String label, DateTime? d, bool from) => GestureDetector(
        onTap: () => _pickDate(from),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: V3.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: d == null ? V3.line : V3.green)),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: V3.muted),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    d == null
                        ? label
                        : '$label ${DateFormat('d MMM yyyy').format(d)}',
                    style:
                        V3.inter(14, color: d == null ? V3.muted : V3.text))),
            if (d != null)
              GestureDetector(
                  onTap: () => setState(() => from ? _from = null : _to = null),
                  child: const Icon(Icons.close, size: 16, color: V3.muted)),
          ]),
        ),
      );

  Widget _card(SearchEvent e) => GestureDetector(
        onTap: () => _open(e),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(e.teamName,
                              overflow: TextOverflow.ellipsis,
                              style: V3.inter(12.5,
                                  weight: FontWeight.w500, color: V3.green))),
                      if (e.cancelled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: V3.redTint,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text('Cancelled',
                              style: V3.inter(11.5,
                                  weight: FontWeight.w600, color: V3.redText)),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(15.5, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(e.dateLabel, style: V3.inter(13.5, color: V3.muted)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _dot(V3.green, e.accepted),
                      const SizedBox(width: 12),
                      _dot(V3.barGrey, e.noReply),
                      const SizedBox(width: 12),
                      _dot(V3.red, e.declined),
                    ]),
                  ]),
            ),
            const Icon(Icons.chevron_right, color: V3.muted),
          ]),
        ),
      );

  Widget _dot(Color c, int n) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text('$n', style: V3.inter(13.5, weight: FontWeight.w600)),
      ]);
}
