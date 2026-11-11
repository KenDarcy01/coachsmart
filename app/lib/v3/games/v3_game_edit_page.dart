// Edit a club game (Edit Game in webviews/games-resource-v2.html): name,
// sport, type, set-up, how to play, variations, teaching points, video and
// the picture (keep, remove, or replace with a sketch). Saved through the
// ai-process-game edge function (action update_game). Pops with the saved
// [V3Game], or null when left without saving.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../v3_theme.dart';
import 'v3_drill_diagram.dart';
import 'v3_game_models.dart';
import 'v3_games_api.dart';

/// Sport choices on the edit form (several allowed).
const List<String> kEditSports = ['Football', 'Hurling', 'Camogie'];

/// Type choices on the edit form (one at a time).
const List<String> kEditTypes = ['Game', 'Warmup', 'Drill', 'Skills', 'Video'];

enum _Pic { current, none, sketch }

class V3GameEditPage extends StatefulWidget {
  const V3GameEditPage({super.key, required this.game, required this.api});
  final V3Game game;
  final V3GamesApi api;

  @override
  State<V3GameEditPage> createState() => _V3GameEditPageState();
}

class _V3GameEditPageState extends State<V3GameEditPage> {
  late final _name = TextEditingController(text: widget.game.name);
  late final _setup = TextEditingController(text: widget.game.setup);
  late final _how = TextEditingController(text: widget.game.howToPlay);
  late final _vars = TextEditingController(text: widget.game.variations);
  late final _tps = TextEditingController(text: widget.game.teachingPoints);
  late final _video = TextEditingController(text: widget.game.video);
  late final Set<String> _sports = {
    for (final s in kEditSports)
      if (widget.game.codes.any((c) => c.toLowerCase() == s.toLowerCase())) s
  };
  late final Set<String> _types = {
    for (final t in kEditTypes)
      if (widget.game.types.any((c) => c.toLowerCase() == t.toLowerCase())) t
  };
  late final bool _hadImage = widget.game.image.trim().isNotEmpty;
  late _Pic _pic = _hadImage ? _Pic.current : _Pic.none;
  bool _removed = false;
  bool _sketchReplacing = false;
  final _sketch = DrillSketchController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _setup, _how, _vars, _tps, _video]) {
      c.dispose();
    }
    _sketch.dispose();
    super.dispose();
  }

  Future<void> _showSketch(bool replacing) async {
    setState(() {
      _sketch.clear();
      _sketchReplacing = replacing;
      _pic = _Pic.sketch;
    });
    if (replacing && _hadImage && !_removed) {
      final img = await loadDrillBackground(widget.game.image.trim());
      if (img != null && mounted && _pic == _Pic.sketch)
        _sketch.background = img;
    }
  }

  void _hideSketch() => setState(() {
        _sketch.clear();
        _pic = (_hadImage && !_removed) ? _Pic.current : _Pic.none;
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final png = _pic == _Pic.sketch && _sketch.hasContent
          ? await renderDrillSketchPng(_sketch.sketch)
          : null;
      final edit = GameEdit(
        name: _name.text.trim(),
        codes: [
          for (final s in kEditSports)
            if (_sports.contains(s)) s
        ],
        types: [
          for (final t in kEditTypes)
            if (_types.contains(t)) t
        ],
        setup: _setup.text.trim(),
        howToPlay: _how.text.trim(),
        variations: _vars.text.trim(),
        teachingPoints: _tps.text.trim(),
        video: _video.text.trim(),
        imagePng: png,
        removeImage: png == null && _removed,
      );
      final saved = await widget.api.updateGame(widget.game, edit);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving: $e', style: V3.inter(14, color: V3.bg)),
          backgroundColor: V3.amber));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t,
            style: V3.inter(15, weight: FontWeight.w600, color: V3.muted)),
      );

  Widget _field(TextEditingController c, String hint,
      {int minLines = 1, bool multi = false, TextInputType? type}) {
    return TextField(
      controller: c,
      minLines: minLines,
      maxLines: multi ? null : 1,
      keyboardType: type ?? (multi ? TextInputType.multiline : null),
      style: V3.inter(16, height: 1.45),
      cursorColor: V3.green,
      decoration: InputDecoration(
        hintText: hint,
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
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => _EditChip(
        label: label,
        on: on,
        onTap: onTap,
      );

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
        title: Text('Edit Game', style: V3.tight(17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save',
                  style: V3.inter(17,
                      weight: FontWeight.w700,
                      color: _saving ? V3.muted : V3.green)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          _label('Name'),
          _field(_name, 'Game name'),
          _label('Sport'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in kEditSports)
              _chip(s, _sports.contains(s), () {
                setState(() =>
                    _sports.contains(s) ? _sports.remove(s) : _sports.add(s));
              }),
          ]),
          _label('Type'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in kEditTypes)
              _chip(t, _types.contains(t), () {
                setState(() {
                  final was = _types.contains(t);
                  _types.clear();
                  if (!was) _types.add(t);
                });
              }),
          ]),
          _label('Setup'),
          _field(_setup, 'Setup instructions…', minLines: 4, multi: true),
          _label('How to Play'),
          _field(_how, 'Step-by-step instructions…', minLines: 5, multi: true),
          _label('Variations'),
          _field(_vars, 'Progressions…', minLines: 3, multi: true),
          _label('Teaching Points'),
          _field(_tps, 'Coaching cues…', minLines: 3, multi: true),
          _label('Video URL'),
          _field(_video, 'https://youtube.com/…', type: TextInputType.url),
          _label('Image / Sketch'),
          if (_pic == _Pic.current) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: widget.game.image.trim(),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    Container(height: 120, color: V3.card2),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(
                  'Remove Image',
                  false,
                  () => setState(() {
                        _removed = true;
                        _pic = _Pic.none;
                      })),
              _chip('Replace with Sketch', false, () => _showSketch(true)),
            ]),
          ],
          if (_pic == _Pic.none)
            Align(
                alignment: Alignment.centerLeft,
                child: _chip('Add Sketch', false, () => _showSketch(false))),
          if (_pic == _Pic.sketch) ...[
            DrillSketchPad(controller: _sketch),
            if (_sketchReplacing) ...[
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: _chip('Cancel', false, _hideSketch)),
            ],
          ],
        ],
      ),
    );
  }
}

class _EditChip extends StatelessWidget {
  const _EditChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? V3.greenTint : V3.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: on ? V3.green : V3.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(label,
                  style: V3.inter(15,
                      weight: FontWeight.w600, color: on ? V3.green : V3.text)),
            ),
          ),
        ),
      ),
    );
  }
}
