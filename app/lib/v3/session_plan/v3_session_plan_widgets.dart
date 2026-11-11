// Session plan pieces: the plan cards (editable or read-only), the saved
// plans picker with its preview, a game's detail and the "add games from the
// library" list. Used by V3SessionPlanPage.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '/v3/games/v3_games.dart';
import '../v3_theme.dart';
import 'v3_session_plan_api.dart';
import 'v3_session_plan_models.dart';

/// The label the session plan uses for a game's variations (as its PDF).
const String kSpHarder = 'Make it harder';

const Color kSpWarm = Color(0xFFF5A524);
const Color kSpCool = Color(0xFF60A5FA);

Color spToneColor(String tone) => switch (tone) {
      'warm' => kSpWarm,
      'cool' => kSpCool,
      _ => V3.green,
    };

void spSnack(BuildContext context, String text, {bool warn = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
}

PreferredSizeWidget spAppBar(BuildContext context, String title,
        {List<Widget>? actions, VoidCallback? onBack}) =>
    AppBar(
      backgroundColor: V3.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
          onPressed: onBack ?? () => Navigator.of(context).maybePop()),
      titleSpacing: 0,
      title: Text(title, overflow: TextOverflow.ellipsis, style: V3.tight(18)),
      actions: actions,
    );

/// A grey upper-case label above a group.
class SpLabel extends StatelessWidget {
  const SpLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.muted, letterSpacing: 0.8)),
      );
}

/// The centred icon / title / text screens (empty, off, error).
class SpStateView extends StatelessWidget {
  const SpStateView(
      {super.key,
      required this.icon,
      required this.title,
      required this.body,
      this.action});
  final String icon, title, body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(icon, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: V3.tight(20, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(body,
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted, height: 1.5)),
            if (action != null) ...[const SizedBox(height: 22), action!],
          ]),
        ),
      );
}

/// A big green button.
class SpButton extends StatelessWidget {
  const SpButton(this.label,
      {super.key,
      this.onPressed,
      this.busy = false,
      this.icon,
      this.outline = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy, outline;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = outline ? V3.green : Colors.black87;
    // The spinner sits inside the button that was tapped, with its words.
    final child = busy
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: fg)),
            const SizedBox(width: 10),
            Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(17, weight: FontWeight.w700, color: fg))),
          ])
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 8)
            ],
            Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(17, weight: FontWeight.w700, color: fg))),
          ]);
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: outline
            ? const BorderSide(color: V3.green, width: 1.5)
            : BorderSide.none);
    return SizedBox(
      height: 54,
      child: TextButton(
        onPressed: busy ? null : onPressed,
        style: TextButton.styleFrom(
            backgroundColor: outline ? Colors.transparent : V3.green,
            disabledBackgroundColor:
                outline ? Colors.transparent : V3.green.withValues(alpha: 0.5),
            shape: shape,
            padding: const EdgeInsets.symmetric(horizontal: 18)),
        child: child,
      ),
    );
  }
}

// ------------------------------------------------------------------ plan

/// Callbacks for an editable plan; null for a read-only preview.
class SpPlanEdit {
  const SpPlanEdit({
    required this.onText,
    required this.onNumber,
    required this.onDuration,
    required this.onMenu,
    this.onOpenGame,
    this.ai = true,
  });

  /// A text field changed (path, value).
  final void Function(String path, String value) onText;

  /// A number field changed (path, value or null when cleared).
  final void Function(String path, int? value) onNumber;

  /// The minutes pill of a section was tapped.
  final void Function(String path) onDuration;

  /// The ⋮ of a section was tapped: move or remove a drill, and (with
  /// [ai]) "Change this part".
  final void Function(SpSection section) onMenu;

  /// AI changes are allowed, so every section gets a ⋮, not only drills.
  final bool ai;

  /// A drill's game name was tapped.
  final void Function(String gameName)? onOpenGame;
}

/// The plan's cards: focus, objective, warm up, station setup, drills,
/// cool down (web renderPlan() / renderPlanReadOnly()).
///
/// [version] changes whenever the plan is replaced, so text fields pick up
/// the new words.
List<Widget> spPlanCards(
  Map<String, dynamic> plan, {
  required int version,
  SpPlanEdit? edit,
  Map<String, DateTime> starts = const {},
  Set<String> changed = const {},
}) {
  final out = <Widget>[];
  final title = '${plan['session_title'] ?? ''}';
  if (title.trim().isNotEmpty) {
    out.add(const _SectionHeader(label: 'FOCUS', tone: 'drill'));
    out.add(_Card(
        child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: _Field(
          path: 'session_title',
          text: title,
          version: version,
          edit: edit,
          style: V3.tight(19, weight: FontWeight.w700)),
    )));
  }
  final obj = '${plan['session_objective'] ?? ''}';
  if (obj.trim().isNotEmpty) {
    out.add(Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
          color: V3.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border(
              left: BorderSide(
                  color: V3.green.withValues(alpha: 0.9), width: 4))),
      child: _Field(
          path: 'session_objective',
          text: obj,
          version: version,
          edit: edit,
          style: V3.inter(16, height: 1.45, color: V3.text)),
    ));
  }

  final sections = planSections(plan);
  var stationDone = false;
  for (final s in sections) {
    if (s.drill != null && !stationDone) {
      stationDone = true;
      out.addAll(_station(plan, version, edit));
    }
    final phase = getPath(plan, s.path);
    if (phase is! Map) continue;
    final mins = durationOf(plan, s.path);
    out.add(_SectionHeader(
      label: s.label,
      tone: s.tone,
      minutes: mins,
      start: starts[s.path],
      onMinutes: edit == null ? null : () => edit.onDuration(s.path),
      changed: changed.contains(s.path),
      onMenu: edit == null || (s.drill == null && !edit.ai)
          ? null
          : () => edit.onMenu(s),
    ));
    final isPrePost = s.path == 'pre_session' || s.path == 'post_session';
    final name = isPrePost ? '' : '${phase['game_name'] ?? ''}';
    final image = isPrePost ? '' : '${phase['game_image'] ?? ''}';
    out.add(_PhaseCard(
      plan: plan,
      path: s.path,
      gameName: name,
      drillNum: s.drill == null ? null : s.drill! + 1,
      image: image,
      version: version,
      edit: edit,
    ));
  }
  if (!stationDone) out.addAll(_station(plan, version, edit));
  return out;
}

List<Widget> _station(Map plan, int version, SpPlanEdit? edit) {
  final st = '${plan['station_setup'] ?? ''}'.trim();
  if (st.isEmpty) return const [];
  return [
    const _SectionHeader(label: 'STATION SETUP', tone: 'drill'),
    _Card(
        child: Padding(
      padding: const EdgeInsets.all(16),
      child: _Field(
          path: 'station_setup',
          text: st,
          version: version,
          edit: edit,
          style: V3.inter(16, height: 1.5)),
    )),
  ];
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: V3.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: V3.line)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.label,
      required this.tone,
      this.minutes,
      this.start,
      this.onMinutes,
      this.onMenu,
      this.changed = false});
  final String label, tone;
  final bool changed;
  final int? minutes;
  final DateTime? start;
  final VoidCallback? onMinutes, onMenu;

  @override
  Widget build(BuildContext context) {
    final c = spToneColor(tone);
    final m = minutes ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(label,
                    style: V3.inter(14,
                        weight: FontWeight.w800, color: c, letterSpacing: 1)),
                if (start != null)
                  Text(spClock(start!),
                      style: V3.inter(15,
                          weight: FontWeight.w600, color: V3.muted)),
                if (changed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: V3.green,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('Changed',
                        style: V3.inter(13,
                            weight: FontWeight.w700, color: Colors.black87)),
                  ),
              ]),
        ),
        if (m > 0 || onMinutes != null)
          Semantics(
            button: onMinutes != null,
            label: '$m minutes',
            child: InkWell(
              key: ValueKey('dur-$label'),
              onTap: onMinutes,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: V3.card2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: onMinutes != null
                              ? V3.green.withValues(alpha: 0.5)
                              : V3.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (onMinutes != null) ...[
                      const Icon(Icons.timer_outlined,
                          size: 16, color: V3.green),
                      const SizedBox(width: 5),
                    ],
                    Text('$m min',
                        style: V3.inter(15, weight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        if (onMenu != null)
          IconButton(
            key: ValueKey('menu-$label'),
            tooltip: 'Options',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.more_vert, color: V3.muted),
            onPressed: onMenu,
          ),
      ]),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.plan,
    required this.path,
    required this.gameName,
    required this.drillNum,
    required this.image,
    required this.version,
    required this.edit,
  });
  final Map plan;
  final String path, gameName, image;
  final int? drillNum;
  final int version;
  final SpPlanEdit? edit;

  @override
  Widget build(BuildContext context) {
    String txt(String k) => '${getPath(plan, '$path.$k') ?? ''}'.trim();
    final setup = txt('setup');
    final desc = txt('description');
    final variation = txt('variation');
    final video = path.endsWith('_session') ? '' : txt('game_video');
    final points = coachingPoints(plan, path);
    final open = edit?.onOpenGame;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (gameName.isNotEmpty || drillNum != null)
          InkWell(
            onTap:
                open == null || gameName.isEmpty ? null : () => open(gameName),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              decoration: const BoxDecoration(
                  color: V3.card2,
                  border: Border(bottom: BorderSide(color: V3.line))),
              child: Row(children: [
                if (drillNum != null) ...[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: V3.green, shape: BoxShape.circle),
                    child: Text('$drillNum',
                        style: V3.inter(15,
                            weight: FontWeight.w800, color: Colors.black87)),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                    child: Text(gameName,
                        style: V3.inter(17, weight: FontWeight.w700))),
                if (open != null && gameName.isNotEmpty)
                  const Icon(Icons.chevron_right, color: V3.muted),
              ]),
            ),
          ),
        if (image.isNotEmpty)
          CachedNetworkImage(
            imageUrl: image,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            placeholder: (_, __) => Container(height: 160, color: V3.card2),
            errorWidget: (_, __, ___) => const SizedBox.shrink(),
          ),
        if (video.isNotEmpty)
          InkWell(
            onTap: () => openGameVideo(video),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: V3.line))),
              child: Row(children: [
                const Icon(Icons.play_circle_fill, color: V3.green, size: 26),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('Watch the video',
                        style: V3.inter(16, weight: FontWeight.w600))),
                const Icon(Icons.open_in_new, color: V3.muted, size: 18),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (setup.isNotEmpty) ...[
              const _CpLabel('Setup'),
              _Field(
                  path: '$path.setup',
                  text: setup,
                  version: version,
                  edit: edit),
            ],
            if (desc.isNotEmpty) ...[
              const _CpLabel('How to Play'),
              _Field(
                  path: '$path.description',
                  text: desc,
                  version: version,
                  edit: edit),
            ],
            if (points.isNotEmpty) ...[
              const _CpLabel('Coaching Points'),
              for (var i = 0; i < points.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1, right: 8),
                          child: Text('•',
                              style: V3.inter(17,
                                  weight: FontWeight.w800, color: V3.green)),
                        ),
                        Expanded(
                            child: _Field(
                                path: '$path.coaching_points.$i',
                                text: points[i],
                                version: version,
                                edit: edit)),
                      ]),
                ),
            ],
            if (variation.isNotEmpty) ...[
              const _CpLabel(kSpHarder),
              _Field(
                  path: '$path.variation',
                  text: variation,
                  version: version,
                  edit: edit),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _CpLabel extends StatelessWidget {
  const _CpLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: 0.8)),
      );
}

/// Text that the coach can tap to edit (web contenteditable).
class _Field extends StatelessWidget {
  const _Field({
    required this.path,
    required this.text,
    required this.version,
    required this.edit,
    this.style,
  });
  final String path, text;
  final int version;
  final SpPlanEdit? edit;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final st = style ?? V3.inter(16, height: 1.5);
    if (edit == null) return Text(text, style: st);
    return TextFormField(
      key: ValueKey('f$version:$path'),
      initialValue: text,
      maxLines: null,
      style: st,
      cursorColor: V3.green,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 4),
          border: InputBorder.none),
      onChanged: (v) => edit!.onText(path, v),
    );
  }
}

/// One of the three stat tiles (players, coaches, minutes).
class SpStat extends StatelessWidget {
  const SpStat(
      {super.key,
      required this.path,
      required this.value,
      required this.label,
      required this.version,
      this.onChanged});
  final String path, label;
  final int? value;
  final int version;
  final void Function(String path, int? value)? onChanged;

  @override
  Widget build(BuildContext context) {
    final st = V3.tight(26, weight: FontWeight.w800);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
            color: V3.card, borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          if (onChanged == null)
            Text(value == null ? '—' : '$value', style: st)
          else
            TextFormField(
              key: ValueKey('s$version:$path'),
              initialValue: value == null ? '' : '$value',
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: st,
              cursorColor: V3.green,
              decoration: InputDecoration(
                  isDense: true,
                  hintText: '—',
                  hintStyle: st.copyWith(color: V3.muted),
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none),
              onChanged: (v) => onChanged!(path, int.tryParse(v)),
            ),
          const SizedBox(height: 2),
          Text(label, style: V3.inter(14, color: V3.muted)),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------- saved plans picker

/// Saved Plans: My Plans and Club Plans tabs. Pops with the chosen plan id.
class SpSavedPlansPage extends StatefulWidget {
  const SpSavedPlansPage({super.key, required this.call, required this.userId});
  final SpCall call;
  final String userId;

  @override
  State<SpSavedPlansPage> createState() => _SpSavedPlansPageState();
}

class _SpSavedPlansPageState extends State<SpSavedPlansPage> {
  List<SpPlanSummary>? _mine, _club;
  String? _mineErr, _clubErr;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load(false);
  }

  Future<void> _load(bool club) async {
    setState(() => club ? _clubErr = null : _mineErr = null);
    try {
      final r = await widget.call(kSpFn, {
        'action': club ? 'get_club_plans' : 'get_user_plans',
        'user_id': widget.userId,
      });
      if (!r.ok) throw Exception();
      final list = parsePlanList(r.data);
      if (!mounted) return;
      setState(() => club ? _club = list : _mine = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => club ? _clubErr = 'x' : _mineErr = 'x');
    }
  }

  void _setTab(int t) {
    setState(() => _tab = t);
    if (t == 1 && _club == null && _clubErr == null) _load(true);
  }

  Future<void> _preview(SpPlanSummary p) async {
    final use = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SpPlanPreviewPage(
            call: widget.call, userId: widget.userId, summary: p)));
    if (use == true && mounted) Navigator.of(context).pop(p.planId);
  }

  @override
  Widget build(BuildContext context) {
    final club = _tab == 1;
    final list = club ? _club : _mine;
    final err = club ? _clubErr : _mineErr;
    Widget body;
    if (err != null) {
      body = SpStateView(
          icon: '⚠️',
          title: 'Failed to load',
          body: 'Check your connection and try again.',
          action: SpButton('Try again',
              outline: true, onPressed: () => _load(club)));
    } else if (list == null) {
      body = const Center(child: CircularProgressIndicator(color: V3.green));
    } else if (list.isEmpty) {
      body = club
          ? const SpStateView(
              icon: '👥',
              title: 'No club plans yet',
              body: "Coaches in your club can share plans — they'll appear "
                  'here once shared.')
          : const SpStateView(
              icon: '📋',
              title: 'No saved plans yet',
              body: "Generate plans from your favourites — they'll appear "
                  'here.');
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final p = list[i];
          return Material(
            color: V3.card,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: V3.line)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _preview(p),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: V3.inter(17, weight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(spPlanMeta(p, club: club),
                              style: V3.inter(15, color: V3.muted)),
                        ]),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: ValueKey('use-${p.planId}'),
                    onPressed: () => Navigator.of(context).pop(p.planId),
                    style: TextButton.styleFrom(
                        backgroundColor: V3.green,
                        minimumSize: const Size(64, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: Text('Use',
                        style: V3.inter(16,
                            weight: FontWeight.w700, color: Colors.black87)),
                  ),
                ]),
              ),
            ),
          );
        },
      );
    }
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: spAppBar(context, 'Saved Plans'),
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: V3.line))),
          child: Row(children: [
            _tabBtn('My Plans', 0),
            _tabBtn('Club Plans', 1),
          ]),
        ),
        Expanded(child: body),
      ]),
    );
  }

  Widget _tabBtn(String label, int t) {
    final on = _tab == t;
    return Expanded(
      child: InkWell(
        onTap: () => _setTab(t),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: on ? V3.green : Colors.transparent, width: 3))),
          child: Text(label,
              style: V3.inter(17,
                  weight: FontWeight.w600, color: on ? V3.green : V3.muted)),
        ),
      ),
    );
  }
}

/// A saved plan, read-only, with "Use This Plan" (pops true).
class SpPlanPreviewPage extends StatefulWidget {
  const SpPlanPreviewPage(
      {super.key,
      required this.call,
      required this.userId,
      required this.summary});
  final SpCall call;
  final String userId;
  final SpPlanSummary summary;

  @override
  State<SpPlanPreviewPage> createState() => _SpPlanPreviewPageState();
}

class _SpPlanPreviewPageState extends State<SpPlanPreviewPage> {
  Map<String, dynamic>? _plan;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.call(kSpFn, {
        'action': 'get_plan',
        'plan_id': widget.summary.planId,
        'user_id': widget.userId,
      });
      final p = r.map['plan'];
      if (!r.ok || p is! Map) throw Exception();
      if (mounted) setState(() => _plan = deepCopy(p));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: spAppBar(
          context,
          '${plan?['session_title'] ?? ''}'.isNotEmpty
              ? '${plan!['session_title']}'
              : 'Plan Preview'),
      body: _failed
          ? const SpStateView(
              icon: '⚠️',
              title: 'Failed to load',
              body: 'Check your connection and try again.')
          : plan == null
              ? const Center(child: CircularProgressIndicator(color: V3.green))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  children: spPlanCards(plan, version: 0),
                ),
      bottomNavigationBar: plan == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SpButton('Use This Plan',
                    onPressed: () => Navigator.of(context).pop(true)),
              ),
            ),
    );
  }
}

// ------------------------------------------------------------- game detail

/// A game from the plan or the favourites list: the heart, Export Game Card,
/// the detail and My Notes (web game sheet).
class SpGamePage extends StatefulWidget {
  const SpGamePage(
      {super.key,
      required this.gameId,
      required this.call,
      required this.userId,
      required this.eventId,
      required this.api,
      required this.favourites});
  final int gameId;
  final SpCall call;
  final String userId;
  final int? eventId;
  final V3GamesApi api;
  final V3GameFavourites favourites;

  @override
  State<SpGamePage> createState() => _SpGamePageState();
}

class _SpGamePageState extends State<SpGamePage> {
  V3Game? _game;
  bool _failed = false;
  bool _pdfBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.call(kSpFn, {
        'action': 'get_game',
        'event_id': widget.eventId,
        'user_id': widget.userId,
        'game_id': widget.gameId,
      });
      final g = r.map['game'];
      if (!r.ok || g is! Map) throw Exception();
      final m = Map<String, dynamic>.from(g);
      // The detail picture is the bigger one when there is one.
      final big = '${m['game_details_image'] ?? ''}'.trim();
      if (big.isNotEmpty) m['game_image'] = big;
      if (mounted) setState(() => _game = V3Game.fromJson(m));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _pdf() async {
    setState(() => _pdfBusy = true);
    try {
      final (bytes, name) = await widget.api.gameCardPdf(widget.gameId);
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (_) {
      if (mounted) {
        spSnack(context, 'Could not generate PDF — please try again',
            warn: true);
      }
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _game;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: spAppBar(context, g?.name ?? '', actions: [
        ListenableBuilder(
          listenable: widget.favourites,
          builder: (_, __) => V3HeartButton(
              on: widget.favourites.isFav(widget.gameId),
              onPressed: () async {
                final msg = await widget.favourites.toggle(widget.gameId);
                if (context.mounted) {
                  spSnack(context, msg, warn: msg.startsWith('Could'));
                }
              }),
        ),
        const SizedBox(width: 4),
      ]),
      body: _failed
          ? const SpStateView(
              icon: '⚠️',
              title: 'Game not found',
              body: 'Could not load game details')
          : g == null
              ? const Center(child: CircularProgressIndicator(color: V3.green))
              : V3GameDetailView(
                  game: g,
                  variationsLabel: kSpHarder,
                  header: SpButton(
                      _pdfBusy ? 'Generating…' : 'Export Game Card',
                      icon: Icons.ios_share,
                      outline: true,
                      busy: _pdfBusy,
                      onPressed: _pdf),
                  footer: V3GameNotes(gameId: g.gameId, api: widget.api),
                ),
    );
  }
}

// -------------------------------------------------- add games from library

/// The games library with hearts, to add favourites to the plan's list.
class SpAddGamesPage extends StatefulWidget {
  const SpAddGamesPage(
      {super.key,
      required this.api,
      required this.favourites,
      required this.call,
      required this.userId,
      required this.eventId,
      this.eventCode = ''});
  final V3GamesApi api;
  final V3GameFavourites favourites;
  final SpCall call;
  final String userId;
  final int? eventId;
  final String eventCode;

  @override
  State<SpAddGamesPage> createState() => _SpAddGamesPageState();
}

class _SpAddGamesPageState extends State<SpAddGamesPage> {
  List<V3Game>? _games;
  String _club = '';
  bool _failed = false;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final clubId = await widget.api.myClubId();
      final all = await widget.api.games(clubId);
      final club = clubId == null ? '' : await widget.api.clubName(clubId);
      all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _games = [
          for (final g in all)
            if (g.canFavourite && g.hasContent) g
        ];
        _club = club;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool _suits(V3Game g) {
    final code = widget.eventCode.toLowerCase().replaceAll(' ', '');
    if (code.isEmpty || g.codes.isEmpty) return true;
    return g.codes.any((c) {
      final n = c.toLowerCase().replaceAll(' ', '');
      return code.contains(n) || n.contains(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = _games;
    final q = _q.trim().toLowerCase();
    final shown = all == null
        ? const <V3Game>[]
        : [
            for (final g in all)
              if (_suits(g) && (q.isEmpty || g.name.toLowerCase().contains(q)))
                g
          ];
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: spAppBar(context, 'Games Library'),
      body: _failed
          ? const SpStateView(
              icon: '⚠️',
              title: 'Something went wrong',
              body: 'The games library could not be loaded.')
          : all == null
              ? const Center(child: CircularProgressIndicator(color: V3.green))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      onChanged: (v) => setState(() => _q = v),
                      style: V3.inter(17),
                      cursorColor: V3.green,
                      decoration: InputDecoration(
                        hintText: 'Search games',
                        hintStyle: V3.inter(17, color: V3.muted),
                        prefixIcon: const Icon(Icons.search, color: V3.muted),
                        filled: true,
                        fillColor: V3.card,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                    child: Text(
                        'Tap the heart to add a game to your favourites.',
                        style: V3.inter(15, color: V3.muted)),
                  ),
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.favourites,
                      builder: (context, _) => ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final g = shown[i];
                          return V3GameCard(
                            game: g,
                            clubName: _club,
                            isFavourite: widget.favourites.isFav(g.gameId),
                            onFavourite: () async {
                              final msg =
                                  await widget.favourites.toggle(g.gameId);
                              if (context.mounted) {
                                spSnack(context, msg,
                                    warn: msg.startsWith('Could'));
                              }
                            },
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => SpGamePage(
                                        gameId: g.gameId,
                                        call: widget.call,
                                        userId: widget.userId,
                                        eventId: widget.eventId,
                                        api: widget.api,
                                        favourites: widget.favourites))),
                          );
                        },
                      ),
                    ),
                  ),
                ]),
    );
  }
}
