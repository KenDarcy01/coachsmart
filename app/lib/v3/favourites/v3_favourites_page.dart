// v3 Favourites: native copy of webviews/favourites.html (main). The coach's
// favourite games: filter, pick up to 10 in session order (drag to set the
// order), swipe a game left to remove it (with Undo), a quick look at each
// game (game card PDF, heart, coach notes), Export Games as a PDF for a
// phone or A4, and, with users.ai_features on, Build Session Plan and My
// Plans. With the flag off: the list and Export Games only, no AI, no mic.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../games/v3_games.dart' show V3Game, V3GameDetailView, kHeartRed;
import '../match_report/v3_voice_sheet.dart';
import '../v3_theme.dart';
import 'v3_fav_widgets.dart';
import 'v3_favourites_api.dart';
import 'v3_favourites_models.dart';
import 'v3_my_plans_page.dart';
import 'v3_session_setup_page.dart';

const _hintKey = 'cs_fav_swipe_hint';

class V3FavouritesPage extends StatefulWidget {
  const V3FavouritesPage({
    super.key,
    this.eventId,
    this.durationMins = 60,
    this.api = const V3FavouritesApi(),
    this.dictation,
  });

  /// Opened from an event: with AI on, My Plans opens first so a plan can
  /// be attached to the event.
  final int? eventId;

  /// Starting session length for Build Session Plan.
  final int durationMins;
  final V3FavouritesApi api;

  /// Tests pass a fake recogniser for the voice panel.
  @visibleForTesting
  final V3Dictation? dictation;

  @override
  State<V3FavouritesPage> createState() => _V3FavouritesPageState();
}

class _V3FavouritesPageState extends State<V3FavouritesPage> {
  bool _loading = true;
  String? _error;
  bool _ai = false;
  List<FavGame> _favs = [];
  List<int> _picked = [];
  String _filter = 'all';
  bool _hintSeen = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final p = await SharedPreferences.getInstance();
      _hintSeen = p.getString(_hintKey) != null;
    } catch (_) {}
    _ai = await widget.api.aiFeatures();
    if (!mounted) return;
    await _loadFavs();
    if (!mounted || widget.eventId == null || !_ai) return;
    // Event-attach mode: open My Plans directly.
    final r = await Navigator.of(context).push<String>(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3MyPlansPage'),
        builder: (_) =>
            V3MyPlansPage(api: widget.api, eventId: widget.eventId)));
    if (r != 'build' && mounted) Navigator.of(context).maybePop();
  }

  Future<void> _loadFavs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.plan('get');
      if (!mounted) return;
      if (!r.ok) {
        setState(() {
          _loading = false;
          _error = r.error ?? 'Failed to load.';
        });
        return;
      }
      final favs = parseFavourites(r.data);
      setState(() {
        _favs = favs;
        _picked = initialPicks(favs);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Network error. Please check your connection and try again.';
      });
    }
  }

  void _snack(String t, {bool warn = false, bool success = false}) {
    if (mounted) favSnack(context, t, warn: warn, success: success);
  }

  // ---------------------------------------------------------------- picks

  void _togglePick(int id) {
    if (_picked.contains(id)) {
      setState(() => _picked.remove(id));
      return;
    }
    if (_picked.length >= kMaxGames) {
      _snack('You can pick up to $kMaxGames games');
      return;
    }
    setState(() => _picked.add(id));
  }

  void _toggleAll() =>
      setState(() => _picked = _picked.isNotEmpty ? [] : initialPicks(_favs));

  // --------------------------------------------------------------- remove

  void _markHintSeen() {
    if (_hintSeen) return;
    _hintSeen = true;
    SharedPreferences.getInstance()
        .then((p) => p.setString(_hintKey, '1'))
        .ignore();
  }

  /// Removes at once (so it sticks even if the coach leaves), and Undo adds
  /// it back.
  Future<void> _removeFav(int gameId) async {
    final index = _favs.indexWhere((f) => f.gameId == gameId);
    if (index < 0) return;
    final fav = _favs[index];
    final pickedAt = _picked.indexOf(gameId);
    setState(() {
      _favs.removeAt(index);
      _picked.remove(gameId);
    });
    _markHintSeen();
    final ok = await widget.api.toggleFavourite(gameId);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _favs.insert(index.clamp(0, _favs.length), fav);
        if (pickedAt >= 0 && _picked.length < kMaxGames) {
          _picked.insert(pickedAt.clamp(0, _picked.length), gameId);
        }
      });
      _snack('Could not remove. Try again', warn: true);
      return;
    }
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      backgroundColor: V3.card2,
      content: Text('Removed "${fav.name}"',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: V3.inter(15, color: V3.text)),
      action: SnackBarAction(
          label: 'Undo',
          textColor: V3.green,
          onPressed: () => _undoRemove(fav, index, pickedAt)),
    ));
  }

  Future<void> _undoRemove(FavGame fav, int index, int pickedAt) async {
    final ok = await widget.api.toggleFavourite(fav.gameId);
    if (!mounted) return;
    if (!ok) {
      _snack('Could not add it back. Try again', warn: true);
      return;
    }
    setState(() {
      _favs.insert(index.clamp(0, _favs.length), fav);
      if (pickedAt >= 0 && _picked.length < kMaxGames) {
        _picked.insert(pickedAt.clamp(0, _picked.length), fav.gameId);
      }
    });
  }

  // --------------------------------------------------------------- export

  Future<void> _exportGames() async {
    final ids = [..._picked];
    if (ids.isEmpty) {
      _snack('Select at least one game');
      return;
    }
    if (ids.length > kMaxGames) {
      _snack('You can pick up to $kMaxGames games');
      return;
    }
    final layout = await pickPdfLayout(context, 'Export Games');
    if (layout == null || !mounted) return;
    setState(() => _exporting = true);
    try {
      final (bytes, name) = await widget.api.gameCardsPdf(ids, layout: layout);
      await sharePdfBytes(bytes, name);
    } catch (_) {
      _snack('Could not generate PDF — please try again', warn: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _build() {
    if (_picked.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'V3SessionSetupPage'),
      builder: (_) => V3SessionSetupPage(
        gameIds: [..._picked],
        durationMins: widget.durationMins,
        eventId: widget.eventId,
        api: widget.api,
        dictation: widget.dictation,
      ),
    ));
  }

  void _openMyPlans() => Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'V3MyPlansPage'),
      builder: (_) => V3MyPlansPage(api: widget.api, eventId: widget.eventId)));

  // ----------------------------------------------------------- quick look

  /// The quick look's heart. Returns whether it is now a favourite and the
  /// message to show, or null when the call failed.
  Future<(bool, String)?> _sheetToggle(int gameId) async {
    final isFav = _favs.any((f) => f.gameId == gameId);
    final ok = await widget.api.toggleFavourite(gameId);
    if (!ok) return null;
    if (isFav && mounted) {
      setState(() {
        _favs.removeWhere((f) => f.gameId == gameId);
        _picked.remove(gameId);
      });
    }
    return (!isFav, isFav ? 'Removed from favourites' : 'Added to favourites');
  }

  Future<void> _openGame(FavGame f) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (ctx) => _QuickLook(
        fav: f,
        api: widget.api,
        ai: _ai,
        onToggle: () => _sheetToggle(f.gameId),
        isEmpty: () => _favs.isEmpty,
        dictation: widget.dictation,
      ),
    );
  }

  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final showList = !_loading && _error == null && _favs.isNotEmpty;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: favAppBar(
        context,
        Text(_loading ? 'Loading…' : 'Favourites', style: V3.tight(18)),
        actions: [
          if (_ai && !_loading) MyPlansPill(onTap: _openMyPlans),
        ],
      ),
      body: _loading
          ? const FavStateView(loading: true, body: 'Loading…')
          : _error != null
              ? FavStateView(
                  icon: '⚠️', title: 'Something went wrong', body: _error!)
              : _favs.isEmpty
                  ? const FavStateView(
                      icon: '⭐',
                      title: 'No Favourites Yet',
                      body:
                          'Head to the Games Library and add some favourites, then come back here.')
                  : _list(),
      bottomNavigationBar: showList ? _bottomBar() : null,
    );
  }

  Widget _bottomBar() {
    final n = _picked.length;
    final export = FavButton(
      label: exportLabel(n, _ai),
      icon: Icons.ios_share,
      primary: false,
      busy: _exporting,
      onPressed: _exportGames,
    );
    return FavBottomBar(children: [
      if (_ai) export else Expanded(child: export),
      if (_ai)
        Expanded(
            child: FavButton(
                label: buildPlanLabel(n), onPressed: n > 0 ? _build : null)),
    ]);
  }

  Widget _list() {
    final chips = favChips(_favs);
    if (!chips.any((c) => c.key == _filter)) _filter = 'all';
    final byId = {for (final f in _favs) f.gameId: f};
    _picked = [
      for (final id in _picked)
        if (byId.containsKey(id)) id
    ];
    final shownPicked = [
      for (final id in _picked)
        if (favMatches(byId[id]!, _filter)) byId[id]!
    ];
    final rest = [
      for (final f in _favs)
        if (!_picked.contains(f.gameId) && favMatches(f, _filter)) f
    ];
    final n = _picked.length;
    final count = pickCountText(n, _favs.length);
    final hint = shownPicked.isEmpty && rest.isEmpty
        ? 'No favourites match this filter'
        : (!_hintSeen ? 'Tip: swipe a game left to remove it' : '');

    Widget sec(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(t.toUpperCase(),
              style: V3.inter(13,
                  weight: FontWeight.w700, color: V3.muted, letterSpacing: 1)),
        );

    return CustomScrollView(slivers: [
      if (chips.isNotEmpty)
        SliverToBoxAdapter(
          child: SizedBox(
            height: 60,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              children: [
                for (final c in chips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _Chip(c.label, c.key == _filter,
                        () => setState(() => _filter = c.key)),
                  ),
              ],
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: count.bold,
                        style: V3.inter(16,
                            weight: FontWeight.w600, color: V3.text)),
                    TextSpan(text: count.rest),
                  ]),
                  style: V3.inter(16, color: V3.muted),
                ),
              ),
              TextButton(
                onPressed: _toggleAll,
                style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
                child: Text(n > 0 ? 'Clear' : 'Pick all',
                    style:
                        V3.inter(16, weight: FontWeight.w600, color: V3.green)),
              ),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pickMeter(n, _favs.length),
                minHeight: 5,
                backgroundColor: V3.card2,
                color: V3.green,
              ),
            ),
          ]),
        ),
      ),
      if (shownPicked.isNotEmpty)
        SliverToBoxAdapter(
            child: sec(shownPicked.length > 1 && _filter == 'all'
                ? 'Picked · drag to set order'
                : 'Picked')),
      SliverReorderableList(
        itemCount: shownPicked.length,
        onReorderStart: (_) => HapticFeedback.mediumImpact(),
        onReorderItem: (from, to) {
          if (from != to) HapticFeedback.lightImpact();
          setState(() => _picked = reorderPicked(
              _picked, [for (final f in shownPicked) f.gameId], from, to));
        },
        proxyDecorator: (child, _, __) => Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.03, child: child),
        ),
        itemBuilder: (_, i) {
          final f = shownPicked[i];
          return KeyedSubtree(
            key: ValueKey(f.gameId),
            child: ReorderableDelayedDragStartListener(
              index: i,
              enabled: shownPicked.length > 1,
              child: _card(f,
                  num: _picked.indexOf(f.gameId) + 1,
                  index: i,
                  canDrag: shownPicked.length > 1),
            ),
          );
        },
      ),
      if (rest.isNotEmpty) SliverToBoxAdapter(child: sec('Not picked')),
      SliverList.builder(
        itemCount: rest.length,
        itemBuilder: (_, i) => _card(rest[i]),
      ),
      if (hint.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(hint,
                textAlign: TextAlign.center,
                style: V3.inter(15, color: V3.muted)),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }

  Widget _card(FavGame f, {int num = 0, int? index, bool canDrag = false}) {
    final picked = num > 0;
    final capped = !picked && _picked.length >= kMaxGames;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Dismissible(
        key: ValueKey('fav-${f.gameId}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => _removeFav(f.gameId),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
              color: const Color(0xFFC0392B),
              borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.heart_broken_outlined, color: Colors.white),
            const SizedBox(height: 3),
            Text('Remove',
                style:
                    V3.inter(14, weight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
        child: Opacity(
          opacity: capped ? 0.45 : 1,
          child: _FavCard(
            fav: f,
            num: num,
            dragIndex: canDrag ? index : null,
            onTap: () => _openGame(f),
            onTick: () => _togglePick(f.gameId),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.on, this.onTap);
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: on ? V3.greenTint : Colors.transparent,
        shape: StadiumBorder(
            side: BorderSide(color: on ? V3.green : V3.line, width: 1.5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(label,
                  style: V3.inter(15,
                      weight: FontWeight.w500,
                      color: on ? V3.green : V3.muted)),
            ),
          ),
        ),
      );
}

class _Tags extends StatelessWidget {
  const _Tags(this.tags);
  final List<FavTag> tags;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: t.type ? V3.greenTint : V3.card2,
                borderRadius: BorderRadius.circular(6)),
            child: Text(t.text,
                style: V3.inter(13,
                    weight: FontWeight.w500,
                    color: t.type ? V3.green : const Color(0xFFB9C3CF))),
          ),
      ]);
}

class _FavCard extends StatelessWidget {
  const _FavCard(
      {required this.fav,
      required this.num,
      this.dragIndex,
      required this.onTap,
      required this.onTick});
  final FavGame fav;
  final int num;
  final int? dragIndex;
  final VoidCallback onTap, onTick;

  @override
  Widget build(BuildContext context) {
    final picked = num > 0;
    final thumbPh = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
          color: V3.card2, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.image_outlined, color: V3.muted),
    );
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: picked ? V3.green.withValues(alpha: 0.5) : V3.line,
                width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
            child: Row(children: [
              SizedBox(
                width: 32,
                height: 48,
                child: dragIndex != null
                    ? ReorderableDragStartListener(
                        index: dragIndex!,
                        child: const Icon(Icons.drag_indicator,
                            color: V3.muted, size: 22),
                      )
                    : null,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: fav.image.isEmpty
                    ? thumbPh
                    : CachedNetworkImage(
                        imageUrl: fav.image,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => thumbPh,
                        errorWidget: (_, __, ___) => thumbPh),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fav.name,
                          style: V3.inter(17,
                              weight: FontWeight.w600, height: 1.25)),
                      const SizedBox(height: 6),
                      _Tags(tagsOf(fav)),
                    ]),
              ),
              Semantics(
                button: true,
                label: picked ? 'Unpick' : 'Pick',
                child: InkResponse(
                  onTap: onTick,
                  radius: 26,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: picked ? V3.green : Colors.transparent,
                          border: Border.all(
                              color:
                                  picked ? V3.green : const Color(0xFF3A4556),
                              width: 2),
                        ),
                        child: picked
                            ? const Icon(Icons.check, size: 18, color: V3.bg)
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
      if (picked)
        Positioned(
          top: -7,
          left: -7,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: V3.green,
                shape: BoxShape.circle,
                border: Border.all(color: V3.bg, width: 2)),
            child: Text('$num',
                style: V3.inter(13, weight: FontWeight.w700, color: V3.bg)),
          ),
        ),
    ]);
  }
}

/// The slide-up quick look at one favourite: Export Game Card, the heart,
/// and coach notes (typed, or spoken when AI is on).
class _QuickLook extends StatefulWidget {
  const _QuickLook({
    required this.fav,
    required this.api,
    required this.ai,
    required this.onToggle,
    required this.isEmpty,
    this.dictation,
  });
  final FavGame fav;
  final V3FavouritesApi api;
  final bool ai;
  final Future<(bool, String)?> Function() onToggle;
  final bool Function() isEmpty;
  final V3Dictation? dictation;

  @override
  State<_QuickLook> createState() => _QuickLookState();
}

class _QuickLookState extends State<_QuickLook> {
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  final _note = TextEditingController();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _game;
  bool _isFav = true;
  bool _pdfBusy = false, _saving = false;

  int get _id => widget.fav.gameId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _snack(String t, {bool warn = false}) {
    final ctx = _messenger.currentContext;
    if (ctx != null) favSnack(ctx, t, warn: warn);
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.plan('get_game', {'game_id': _id});
      if (!mounted) return;
      final g = r.data['game'];
      setState(() {
        _loading = false;
        if (g is Map) {
          _game = Map<String, dynamic>.from(g);
          _note.text = '${r.data['coach_note'] ?? ''}';
        } else {
          _error = 'Game not found';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load game details';
        });
      }
    }
  }

  Future<void> _toggle() async {
    try {
      final r = await widget.onToggle();
      if (!mounted) return;
      if (r == null) {
        _snack('Could not update favourites');
        return;
      }
      setState(() => _isFav = r.$1);
      if (!r.$1 && widget.isEmpty()) {
        Navigator.of(context).pop();
        return;
      }
      _snack(r.$2);
    } catch (_) {
      _snack('Network error');
    }
  }

  Future<void> _saveNote() async {
    setState(() => _saving = true);
    try {
      final r = await widget.api
          .plan('save_coach_note', {'game_id': _id, 'note': _note.text.trim()});
      _snack(r.data['ok'] == true ? 'Note saved ✓' : 'Could not save note');
    } catch (_) {
      _snack('Network error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _voiceNote() async {
    FocusScope.of(context).unfocus();
    await showV3VoiceSheet(
      context,
      title: 'Coach notes',
      subtitle: 'Your own notes for this game. Only you see them.',
      placeholder: 'e.g. Works best with 8 a side, keep the boxes tight',
      text: _note.text,
      submitLabel: 'Save note',
      onSubmit: (text) async {
        _note.text = text;
        _saveNote();
        return true;
      },
      onError: (m) => _snack(m, warn: true),
      dictation: widget.dictation,
    );
  }

  Future<void> _pdf() async {
    final layout = await pickPdfLayout(context, 'Export Game Card');
    if (layout == null || !mounted) return;
    setState(() => _pdfBusy = true);
    try {
      final (bytes, name) =
          await widget.api.gameCardsPdf([_id], layout: layout, single: true);
      await sharePdfBytes(bytes, name);
    } catch (_) {
      _snack('Could not generate PDF');
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final g = _game;
    final name = g != null ? '${g['game_name'] ?? ''}' : widget.fav.name;
    return Container(
      height: h - MediaQuery.of(context).padding.top - 48,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: ScaffoldMessenger(
        key: _messenger,
        child: Scaffold(
          backgroundColor: V3.card,
          body: Column(children: [
            const SizedBox(height: 8),
            const SheetGrab(),
            Row(children: [
              IconButton(
                tooltip: 'Close',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.keyboard_arrow_down,
                    color: V3.muted, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Spacer(),
              IconButton(
                tooltip:
                    _isFav ? 'Remove from favourites' : 'Add to favourites',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
                    color: _isFav ? kHeartRed : V3.muted, size: 26),
                onPressed: _toggle,
              ),
              const SizedBox(width: 6),
            ]),
            Expanded(child: _body(name, g)),
          ]),
        ),
      ),
    );
  }

  Widget _body(String name, Map<String, dynamic>? g) {
    final title = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Text(name, style: V3.tight(22, weight: FontWeight.w700)),
    );
    if (_loading || _error != null) {
      return ListView(children: [
        title,
        if (_loading)
          const FavStateView(loading: true)
        else
          FavStateView(body: _error!),
      ]);
    }
    final game = V3Game(
      gameId: _id,
      name: name,
      setup: '${g!['game_setup'] ?? ''}',
      howToPlay: '${g['game_how_to_play'] ?? ''}',
      variations: '${g['game_variations'] ?? ''}',
      teachingPoints: '${g['game_teaching_points'] ?? ''}',
      image: '${g['game_details_image'] ?? ''}'.trim().isNotEmpty
          ? '${g['game_details_image']}'
          : '${g['game_image'] ?? ''}',
    );
    List<String> strs(dynamic v) =>
        v is List ? [for (final e in v) '$e'] : const [];
    final tags = favTags(
        types: strs(g['game_type']),
        ages: strs(g['game_age']),
        codes: strs(g['game_code']),
        hasVideo: widget.fav.hasVideo);
    return ListView(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      children: [
        title,
        V3GameDetailView(
          game: game,
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          header:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (tags.isNotEmpty) ...[
              _Tags(tags),
              const SizedBox(height: 14),
            ],
            FavButton(
              label: _pdfBusy ? 'Preparing card…' : 'Export Game Card',
              icon: Icons.ios_share,
              primary: false,
              busy: _pdfBusy,
              onPressed: _pdf,
            ),
          ]),
          footer: _notes(),
        ),
      ],
    );
  }

  Widget _notes() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('COACH NOTES',
          style: V3.inter(13,
              weight: FontWeight.w700, color: V3.green, letterSpacing: 1.5)),
      const SizedBox(height: 8),
      Stack(children: [
        TextField(
          controller: _note,
          minLines: 5,
          maxLines: null,
          style: V3.inter(16, height: 1.5),
          cursorColor: V3.green,
          decoration: InputDecoration(
            hintText: widget.ai
                ? 'Type your notes, or tap the mic to say them'
                : 'Add your coaching notes for this game…',
            hintStyle: V3.inter(16, color: V3.muted),
            filled: true,
            fillColor: V3.bg,
            contentPadding:
                EdgeInsets.fromLTRB(14, 12, widget.ai ? 60 : 14, 12),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: V3.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: V3.green)),
          ),
        ),
        if (widget.ai)
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filled(
              tooltip: 'Speak your notes',
              style: IconButton.styleFrom(
                  backgroundColor: V3.green, minimumSize: const Size(44, 44)),
              icon: const Icon(Icons.mic_none, color: Colors.black87),
              onPressed: _voiceNote,
            ),
          ),
      ]),
      const SizedBox(height: 10),
      FavButton(
        label: _saving ? 'Saving…' : 'Save Note',
        primary: false,
        busy: _saving,
        onPressed: _saveNote,
      ),
    ]);
  }
}
