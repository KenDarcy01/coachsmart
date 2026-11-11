// v3 Club Analytics: a native copy of webviews/dashboard-app.html, opened
// from the v3 Home menu. Teams, Players and Squads tabs over one
// get_club_comparison_dashboard call, with the period, the filter sheet,
// the team page, the event / squad / roster sheets and PDF sharing.
// Only teams where the user holds a grade 100 (admin) role are shown.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_analytics_charts.dart';
import 'v3_analytics_models.dart';
import 'v3_analytics_pdf.dart';

class V3AnalyticsPage extends StatefulWidget {
  const V3AnalyticsPage({super.key, this.testData, this.testNow});

  static String routeName = 'V3Analytics';
  static String routePath = 'v3Analytics';

  /// Widget tests pass {admin_teams, default_club, dashboard} here instead
  /// of calling Supabase.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  /// A fixed "now" for tests.
  @visibleForTesting
  final DateTime? testNow;

  @override
  State<V3AnalyticsPage> createState() => _V3AnalyticsPageState();
}

class _V3AnalyticsPageState extends State<V3AnalyticsPage> {
  bool _loading = true;
  bool _denied = false;
  String? _error;
  bool _exporting = false;
  int _seq = 0;

  Set<int> _adminTeamIds = {};
  List<AnClub> _clubs = [];
  int _clubId = 0;
  AnData? _data;
  final AnFilters _f = AnFilters();

  String _tab = 'teams';
  AnPeriod _period = AnPeriod.season;
  AnCustom? _custom;
  int? _teamPage;
  String _teamSort = 'att';
  String _playerSort = 'low';
  String _teamPlayerSort = 'low';
  String _q = '';
  final Set<String> _expanded = {};

  final _scroll = ScrollController();
  final _search = TextEditingController();

  /// Bumped on every change so open sheets rebuild too.
  final _tick = ValueNotifier<int>(0);

  DateTime get _now => widget.testNow ?? DateTime.now();
  AnRange get _range => periodRange(_period, _custom, _now);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _tick.dispose();
    super.dispose();
  }

  void _update(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _tick.value++;
  }

  // ------------------------------------------------------------------ data

  Future<void> _start() async {
    try {
      final td = widget.testData;
      List<AdminTeam> teams;
      dynamic defClub;
      if (td != null) {
        teams = [
          for (final t in (td['admin_teams'] as List? ?? const []))
            AdminTeam.fromJson(t as Map)
        ];
        defClub = td['default_club'];
      } else {
        teams = await _fetchAdminTeams();
        if (teams.isNotEmpty) defClub = await _fetchDefaultClub();
      }
      if (teams.isEmpty) {
        _update(() {
          _denied = true;
          _loading = false;
        });
        return;
      }
      _adminTeamIds = {for (final t in teams) t.teamId};
      _clubs = clubsOf(teams);
      _clubId = defaultClubFor(_clubs, defClub);
      await _loadData();
    } catch (_) {
      _update(() {
        _loading = false;
        _error = "Couldn't load club data";
      });
    }
  }

  /// Teams where the user holds an admin (grade 100) role.
  Future<List<AdminTeam>> _fetchAdminTeams() async {
    final c = SupaFlow.client;
    final uml = await c
        .from('user_member_link')
        .select('member_id')
        .eq('user_id', currentUserUid);
    if (uml.isEmpty) return [];
    final mtl = await c
        .from('member_team_link')
        .select('member_team_id,team_id')
        .inFilter('member_id', [for (final r in uml) r['member_id']]);
    if (mtl.isEmpty) return [];
    final mtlMap = {for (final r in mtl) r['member_team_id']: r['team_id']};
    final mtrl = await c
        .from('member_team_role_link')
        .select('member_team_id,role_id')
        .inFilter('member_team_id', [for (final r in mtl) r['member_team_id']]);
    if (mtrl.isEmpty) return [];
    final roles = await c
        .from('roles')
        .select('role_id')
        .inFilter('role_id', {for (final r in mtrl) r['role_id']}.toList())
        .eq('role_grade', 100);
    if (roles.isEmpty) return [];
    final adminRoleIds = {for (final r in roles) r['role_id']};
    final teamIds = {
      for (final r in mtrl)
        if (adminRoleIds.contains(r['role_id']) &&
            mtlMap[r['member_team_id']] != null)
          mtlMap[r['member_team_id']]
    }.toList();
    if (teamIds.isEmpty) return [];
    final teams = await c
        .from('teams')
        .select('team_id,team_name,club_id')
        .inFilter('team_id', teamIds);
    if (teams.isEmpty) return [];
    final clubs = await c
        .from('clubs')
        .select('club_id,club_name')
        .inFilter('club_id', {for (final t in teams) t['club_id']}.toList());
    final clubMap = {for (final c in clubs) c['club_id']: c['club_name']};
    return [
      for (final t in teams)
        AdminTeam.fromJson({...t, 'club_name': clubMap[t['club_id']] ?? 'Club'})
    ];
  }

  Future<dynamic> _fetchDefaultClub() async {
    try {
      final r = await SupaFlow.client
          .from('users')
          .select('default_club')
          .eq('user_id', currentUserUid)
          .maybeSingle();
      return r?['default_club'];
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadData() async {
    final need = needFrom(_range);
    final d = _data;
    if (d != null && d.clubId == _clubId && !d.from.isAfter(need)) {
      _update(() {});
      return;
    }
    final seq = ++_seq;
    _update(() {
      _loading = true;
      _error = null;
    });
    try {
      Map json;
      if (widget.testData != null) {
        json = widget.testData!['dashboard'] as Map? ?? {};
      } else {
        final r =
            await SupaFlow.client.rpc('get_club_comparison_dashboard', params: {
          'p_club_id': _clubId,
          'p_start_date': need.toUtc().toIso8601String(),
          'p_end_date': DateTime.now().toUtc().toIso8601String(),
        });
        json = r is Map ? r : {};
      }
      if (seq != _seq) return;
      if (json['error'] != null) {
        _update(() {
          _loading = false;
          _error = "Couldn't load club data: ${json['error']}";
        });
        return;
      }
      final data = normalise(json, _adminTeamIds, _clubId, need);
      _f.rebuild(data);
      _update(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (seq != _seq) return;
      _update(() {
        _loading = false;
        _error = "Couldn't load club data";
      });
    }
  }

  // --------------------------------------------------------------- actions

  void _toTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _setTab(String t) {
    _update(() {
      _tab = t;
      _teamPage = null;
      _expanded.clear();
    });
    _toTop();
  }

  void _openTeam(int id) {
    _update(() {
      _tab = 'teams';
      _teamPage = id;
      _expanded.clear();
    });
    _toTop();
  }

  void _closeTeam() {
    _update(() {
      _teamPage = null;
      _expanded.clear();
    });
    _toTop();
  }

  void _setPeriod(AnPeriod p) {
    _period = p;
    _custom = null;
    _expanded.clear();
    _loadData();
  }

  void _openPlayer(int id, String name) {
    context.pushNamed(MemberAnalyticsWidget.routeName,
        queryParameters: {
          'memberId': serializeParam(id, ParamType.int),
          'memberName': serializeParam(name, ParamType.String),
        }.withoutNulls);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
        backgroundColor: V3.amber));
  }

  String _subLine() {
    final d = _data!;
    return [
      _range.label,
      ..._f.changedLabels(),
      if (_f.isDefault('team') && d.teams.length > 1) 'All teams',
    ].join(' · ');
  }

  Report? _viewReport() {
    final d = _data;
    if (d == null) return null;
    final team =
        _tab == 'teams' && _teamPage != null ? d.team(_teamPage!) : null;
    if (team != null) {
      final sub = [
        _range.label,
        ..._f.changedLabels().where((l) => !l.startsWith('Teams:'))
      ].join(' · ');
      return teamPageReport(d, team, _f,
          contextFor(d, _f, _range, teamId: team.id), _teamPlayerSort, sub);
    }
    final ctx = contextFor(d, _f, _range);
    switch (_tab) {
      case 'players':
        return playersReport(d, ctx, _playerSort, _q, _subLine());
      case 'squads':
        return squadsReport(d, ctx, _subLine());
      default:
        return teamsReport(d, _f, ctx, _teamSort, _subLine());
    }
  }

  Future<void> _sharePdf(Report? r) async {
    if (r == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      pw.Font? base, bold;
      try {
        base = await PdfGoogleFonts.interRegular()
            .timeout(const Duration(seconds: 8));
        bold = await PdfGoogleFonts.interBold()
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        base = bold = null;
      }
      final bytes =
          await buildReportPdf(r, DateTime.now(), base: base, bold: bold);
      await Printing.sharePdf(
          bytes: bytes, filename: '${pdfFileBase(r.fileBase)}.pdf');
    } catch (_) {
      _snack('Could not create the PDF');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final onTeamPage = _tab == 'teams' && _teamPage != null;
    final ready = _data != null && !_loading && _error == null;
    final hasFilters = _custom != null || _f.changed.isNotEmpty;
    return PopScope(
      canPop: !onTeamPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeTeam();
      },
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: AppBar(
          backgroundColor: V3.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
              tooltip: onTeamPage ? 'Teams' : 'Back',
              icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
              onPressed: () =>
                  onTeamPage ? _closeTeam() : Navigator.of(context).maybePop()),
          title: Text('Club Analytics',
              style: V3.tight(18, weight: FontWeight.w600)),
          actions: [
            if (!onTeamPage && !_denied)
              IconButton(
                tooltip: 'Filters',
                onPressed: _data == null ? null : _openFilters,
                icon: Stack(clipBehavior: Clip.none, children: [
                  const Icon(Icons.tune, color: V3.text, size: 26),
                  if (hasFilters)
                    Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                                color: V3.green, shape: BoxShape.circle))),
                ]),
              ),
            if (!_denied)
              IconButton(
                  tooltip: 'Share PDF',
                  onPressed: ready ? () => _sharePdf(_viewReport()) : null,
                  icon: const Icon(Icons.ios_share, color: V3.text, size: 24)),
            const SizedBox(width: 4),
          ],
        ),
        body: Stack(children: [
          _body(onTeamPage),
          if (_exporting)
            Positioned.fill(
                child: ColoredBox(
                    color: V3.bg,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: V3.green),
                          const SizedBox(height: 14),
                          Text('Preparing PDF…',
                              style: V3.inter(16, color: kText2)),
                        ]))),
        ]),
      ),
    );
  }

  Widget _body(bool onTeamPage) {
    if (_denied) return _deniedBox();
    if (_data == null && _loading) return _spinner();
    if (_data == null && _error != null) return _errorBox();
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        if (!onTeamPage) ...[
          _tabs(),
          const SizedBox(height: 12),
          _periodSeg(),
          _chips(),
          const SizedBox(height: 12),
        ],
        if (_loading)
          Padding(padding: const EdgeInsets.only(top: 60), child: _spinner())
        else if (_error != null)
          _errorBox()
        else
          ..._view(onTeamPage),
      ],
    );
  }

  Widget _spinner() =>
      const Center(child: CircularProgressIndicator(color: V3.green));

  Widget _errorBox() => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded, color: V3.amber, size: 36),
          const SizedBox(height: 12),
          Text(_error ?? '',
              textAlign: TextAlign.center,
              style: V3.inter(16, color: V3.muted)),
          const SizedBox(height: 16),
          _greenButton('Try again', () {
            if (_clubs.isEmpty) {
              _update(() {
                _loading = true;
                _error = null;
              });
              _start();
            } else {
              _data = null;
              _loadData();
            }
          }),
        ]),
      );

  Widget _deniedBox() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
                color: V3.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: V3.line)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('No admin teams',
                  style: V3.inter(19, weight: FontWeight.w600, color: kNo)),
              const SizedBox(height: 10),
              Text(
                  'Club analytics is for team admins.\nAsk your club administrator for access.',
                  textAlign: TextAlign.center,
                  style: V3.inter(16, color: V3.muted, height: 1.6)),
            ]),
          ),
        ),
      );

  List<Widget> _view(bool onTeamPage) {
    if (onTeamPage) return _teamPageView();
    switch (_tab) {
      case 'players':
        return _playersView();
      case 'squads':
        return _squadsView();
      default:
        return _teamsView();
    }
  }

  // ------------------------------------------------------------- controls

  Widget _tabs() {
    Widget tab(String key, String label) {
      final on = _tab == key;
      return Expanded(
        child: InkWell(
          onTap: () => _setTab(key),
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: on ? V3.green : Colors.transparent,
                        width: 2.5))),
            child: Text(label,
                style: V3.inter(16,
                    weight: on ? FontWeight.w600 : FontWeight.w400,
                    color: on ? V3.text : kText2)),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: V3.line))),
      child: Row(children: [
        tab('teams', 'Teams'),
        tab('players', 'Players'),
        tab('squads', 'Squads'),
      ]),
    );
  }

  Widget _periodSeg() => _seg([
        for (final p in AnPeriod.values)
          (
            kPeriodLabels[p]!,
            _custom == null && _period == p,
            () => _setPeriod(p)
          )
      ]);

  Widget _seg(List<(String, bool, VoidCallback)> items) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: V3.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: V3.line)),
        child: Row(children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: it.$3,
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: it.$2 ? V3.card2 : Colors.transparent,
                      borderRadius: BorderRadius.circular(9)),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(it.$1,
                          style: V3.inter(15,
                              weight: it.$2 ? FontWeight.w600 : FontWeight.w400,
                              color: it.$2 ? V3.text : kText2)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );

  /// A scrolling row of choice pills (sorts).
  Widget _pills(List<(String, String)> opts, String value,
          ValueChanged<String> onPick) =>
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final o in opts)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _pill(o.$2, value == o.$1, () => onPick(o.$1)),
              ),
          ],
        ),
      );

  Widget _pill(String label, bool on, VoidCallback onTap) => Material(
        color: on ? V3.greenTint : V3.card,
        shape: StadiumBorder(side: BorderSide(color: on ? V3.green : V3.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(label,
                  style: V3.inter(15,
                      weight: on ? FontWeight.w600 : FontWeight.w400,
                      color: on ? V3.green : kText2)),
            ),
          ),
        ),
      );

  Widget _chips() {
    final chips = <(String, VoidCallback)>[
      if (_custom != null)
        (
          _range.label,
          () {
            _custom = null;
            _period = AnPeriod.season;
            _loadData();
          }
        ),
      for (final g in _f.changed)
        ('${g.$2}: ${_f.label(g.$1)}', () => _update(() => _f.reset(g.$1))),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in chips)
          Material(
            color: Colors.transparent,
            shape: const StadiumBorder(side: BorderSide(color: V3.green)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: c.$2,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(c.$1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(14, color: V3.green)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.close, size: 16, color: V3.green),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  // ---------------------------------------------------------- shared bits

  Widget _card(Widget child,
          {VoidCallback? onTap,
          EdgeInsets padding = const EdgeInsets.all(16),
          double bottom = 12}) =>
      Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Material(
          color: V3.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: V3.line)),
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? Padding(padding: padding, child: child)
              : InkWell(
                  onTap: onTap, child: Padding(padding: padding, child: child)),
        ),
      );

  Widget _h(String text, {String? more, VoidCallback? onMore}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: V3.inter(13,
                    weight: FontWeight.w600,
                    color: V3.muted,
                    letterSpacing: 0.8)),
          ),
          if (more != null)
            TextButton(
                onPressed: onMore,
                style: TextButton.styleFrom(
                    minimumSize: const Size(44, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(more,
                    style: V3.inter(15,
                        weight: FontWeight.w500, color: V3.green))),
        ]),
      );

  /// "See all 32" / "Show less" for a list over its limit.
  String? _moreLabel(String key, int n, int limit) => n > limit
      ? (_expanded.contains(key) ? 'Show less' : 'See all ${fmtN(n)}')
      : null;
  void _toggleMore(String key) => _update(() =>
      _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key));
  List<T> _shown<T>(String key, List<T> list, int limit) =>
      _expanded.contains(key) || list.length <= limit
          ? list
          : list.sublist(0, limit);

  Widget _rows(List<Widget> rows) => Column(children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: V3.line))),
            child: rows[i],
          ),
      ]);

  Widget _empty(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: V3.inter(15, color: V3.muted))));

  Widget _noEvents() => _card(_empty(
      'No events in this period${_f.changedLabels().isNotEmpty ? ' for these filters' : ''}'));

  Widget _tag(String text, Color bg, Color fg, {double size = 14}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
        child: Text(text,
            style: V3.inter(size, weight: FontWeight.w600, color: fg)),
      );

  /// Pill colours by attendance: green, amber, red.
  (Color, Color) _bandPill(int p) => p >= 70
      ? (V3.greenTint, V3.green)
      : p >= 50
          ? (V3.amberTint, kWarn)
          : (V3.redTint, kNoText);

  Widget _avatar(String name, {Color? bg, Color? fg}) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: bg ?? V3.card2, shape: BoxShape.circle),
        child: Text(initials(name),
            style: V3.inter(14, weight: FontWeight.w700, color: fg ?? kText2)),
      );

  Widget _chev() => const Icon(Icons.chevron_right, color: V3.muted, size: 24);

  Widget _trend(AnTrend? t) {
    if (t == null) return const SizedBox.shrink();
    final c = t.diff > 0
        ? kYes
        : t.diff < 0
            ? kNoText
            : V3.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child:
          Text(t.text, style: V3.inter(14, weight: FontWeight.w600, color: c)),
    );
  }

  Widget _two(List<Widget> cards) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: cards[i]),
            if (i + 1 < cards.length) ...[
              const SizedBox(width: 12),
              Expanded(child: cards[i + 1]),
            ] else if (cards.length > 1) ...[
              const SizedBox(width: 12),
              const Expanded(child: SizedBox.shrink()),
            ],
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _kpi(
          {required String big,
          String? unit,
          required String label,
          required String sub,
          required Widget bar,
          Widget? head,
          VoidCallback? onTap}) =>
      _card(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (head != null) ...[head, const SizedBox(height: 4)],
            Text.rich(TextSpan(children: [
              TextSpan(text: big, style: V3.tight(30, weight: FontWeight.w700)),
              if (unit != null)
                TextSpan(
                    text: unit,
                    style:
                        V3.inter(17, weight: FontWeight.w500, color: V3.muted)),
            ])),
            if (label.isNotEmpty)
              Text(label, style: V3.inter(15, color: kText2)),
            const SizedBox(height: 6),
            Text(sub, style: V3.inter(14, color: kText2)),
            const Spacer(),
            const SizedBox(height: 10),
            bar,
          ]),
          onTap: onTap,
          bottom: 0);

  Widget _hero(AnCtx ctx, AnTotals t, {Widget? extra}) => _card(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AnRing(pct: t.pct, color: bandColor(t.pct)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${fmtN(t.acc)} of ${fmtN(t.total)} places filled',
                        style: V3.inter(17, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                        'Replied ${t.replied}% · ${plural(t.nr, 'no reply', 'no replies')}',
                        style: V3.inter(15, color: kText2)),
                    _trend(trendLine(ctx, t.pct)),
                  ]),
            ),
          ]),
          if (extra != null) extra,
        ],
      ));

  Widget _split(List<AnEvent> evs) {
    final tr = evs.where((e) => e.isTraining).toList();
    final ma = evs.where((e) => e.isMatch).toList();
    Widget card(List<AnEvent> l, String label, String unit, [String? pl]) {
      final t = totals(l);
      return _kpi(
          big: '${t.pct}',
          unit: '%',
          label: label,
          sub:
              '${fmtN(t.acc)} of ${fmtN(t.total)} · ${plural(l.length, unit, pl)}',
          bar: AnSegBar(
              segs: [AnSeg(1, bandColor(t.pct))],
              fill: t.pct / 100,
              height: 7));
    }

    return _two([
      if (tr.isNotEmpty) card(tr, 'Training attendance', 'session'),
      if (ma.isNotEmpty) card(ma, 'Match availability', 'match', 'matches'),
    ]);
  }

  Widget _codeCards(List<AnEvent> evs) {
    final codes = {
      for (final e in evs)
        if (e.code != null) e.code!
    }.toList()
      ..sort();
    if (codes.length < 2) return const SizedBox.shrink();
    return _two([
      for (final c in codes)
        () {
          final l = evs.where((e) => e.code == c).toList(), t = totals(l);
          return _kpi(
              head: Text(c.toUpperCase(),
                  style: V3.inter(13,
                      weight: FontWeight.w700,
                      color: V3.green,
                      letterSpacing: 0.8)),
              big: '${t.pct}',
              unit: '%',
              label: '',
              sub: '${plural(l.length, 'event')} · replied ${t.replied}%',
              bar: const SizedBox.shrink(),
              onTap: () => _update(() => _f.only('code', c)));
        }()
    ]);
  }

  Widget _monthsChart(AnCtx ctx) {
    final ms = months(ctx);
    if (ms.length < 2 || ctx.evs.isEmpty) return const SizedBox.shrink();
    final avg = totals(ctx.evs).pct;
    return Column(children: [
      _h('Attendance by month'),
      _card(SizedBox(
        height: 160,
        width: double.infinity,
        child: CustomPaint(
            painter: AnBarsPainter([
          for (final m in ms)
            AnBar(
                m.pct == null
                    ? const []
                    : [
                        AnSeg(
                            m.pct!.clamp(2, 100).toDouble(),
                            V3.green.withValues(
                                alpha: m.pct! < avg - 15 ? 0.55 : 1))
                      ],
                m.pct == null ? '–' : '${m.pct}%',
                monthLabel(m.d, ms.length))
        ], 100)),
      )),
    ]);
  }

  Widget _eventRow(AnEvent e, bool multiCode, bool showTeam) {
    final d = e.date;
    final yr = d.year != _now.year ? ' ’${d.year.toString().substring(2)}' : '';
    final meta = eventMeta(e, showTeam);
    final p = pctOf(e.acc, e.total);
    final (bg, fg) = _bandPill(p);
    return InkWell(
      onTap: () => _openEvent(e.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          SizedBox(
            width: 50,
            child: Column(children: [
              Text('${d.day}', style: V3.tight(20, weight: FontWeight.w700)),
              Text('${kMon[d.month - 1]}$yr'.toUpperCase(),
                  style: V3.inter(12, color: V3.muted)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(eventTitle(e),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(16, weight: FontWeight.w600)),
              if (meta.isNotEmpty || multiCode)
                Row(children: [
                  if (multiCode)
                    Padding(
                      padding: const EdgeInsets.only(right: 6, top: 2),
                      child: e.code != null
                          ? _tag(e.code!.toUpperCase(), V3.greenTint, V3.green,
                              size: 11)
                          : _tag('NO CODE', V3.card2, kText2, size: 11),
                    ),
                  Expanded(
                    child: Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(14, color: kText2)),
                  ),
                ]),
            ]),
          ),
          const SizedBox(width: 8),
          _tag('${e.acc} of ${e.total}', bg, fg),
        ]),
      ),
    );
  }

  Widget _dots(List<String> recent) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          for (final c in recent.take(10).toList().reversed)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c == 'yes'
                      ? kYes
                      : c == 'no'
                          ? kNo
                          : kNone),
            ),
        ]),
      );

  Widget _playerRow(PlayerStat p, String sort, bool showTeam) {
    final badges = playerBadges(p, sort, showTeam);
    return InkWell(
      onTap: () => _openPlayer(p.id, p.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          _avatar(p.name),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V3.inter(16, weight: FontWeight.w600)),
              if (badges.isNotEmpty)
                Text.rich(
                    TextSpan(children: [
                      for (var i = 0; i < badges.length; i++) ...[
                        if (i > 0) const TextSpan(text: ' · '),
                        TextSpan(
                            text: badges[i].text,
                            style: TextStyle(
                                color: switch (badges[i].kind) {
                              BadgeKind.warn => kWarn,
                              BadgeKind.up => kYes,
                              BadgeKind.down => kNoText,
                              BadgeKind.plain => kText2,
                            })),
                      ]
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(14, color: kText2)),
              _dots(p.recent),
            ]),
          ),
          const SizedBox(width: 8),
          Text('${p.rate}%',
              style: V3.inter(17,
                  weight: FontWeight.w700, color: bandText(p.rate))),
          _chev(),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------ Teams tab

  List<Widget> _teamsView() {
    final d = _data!;
    final ctx = contextFor(d, _f, _range);
    if (ctx.evs.isEmpty) return [_noEvents()];
    final teams = teamRanking(ctx, _teamSort);
    return [
      _pills(
          kTeamSorts,
          _teamSort,
          (v) => _update(() {
                _teamSort = v;
                _expanded.clear();
              })),
      const SizedBox(height: 12),
      for (final tm in teams) _teamCard(ctx, tm),
    ];
  }

  Widget _teamCard(AnCtx ctx, TeamRank tm) {
    final ms = months(ctx.withEvs(tm.evs));
    final split = [
      if (tm.tr.events > 0) 'Training ${tm.tr.pct}%',
      if (tm.ma.events > 0) 'Matches ${tm.ma.pct}%',
    ].join(' · ');
    return _card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            AnRing(pct: tm.t.pct, color: bandColor(tm.t.pct), size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tm.name, style: V3.inter(17, weight: FontWeight.w600)),
                    if (split.isNotEmpty)
                      Text(split, style: V3.inter(15, color: kText2)),
                    _trend(trendText(tm.trend, ctx.r.prevLabel)),
                  ]),
            ),
            _chev(),
          ]),
          if (ms.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 36,
                width: double.infinity,
                child: CustomPaint(
                    painter:
                        AnSparkPainter([for (final m in ms) m.pct], tm.t.pct)),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: V3.line))),
            child: Row(children: [
              Expanded(
                child: Text(
                    '${plural(tm.players, 'player')} · ${plural(tm.evs.length, 'event')}',
                    style: V3.inter(14, color: kText2)),
              ),
              Text('Replied ${tm.t.replied}%',
                  style: V3.inter(14, color: kText2)),
            ]),
          ),
        ]),
        onTap: () => _openTeam(tm.id));
  }

  // ------------------------------------------------------------ Team page

  List<Widget> _teamPageView() {
    final d = _data!;
    final team = d.team(_teamPage!);
    if (team == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _closeTeam());
      return const [];
    }
    final ctx = contextFor(d, _f, _range, teamId: team.id);
    final t = totals(ctx.evs);
    final stats = playerStats(ctx.evs);
    final head = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
        child: Text(team.name, style: V3.tight(24, weight: FontWeight.w700)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
        child: Text(
            '${_range.label} · ${plural(stats.length, 'player')} · ${plural(ctx.evs.length, 'event')}',
            style: V3.inter(15, color: kText2)),
      ),
    ];
    if (ctx.evs.isEmpty) return [...head, _noEvents()];

    final last10 = ctx.evs.take(10).toList().reversed.toList();
    final extra =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 14),
      Text('Last ${last10.length} events (players there)',
          style: V3.inter(14, color: kText2)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in last10)
          () {
            final p = pctOf(e.acc, e.total);
            final (bg, fg) = p >= 70
                ? (V3.greenTint, V3.green)
                : p >= 50
                    ? (V3.card2, kText2)
                    : (V3.redTint, kNoText);
            return _tag('${e.acc}', bg, fg);
          }()
      ]),
    ]);

    final roles =
        team.roles.where((r) => _f.on['role']!.contains(r.role)).toList();
    final list = sortPlayers(stats.values.toList(), _teamPlayerSort);
    final mc = multiCodeIn(ctx.evs);
    return [
      ...head,
      _hero(ctx, t, extra: extra),
      _split(ctx.evs),
      _codeCards(ctx.evs),
      if (roles.isNotEmpty) ...[
        _h('Squad'),
        _card(Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < roles.length; i++)
            Material(
              color: i == 0 ? V3.greenTint : V3.card2,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => _openRoster(roles[i].role),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    widthFactor: 1,
                    child: Text('${roles[i].role} ${roles[i].count}',
                        style: V3.inter(15,
                            weight: FontWeight.w600,
                            color: i == 0 ? V3.green : kText2)),
                  ),
                ),
              ),
            ),
        ])),
      ],
      _h('Players',
          more: _moreLabel('teamPlayers', list.length, kLimitTeamPlayers),
          onMore: () => _toggleMore('teamPlayers')),
      _pills(
          kTeamPlayerSorts,
          _teamPlayerSort,
          (v) => _update(() {
                _teamPlayerSort = v;
                _expanded.clear();
              })),
      const SizedBox(height: 10),
      _card(
          _rows([
            for (final p in _shown('teamPlayers', list, kLimitTeamPlayers))
              _playerRow(p, _teamPlayerSort, false)
          ]),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
      _monthsChart(ctx),
      _h('Events',
          more: _moreLabel('teamEvents', ctx.evs.length, kLimitTeamEvents),
          onMore: () => _toggleMore('teamEvents')),
      _card(
          _rows([
            for (final e in _shown('teamEvents', ctx.evs, kLimitTeamEvents))
              _eventRow(e, mc, false)
          ]),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
    ];
  }

  // ---------------------------------------------------------- Players tab

  List<Widget> _playersView() {
    final d = _data!;
    final ctx = contextFor(d, _f, _range);
    if (ctx.evs.isEmpty) return [_noEvents()];
    final stats = playerStats(ctx.evs);
    movers(ctx, stats);
    final all = stats.values.toList();
    final (lo, mid, hi) = spread(all);
    final avg = totals(ctx.evs).pct;
    final list = playerList(all, _q, _playerSort);
    Widget legend(Color c, String text) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: V3.inter(14, color: kText2)),
        ]);
    final more = _moreLabel('players', list.length, kLimitPlayers);
    return [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                  child: Text(plural(all.length, 'player'),
                      style: V3.inter(18, weight: FontWeight.w600))),
              Text('Average $avg%', style: V3.inter(15, color: kText2)),
            ]),
        const SizedBox(height: 12),
        AnSegBar(segs: [
          AnSeg(lo.toDouble(), kNo),
          AnSeg(mid.toDouble(), kWarn),
          AnSeg(hi.toDouble(), kAccent),
        ], gap: 2, height: 12, track: false),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, children: [
          legend(kNo, 'Under 50% · $lo'),
          legend(kWarn, '50–69% · $mid'),
          legend(kAccent, '70%+ · $hi'),
        ]),
      ])),
      TextField(
        controller: _search,
        onChanged: (v) => _update(() => _q = v),
        style: V3.inter(16),
        cursorColor: V3.green,
        decoration: InputDecoration(
          hintText: 'Search players',
          hintStyle: V3.inter(16, color: V3.muted),
          prefixIcon: const Icon(Icons.search, color: V3.muted),
          filled: true,
          fillColor: V3.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: V3.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: V3.green)),
        ),
      ),
      const SizedBox(height: 10),
      _pills(
          kPlayerSorts,
          _playerSort,
          (v) => _update(() {
                _playerSort = v;
                _expanded.clear();
              })),
      const SizedBox(height: 10),
      _card(
          list.isEmpty
              ? _empty(_q.isNotEmpty
                  ? 'No players match'
                  : 'Nobody here for this period')
              : _rows([
                  for (final p in _shown('players', list, kLimitPlayers))
                    _playerRow(p, _playerSort, true)
                ]),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
      if (more != null)
        Center(
          child: TextButton(
              onPressed: () => _toggleMore('players'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: Text(more,
                  style:
                      V3.inter(16, weight: FontWeight.w500, color: V3.green))),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('Tap a player to open their full stats page',
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.muted)),
      ),
    ];
  }

  // ----------------------------------------------------------- Squads tab

  List<Widget> _squadsView() {
    final d = _data!;
    final ctx = contextFor(d, _f, _range);
    if (ctx.evs.isEmpty) return [_noEvents()];
    final sm = SquadModel(d, ctx);
    if (sm.withPicks.isEmpty) {
      return [_card(_empty('No match squads saved in this period'))];
    }
    final p = pctOf(sm.picked, sm.poolN);
    final most = sm.most;
    final unpicked = sm.unpicked;
    final squads = sm.squadList;
    final places = squads.fold(0, (t, s) => t + s.places);
    final maxPlaces = squads.fold(1, (m, s) => s.places > m ? s.places : m);
    final maxPick = most.isEmpty ? 1 : most.first.total;
    final segs = sm.donut(squads);
    final cols = sm.byMonth(ctx);
    final mx = cols.fold(1, (m, c) => c.total > m ? c.total : m);
    final buckets = sm.buckets();
    final bMax = buckets.fold(1, (m, x) => x > m ? x : m);

    return [
      _card(Row(children: [
        AnRing(pct: p, color: bandColor(p)),
        const SizedBox(width: 16),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${sm.picked} of ${sm.poolN} players picked',
                style: V3.inter(17, weight: FontWeight.w600)),
            Text('For at least one match squad',
                style: V3.inter(15, color: kText2)),
            const SizedBox(height: 3),
            Text(
                unpicked.isNotEmpty
                    ? '${plural(unpicked.length, 'player')} not picked yet'
                    : 'Everyone has been picked',
                style: V3.inter(14, weight: FontWeight.w600, color: V3.muted)),
          ]),
        ),
      ])),
      _two([
        _kpi(
            big: '$places',
            label: 'Squad places',
            sub: 'across ${plural(sm.withPicks.length, 'match', 'matches')}',
            bar: AnSegBar(segs: [
              for (final s in squads) AnSeg(s.places.toDouble(), sm.sqHex(s.id))
            ], height: 7)),
        _kpi(
            big: '${sm.multi}',
            label: 'Played 2+ squads',
            sub: '${pctOf(sm.multi, sm.picked)}% of picked players',
            bar: AnSegBar(
                segs: const [AnSeg(1, kPurple)],
                fill: pctOf(sm.multi, sm.picked) / 100,
                height: 7)),
      ]),
      _h('Squad split'),
      _card(Row(children: [
        SizedBox(
            width: 128,
            height: 128,
            child: CustomPaint(
                painter: AnDonutPainter(
                    [for (final x in segs) AnSeg(x.v.toDouble(), x.color)],
                    '$places',
                    'places'))),
        const SizedBox(width: 16),
        Expanded(
          child: Column(children: [
            for (final x in segs)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: x.color,
                          borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(x.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V3.inter(15, color: kText2)),
                          if (x.team.isNotEmpty)
                            Text(x.team,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: V3.inter(12, color: V3.muted)),
                        ]),
                  ),
                  Text('${x.v}', style: V3.inter(15, weight: FontWeight.w700)),
                  SizedBox(
                    width: 44,
                    child: Text('${pctOf(x.v, places)}%',
                        textAlign: TextAlign.right,
                        style: V3.inter(14, color: V3.muted)),
                  ),
                ]),
              ),
          ]),
        ),
      ])),
      if (cols.isNotEmpty) ...[
        _h('Squad places by month'),
        _card(SizedBox(
          height: 170,
          width: double.infinity,
          child: CustomPaint(
              painter: AnBarsPainter([
            for (final c in cols)
              AnBar([
                for (final en in sm.ordered(c.counts))
                  AnSeg(en.value.toDouble(), sm.sqHex(en.key))
              ], c.total == 0 ? '–' : '${c.total}', c.label)
          ], mx.toDouble())),
        )),
      ],
      _h('Squads'),
      _card(
          _rows([
            for (final s in squads)
              () {
                final top = stableSort(
                        s.members.entries.toList(), (a, b) => b.value - a.value)
                    .firstOrNull;
                final c = sm.sqHex(s.id);
                return InkWell(
                  onTap: () => _openSquad(s.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      _sqBadge(sm, s.id),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sm.sqLabel(s.id),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V3.inter(16, weight: FontWeight.w600)),
                              Text(
                                  '${plural(s.events.length, 'match', 'matches')}${top != null ? ' · most picked ${sm.nameOf(top.key)} ×${top.value}' : ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: V3.inter(14, color: kText2)),
                              const SizedBox(height: 6),
                              AnSegBar(
                                  segs: [AnSeg(1, c)],
                                  fill: s.places / maxPlaces,
                                  height: 7),
                            ]),
                      ),
                      const SizedBox(width: 8),
                      _tag(plural(s.members.length, 'player'),
                          c.withValues(alpha: 0.16), c),
                      _chev(),
                    ]),
                  ),
                );
              }()
          ]),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
      _h('How often players are picked'),
      _card(Column(children: [
        for (var i = 0; i < kPickBuckets.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(
                  width: 128,
                  child: Text(kPickBuckets[i].$1,
                      style: V3.inter(14, color: kText2))),
              Expanded(
                child: buckets[i] == 0
                    ? const AnSegBar(segs: [], height: 14)
                    : AnSegBar(
                        segs: [AnSeg(1, kPickBuckets[i].$2)],
                        fill: buckets[i] / bMax,
                        height: 14),
              ),
              SizedBox(
                width: 36,
                child: Text('${buckets[i]}',
                    textAlign: TextAlign.right,
                    style: V3.inter(15, weight: FontWeight.w700)),
              ),
            ]),
          ),
        const SizedBox(height: 6),
        Text("Share of their team's picked matches",
            style: V3.inter(13, color: V3.muted)),
      ])),
      _h('Most picked',
          more: _moreLabel('picked', most.length, kLimitPicked),
          onMore: () => _toggleMore('picked')),
      _card(
          _rows([
            for (final (i, pl) in _shown('picked', most, kLimitPicked).indexed)
              InkWell(
                onTap: () => _openPlayer(pl.id, pl.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(children: [
                    _medal(i),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pl.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: V3.inter(16, weight: FontWeight.w600)),
                            Wrap(spacing: 10, children: [
                              for (final en in stableSort(pl.m.entries.toList(),
                                  (a, b) => b.value - a.value))
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                          color: sm.sqHex(en.key),
                                          shape: BoxShape.circle)),
                                  Text('${sm.sqName(en.key)} ×${en.value}',
                                      style: V3.inter(14, color: kText2)),
                                ]),
                            ]),
                            const SizedBox(height: 6),
                            AnSegBar(segs: [
                              for (final en in sm.ordered(pl.m))
                                AnSeg(en.value.toDouble(), sm.sqHex(en.key))
                            ], fill: pl.total / maxPick, gap: 1, height: 8),
                          ]),
                    ),
                    const SizedBox(width: 10),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${pl.total}',
                              style: V3.inter(17,
                                  weight: FontWeight.w700, color: V3.green)),
                          if (pl.of > 0)
                            Text('of ${pl.of}',
                                style: V3.inter(13, color: V3.muted)),
                        ]),
                  ]),
                ),
              ),
          ]),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
      if (unpicked.isNotEmpty) ...[
        _h('Not picked yet',
            more: _moreLabel('unpicked', unpicked.length, kLimitUnpicked),
            onMore: () => _toggleMore('unpicked')),
        _card(
            _rows([
              for (final pl in _shown('unpicked', unpicked, kLimitUnpicked))
                InkWell(
                  onTap: () => _openPlayer(pl.id, pl.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      AnRing(pct: pl.rate, color: bandColor(pl.rate), size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pl.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: V3.inter(16, weight: FontWeight.w600)),
                              Text(
                                  '${pl.teams.join(', ')} · attendance ${pl.rate}%',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: V3.inter(14, color: kText2)),
                            ]),
                      ),
                      _chev(),
                    ]),
                  ),
                ),
            ]),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
      ],
    ];
  }

  Widget _sqBadge(SquadModel sm, int id) {
    final c = sm.sqHex(id);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.45))),
      child: Text(initials(sm.sqName(id)),
          style: V3.inter(13, weight: FontWeight.w800, color: c)),
    );
  }

  Widget _medal(int i) {
    const colours = [Color(0xFFF5C542), Color(0xFFC9D1DC), Color(0xFFD08B4C)];
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: i < 3 ? colours[i] : V3.card2, shape: BoxShape.circle),
      child: Text('${i + 1}',
          style: V3.inter(14,
              weight: FontWeight.w700, color: i < 3 ? V3.bg : V3.muted)),
    );
  }

  // --------------------------------------------------------------- sheets

  Widget _greenButton(String label, VoidCallback onTap, {IconData? icon}) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
              backgroundColor: V3.green,
              foregroundColor: V3.bg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: V3.bg),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: V3.inter(16, weight: FontWeight.w700, color: V3.bg)),
          ]),
        ),
      );

  Future<void> _sheet(Widget Function(BuildContext ctx) build) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: V3.card,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
        builder: (ctx) => ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.86),
          child: ValueListenableBuilder<int>(
              valueListenable: _tick, builder: (c, _, __) => build(c)),
        ),
      );

  /// Grab handle, title with a PDF button, subtitle, the rows and a Share
  /// PDF button.
  Widget _detail(
      {required String title,
      required String sub,
      required List<Widget> top,
      required List<Widget> rows,
      required Report Function() report}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: V3.card2, borderRadius: BorderRadius.circular(2))),
          Row(children: [
            Expanded(
                child:
                    Text(title, style: V3.inter(19, weight: FontWeight.w600))),
            IconButton(
                tooltip: 'Share PDF',
                onPressed: () => _sharePdf(report()),
                icon: const Icon(Icons.ios_share, color: V3.text)),
          ]),
          if (sub.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(sub, style: V3.inter(15, color: kText2)),
            ),
          ...top,
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                rows.isEmpty ? _empty('Nobody here') : _rows(rows),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _greenButton('Share PDF', () => _sharePdf(report()),
              icon: Icons.ios_share),
        ]),
      ),
    );
  }

  void _openEvent(int id) {
    var resp = 'all';
    _sheet((ctx) => StatefulBuilder(builder: (ctx, set) {
          final d = _data!;
          final e = scopeEvent(d, _f, id);
          if (e == null) {
            return Padding(
                padding: const EdgeInsets.all(24),
                child: _empty('Event not found'));
          }
          void pick(String v) =>
              set(() => resp = resp == v && v != 'all' ? 'all' : v);
          Widget count(String v, int n, Color bg, Color fg) => Expanded(
                child: Material(
                  color: bg,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: resp == v ? fg : Colors.transparent,
                          width: 1.5)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => pick(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(children: [
                        Text('$n',
                            style: V3.tight(24,
                                weight: FontWeight.w700, color: fg)),
                        Text(kRespLabel[v]!, style: V3.inter(14, color: fg)),
                      ]),
                    ),
                  ),
                ),
              );
          return _detail(
            title: eventTitle(e),
            sub: eventSub(e),
            report: () => eventReport(d, e, resp),
            top: [
              const SizedBox(height: 12),
              Row(children: [
                count('accepted', e.acc, kYes.withValues(alpha: 0.14), kYes),
                const SizedBox(width: 8),
                count('declined', e.dec, kNo.withValues(alpha: 0.14), kNoText),
                const SizedBox(width: 8),
                count(
                    'no_response', e.nr, kNone.withValues(alpha: 0.35), kText2),
              ]),
              const SizedBox(height: 12),
              _seg([
                ('All ${e.total}', resp == 'all', () => pick('all')),
                ('Going', resp == 'accepted', () => pick('accepted')),
                ('Not going', resp == 'declined', () => pick('declined')),
                ('No reply', resp == 'no_response', () => pick('no_response')),
              ]),
              const SizedBox(height: 8),
            ],
            rows: [
              for (final m in eventMembers(e, resp))
                () {
                  final sq =
                      m.squadId != null ? d.squads[m.squadId]?.name : null;
                  final (bg, fg) = m.response == 'accepted'
                      ? (kYes.withValues(alpha: 0.14), kYes)
                      : m.response == 'declined'
                          ? (kNo.withValues(alpha: 0.14), kNoText)
                          : (kNone.withValues(alpha: 0.35), kText2);
                  return InkWell(
                    onTap: () => _openPlayer(m.id, m.name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(children: [
                        _avatar(m.name),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        V3.inter(16, weight: FontWeight.w600)),
                                Text(
                                    [m.role, if (sq != null) sq]
                                        .where((s) => s.isNotEmpty)
                                        .join(' · '),
                                    style: V3.inter(14, color: kText2)),
                              ]),
                        ),
                        _tag(kRespLabel[m.response] ?? 'No reply', bg, fg),
                      ]),
                    ),
                  );
                }()
            ],
          );
        }));
  }

  void _openSquad(int id) {
    _sheet((ctx) {
      final d = _data!;
      final ctxA = contextFor(d, _f, _range);
      final sm = SquadModel(d, ctxA);
      final c = sm.sqHex(id);
      final n = sm.squads[id]?.events.length ?? 0;
      final rows = squadMembers(sm, id);
      return _detail(
        title: sm.sqLabel(id),
        sub:
            '${_range.label} · ${plural(n, 'match', 'matches')} · ${plural(rows.length, 'player')}',
        report: () => squadReport(d, sm, id, _range.label),
        top: [
          Container(
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                  color: c, borderRadius: BorderRadius.circular(2))),
        ],
        rows: [
          for (final r in rows)
            InkWell(
              onTap: () => _openPlayer(r.$1, r.$2),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  _avatar(r.$2, bg: c.withValues(alpha: 0.18), fg: c),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V3.inter(16, weight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          AnSegBar(
                              segs: [AnSeg(1, c)],
                              fill: n == 0 ? 0 : r.$3 / n,
                              height: 7),
                        ]),
                  ),
                  const SizedBox(width: 10),
                  _tag('${r.$3} of $n', c.withValues(alpha: 0.16), c),
                ]),
              ),
            ),
        ],
      );
    });
  }

  void _openRoster(String role) {
    _sheet((ctx) {
      final d = _data!;
      final team = _teamPage == null ? null : d.team(_teamPage!);
      final group = team?.roles.where((r) => r.role == role).firstOrNull;
      final stats =
          playerStats(contextFor(d, _f, _range, teamId: _teamPage).evs);
      final rows = rosterRows(group, stats);
      return _detail(
        title: '${team?.name ?? ''} · $role',
        sub:
            '${plural(rows.length, 'member')} · attendance for ${_range.label}',
        report: () => rosterReport(team, role, stats, _range.label),
        top: const [SizedBox(height: 8)],
        rows: [
          for (final r in rows)
            InkWell(
              onTap: () => _openPlayer(r.$1.id, r.$1.name),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  _avatar(r.$1.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$1.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: V3.inter(16, weight: FontWeight.w600)),
                          if (r.$2 != null)
                            Text(plural(r.$2!.events, 'event'),
                                style: V3.inter(14, color: kText2)),
                        ]),
                  ),
                  r.$2 != null
                      ? Text('${r.$2!.rate}%',
                          style: V3.inter(17,
                              weight: FontWeight.w700,
                              color: bandText(r.$2!.rate)))
                      : _tag(
                          'No events', kNone.withValues(alpha: 0.35), kText2),
                ]),
              ),
            ),
        ],
      );
    });
  }

  // --------------------------------------------------------- filter sheet

  Widget _pickerTheme(BuildContext ctx, Widget? child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: V3.green,
              onPrimary: V3.bg,
              surface: V3.card,
              onSurface: V3.text),
          dialogTheme: const DialogThemeData(backgroundColor: V3.card),
        ),
        child: child!,
      );

  Future<void> _pickDates() async {
    final now = _now;
    final r = await showDateRangePicker(
      context: context,
      firstDate: kAllFrom,
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _custom == null
          ? null
          : DateTimeRange(start: _custom!.from, end: _custom!.to),
      builder: _pickerTheme,
    );
    if (r == null) return;
    final from = DateTime(r.start.year, r.start.month, r.start.day);
    final to = DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59);
    if (to.isBefore(from)) {
      _snack('The end date is before the start date');
      return;
    }
    _custom = AnCustom(from, to);
    _expanded.clear();
    _loadData();
  }

  void _openFilters() {
    _sheet((ctx) {
      Widget label(String text, {List<Widget> trailing = const []}) => Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Row(children: [
              Expanded(
                child: Text(text.toUpperCase(),
                    style: V3.inter(13,
                        weight: FontWeight.w600,
                        color: V3.muted,
                        letterSpacing: 0.8)),
              ),
              ...trailing,
            ]),
          );
      Widget link(String text, VoidCallback onTap) => TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10)),
          child: Text(text,
              style: V3.inter(15, weight: FontWeight.w500, color: V3.green)));
      final c = _custom;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: V3.card2, borderRadius: BorderRadius.circular(2))),
            Row(children: [
              Expanded(
                  child: Text('Filters',
                      style: V3.inter(19, weight: FontWeight.w600))),
              link('Reset all', () {
                final hadCustom = _custom != null;
                _f.resetAll();
                _custom = null;
                hadCustom ? _loadData() : _update(() {});
              }),
            ]),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                if (_clubs.length > 1) ...[
                  label('Club'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final cl in _clubs)
                      _pill(cl.name, cl.id == _clubId, () {
                        if (cl.id == _clubId) return;
                        _clubId = cl.id;
                        _f.clear();
                        _teamPage = null;
                        _loadData();
                      }),
                  ]),
                ],
                if (_loading)
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                          child: CircularProgressIndicator(color: V3.green)))
                else
                  for (final g in _f.visibleGroups) ...[
                    label(g.$2, trailing: [
                      link('All', () => _update(() => _f.all(g.$1))),
                      link('None', () => _update(() => _f.none(g.$1))),
                    ]),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final o in _f.options[g.$1]!)
                        _pill(o.$2, _f.on[g.$1]!.contains(o.$1),
                            () => _update(() => _f.toggle(g.$1, o.$1))),
                    ]),
                  ],
                label('Custom dates'),
                Material(
                  color: V3.card2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: V3.line)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDates,
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(children: [
                        const Icon(Icons.date_range, color: V3.muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              c == null
                                  ? 'Pick a from and to date'
                                  : '${fmtDay(c.from)} – ${fmtDay(c.to)}',
                              style: V3.inter(16,
                                  color: c == null ? V3.muted : V3.text)),
                        ),
                        if (c != null)
                          IconButton(
                              tooltip: 'Clear dates',
                              onPressed: () {
                                _custom = null;
                                _period = AnPeriod.season;
                                _loadData();
                              },
                              icon: const Icon(Icons.close, color: V3.muted)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            _greenButton('Done', () => Navigator.of(ctx).pop()),
          ]),
        ),
      );
    });
  }
}
