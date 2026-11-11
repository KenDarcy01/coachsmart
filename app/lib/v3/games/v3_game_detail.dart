// A game's detail: [V3GameDetailView] is the body (badges, set-up, the
// diagram, how-to-play steps, variations as "make it harder" lines,
// teaching points, video), reusable anywhere; [V3GameDetailPage] is the full
// page from webviews/games-resource-v2.html (heart, Edit and Delete gates,
// PDF card, My Notes).
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../v3_theme.dart';
import 'v3_game_card.dart';
import 'v3_game_edit_page.dart';
import 'v3_game_models.dart';
import 'v3_games_api.dart';
import 'v3_image_viewer.dart';

/// Opens a video (or any link) in the browser / YouTube app.
Future<bool> openGameVideo(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// The body of a game's detail, without page chrome.
///
/// * [header] goes first (the page puts the PDF button there).
/// * [footer] goes last (the page puts My Notes there).
/// * [variationsLabel]: 'Variations' as the web page and game card PDF say;
///   Session plan may pass 'Make it harder' as its PDF does.
/// * [onOpenImage] taps on the diagram; default opens [V3ImageViewerPage].
class V3GameDetailView extends StatelessWidget {
  const V3GameDetailView({
    super.key,
    required this.game,
    this.header,
    this.footer,
    this.variationsLabel = 'Variations',
    this.onOpenImage,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 32),
    this.shrinkWrap = false,
  });

  final V3Game game;
  final Widget? header;
  final Widget? footer;
  final String variationsLabel;
  final VoidCallback? onOpenImage;
  final EdgeInsets padding;

  /// True when placed inside another scroll view.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final g = game;
    final kc = gameKindColor(g.kind);
    final typeColor = g.kind == GameKind.game ? V3.text : kc;
    final steps = g.steps;
    final ideas = g.harderIdeas;
    final children = <Widget>[
      if (header != null) ...[header!, const SizedBox(height: 16)],
      if (g.codes.isNotEmpty || g.types.isNotEmpty || g.skills.isNotEmpty) ...[
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in g.codes) V3GameTag(s, color: V3.green, size: 14),
          for (final t in g.types) V3GameTag(t, color: typeColor, size: 14),
          for (final s in g.skills) V3GameTag(s, size: 14),
        ]),
        const SizedBox(height: 18),
      ],
      if (g.setup.trim().isNotEmpty)
        _Section('Setup', [
          for (final l in textLines(g.setup)) _Para(l),
        ]),
      if (g.image.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: GestureDetector(
            onTap: onOpenImage ??
                () => Navigator.of(context).push(MaterialPageRoute(
                    settings: const RouteSettings(name: 'V3ImageViewerPage'),
                    builder: (_) => V3ImageViewerPage(
                        imageUrl: g.image.trim(), title: g.name))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: g.image.trim(),
                width: double.infinity,
                fit: BoxFit.fitWidth,
                placeholder: (_, __) => Container(
                    height: 200,
                    color: V3.card2,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(color: V3.green)),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      if (g.howToPlay.trim().isNotEmpty)
        _Section('How to Play', [
          for (final l in steps.intro) _Para(l),
          for (var i = 0; i < steps.steps.length; i++)
            _Step(i + 1, steps.steps[i]),
        ]),
      if (g.variations.trim().isNotEmpty)
        _Section(variationsLabel, [
          for (final idea in ideas.isEmpty ? [g.variations.trim()] : ideas)
            _IconLine(Icons.trending_up, idea, V3.amberText),
        ]),
      if (g.teachingPoints.trim().isNotEmpty)
        _Section('Teaching Points', [
          for (final l in textLines(g.teachingPoints))
            _IconLine(Icons.check_circle_outline, l, V3.green),
        ]),
      if (g.video.trim().isNotEmpty) _Section('Video', [_VideoTile(g.video)]),
      if (footer != null) footer!,
    ];
    return ListView(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      children: children,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.label, this.children);
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: V3.green, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

class _Para extends StatelessWidget {
  const _Para(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: V3.inter(16, height: 1.55)),
      );
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);
  final int n;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: V3.green, shape: BoxShape.circle),
            child: Text('$n',
                style: V3.inter(14, weight: FontWeight.w700, color: V3.bg)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: V3.inter(16, height: 1.5)),
          )),
        ]),
      );
}

class _IconLine extends StatelessWidget {
  const _IconLine(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: V3.inter(16, height: 1.5))),
        ]),
      );
}

class _VideoTile extends StatelessWidget {
  const _VideoTile(this.url);
  final String url;

  @override
  Widget build(BuildContext context) {
    final id = youtubeIdOf(url);
    void open() async {
      final ok = await openGameVideo(url);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Could not open the video',
                style: V3.inter(14, color: V3.bg)),
            backgroundColor: V3.amber));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (id != null)
        GestureDetector(
          onTap: open,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(
                    imageUrl: youtubeThumb(id),
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        const ColoredBox(color: Colors.black)),
                const ColoredBox(color: Color(0x33000000)),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                        color: Color(0xCC000000), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 40),
                  ),
                ),
              ]),
            ),
          ),
        ),
      const SizedBox(height: 10),
      _MediaButton(
          icon: Icons.play_arrow,
          label: id != null ? 'Open in YouTube' : 'Open video',
          onTap: open),
    ]);
  }
}

class _MediaButton extends StatelessWidget {
  const _MediaButton(
      {required this.icon, required this.label, this.onTap, this.busy = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: V3.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: V3.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: V3.green))
                : Icon(icon, color: V3.green, size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: V3.inter(16, weight: FontWeight.w600, color: V3.green)),
          ]),
        ),
      ),
    );
  }
}

/// The full game page.
///
/// * [favourites]: the page's shared favourites (hearts stay in step).
/// * [myClubId]: users.default_club; a club game of this club shows Edit.
/// * [onChanged]: called with the saved game after an edit.
/// * [onDeleted]: called with the id after a delete (the page then pops).
/// * [showNotes]: My Notes (private, game_coach_notes); on by default.
class V3GameDetailPage extends StatefulWidget {
  const V3GameDetailPage({
    super.key,
    required this.game,
    required this.api,
    required this.favourites,
    this.myClubId,
    this.onChanged,
    this.onDeleted,
    this.showNotes = true,
  });

  final V3Game game;
  final V3GamesApi api;
  final V3GameFavourites favourites;
  final int? myClubId;
  final ValueChanged<V3Game>? onChanged;
  final ValueChanged<int>? onDeleted;
  final bool showNotes;

  @override
  State<V3GameDetailPage> createState() => _V3GameDetailPageState();
}

class _V3GameDetailPageState extends State<V3GameDetailPage> {
  late V3Game _g = widget.game;
  bool _pdfBusy = false;

  void _snack(String text, {bool warn = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
        backgroundColor: warn ? V3.amber : V3.green));
  }

  Future<void> _toggleFav() async {
    final msg = await widget.favourites.toggle(_g.gameId);
    _snack(msg, warn: msg.startsWith('Could'));
  }

  Future<void> _pdf() async {
    setState(() => _pdfBusy = true);
    try {
      final (bytes, name) = await widget.api.gameCardPdf(_g.gameId);
      await Printing.sharePdf(bytes: bytes, filename: name, subject: _g.name);
    } catch (_) {
      _snack('Could not generate PDF — please try again', warn: true);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<V3Game>(MaterialPageRoute(
        settings: const RouteSettings(name: 'V3GameEditPage'),
        builder: (_) => V3GameEditPage(game: _g, api: widget.api)));
    if (saved == null || !mounted) return;
    setState(() => _g = saved);
    widget.onChanged?.call(saved);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: V3.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete this game?', style: V3.tight(20)),
        content: Text(deleteGameText(_g),
            style: V3.inter(16, color: V3.muted, height: 1.45)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: V3.inter(16, color: V3.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: V3.inter(16,
                      weight: FontWeight.w700, color: V3.redText))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.api.deleteGame(_g.gameId);
      widget.favourites.forget(_g.gameId);
      widget.onDeleted?.call(_g.gameId);
      _snack('Game deleted');
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      _snack(
          e is V3GamesError ? e.message : 'Could not delete — please try again',
          warn: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _g.canEdit(widget.myClubId);
    final canDelete =
        _g.canDelete(userId: widget.api.userId, email: widget.api.userEmail);
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).maybePop()),
        titleSpacing: 0,
        title:
            Text(_g.name, overflow: TextOverflow.ellipsis, style: V3.tight(17)),
        actions: [
          if (_g.canFavourite)
            ListenableBuilder(
              listenable: widget.favourites,
              builder: (_, __) => V3HeartButton(
                  on: widget.favourites.isFav(_g.gameId),
                  onPressed: _toggleFav),
            ),
          if (canDelete)
            IconButton(
                tooltip: 'Delete game',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.delete_outline, color: V3.redText),
                onPressed: _delete),
          if (canEdit)
            IconButton(
                tooltip: 'Edit game',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: const Icon(Icons.edit_outlined, color: V3.green),
                onPressed: _edit),
          const SizedBox(width: 4),
        ],
      ),
      body: V3GameDetailView(
        game: _g,
        header: Align(
          alignment: Alignment.centerLeft,
          child: _MediaButton(
              icon: Icons.picture_as_pdf_outlined,
              label: _pdfBusy ? 'Generating…' : 'PDF Card',
              busy: _pdfBusy,
              onTap: _pdf),
        ),
        footer: widget.showNotes
            ? V3GameNotes(
                key: ValueKey(_g.gameId), gameId: _g.gameId, api: widget.api)
            : null,
      ),
    );
  }
}

/// My Notes: a private note per game (game_coach_notes). Saves 2 seconds
/// after typing stops, when the box loses focus, or on Save.
class V3GameNotes extends StatefulWidget {
  const V3GameNotes({super.key, required this.gameId, required this.api});
  final int gameId;
  final V3GamesApi api;

  @override
  State<V3GameNotes> createState() => _V3GameNotesState();
}

class _V3GameNotesState extends State<V3GameNotes> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  bool _dirty = false, _saving = false;
  String _hint = '';

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _dirty) _save();
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final n = await widget.api.note(widget.gameId);
      if (!mounted || _dirty) return;
      _ctrl.text = n;
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_dirty) widget.api.saveNote(widget.gameId, _ctrl.text).ignore();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _timer?.cancel();
    setState(() {
      _dirty = true;
      _hint = 'Unsaved changes';
    });
    _timer = Timer(const Duration(seconds: 2), _save);
  }

  Future<void> _save() async {
    _timer?.cancel();
    if (_saving) return;
    setState(() => _saving = true);
    final text = _ctrl.text;
    try {
      await widget.api.saveNote(widget.gameId, text);
      if (!mounted) return;
      setState(() {
        _dirty = _ctrl.text != text;
        _hint = 'Saved';
      });
      Timer(const Duration(milliseconds: 2500), () {
        if (mounted && !_dirty) setState(() => _hint = '');
      });
    } catch (_) {
      if (mounted) setState(() => _hint = 'Could not save');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('MY NOTES',
          style: V3.inter(13,
              weight: FontWeight.w700, color: V3.green, letterSpacing: 1.2)),
      const SizedBox(height: 10),
      TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: _changed,
        minLines: 4,
        maxLines: null,
        style: V3.inter(16, height: 1.45),
        cursorColor: V3.green,
        decoration: InputDecoration(
          hintText: 'Add your private coaching notes for this drill…',
          hintStyle: V3.inter(16, color: V3.muted),
          filled: true,
          fillColor: V3.card,
          contentPadding: const EdgeInsets.all(14),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: V3.line)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: V3.green)),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(_hint, style: V3.inter(14, color: V3.muted))),
        SizedBox(
          height: 44,
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: V3.green,
                foregroundColor: V3.bg,
                disabledBackgroundColor: V3.greenTint,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: _saving ? null : _save,
            child: Text('Save',
                style: V3.inter(16, weight: FontWeight.w700, color: V3.bg)),
          ),
        ),
      ]),
    ]);
  }
}
