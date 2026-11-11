// v3 Create a team: a native copy of webviews/create_team.html (opened by
// the old CreateTeamNew route). Four steps: club, team details, codes,
// squads; then the new team's join code. Same RPCs as the web page:
// clubs + users (select), get_club_codes, create_team_with_admin, which
// makes the creator the team's Admin and writes team_code_link for the
// picked codes (team_has_code). The web page stays for the old app.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_create_team_models.dart';
import '/v3/tracking/v3_track.dart';

/// The steps of the flow.
enum CtStep { loading, resume, club, details, codes, squads, success }

class V3CreateTeamPage extends StatefulWidget {
  const V3CreateTeamPage({super.key, this.testData});

  static String routeName = 'V3CreateTeam';
  static String routePath = 'v3CreateTeam';

  /// Widget tests pass the data here instead of calling Supabase:
  /// {'user': {first_name, last_name}, 'clubs': [...], 'codes': [...],
  ///  'result': {team_id, team_unique_code} or 'error': 'message',
  ///  'draft': a saved draft (optional)}.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  @override
  State<V3CreateTeamPage> createState() => _V3CreateTeamPageState();
}

const _draftKey = 'cs_v3_create_team_draft';

class _V3CreateTeamPageState extends State<V3CreateTeamPage> {
  CtStep _step = CtStep.loading;
  CreateTeamDraft _d = CreateTeamDraft();

  List<CtClub>? _clubs; // null while loading
  bool _clubsFailed = false;
  String _search = '';

  List<CtCode> _codes = [];
  int? _codesFor; // club the codes belong to
  bool _loadingCodes = false;

  final _teamName = TextEditingController();
  final _searchCtl = TextEditingController();
  final List<TextEditingController> _squadCtl = [];

  String? _error;
  bool _creating = false;
  String _teamCode = '';
  bool _copied = false;

  bool get _test => widget.testData != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _teamName.dispose();
    _searchCtl.dispose();
    for (final c in _squadCtl) {
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ data

  Future<void> _init() async {
    final draft = await _loadDraft();
    if (draft != null && draft.worthResuming) {
      if (!mounted) return;
      setState(() {
        _d = draft;
        _step = CtStep.resume;
      });
      return;
    }
    await _fetchUserName();
    _loadClubs();
    if (mounted) setState(() => _step = CtStep.club);
  }

  Future<void> _fetchUserName() async {
    try {
      final Map? row;
      if (_test) {
        row = widget.testData!['user'] as Map?;
      } else {
        if (currentUserUid.isEmpty) return;
        row = await SupaFlow.client
            .from('users')
            .select('first_name, last_name')
            .eq('user_id', currentUserUid)
            .maybeSingle();
      }
      if (row != null) {
        _d.firstName = '${row['first_name'] ?? ''}';
        _d.lastName = '${row['last_name'] ?? ''}';
      }
    } catch (_) {
      // The web page carries on without the name too.
    }
  }

  Future<void> _loadClubs() async {
    setState(() {
      _clubs = null;
      _clubsFailed = false;
    });
    try {
      final rows = _test
          ? widget.testData!['clubs']
          : await SupaFlow.client
              .from('clubs')
              .select('club_id, club_name')
              .order('club_name');
      if (!mounted) return;
      setState(() => _clubs = parseClubs(rows));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _clubs = [];
        _clubsFailed = true;
      });
    }
  }

  Future<void> _loadClubCodes() async {
    if (_codesFor == _d.clubId) return;
    List<CtCode> codes;
    try {
      final r = _test
          ? widget.testData!['codes']
          : await SupaFlow.client
              .rpc('get_club_codes', params: {'p_club_id': _d.clubId});
      codes = parseCodes(r);
    } catch (_) {
      codes = [];
    }
    _codes = codes;
    _codesFor = _d.clubId;
    _d.codeIds = defaultCodeIds(codes, _d.codeIds);
  }

  // ----------------------------------------------------------------- draft

  Future<CreateTeamDraft?> _loadDraft() async {
    try {
      if (_test) {
        final j = widget.testData!['draft'];
        return j is Map<String, dynamic> ? CreateTeamDraft.fromJson(j) : null;
      }
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_draftKey);
      if (s == null) return null;
      final j = jsonDecode(s);
      return j is Map<String, dynamic> ? CreateTeamDraft.fromJson(j) : null;
    } catch (_) {
      return null;
    }
  }

  void _saveDraft() {
    if (_test) return;
    final s = jsonEncode(_d.toJson());
    SharedPreferences.getInstance()
        .then((p) => p.setString(_draftKey, s))
        .catchError((_) => false);
  }

  void _clearDraft() {
    if (_test) return;
    SharedPreferences.getInstance()
        .then((p) => p.remove(_draftKey))
        .catchError((_) => false);
  }

  Future<void> _resume() async {
    _teamName.text = _d.teamName;
    _syncSquadControllers();
    if (_d.clubId != null) _loadClubs();
    setState(() {
      _error = null;
      _step = CtStep.details;
    });
  }

  Future<void> _startFresh() async {
    _clearDraft();
    _d = CreateTeamDraft();
    _teamName.clear();
    _codesFor = null;
    _syncSquadControllers();
    await _fetchUserName();
    if (_clubs == null || _clubs!.isEmpty) _loadClubs();
    if (mounted) {
      setState(() {
        _error = null;
        _step = CtStep.club;
      });
    }
  }

  // ------------------------------------------------------------ navigation

  void _go(CtStep s) => setState(() {
        _error = null;
        _step = s;
      });

  void _selectClub(CtClub c) {
    setState(() {
      if (_d.clubId != c.clubId) _d.codeIds = null;
      _d.clubId = c.clubId;
      _d.clubName = c.clubName;
      _error = null;
    });
    _saveDraft();
  }

  void _toDetails() {
    if (_d.clubId == null) {
      setState(() => _error = 'Please select a club.');
      return;
    }
    _saveDraft();
    _go(CtStep.details);
  }

  void _readDetails() {
    _d.teamName = _teamName.text.trim();
  }

  Future<void> _toCodes() async {
    _readDetails();
    if (_d.teamName.isEmpty) {
      setState(() => _error = 'Please enter a team name.');
      return;
    }
    FocusScope.of(context).unfocus();
    _saveDraft();
    setState(() {
      _error = null;
      _loadingCodes = true;
    });
    await _loadClubCodes();
    if (!mounted) return;
    setState(() => _loadingCodes = false);
    if (_codes.isEmpty) {
      _d.codeIds = null;
      _toSquads(skippedCodes: true);
      return;
    }
    _go(CtStep.codes);
  }

  void _toggleCode(int id) {
    setState(() {
      final ids = _d.codeIds ??= [];
      if (!ids.remove(id)) ids.add(id);
      _error = null;
    });
    _saveDraft();
  }

  void _toSquads({bool skippedCodes = false}) {
    if (!skippedCodes && _codes.isNotEmpty && (_d.codeIds?.isEmpty ?? true)) {
      setState(() => _error = 'Pick at least one code.');
      return;
    }
    _saveDraft();
    _syncSquadControllers();
    _go(CtStep.squads);
  }

  /// The AppBar back and the system back walk back through the steps, as
  /// the web page's own Back buttons; the first step leaves the page.
  bool _stepBack() {
    switch (_step) {
      case CtStep.details:
        _readDetails();
        _saveDraft();
        _go(CtStep.club);
        return true;
      case CtStep.codes:
        _go(CtStep.details);
        return true;
      case CtStep.squads:
        _go(_codes.isNotEmpty ? CtStep.codes : CtStep.details);
        return true;
      default:
        return false;
    }
  }

  void _back() {
    if (_creating) return;
    if (!_stepBack()) Navigator.of(context).maybePop();
  }

  // ---------------------------------------------------------------- squads

  void _syncSquadControllers() {
    while (_squadCtl.length > _d.squads.length) {
      _squadCtl.removeLast().dispose();
    }
    for (var i = 0; i < _d.squads.length; i++) {
      if (i < _squadCtl.length) {
        if (_squadCtl[i].text != _d.squads[i].name) {
          _squadCtl[i].text = _d.squads[i].name;
        }
      } else {
        _squadCtl.add(TextEditingController(text: _d.squads[i].name));
      }
    }
  }

  void _changeSquadCount(int delta) {
    final n = (_d.squads.length + delta).clamp(0, kMaxSquads);
    setState(() {
      while (_d.squads.length < n) {
        _d.squads.add(CtSquad('', nextSquadColour(_d.squads)));
      }
      if (_d.squads.length > n) _d.squads.removeRange(n, _d.squads.length);
      _syncSquadControllers();
    });
    _saveDraft();
  }

  Future<void> _pickColour(int i) async {
    final q = _d.squads[i];
    final label = q.name.trim().isEmpty ? 'Squad ${i + 1}' : q.name.trim();
    final title =
        'Colour for ${q.name.trim().isEmpty ? 'squad ${i + 1}' : q.name.trim()}';
    final hex = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) =>
          V3SquadColourSheet(title: title, label: label, colour: q.colour),
    );
    if (hex == null || !mounted) return;
    setState(() => q.colour = hex);
    _saveDraft();
  }

  // ---------------------------------------------------------------- create

  Future<void> _create() async {
    if (_d.teamName.isEmpty) {
      _go(CtStep.details);
      setState(() => _error = 'Please enter a team name.');
      return;
    }
    final err = squadsError(_d.squads);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    FocusScope.of(context).unfocus();
    _saveDraft();
    setState(() {
      _error = null;
      _creating = true;
    });
    try {
      final dynamic result;
      if (_test) {
        if (widget.testData!['error'] != null) {
          throw Exception(widget.testData!['error']);
        }
        result = widget.testData!['result'];
      } else {
        V3Track.event('team_created');
        result = await SupaFlow.client.rpc('create_team_with_admin',
            params: createTeamParams(_d, clubHasCodes: _codes.isNotEmpty));
      }
      _clearDraft();
      if (!mounted) return;
      setState(() {
        _teamCode = teamCodeFrom(result);
        _creating = false;
        _step = CtStep.success;
      });
    } catch (e) {
      if (!mounted) return;
      String msg = e is PostgrestException
          ? e.message
          : '$e'.replaceFirst('Exception: ', '');
      if (msg.trim().isEmpty) msg = 'Something went wrong. Please try again.';
      setState(() {
        _error = msg;
        _creating = false;
      });
    }
  }

  Future<void> _copyCode() async {
    if (_teamCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _teamCode));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareCode() async {
    final text =
        'Join ${_d.teamName} on CoachSmart. Open the app, choose Join a team and enter the code $_teamCode. Get CoachSmart at https://coachsmart.app';
    try {
      if (kIsWeb) throw UnsupportedError('web');
      await SharePlus.instance.share(ShareParams(
          text: text, subject: 'Join ${_d.teamName} on CoachSmart'));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invite text copied. Paste it into a message.',
              textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
          backgroundColor: V3.green));
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final inFlow = _step == CtStep.details ||
        _step == CtStep.codes ||
        _step == CtStep.squads;
    return PopScope(
      canPop: !inFlow && !_creating,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: AppBar(
          backgroundColor: V3.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
              onPressed: _back),
          title: Text(
              _step == CtStep.success ? 'Team created' : 'Create a team',
              style: V3.tight(17, weight: FontWeight.w600)),
        ),
        body: SafeArea(top: false, child: _body()),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case CtStep.loading:
        return const Center(child: CircularProgressIndicator(color: V3.green));
      case CtStep.resume:
        return _resumeView();
      case CtStep.club:
        return _clubView();
      case CtStep.details:
        return _detailsView();
      case CtStep.codes:
        return _codesView();
      case CtStep.squads:
        return _squadsView();
      case CtStep.success:
        return _successView();
    }
  }

  /// A step: progress, heading, error, the step's content and a button
  /// fixed at the bottom.
  Widget _stepFrame({
    required int n,
    required String title,
    required String sub,
    required List<Widget> children,
    required String button,
    required VoidCallback? onButton,
    bool busy = false,
  }) {
    return Column(children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _progress(n),
            const SizedBox(height: 18),
            Text('STEP $n OF 4',
                style: V3.inter(13,
                    weight: FontWeight.w700,
                    color: V3.green,
                    letterSpacing: 0.8)),
            const SizedBox(height: 6),
            Text(title, style: V3.tight(26, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(sub, style: V3.inter(16, color: V3.muted, height: 1.35)),
            const SizedBox(height: 18),
            if (_error != null) ...[
              _errorBox(_error!),
              const SizedBox(height: 14),
            ],
            ...children,
          ],
        ),
      ),
      _bottomButton(button, onButton, busy: busy),
    ]);
  }

  Widget _progress(int n) => Row(children: [
        for (var i = 1; i <= 4; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 5,
              decoration: BoxDecoration(
                  color: i <= n ? V3.green : V3.line,
                  borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ],
      ]);

  Widget _errorBox(String msg) => Container(
        key: const ValueKey('ct-error'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: V3.redTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: V3.red.withValues(alpha: 0.5))),
        child: Row(children: [
          const Icon(Icons.error_outline, color: V3.redText, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: V3.inter(15, color: V3.redText))),
        ]),
      );

  Widget _bottomButton(String label, VoidCallback? onTap, {bool busy = false}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
          color: V3.bg, border: Border(top: BorderSide(color: V3.line))),
      child: _primary(label, onTap, busy: busy),
    );
  }

  Widget _primary(String label, VoidCallback? onTap, {bool busy = false}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: V3.green,
            foregroundColor: V3.bg,
            disabledBackgroundColor: V3.green.withValues(alpha: 0.35),
            disabledForegroundColor: V3.bg.withValues(alpha: 0.7),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14))),
        onPressed: busy ? null : onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (busy) ...[
            const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(strokeWidth: 2.5, color: V3.bg)),
            const SizedBox(width: 10),
          ],
          Text(label,
              style: V3.inter(17, weight: FontWeight.w700, color: V3.bg)),
        ]),
      ),
    );
  }

  Widget _secondary(String label, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
              foregroundColor: V3.text,
              side: const BorderSide(color: V3.line, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          onPressed: onTap,
          child: Text(label, style: V3.inter(17, weight: FontWeight.w600)),
        ),
      );

  // ---------------------------------------------------------------- resume

  Widget _resumeView() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
            decoration: BoxDecoration(
                color: V3.card, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: V3.greenTint, shape: BoxShape.circle),
                child: const Icon(Icons.history, color: V3.green, size: 30),
              ),
              const SizedBox(height: 16),
              Text('Continue where you left off?',
                  textAlign: TextAlign.center,
                  style: V3.tight(22, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                  'You started creating a team. Pick up where you left off or start fresh.',
                  textAlign: TextAlign.center,
                  style: V3.inter(16, color: V3.muted, height: 1.35)),
              const SizedBox(height: 22),
              _primary('Continue', _resume),
              const SizedBox(height: 10),
              _secondary('Start Fresh', _startFresh),
            ]),
          ),
        ),
      );

  // ----------------------------------------------------------- step 1: club

  Widget _clubView() {
    final clubs = _clubs;
    final list = clubs == null ? const <CtClub>[] : filterClubs(clubs, _search);
    Widget empty(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
            child: Text(t,
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted))));
    return _stepFrame(
      n: 1,
      title: 'Select your club',
      sub: 'Your team will sit under this club.',
      button: 'Next',
      onButton: _d.clubId == null ? null : _toDetails,
      children: [
        TextField(
          controller: _searchCtl,
          onChanged: (v) => setState(() => _search = v),
          style: V3.inter(17),
          cursorColor: V3.green,
          decoration: _inputDecoration('Search clubs…',
              prefix: const Icon(Icons.search, color: V3.muted)),
        ),
        const SizedBox(height: 12),
        if (clubs == null)
          empty('Loading clubs…')
        else if (_clubsFailed)
          Column(children: [
            empty('Failed to load clubs. Please try again.'),
            TextButton(
                onPressed: _loadClubs,
                child: Text('Try again',
                    style: V3.inter(16,
                        weight: FontWeight.w600, color: V3.green))),
          ])
        else if (list.isEmpty)
          empty('No clubs found')
        else
          Container(
            decoration: BoxDecoration(
                color: V3.card, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, thickness: 1, color: V3.line, indent: 16),
                _clubRow(list[i]),
              ],
            ]),
          ),
      ],
    );
  }

  Widget _clubRow(CtClub c) {
    final sel = _d.clubId == c.clubId;
    return Material(
      color: sel ? V3.greenTint : Colors.transparent,
      child: InkWell(
        onTap: () => _selectClub(c),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                  child: Text(c.clubName,
                      style: V3.inter(17,
                          weight: sel ? FontWeight.w600 : FontWeight.w400))),
              const SizedBox(width: 10),
              _radio(sel),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _radio(bool on) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: on ? V3.green : V3.barGrey, width: 2)),
        alignment: Alignment.center,
        child: on
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                    color: V3.green, shape: BoxShape.circle))
            : null,
      );

  InputDecoration _inputDecoration(String hint, {Widget? prefix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: V3.inter(17, color: V3.muted),
        prefixIcon: prefix,
        filled: true,
        fillColor: V3.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: V3.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: V3.green, width: 1.5)),
      );

  // -------------------------------------------------------- step 2: details

  Widget _detailsView() => _stepFrame(
        n: 2,
        title: 'Team details',
        sub: 'Tell us a bit about your team.',
        button: _loadingCodes ? 'Loading…' : 'Next',
        busy: _loadingCodes,
        onButton: _toCodes,
        children: [
          if (_d.clubName.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.shield_outlined, color: V3.muted, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child:
                      Text(_d.clubName, style: V3.inter(16, color: V3.muted))),
            ]),
            const SizedBox(height: 16),
          ],
          Text('Team Name',
              style: V3.inter(15, weight: FontWeight.w600, color: V3.muted)),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('ct-team-name'),
            controller: _teamName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _toCodes(),
            style: V3.inter(17),
            cursorColor: V3.green,
            decoration: _inputDecoration('e.g. U13 Boys'),
          ),
          const SizedBox(height: 16),
          _toggle('Under 18 team', 'Is this a juvenile / underage team?',
              _d.juvenile, (v) {
            setState(() => _d.juvenile = v);
            _saveDraft();
          }),
          const SizedBox(height: 10),
          _toggle('Female team', 'Is this a female / ladies team?', _d.female,
              (v) {
            setState(() => _d.female = v);
            _saveDraft();
          }),
        ],
      );

  Widget _toggle(
          String title, String sub, bool value, ValueChanged<bool> onChanged) =>
      Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: V3.inter(17, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(sub, style: V3.inter(15, color: V3.muted)),
                    ]),
              ),
              Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: V3.bg,
                  activeTrackColor: V3.green,
                  inactiveThumbColor: V3.muted,
                  inactiveTrackColor: V3.card2),
            ]),
          ),
        ),
      );

  // ---------------------------------------------------------- step 3: codes

  Widget _codesView() => _stepFrame(
        n: 3,
        title: 'What does this team play?',
        sub: 'Pick one or more. These are the codes ${_d.clubName} uses.',
        button: 'Next',
        onButton: () => _toSquads(),
        children: [
          for (final c in _codes) ...[
            _codeRow(c),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Text(
              'Events, squads and attendance are split by code. You can change this later in Team setup.',
              style: V3.inter(15, color: V3.muted, height: 1.4)),
        ],
      );

  Widget _codeRow(CtCode c) {
    final sel = _d.codeIds?.contains(c.codeId) ?? false;
    final label = codeLabel(c.name, _d.female);
    final sub = codeSub(c.name, _d.female);
    return Material(
      color: sel ? V3.greenTint : V3.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: sel ? V3.green : V3.line, width: 1.5)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleCode(c.codeId),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: V3.inter(18, weight: FontWeight.w600)),
                      if (sub.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(sub, style: V3.inter(15, color: V3.muted)),
                      ],
                    ]),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: sel ? V3.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? V3.green : V3.barGrey, width: 2)),
                child: sel
                    ? const Icon(Icons.check, color: V3.bg, size: 20)
                    : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------- step 4: squads

  Widget _squadsView() {
    final n = _d.squads.length;
    return _stepFrame(
      n: 4,
      title: 'Squads',
      sub:
          'Split players into groups for training and matches. Tap a colour to change it.',
      button: _creating ? 'Creating…' : 'Create Team',
      busy: _creating,
      onButton: _create,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          decoration: BoxDecoration(
              color: V3.card, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How many squads?',
                        style: V3.inter(17, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('You can add more later',
                        style: V3.inter(15, color: V3.muted)),
                  ]),
            ),
            _stepBtn(Icons.remove, 'Fewer squads',
                n == 0 || _creating ? null : () => _changeSquadCount(-1)),
            SizedBox(
                width: 40,
                child: Text('$n',
                    key: const ValueKey('ct-squad-count'),
                    textAlign: TextAlign.center,
                    style: V3.tight(22, weight: FontWeight.w700))),
            _stepBtn(
                Icons.add,
                'More squads',
                n >= kMaxSquads || _creating
                    ? null
                    : () => _changeSquadCount(1)),
          ]),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < n; i++) ...[
          _squadRow(i),
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: V3.line, width: 1.5)),
          child: Row(children: [
            Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: const Color(0xFF9AA0A6),
                    borderRadius: BorderRadius.circular(7))),
            const SizedBox(width: 12),
            Expanded(
                child: Text('No Team: players start here until you place them',
                    style: V3.inter(15, color: V3.muted))),
          ]),
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, String tip, VoidCallback? onTap) =>
      IconButton.filled(
        tooltip: tip,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        style: IconButton.styleFrom(
            backgroundColor: V3.card2,
            foregroundColor: V3.text,
            disabledBackgroundColor: V3.card2.withValues(alpha: 0.5),
            disabledForegroundColor: V3.barGrey),
        onPressed: onTap,
        icon: Icon(icon, size: 24),
      );

  Widget _squadRow(int i) {
    final q = _d.squads[i];
    return Row(children: [
      Semantics(
        button: true,
        label: 'Colour',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _creating ? null : () => _pickColour(i),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
                color: colourFromHex(q.colour),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 1.5)),
            child: Icon(Icons.palette_outlined,
                size: 20, color: textOnHex(q.colour).withValues(alpha: 0.75)),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: TextField(
          key: ValueKey('ct-squad-$i'),
          controller: _squadCtl[i],
          maxLength: 40,
          enabled: !_creating,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) {
            q.name = v;
            if (_error != null) setState(() => _error = null);
            _saveDraft();
          },
          style: V3.inter(17),
          cursorColor: V3.green,
          decoration:
              _inputDecoration('Squad ${i + 1} name').copyWith(counterText: ''),
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------- success

  Widget _successView() => ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration:
                  const BoxDecoration(color: V3.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: V3.bg, size: 44),
            ),
          ),
          const SizedBox(height: 18),
          Text('${_d.teamName} — Created!',
              textAlign: TextAlign.center,
              style: V3.tight(26, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              'Share the code below with your players and coaches so they can join.',
              textAlign: TextAlign.center,
              style: V3.inter(16, color: V3.muted, height: 1.35)),
          const SizedBox(height: 24),
          Material(
            color: V3.card,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _copyCode,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(children: [
                  Text('TEAM CODE',
                      style: V3.inter(13,
                          weight: FontWeight.w700,
                          color: V3.muted,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(_teamCode.isEmpty ? '———' : _teamCode,
                        key: const ValueKey('ct-team-code'),
                        style: V3
                            .tight(46, weight: FontWeight.w700)
                            .copyWith(color: V3.green, letterSpacing: 6)),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: _copied
                        ? Text('Copied ✓',
                            key: const ValueKey('copied'),
                            style: V3.inter(15,
                                weight: FontWeight.w600, color: V3.green))
                        : Row(
                            key: const ValueKey('hint'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                const Icon(Icons.copy,
                                    size: 16, color: V3.muted),
                                const SizedBox(width: 6),
                                Text('Tap to copy',
                                    style: V3.inter(15, color: V3.muted)),
                              ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
              'Tap the code to copy it, then paste into WhatsApp or any chat to share with your squad.',
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted, height: 1.4)),
          const SizedBox(height: 22),
          _primary('Share the code', _shareCode),
          const SizedBox(height: 10),
          _secondary('Done', () => Navigator.of(context).maybePop()),
        ],
      );
}

/// The squad colour sheet, as cs-colour-picker.js: twelve swatches, then
/// a custom colour from hue and lightness sliders, a preview and "Use this
/// colour". Pops with the picked hex.
class V3SquadColourSheet extends StatefulWidget {
  const V3SquadColourSheet(
      {super.key,
      required this.title,
      required this.label,
      required this.colour});

  final String title;
  final String label;
  final String colour;

  @override
  State<V3SquadColourSheet> createState() => _V3SquadColourSheetState();
}

class _V3SquadColourSheetState extends State<V3SquadColourSheet> {
  late String _cur;
  double _hue = 0;
  double _light = 0.5;

  @override
  void initState() {
    super.initState();
    _set(isHexColour(widget.colour) ? widget.colour : kSquadSwatches.first,
        moveSliders: true);
  }

  void _set(String hex, {required bool moveSliders}) {
    _cur = hex.toUpperCase();
    if (moveSliders) {
      final (h, l) = hexToHueLight(_cur);
      _hue = h.roundToDouble().clamp(0, 359);
      _light = ((l * 100).round().clamp(12, 88)) / 100;
    }
  }

  void _fromSliders() =>
      setState(() => _set(hslToHex(_hue, 0.7, _light), moveSliders: false));

  @override
  Widget build(BuildContext context) {
    final label = widget.label.isEmpty ? 'Squad' : widget.label;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: V3.barGrey,
                          borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              Text(widget.title, style: V3.tight(20)),
              const SizedBox(height: 2),
              Text('Pick a team colour or make your own.',
                  style: V3.inter(15, color: V3.muted)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (final c in kSquadSwatches)
                    Semantics(
                      button: true,
                      label: c,
                      selected: c == _cur,
                      child: GestureDetector(
                        onTap: () => setState(() => _set(c, moveSliders: true)),
                        child: Container(
                          decoration: BoxDecoration(
                            color: colourFromHex(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: c == _cur ? V3.text : Colors.white24,
                                width: c == _cur ? 3 : 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text('CUSTOM COLOUR',
                  style: V3.inter(13,
                      weight: FontWeight.w700,
                      color: V3.muted,
                      letterSpacing: 0.6)),
              const SizedBox(height: 4),
              _slider(
                  value: _hue,
                  min: 0,
                  max: 359,
                  colours: [
                    for (var h = 0; h <= 360; h += 60)
                      colourFromHex(hslToHex(h % 360, 1, 0.5))
                  ],
                  onChanged: (v) {
                    _hue = v;
                    _fromSliders();
                  }),
              _slider(
                  value: _light,
                  min: 0.12,
                  max: 0.88,
                  colours: [
                    colourFromHex(hslToHex(_hue, 0.7, 0.12)),
                    colourFromHex(hslToHex(_hue, 0.7, 0.5)),
                    colourFromHex(hslToHex(_hue, 0.7, 0.88)),
                  ],
                  onChanged: (v) {
                    _light = v;
                    _fromSliders();
                  }),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: V3.card2, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                          color: colourFromHex(_cur),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: V3.inter(16, weight: FontWeight.w500))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                        color: colourFromHex(_cur),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(label,
                        style: V3.inter(14,
                            weight: FontWeight.w700, color: textOnHex(_cur))),
                  ),
                  const SizedBox(width: 10),
                  Text(_cur, style: V3.inter(14, color: V3.muted)),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: V3.green,
                      foregroundColor: V3.bg,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () => Navigator.pop(context, _cur),
                  child: Text('Use this colour',
                      style:
                          V3.inter(17, weight: FontWeight.w700, color: V3.bg)),
                ),
              ),
            ]),
      ),
    );
  }

  /// A slider drawn on a colour gradient track.
  Widget _slider({
    required double value,
    required double min,
    required double max,
    required List<Color> colours,
    required ValueChanged<double> onChanged,
  }) =>
      SizedBox(
        height: 48,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(colors: colours)),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 0,
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbColor: colourFromHex(_cur),
              overlayColor: Colors.white12,
              thumbShape: const _RingThumb(),
            ),
            child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged),
          ),
        ]),
      );
}

/// A white-ringed thumb filled with the current colour.
class _RingThumb extends SliderComponentShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(30, 30);

  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final c = context.canvas;
    c.drawCircle(center, 15, Paint()..color = Colors.white);
    c.drawCircle(
        center, 12, Paint()..color = sliderTheme.thumbColor ?? Colors.white);
  }
}
