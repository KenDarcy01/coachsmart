// v3 Add Game / Drill: a native copy of webviews/game-upload.html (the page
// the ResourcesAdd route shows in a web view). Add a game from a photo, a
// sketch or (AI users) a written or spoken description; the AI drafts the
// fields (ai-process-game) and draws a clean diagram (diagram-to-drawio,
// drawn here by the CSScene port in v3_scene.dart); the coach checks the
// draft, can fix the drawing or revise the text by voice, and saves.
//
// Coaches without AI features type the details, add a photo or sketch and
// save. "Import from a document" stays hidden (Ken, 2026-11-10: needs
// refinement, too expensive), so it is not built here.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../games/v3_games.dart';
import '../games/v3_scene.dart';
import '../match_report/v3_voice_sheet.dart';
import '../v3_theme.dart';
import 'v3_game_upload_models.dart';
import 'v3_game_upload_services.dart';

enum _Stage { create, processing, review }

/// A drawing the AI made, kept so "Fix the drawing" can send it back.
class _Diag {
  _Diag({required this.scene, this.img, this.notes = '', this.drawing});
  Map<String, dynamic> scene;
  final GuImage? img;
  final String notes;
  final String? drawing;
}

/// One diagram-to-drawio round (the page's standardiseDiagram).
class _Std {
  const _Std(
      {this.image,
      this.gameName,
      this.codes = const [],
      this.scene,
      this.error});
  final GuImage? image;
  final String? gameName;
  final List<String> codes;
  final Map<String, dynamic>? scene;
  final String? error;
}

class V3GameUploadPage extends StatefulWidget {
  const V3GameUploadPage(
      {super.key, this.services, this.testAiEnabled, this.testDictation});

  /// Tests pass a fake; the app uses the real edge functions.
  @visibleForTesting
  final V3GameUploadServices? services;

  /// Tests set the AI flag instead of asking Supabase.
  @visibleForTesting
  final bool? testAiEnabled;

  /// Tests pass a fake recogniser to the voice panel.
  @visibleForTesting
  final V3Dictation? testDictation;

  @override
  State<V3GameUploadPage> createState() => _V3GameUploadPageState();
}

class _V3GameUploadPageState extends State<V3GameUploadPage> {
  late final V3GameUploadServices _svc =
      widget.services ?? const V3GameUploadServices();

  bool _ai = false;
  _Stage _stage = _Stage.create;

  // Create.
  GuMedia _tab = GuMedia.photo;
  final List<GuPhoto> _photos = [];
  final DrillSketchController _sketch = DrillSketchController();
  final TextEditingController _desc = TextEditingController();
  bool _picking = false;

  // Processing.
  String _procTitle = 'Creating your draft…';
  String _procStatus = 'Reading your diagram…';
  int _elapsed = 0;
  Timer? _timer;

  // Review.
  GuImage? _reviewImage;
  _Diag? _diag;
  final List<({Map<String, dynamic> scene, GuImage? image})> _diagUndo = [];
  String _tidied = '';
  String? _type;
  List<String> _ages = [], _codes = [], _skills = [];
  final _video = TextEditingController();
  final _name = TextEditingController();
  final _setup = TextEditingController();
  final _howTo = TextEditingController();
  final _variations = TextEditingController();
  final _teaching = TextEditingController();
  final _nameFocus = FocusNode();
  bool _saving = false, _saved = false;
  int _reviewRound = 0;

  ValueNotifier<V3SheetNote?>? _sheetNote;

  @override
  void initState() {
    super.initState();
    _desc.addListener(() => setState(() {}));
    _sketch.addListener(() => setState(() {}));
    _loadAi();
  }

  Future<void> _loadAi() async {
    final on = widget.testAiEnabled ?? await _svc.aiEnabled();
    if (mounted && on) setState(() => _ai = true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wake(false);
    _sketch.dispose();
    for (final c in [
      _desc,
      _video,
      _name,
      _setup,
      _howTo,
      _variations,
      _teaching
    ]) {
      c.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- helpers

  void _wake(bool on) {
    try {
      WakelockPlus.toggle(enable: on).catchError((_) {});
    } catch (_) {}
  }

  void _say(String text, {bool error = false, int ms = 2800}) {
    if (!mounted) return;
    final note = _sheetNote;
    if (note != null) {
      note.value = V3SheetNote(text, error: error);
      return;
    }
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(
        duration: Duration(milliseconds: ms),
        content: Text(text,
            textAlign: TextAlign.center, style: V3.inter(15, color: V3.bg)),
        backgroundColor: error ? V3.amber : V3.green));
  }

  void _toStage(_Stage s) {
    _timer?.cancel();
    _timer = null;
    if (s == _Stage.processing) {
      _elapsed = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed++);
      });
    }
    setState(() => _stage = s);
  }

  void _status(String title, String sub) => setState(() {
        _procTitle = title;
        _procStatus = sub;
      });

  bool get _drawn => _sketch.hasContent;

  bool get _canCreate => guCanCreate(
      tab: _tab,
      photos: _photos.length,
      drawn: _drawn,
      ai: _ai,
      words: _desc.text);

  // --------------------------------------------------------------- photos

  Future<void> _addPhotos() async {
    if (_picking || _photos.length >= kGuMaxPhotos) return;
    FocusScope.of(context).unfocus();
    final camera = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _SheetRow(
                icon: Icons.photo_camera_outlined,
                label: 'Take a photo',
                onTap: () => Navigator.pop(ctx, true)),
            _SheetRow(
                icon: Icons.photo_library_outlined,
                label: 'Choose from library',
                onTap: () => Navigator.pop(ctx, false)),
          ]),
        ),
      ),
    );
    if (camera == null || !mounted) return;
    setState(() => _picking = true);
    try {
      final got = await _svc.pickPhotos(
          camera: camera, max: kGuMaxPhotos - _photos.length);
      if (!mounted) return;
      setState(() => _photos.addAll(got));
    } catch (_) {
      _say('Could not add that photo. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // ---------------------------------------------------------------- voice

  Future<void> _voice({
    required String title,
    required String subtitle,
    required String placeholder,
    String text = '',
    required String submitLabel,
    String? busyLabel,
    required Future<bool> Function(String) onSubmit,
  }) async {
    if (_sheetNote != null) return;
    FocusScope.of(context).unfocus();
    final note = _sheetNote = ValueNotifier<V3SheetNote?>(null);
    await showV3VoiceSheet(context,
        title: title,
        subtitle: subtitle,
        placeholder: placeholder,
        text: text,
        submitLabel: submitLabel,
        busyLabel: busyLabel,
        onSubmit: onSubmit,
        onError: (m) => _say(m, error: true),
        note: note,
        dictation: widget.testDictation);
    _sheetNote = null;
    final last = note.value;
    note.dispose();
    if (last != null && mounted) _say(last.text, error: last.error);
  }

  void _openDescVoice() => _voice(
        title: 'Describe the drill',
        subtitle:
            'Setup, how to play, variations, coaching points. AI will also read any text in your image.',
        placeholder: 'e.g. 4 v 2 in a 20m square, keep the ball for 5 passes…',
        text: _desc.text,
        submitLabel: 'Done',
        onSubmit: (t) async {
          _desc.text = t;
          return true;
        },
      );

  void _openFbVoice() => _voice(
        title: 'Revise the draft',
        subtitle: 'Say or type what you would like changed.',
        placeholder: guRevisePlaceholder(_codes),
        submitLabel: 'Revise',
        busyLabel: 'Revising…',
        onSubmit: _revise,
      );

  void _openDiagramFix() {
    if (_diag == null) return;
    _voice(
      title: 'Fix the drawing',
      subtitle: 'Say or type what is wrong. Only that changes.',
      placeholder:
          "e.g. there's no line down the middle, that's a shadow. Add a cone beside player 3.",
      submitLabel: 'Update',
      busyLabel: 'Redrawing…',
      onSubmit: _fixDrawing,
    );
  }

  // ------------------------------------------------------------- diagram

  Future<Uint8List> _draw(GuDiagramAnswer a, GuImage? from, double dpr) {
    final size = from == null ? null : sceneImageSize(from.bytes);
    final d = diagramFromAnswer(
        xml: a.xml,
        scene: a.scene,
        imgW: size?.w ?? 1000,
        imgH: size?.h ?? 1000);
    if (d == null) throw const GuError('no diagram returned');
    return _svc.diagramPng(d, dpr);
  }

  /// The page's standardiseDiagram: [img] is the picture (null when drawn
  /// from words), [fix] a change to an earlier drawing.
  Future<_Std> _standardise(GuImage? img,
      {GuFix? fix, String notes = '', String? drawing}) async {
    final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 3.0);
    try {
      final a = GuDiagramAnswer.fromJson(await _svc.diagram(
          guDiagramBody(image: img, fix: fix, notes: notes, drawing: drawing)));
      if (!a.ok) return _Std(error: a.error);
      var png = await _draw(a, img, dpr);
      var scene = a.scene;
      final words = (fix?.drawing?.isNotEmpty == true ? fix!.drawing : null) ??
          drawing ??
          '';
      // Drawn from words: the AI looks at its own drawing once and corrects
      // it (one look: more cost too much, Ken 2026-11-03).
      if (img == null && fix == null && words.isNotEmpty && scene != null) {
        try {
          final b = GuDiagramAnswer.fromJson(await _svc.diagram(guCheckBody(
              drawing: words,
              notes: notes,
              scene: scene,
              pngBase64: base64Encode(png))));
          if (b.xml != null && b.scene != null) {
            png = await _draw(b, null, dpr);
            scene = b.scene;
          }
        } catch (_) {/* keep the drawing so far */}
      }
      return _Std(
          image: GuImage(png, 'image/png'),
          gameName: a.gameName,
          codes: a.codes,
          scene: scene);
    } catch (e) {
      return _Std(error: '$e');
    }
  }

  Future<bool> _fixDrawing(String text) async {
    final d = _diag;
    if (d == null || text.trim().isEmpty) return false;
    final r = await _standardise(d.img,
        fix: GuFix(
            scene: d.scene,
            instruction: text,
            notes: d.notes,
            drawing: d.drawing));
    if (!mounted) return false;
    if (r.error != null || r.scene == null || r.image == null) {
      _say('Could not redraw it — please try again', error: true);
      return false;
    }
    setState(() {
      _diagUndo.add((scene: d.scene, image: _reviewImage));
      d.scene = r.scene!;
      _reviewImage = r.image;
      _tidied = guTidied(r.scene);
    });
    _say('Drawing updated');
    return true;
  }

  void _undoFix() {
    final d = _diag;
    if (_diagUndo.isEmpty || d == null) return;
    final prev = _diagUndo.removeLast();
    setState(() {
      d.scene = prev.scene;
      _reviewImage = prev.image;
      _tidied = guTidied(prev.scene);
    });
  }

  // --------------------------------------------------------------- create

  Future<void> _createDraft() async {
    FocusScope.of(context).unfocus();
    final words = _desc.text.trim();
    final fromWords = guFromWords(
        tab: _tab,
        photos: _photos.length,
        drawn: _drawn,
        ai: _ai,
        words: words);
    GuImage? source, diagramImg;
    if (!fromWords) {
      final missing = guMissingSource(
          tab: _tab, photos: _photos.length, drawn: _drawn, ai: _ai);
      if (missing != null) {
        _say(missing, error: true);
        return;
      }
      if (_tab == GuMedia.sketch) {
        source = GuImage(await _svc.sketchPng(_sketch.sketch), 'image/png');
      } else {
        source = _photos.first.form;
        diagramImg = _photos.first.hires;
      }
    }
    if (!mounted) return;

    // Without AI: straight to the form with what was typed.
    if (!_ai) {
      _reviewImage = source;
      _diag = null;
      _tidied = '';
      _showReview(GuDraft(howTo: words));
      return;
    }

    _status(
        'Creating your draft…',
        fromWords
            ? 'Drawing it from your description…'
            : 'Reading your diagram…');
    _toStage(_Stage.processing);
    _wake(true);

    final images = <GuImage>[
      if (source != null) source,
      if (source != null && _tab == GuMedia.photo)
        for (final p in _photos.skip(1)) p.form,
    ];
    Map<String, dynamic>? ai;
    _Std? std;
    Object? aiErr;
    final aiF = _svc.aiProcessGame(guSplitVoiceBody(words, images)).then((r) {
      ai = guUnwrapAi(r);
      if (mounted) {
        _status('Creating your draft…',
            std == null ? 'Standardising diagram…' : 'Almost done…');
      }
    }).catchError((Object e) {
      aiErr = e;
    });
    final stdF = (fromWords
            ? _standardise(null, drawing: words)
            : _standardise(diagramImg ?? source, notes: words))
        .then((r) {
      std = r;
      if (mounted) {
        _status('Creating your draft…',
            ai == null ? 'Reading your diagram…' : 'Almost done…');
      }
    });
    await Future.wait([aiF, stdF]);
    _wake(false);
    if (!mounted) return;
    if (aiErr != null || ai == null) {
      _toStage(_Stage.create);
      _say('Error: ${aiErr ?? 'AI failed'}', error: true);
      return;
    }
    final s = std;
    final drewIt = s != null && s.error == null && s.image != null;
    _reviewImage = drewIt ? s.image : source;
    _diag = drewIt && s.scene != null
        ? (fromWords
            ? _Diag(scene: s.scene!, drawing: words)
            : _Diag(scene: s.scene!, img: diagramImg ?? source, notes: words))
        : null;
    if (fromWords && _reviewImage == null) {
      _say(
          "Couldn't draw it this time. Go back and try again, or save it without a picture.",
          error: true,
          ms: 4000);
    }
    _tidied = _diag != null ? guTidied(_diag!.scene) : '';
    _diagUndo.clear();

    final draft = GuDraft.fromJson(ai!);
    _type = guMatchType(draft.type) ?? _type;
    _ages = guPreselect(kGuAges, _ages, draft.ages);
    _codes = guPreselect(
        kGuCodes, _codes, guDraftCodes(s?.codes ?? const [], draft.sport));
    _skills = guPreselect(kGuSkills, _skills, draft.skills);
    _showReview(draft);
    // A clear written title on the diagram beats the AI's guess.
    if (s?.gameName != null) _name.text = s!.gameName!;
  }

  void _showReview(GuDraft d) {
    _reviewRound++;
    _saved = false;
    _name.text = d.name;
    _setup.text = d.setup;
    _howTo.text = d.howTo;
    _variations.text = d.variations;
    _teaching.text = d.teaching;
    _toStage(_Stage.review);
  }

  // --------------------------------------------------------------- revise

  Future<bool> _revise(String feedback) async {
    feedback = feedback.trim();
    if (feedback.isEmpty) return false;
    try {
      final d = GuDraft.fromJson(guUnwrapAi(await _svc.aiProcessGame(
          guReviseBody(
              name: _name.text,
              setup: _setup.text,
              howTo: _howTo.text,
              variations: _variations.text,
              teaching: _teaching.text,
              feedback: feedback))));
      if (!mounted) return false;
      setState(() {
        _name.text = d.name;
        _setup.text = d.setup;
        _howTo.text = d.howTo;
        _variations.text = d.variations;
        _teaching.text = d.teaching;
      });
      _say('Draft revised ✓');
      return true;
    } catch (_) {
      _say('Revision failed — please try again', error: true);
      return false;
    }
  }

  // ----------------------------------------------------------------- save

  Future<void> _save() async {
    if (_saving) return;
    if (_saved) {
      _say('This game is already saved');
      return;
    }
    final problem = guSaveProblem(name: _name.text, type: _type, codes: _codes);
    if (problem != null) {
      _say(problem, error: true);
      if (_name.text.trim().isEmpty) _nameFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    final visible = guVisibleSkills(_codes);
    setState(() => _saving = true);
    try {
      final r = await _svc.aiProcessGame(guSaveBody(
          name: _name.text,
          type: _type!,
          ages: _ages,
          codes: _codes,
          skills: [
            for (final s in _skills)
              if (visible.contains(s)) s
          ],
          setup: _setup.text,
          howTo: _howTo.text,
          variations: _variations.text,
          teaching: _teaching.text,
          video: _video.text,
          image: _reviewImage));
      if (r['success'] != true) throw GuError('${r['error'] ?? 'Save failed'}');
      if (!mounted) return;
      setState(() => _saved = true);
      _say('Game saved!');
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).maybePop(true);
    } catch (e) {
      _say('Error saving: ${e is GuError ? e.message : 'please try again'}',
          error: true, ms: 4000);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stage != _Stage.review,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stage == _Stage.review) _toStage(_Stage.create);
      },
      child: Scaffold(
        backgroundColor: V3.bg,
        appBar: _stage == _Stage.processing
            ? null
            : AppBar(
                backgroundColor: V3.bg,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: true,
                leading: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.chevron_left,
                        color: V3.green, size: 40),
                    onPressed: () => _stage == _Stage.review
                        ? _toStage(_Stage.create)
                        : Navigator.of(context).maybePop()),
                title: Text(
                    _stage == _Stage.review
                        ? 'Review & Edit'
                        : 'Add Game / Drill',
                    style: V3.tight(18, weight: FontWeight.w600)),
              ),
        body: switch (_stage) {
          _Stage.create => _buildCreate(),
          _Stage.processing => _buildProcessing(),
          _Stage.review => _buildReview(),
        },
        // In the bottom bar so messages show above the button.
        bottomNavigationBar: switch (_stage) {
          _Stage.create => _footer(_PrimaryButton(
              label: _ai ? 'Create Draft' : 'Continue',
              icon: Icons.layers_outlined,
              onTap: _canCreate ? _createDraft : null)),
          _Stage.processing => null,
          _Stage.review => _footer(_PrimaryButton(
              label: _saved
                  ? 'Saved ✓'
                  : _saving
                      ? 'Saving…'
                      : 'Save',
              icon: Icons.save_outlined,
              busy: _saving,
              onTap: _saved || _saving ? null : _save)),
        },
      ),
    );
  }

  Widget _footer(Widget button) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
              color: V3.bg, border: Border(top: BorderSide(color: V3.line))),
          child: button,
        ),
      );

  Widget _buildCreate() {
    return ListView(
      key: const PageStorageKey('v3-game-create'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(children: [
          Expanded(
            child: _Label('Diagram / Sketch',
                required: !_ai, optional: _ai ? '(optional)' : null),
          ),
          if (_ai)
            _SmallButton(
                icon: Icons.info_outline,
                label: 'How to draw',
                onTap: () => _showDrawingHelp(context)),
        ]),
        const SizedBox(height: 10),
        _Tabs(
            value: _tab,
            onChanged: (t) {
              FocusScope.of(context).unfocus();
              setState(() => _tab = t);
            }),
        const SizedBox(height: 12),
        if (_tab == GuMedia.photo)
          _photoPanel()
        else
          DrillSketchPad(controller: _sketch),
        const SizedBox(height: 22),
        _Label('Description',
            optional: _ai ? '(or use this instead)' : '(optional)'),
        const SizedBox(height: 10),
        Stack(children: [
          _Field(
              controller: _desc,
              hint:
                  'Describe the drill — setup, how to play, variations, coaching points…',
              minLines: 4,
              rightPad: _ai ? 60 : 14),
          if (_ai)
            Positioned(
              right: 6,
              top: 6,
              child: IconButton(
                tooltip: 'Speak instead',
                iconSize: 26,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                style: IconButton.styleFrom(
                    backgroundColor: V3.greenTint, shape: const CircleBorder()),
                icon: const Icon(Icons.mic_none, color: V3.green),
                onPressed: _openDescVoice,
              ),
            ),
        ]),
        if (_ai) ...[
          const SizedBox(height: 8),
          Text(
              "No sketch or photo? Just describe the drill, or tap the mic and say it: where the players and cones are and who runs or passes where. We'll draw it for you.",
              style: V3.inter(15, color: V3.muted, height: 1.45)),
        ],
      ],
    );
  }

  Widget _photoPanel() {
    if (_photos.isEmpty) {
      return Material(
        color: V3.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _addPhotos,
          child: Container(
            height: 190,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: V3.line, width: 1.5)),
            child: Center(
              child: _picking
                  ? const CircularProgressIndicator(color: V3.green)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: V3.muted, size: 44),
                      const SizedBox(height: 10),
                      Text('Tap to add photo',
                          style: V3.inter(17, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('Diagrams, whiteboard, handwritten notes',
                          style: V3.inter(15, color: V3.muted)),
                    ]),
            ),
          ),
        ),
      );
    }
    Widget remove(int i) => Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            tooltip: 'Remove photo',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.6)),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => setState(() => _photos.removeAt(i)),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
                color: V3.card,
                child: Image.memory(_photos.first.form.bytes,
                    fit: BoxFit.contain, gaplessPlayback: true)),
          ),
        ),
        remove(0),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 1; i < _photos.length; i++)
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      Image.memory(_photos[i].form.bytes, fit: BoxFit.cover)),
              remove(i),
            ]),
          ),
        if (_photos.length < kGuMaxPhotos)
          SizedBox(
            width: 84,
            height: 84,
            child: Material(
              color: V3.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: V3.line, width: 1.5)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _addPhotos,
                child: Center(
                    child: _picking
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: V3.green))
                        : const Icon(Icons.add, color: V3.muted, size: 32)),
              ),
            ),
          ),
      ]),
    ]);
  }

  Widget _buildProcessing() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(
                width: 56,
                height: 56,
                child:
                    CircularProgressIndicator(strokeWidth: 4, color: V3.green)),
            const SizedBox(height: 26),
            Text(_procTitle,
                textAlign: TextAlign.center,
                style: V3.tight(22, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(_procStatus,
                textAlign: TextAlign.center,
                style: V3.inter(17, color: V3.muted)),
            const SizedBox(height: 14),
            Text(guElapsed(_elapsed),
                textAlign: TextAlign.center,
                style: V3.inter(15, color: V3.muted)),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: V3.amberTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: V3.amberLine)),
              child: Text('This takes 60–90 seconds — keep this screen open',
                  textAlign: TextAlign.center,
                  style: V3.inter(15,
                      weight: FontWeight.w600, color: V3.amberText)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildReview() {
    final img = _reviewImage;
    final showFix = _ai && _diag != null;
    final skills = guVisibleSkills(_codes);
    return ListView(
      // A new list, so each draft opens at the top.
      key: ValueKey('v3-game-review-$_reviewRound'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (img != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: V3.card,
              child: Image.memory(img.bytes,
                  key: const ValueKey('v3-game-diagram'),
                  fit: BoxFit.contain,
                  gaplessPlayback: true),
            ),
          ),
        if (showFix) ...[
          const SizedBox(height: 10),
          if (_tidied.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Text(_tidied,
                  style: V3.inter(15, color: V3.muted, height: 1.4)),
            ),
          _VoiceRest(
              label: 'Fix the drawing',
              placeholder: 'e.g. that line is a shadow, remove it…',
              onTap: _openDiagramFix),
          if (_diagUndo.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _undoFix,
                style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44), foregroundColor: V3.muted),
                child: Text('Undo last fix',
                    style: V3
                        .inter(15, color: V3.muted, weight: FontWeight.w500)
                        .copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: V3.muted)),
              ),
            ),
        ],
        const SizedBox(height: 20),
        const _Label('Type', required: true),
        const SizedBox(height: 10),
        _Chips(
            options: kGuTypes,
            selected: [if (_type != null) _type!],
            onTap: (o) => setState(() => _type = _type == o ? null : o)),
        const SizedBox(height: 20),
        const _Label('Age Group'),
        const SizedBox(height: 10),
        _Chips(
            options: kGuAges,
            selected: _ages,
            onTap: (o) => setState(() => _ages = _toggle(_ages, o, kGuAges))),
        const SizedBox(height: 20),
        const _Label('Code', required: true),
        const SizedBox(height: 10),
        _Chips(
            options: kGuCodes,
            selected: _codes,
            onTap: (o) =>
                setState(() => _codes = _toggle(_codes, o, kGuCodes))),
        const SizedBox(height: 20),
        const _Label('Skills', optional: '(optional)'),
        const SizedBox(height: 10),
        _Chips(
            options: skills,
            selected: _skills,
            onTap: (o) =>
                setState(() => _skills = _toggle(_skills, o, kGuSkills))),
        const SizedBox(height: 20),
        const _Label('Video Link', optional: '(optional)'),
        const SizedBox(height: 10),
        _Field(
            controller: _video,
            hint: 'https://youtube.com/watch?v=…',
            keyboard: TextInputType.url),
        const SizedBox(height: 20),
        const _Label('Game Name', required: true),
        const SizedBox(height: 10),
        _Field(
            controller: _name,
            hint: 'Game name…',
            focusNode: _nameFocus,
            fieldKey: const ValueKey('v3-game-name')),
        for (final (label, c, hint) in [
          ('Setup', _setup, 'Setup instructions…'),
          ('How to Play', _howTo, 'Step-by-step instructions…'),
          ('Variations', _variations, 'Progressions and variations…'),
          ('Teaching Points', _teaching, 'Key coaching cues…'),
        ]) ...[
          const SizedBox(height: 20),
          _Label(label),
          const SizedBox(height: 10),
          _Field(controller: c, hint: hint, minLines: 3),
        ],
        if (_ai) ...[
          const SizedBox(height: 24),
          _VoiceRest(
              label: 'Revise with feedback',
              placeholder: 'Tell me what to change…',
              onTap: _openFbVoice),
        ],
      ],
    );
  }

  static List<String> _toggle(List<String> cur, String o, List<String> order) {
    final next = cur.contains(o) ? (cur.toList()..remove(o)) : [...cur, o];
    return [
      for (final x in order)
        if (next.contains(x)) x
    ];
  }
}

// ------------------------------------------------------------------ parts

class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false, this.optional});
  final String text;
  final bool required;
  final String? optional;

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(text: text, style: V3.inter(16, weight: FontWeight.w600)),
        if (required)
          TextSpan(text: ' *', style: V3.inter(16, color: V3.redText)),
        if (optional != null)
          TextSpan(text: ' $optional', style: V3.inter(15, color: V3.muted)),
      ]));
}

class _Field extends StatelessWidget {
  const _Field(
      {required this.controller,
      required this.hint,
      this.minLines = 1,
      this.rightPad = 14,
      this.keyboard,
      this.focusNode,
      this.fieldKey});
  final TextEditingController controller;
  final String hint;
  final int minLines;
  final double rightPad;
  final TextInputType? keyboard;
  final FocusNode? focusNode;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final multi = minLines > 1;
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: multi ? null : 1,
      keyboardType: keyboard ?? (multi ? TextInputType.multiline : null),
      textCapitalization:
          multi ? TextCapitalization.sentences : TextCapitalization.none,
      style: V3.inter(17, height: 1.4),
      cursorColor: V3.green,
      decoration: InputDecoration(
        hintText: hint,
        hintMaxLines: 3,
        hintStyle: V3.inter(17, color: V3.muted.withValues(alpha: 0.7)),
        filled: true,
        fillColor: V3.card,
        contentPadding: EdgeInsets.fromLTRB(14, 14, rightPad, 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: V3.line, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: V3.green, width: 1.5)),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips(
      {required this.options, required this.selected, required this.onTap});
  final List<String> options;
  final List<String> selected;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in options)
            Builder(builder: (_) {
              final on = selected.contains(o);
              return Material(
                color: on ? V3.greenTint : V3.card,
                shape: StadiumBorder(
                    side:
                        BorderSide(color: on ? V3.green : V3.line, width: 1.5)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onTap(o),
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: 44, minWidth: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        widthFactor: 1,
                        child: Text(o,
                            style: V3.inter(16,
                                weight: FontWeight.w600,
                                color: on ? V3.green : V3.text)),
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.value, required this.onChanged});
  final GuMedia value;
  final void Function(GuMedia) onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(GuMedia m, IconData icon, String label) {
      final on = value == m;
      return Expanded(
        child: Material(
          color: on ? V3.greenTint : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => onChanged(m),
            child: SizedBox(
              height: 46,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 20, color: on ? V3.green : V3.muted),
                const SizedBox(width: 8),
                Text(label,
                    style: V3.inter(16,
                        weight: FontWeight.w600,
                        color: on ? V3.green : V3.muted)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: V3.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: V3.line)),
      child: Row(children: [
        tab(GuMedia.photo, Icons.photo_camera_outlined, 'Photo'),
        const SizedBox(width: 4),
        tab(GuMedia.sketch, Icons.edit_outlined, 'Sketch'),
      ]),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(
      {required this.label, required this.icon, this.onTap, this.busy = false});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        width: double.infinity,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
              backgroundColor: V3.green,
              foregroundColor: V3.bg,
              disabledBackgroundColor: V3.green.withValues(alpha: 0.35),
              disabledForegroundColor: V3.bg.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (busy)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2.5, color: V3.bg))
            else
              Icon(icon, size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: V3.inter(17, weight: FontWeight.w700, color: V3.bg)),
          ]),
        ),
      );
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: V3.line, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18, color: V3.muted),
                const SizedBox(width: 6),
                Text(label,
                    style:
                        V3.inter(15, weight: FontWeight.w600, color: V3.muted)),
              ]),
            ),
          ),
        ),
      );
}

/// The resting box that opens the voice panel (cs-voice-sheet restHtml).
class _VoiceRest extends StatelessWidget {
  const _VoiceRest(
      {required this.label, required this.placeholder, required this.onTap});
  final String label, placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: V3.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: V3.line, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: V3.inter(16, weight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(placeholder, style: V3.inter(15, color: V3.muted)),
                    ]),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: V3.greenTint, shape: BoxShape.circle),
                child: const Icon(Icons.mic_none, color: V3.green, size: 26),
              ),
            ]),
          ),
        ),
      );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Row(children: [
            Icon(icon, color: V3.green, size: 26),
            const SizedBox(width: 14),
            Text(label, style: V3.inter(17, weight: FontWeight.w600)),
          ]),
        ),
      );
}

// ------------------------------------------------------------ drawing help

enum _Ico { players, coach, ball, cone, goal, wall, run, pass, pitchLine, arc }

void _showDrawingHelp(BuildContext context) {
  Widget section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
        child: Text(t.toUpperCase(),
            style: V3.inter(14,
                weight: FontWeight.w700, color: V3.muted, letterSpacing: 1.1)),
      );
  Widget row(_Ico icon, String title, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 64,
              height: 40,
              child: CustomPaint(painter: _HelpIcon(icon))),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: V3.inter(16, weight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(sub, style: V3.inter(15, color: V3.muted, height: 1.4)),
            ]),
          ),
        ]),
      );
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: V3.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
            child: Row(children: [
              Expanded(
                  child: Text('How to draw your diagram',
                      style: V3.tight(19, weight: FontWeight.w700))),
              IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close, color: V3.muted),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          const Divider(height: 1, color: V3.line),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: [
                section('Circles'),
                row(_Ico.players, 'Numbered circle = Player',
                    'A stick man or X with a number works too\nSide by side, numbers sum to 17 → opponents (3 & 14, 6 & 11…)\nSide by side, same number → drill opponents\nSingle team spread out → all red'),
                row(_Ico.coach, 'Circle with C = Coach',
                    'Renders as a black circle'),
                row(_Ico.ball, 'Empty circle = Football',
                    'Small circle, no label'),
                section('Other shapes'),
                row(_Ico.cone, 'Triangle = Cone', 'Renders as an orange cone'),
                row(_Ico.goal, 'H shape = Goalposts',
                    'Two uprights and a crossbar'),
                row(_Ico.wall, 'Wide rectangle labelled "Wall"',
                    'Training wall — spans most of the canvas width at the top. Arrows end at its base'),
                section('Lines & arrows'),
                row(_Ico.run, 'Solid arrow = Player run',
                    'Straight, curved, or wavy'),
                row(_Ico.pass, 'Dashed arrow = Kick / Pass',
                    'Renders in yellow'),
                row(_Ico.pitchLine, 'Pitch line = Zone boundary',
                    '13m, 20m, 45m, halfway — long line spanning full width, no arrowhead'),
                row(_Ico.arc, 'Arc = Pitch arc',
                    'D-arc, 2-pointer arc, centre circle — curved pitch markings, no arrowhead'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: V3.card2, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tips for best results',
                            style: V3.inter(15,
                                weight: FontWeight.w700, color: V3.green)),
                        const SizedBox(height: 6),
                        Text(
                            '• Keep circles clearly round and label them legibly\n'
                            "• Use numbered circles for players — matchstick figures won't be recognised\n"
                            '• Opponent pairs: draw side by side. Numbers that sum to 15 (e.g. 3 & 12) are automatically coloured red vs blue\n'
                            '• Draw arrows that clearly start and end at shapes\n'
                            '• Pitch zone lines should span the full width — the AI tells them apart from movement arrows',
                            style: V3.inter(15, color: V3.muted, height: 1.55)),
                      ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    ),
  );
}

class _HelpIcon extends CustomPainter {
  const _HelpIcon(this.icon);
  final _Ico icon;

  @override
  void paint(Canvas c, Size size) {
    final cy = size.height / 2;
    void disc(Offset o, double r, Color fill, Color edge, String label) {
      c.drawCircle(o, r, Paint()..color = fill);
      c.drawCircle(
          o,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = edge);
      if (label.isEmpty) return;
      final tp = TextPainter(
          text: TextSpan(
              text: label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white;
    switch (icon) {
      case _Ico.players:
        disc(Offset(14, cy), 13, const Color(0xFFC62828),
            const Color(0xFFB71C1C), '3');
        disc(Offset(46, cy), 13, const Color(0xFF1565C0),
            const Color(0xFF0D47A1), '12');
      case _Ico.coach:
        disc(Offset(18, cy), 14, const Color(0xFF1A1A1A), Colors.black, 'C');
      case _Ico.ball:
        disc(Offset(18, cy), 10, Colors.white, const Color(0xFF555555), '');
      case _Ico.cone:
        final p = Path()
          ..moveTo(18, cy - 12)
          ..lineTo(32, cy + 12)
          ..lineTo(4, cy + 12)
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFFFF6D00));
      case _Ico.goal:
        c.drawLine(Offset(10, cy - 14), Offset(10, cy + 14), line);
        c.drawLine(Offset(26, cy - 14), Offset(26, cy + 14), line);
        c.drawLine(Offset(10, cy), Offset(26, cy), line);
      case _Ico.wall:
        final r = Rect.fromLTWH(2, cy - 8, 56, 16);
        c.drawRect(r, Paint()..color = const Color(0xFF455A64));
        c.drawRect(
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = const Color(0xFFB0BEC5));
        final tp = TextPainter(
            text: const TextSpan(
                text: 'WALL',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(c, Offset(30 - tp.width / 2, cy - tp.height / 2));
      case _Ico.run:
        c.drawLine(Offset(4, cy), Offset(26, cy), line);
        c.drawPath(
            Path()
              ..moveTo(36, cy)
              ..lineTo(24, cy - 5)
              ..lineTo(24, cy + 5)
              ..close(),
            Paint()..color = Colors.white);
      case _Ico.pass:
        final y = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFFFD700);
        for (double x = 4; x < 26; x += 10) {
          c.drawLine(Offset(x, cy), Offset(_min(x + 6, 26), cy), y);
        }
        c.drawPath(
            Path()
              ..moveTo(24, cy - 5)
              ..lineTo(36, cy)
              ..lineTo(24, cy + 5),
            y..strokeWidth = 2);
      case _Ico.pitchLine:
        c.drawLine(
            Offset(4, cy),
            Offset(32, cy),
            Paint()
              ..strokeWidth = 1.5
              ..color = Colors.white.withValues(alpha: 0.45));
      case _Ico.arc:
        c.drawPath(
            Path()
              ..moveTo(4, cy + 12)
              ..quadraticBezierTo(18, cy - 14, 32, cy + 12),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = Colors.white.withValues(alpha: 0.45));
    }
  }

  static double _min(double a, double b) => a < b ? a : b;

  @override
  bool shouldRepaint(_HelpIcon old) => old.icon != icon;
}
