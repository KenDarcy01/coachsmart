// v3 Match report: write, dictate and save the report for one match. A
// native copy of webviews/match-report.html (which the old app keeps using).
// Everything goes through the ai-match-report edge function:
//   load   → event, team, squads, ai flag, earlier reports (role 100+ only)
//   draft / revise → the AI tidies spoken words (users.ai_features only)
//   save   → inserts match_reports and emails the team's admins.
// The server applies every role gate (on the team; 100+ for the list; AI
// flag for draft/revise); the page shows what it is sent.
import 'dart:async';

import 'package:flutter/material.dart';

import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '../v3_theme.dart';
import 'v3_match_report_models.dart';
import 'v3_voice_sheet.dart';

typedef MrCall = Future<dynamic> Function(Map<String, dynamic> body);

class V3MatchReportPage extends StatefulWidget {
  const V3MatchReportPage(
      {super.key,
      required this.eventId,
      this.testData,
      this.testCall,
      this.testDictation});

  final int eventId;

  /// Widget tests pass the load action's data here instead of calling the
  /// edge function.
  @visibleForTesting
  final Map<String, dynamic>? testData;

  /// Widget tests answer draft / revise / save here (return the response
  /// JSON, {success, data} or {error}).
  @visibleForTesting
  final MrCall? testCall;

  @visibleForTesting
  final V3Dictation? testDictation;

  @override
  State<V3MatchReportPage> createState() => _V3MatchReportPageState();
}

class _V3MatchReportPageState extends State<V3MatchReportPage> {
  MrLoad? _data;
  bool _loading = true;
  String? _error;

  final _report = TextEditingController();
  final _opposition = TextEditingController();
  final _reportFocus = FocusNode();
  final _oppFocus = FocusNode();
  int? _squadId;

  bool _busy = false; // AI is working on the report
  bool _saving = false;
  String? _undoText; // report before the last AI change

  /// Set while the voice panel is open: messages go there, since the panel
  /// covers the snack bar.
  ValueNotifier<V3SheetNote?>? _sheetNote;

  @override
  void initState() {
    super.initState();
    _report.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _report.dispose();
    _opposition.dispose();
    _reportFocus.dispose();
    _oppFocus.dispose();
    super.dispose();
  }

  Future<dynamic> _call(Map<String, dynamic> body) async {
    final payload = {'event_id': widget.eventId, ...body};
    if (widget.testCall != null) {
      return unwrapMr(await widget.testCall!(payload));
    }
    try {
      final res = await SupaFlow.client.functions
          .invoke('ai-match-report', body: payload);
      return unwrapMr(res.data);
    } on FunctionException catch (e) {
      return unwrapMr(e.details);
    }
  }

  Future<void> _load() async {
    if (widget.testData != null) {
      _apply(MrLoad.fromJson(widget.testData!));
      return;
    }
    if (widget.eventId == 0) {
      setState(() {
        _loading = false;
        _error = 'No match was given. Go back and open the report from the '
            'match.';
      });
      return;
    }
    if (currentJwtToken.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please sign in again to write a match report.';
      });
      return;
    }
    try {
      final d = await _call({'action': 'load'});
      if (!mounted) return;
      _apply(MrLoad.fromJson(d is Map ? d : {}));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is MrError ? e.message : 'Could not load the match.';
      });
    }
  }

  void _apply(MrLoad d) {
    setState(() {
      _data = d;
      _squadId = d.initialSquadId;
      _loading = false;
    });
  }

  void _snack(String text, {bool error = false, int ms = 2800}) {
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

  // ------------------------------------------------------------ actions

  void _undo() {
    final back = _undoText;
    if (back == null || _busy) return;
    setState(() {
      _undoText = null;
      _report.text = back;
    });
    _snack('Change undone');
  }

  Future<void> _openVoice() async {
    if (_busy || _sheetNote != null) return;
    FocusScope.of(context).unfocus();
    final t = MrVoiceText.forReport(_report.text);
    final note = _sheetNote = ValueNotifier<V3SheetNote?>(null);
    await showV3VoiceSheet(
      context,
      title: t.title,
      subtitle: t.subtitle,
      placeholder: t.placeholder,
      submitLabel: t.submit,
      busyLabel: t.busy,
      onSubmit: _handleVoice,
      onError: (m) => _snack(m, error: true),
      note: note,
      dictation: widget.testDictation,
    );
    _sheetNote = null;
    // The panel closed: repeat its last message where it can be seen.
    final last = note.value;
    if (last != null && mounted) _snack(last.text, error: last.error);
  }

  Future<bool> _handleVoice(String transcript) async {
    if (transcript.trim().isEmpty) {
      _snack("Didn't catch that. Please try again.", error: true);
      return false;
    }
    if (_busy) return false;
    final current = _report.text.trim();
    final first = current.isEmpty;
    setState(() => _busy = true);
    _snack(first ? 'Writing up your report…' : 'Updating your report…',
        ms: 60000);
    try {
      final data = await _call(voiceBody(
          current: current,
          transcript: transcript,
          squadId: _squadId,
          opposition: _opposition.text));
      final report = data is Map ? '${data['report'] ?? ''}' : '';
      if (report.trim().isEmpty) throw const MrError('No report came back');
      if (!mounted) return true;
      setState(() {
        _undoText = _report.text;
        _report.text = report;
      });
      _snack(first ? 'Draft ready. Check it over.' : 'Report updated');
      return true;
    } catch (_) {
      if (!mounted) return false;
      // Keep what was said rather than losing it.
      if (first) {
        setState(() => _report.text = transcript);
        _snack('AI is unavailable, so your words were added as spoken',
            error: true, ms: 4000);
        return true;
      }
      _snack('Could not update the report. Please try again.',
          error: true, ms: 4000);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSquad() async {
    final d = _data!;
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: V3.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Select a squad',
                    style: V3.tight(18, weight: FontWeight.w700)),
              ),
              for (final s in d.squads)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(ctx).pop(s.squadId),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Row(children: [
                      Expanded(
                          child: Text(s.label,
                              style: V3.inter(17, weight: FontWeight.w500))),
                      if (s.squadId == _squadId)
                        const Icon(Icons.check, color: V3.green, size: 26),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _squadId = picked);
  }

  Future<void> _save() async {
    if (_saving || _busy) return;
    final d = _data!;
    final problem = saveProblem(
        needsSquad: d.needsSquad,
        squadId: _squadId,
        opposition: _opposition.text,
        report: _report.text);
    if (problem != null) {
      _snack(problem, error: true);
      if (problem == 'Please select a squad') {
        _pickSquad();
      } else if (problem == 'Please enter the opposition') {
        _oppFocus.requestFocus();
      } else {
        _reportFocus.requestFocus();
      }
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await _call({
        'action': 'save',
        'report': _report.text.trim(),
        ...matchFields(_squadId, _opposition.text),
      });
      _snack('Match Report Saved');
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).maybePop(true);
    } catch (e) {
      _snack('Error saving: ${e is MrError ? e.message : 'please try again'}',
          error: true, ms: 4000);
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openDetail(MrReport r) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => V3MatchReportDetailPage(report: r)));
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: _bar(context, 'Match Report'),
      body: _loading
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: V3.green),
              const SizedBox(height: 16),
              Text('Loading match…', style: V3.inter(16, color: V3.muted)),
            ]))
          : _error != null || d == null
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error ?? 'Could not load the match.',
                      textAlign: TextAlign.center,
                      style: V3.inter(16, color: V3.muted, height: 1.5)),
                ))
              : _form(d),
      bottomNavigationBar: d == null || _error != null ? null : _footer(),
    );
  }

  Widget _form(MrLoad d) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardBox(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title,
                    style: V3.tight(18, weight: FontWeight.w700, height: 1.3)),
                if (d.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(d.subtitle, style: V3.inter(15, color: V3.muted)),
                ],
              ],
            ),
          ),
          if (d.showSquadPicker) ...[
            const SizedBox(height: 22),
            _label('Squad', required: true),
            _squadField(d),
          ],
          const SizedBox(height: 22),
          _label('Opposition', required: true),
          TextField(
            key: const ValueKey('opposition'),
            controller: _opposition,
            focusNode: _oppFocus,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            style: V3.inter(17),
            cursorColor: V3.green,
            decoration:
                _inputDeco('Who did you play?').copyWith(counterText: ''),
          ),
          const SizedBox(height: 22),
          _label('Report', required: true),
          _reportField(d),
          if (_undoText != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : _undo,
                style: TextButton.styleFrom(
                    foregroundColor: V3.green, minimumSize: const Size(44, 44)),
                icon: const Icon(Icons.undo, size: 20),
                label: Text('Undo last change',
                    style:
                        V3.inter(15, weight: FontWeight.w600, color: V3.green)),
              ),
            ),
          if (d.aiEnabled) ...[
            const SizedBox(height: 16),
            _voiceRest(),
          ],
          if (d.showReports) ..._reports(d.reports!),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text.rich(
            TextSpan(children: [
              TextSpan(text: text.toUpperCase()),
              if (required)
                const TextSpan(text: ' *', style: TextStyle(color: V3.redText)),
            ]),
            style: V3.inter(14,
                weight: FontWeight.w600, color: V3.muted, letterSpacing: 1.1)),
      );

  BoxDecoration _cardBox() => BoxDecoration(
        color: V3.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: V3.line),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: V3.inter(17, color: V3.muted),
        filled: true,
        fillColor: V3.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: V3.line)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: V3.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: V3.green, width: 1.5)),
      );

  Widget _squadField(MrLoad d) {
    final name = d.squads
        .where((s) => s.squadId == _squadId)
        .map((s) => s.label)
        .firstOrNull;
    return Material(
      color: V3.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('squad'),
        borderRadius: BorderRadius.circular(14),
        onTap: _pickSquad,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: V3.line)),
          child: Row(children: [
            Expanded(
                child: Text(name ?? 'Select a squad',
                    style: V3.inter(17,
                        color: name == null ? V3.muted : V3.text))),
            const Icon(Icons.expand_more, color: V3.muted, size: 26),
          ]),
        ),
      ),
    );
  }

  Widget _reportField(MrLoad d) {
    final hasText = _report.text.trim().isNotEmpty;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _busy ? 0.55 : 1,
      child: TextField(
        key: const ValueKey('report'),
        controller: _report,
        focusNode: _reportFocus,
        readOnly: _busy,
        minLines: 7,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        style: V3.inter(17, height: 1.55),
        cursorColor: V3.green,
        // Typing by hand replaces what undo would bring back.
        onChanged: (_) {
          if (_undoText != null) setState(() => _undoText = null);
        },
        decoration: _inputDeco(d.aiEnabled
                ? 'Your report will appear here. You can also type it.'
                : 'Type your match report…')
            .copyWith(
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: hasText ? V3.line : V3.barGrey, width: 1.5)),
        ),
      ),
    );
  }

  Widget _voiceRest() {
    final t = MrVoiceText.forReport(_report.text);
    return Opacity(
      opacity: _busy ? 0.5 : 1,
      child: Material(
        color: V3.card2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const ValueKey('voice-rest'),
          borderRadius: BorderRadius.circular(16),
          onTap: _busy ? null : _openVoice,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: V3.green.withValues(alpha: 0.55), width: 1.5)),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.label.toUpperCase(),
                        style: V3.inter(13,
                            weight: FontWeight.w700,
                            color: V3.green,
                            letterSpacing: 0.9)),
                    const SizedBox(height: 4),
                    Text(t.placeholder,
                        style: V3.inter(16, color: V3.muted, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                    color: V3.green, shape: BoxShape.circle),
                child: const Icon(Icons.mic_none_rounded,
                    color: Colors.black87, size: 26),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _reports(List<MrReport> list) => [
        const SizedBox(height: 22),
        const Divider(color: V3.line, height: 1),
        const SizedBox(height: 18),
        _label('Reports for this match'),
        if (list.isEmpty)
          Text('No reports yet for this match.',
              style: V3.inter(16, color: V3.muted)),
        for (final r in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: V3.card,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openDetail(r),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: V3.line)),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.author,
                              style: V3.inter(17, weight: FontWeight.w600)),
                          if (r.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(r.subtitle,
                                style: V3.inter(15, color: V3.muted)),
                          ],
                          if (r.report.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(r.report,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    V3.inter(15, color: V3.muted, height: 1.4)),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: V3.muted, size: 26),
                  ]),
                ),
              ),
            ),
          ),
      ];

  Widget _footer() => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
              color: V3.bg, border: Border(top: BorderSide(color: V3.line))),
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              key: const ValueKey('save'),
              style: FilledButton.styleFrom(
                backgroundColor: V3.green,
                disabledBackgroundColor: V3.green.withValues(alpha: 0.4),
                foregroundColor: const Color(0xFF111111),
                disabledForegroundColor: const Color(0xFF111111),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _busy || _saving ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 22),
              label: Text(_saving ? 'Saving…' : 'Save Match Report',
                  style: V3.inter(17,
                      weight: FontWeight.w700, color: const Color(0xFF111111))),
            ),
          ),
        ),
      );
}

PreferredSizeWidget _bar(BuildContext context, String title) => AppBar(
      backgroundColor: V3.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
          onPressed: () => Navigator.of(context).maybePop()),
      title: Text(title, style: V3.tight(17, weight: FontWeight.w600)),
    );

/// Read-only view of one earlier report, opened from the list.
class V3MatchReportDetailPage extends StatelessWidget {
  const V3MatchReportDetailPage({super.key, required this.report});

  final MrReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: _bar(context, 'Match Report'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            for (final e in report.meta)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 104,
                        child:
                            Text(e.key, style: V3.inter(16, color: V3.muted))),
                    Expanded(child: Text(e.value, style: V3.inter(16))),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: V3.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: V3.line),
              ),
              child: SelectableText(report.report,
                  style: V3.inter(17, height: 1.6)),
            ),
          ],
        ),
      ),
    );
  }
}
