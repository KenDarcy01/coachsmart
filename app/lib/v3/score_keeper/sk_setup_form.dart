// v3 Score keeper: the match setup form — opposition, squad, a squad's own
// throw-in time and venue, half length and injury time. Shown on the page
// before kick-off and in the ⋯ menu's Match setup sheet.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../v3_theme.dart';
import 'sk_controller.dart';
import 'sk_widgets.dart';

const kSkDurations = [15, 20, 25, 30, 35];
const kSkInjuries = [0, 2, 3, 5, 10];

class SkSetupForm extends StatefulWidget {
  const SkSetupForm({super.key, required this.ctl, required this.draft});
  final SkController ctl;

  /// Changed in place as the coach fills it in.
  final SkDraft draft;

  @override
  State<SkSetupForm> createState() => _SkSetupFormState();
}

class _SkSetupFormState extends State<SkSetupForm> {
  late final _opp = TextEditingController(text: widget.draft.opp);
  late final _venue = TextEditingController(text: widget.draft.venue);
  late final _other =
      TextEditingController(text: '${(widget.draft.dur / 60).round()}');
  final _otherFocus = FocusNode();

  @override
  void dispose() {
    _opp.dispose();
    _venue.dispose();
    _other.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  SkDraft get d => widget.draft;

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: V3.inter(17, color: V3.muted),
        filled: true,
        fillColor: V3.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x14FFFFFF), width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: V3.green, width: 1.5)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t.toUpperCase(), style: skCaps(size: 12)),
      );

  Widget _hint(String t) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(t, style: V3.inter(14, color: V3.muted)),
      );

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: d.throwH != null
          ? TimeOfDay(hour: d.throwH!, minute: d.throwM ?? 0)
          : TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: V3.green, surface: V3.card, onPrimary: V3.bg)),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      d.throwH = t.hour;
      d.throwM = t.minute;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.ctl.c!;
    final ev = DateTime.tryParse(c.eventDateTime)?.toLocal();
    final when = ev == null ? '' : DateFormat('EEE d MMM').format(ev);
    final subLine = [when, c.eventCode, c.eventType, c.teamName]
        .where((x) => x.isNotEmpty)
        .join(' · ');
    final dm = (d.dur / 60).round();
    final other = d.otherDur || !kSkDurations.contains(dm);
    final opp = d.opp.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 10),
      Text('${widget.ctl.us}${opp.isNotEmpty ? ' v $opp' : ''}',
          style: V3.tight(24, weight: FontWeight.w700)),
      if (subLine.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(subLine, style: V3.inter(15, color: V3.muted)),
        ),
      _label('Opposition'),
      TextField(
        controller: _opp,
        style: V3.inter(17),
        textCapitalization: TextCapitalization.words,
        decoration: _dec('Who are you playing?'),
        onChanged: (v) => setState(() => d.opp = v),
      ),
      if (c.squads.isNotEmpty) ...[
        _label('Squad'),
        DropdownButtonFormField<int?>(
          initialValue:
              c.squads.any((s) => s.id == d.squadId) ? d.squadId : null,
          dropdownColor: V3.card2,
          style: V3.inter(17),
          iconEnabledColor: V3.muted,
          decoration: _dec(''),
          items: [
            DropdownMenuItem<int?>(
                value: null, child: Text('Whole team', style: V3.inter(17))),
            for (final s in c.squads)
              DropdownMenuItem<int?>(
                  value: s.id, child: Text(s.name, style: V3.inter(17))),
          ],
          onChanged: (v) => setState(() => d.squadId = v),
        ),
        _label('Throw-in time and venue, if different'),
        Row(children: [
          SizedBox(
            width: 140,
            child: Semantics(
              button: true,
              label: 'Throw-in time',
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _pickTime,
                onLongPress: () => setState(() {
                  d.throwH = null;
                  d.throwM = null;
                }),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: V3.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0x14FFFFFF), width: 1.5)),
                  child: Row(children: [
                    Expanded(
                      child: Text(
                          d.throwH == null
                              ? '--:--'
                              : '${pad(d.throwH!)}:${pad(d.throwM ?? 0)}',
                          style: V3.inter(17,
                              color: d.throwH == null ? V3.muted : V3.text)),
                    ),
                    if (d.throwH != null)
                      GestureDetector(
                        onTap: () => setState(() {
                          d.throwH = null;
                          d.throwM = null;
                        }),
                        child:
                            const Icon(Icons.close, color: V3.muted, size: 20),
                      )
                    else
                      const Icon(Icons.schedule, color: V3.muted, size: 20),
                  ]),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _venue,
              style: V3.inter(17),
              decoration: _dec('Same as the event'),
              onChanged: (v) => d.venue = v,
            ),
          ),
        ]),
        _hint(
            'For squads playing at different times or grounds. Shown on the live link.'),
      ],
      _label('Half length'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in kSkDurations)
          SkChoice(
              label: '$m min',
              bg: V3.card,
              on: !other && dm == m,
              onTap: () => setState(() {
                    d.otherDur = false;
                    d.dur = m * 60;
                    _other.text = '$m';
                  })),
        SkChoice(
            label: 'Other',
            bg: V3.card,
            on: other,
            onTap: () {
              setState(() => d.otherDur = true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _otherFocus.requestFocus();
                _other.selection = TextSelection(
                    baseOffset: 0, extentOffset: _other.text.length);
              });
            }),
      ]),
      if (other)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(children: [
            SizedBox(
              width: 96,
              child: TextField(
                controller: _other,
                focusNode: _otherFocus,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: V3.inter(19, weight: FontWeight.w600),
                decoration: _dec(''),
                onChanged: (v) {
                  final n = num.tryParse(v)?.round();
                  if (n != null && n >= 1 && n <= 60) d.dur = n * 60;
                },
              ),
            ),
            const SizedBox(width: 10),
            Text('minutes per half', style: V3.inter(16, color: V3.muted)),
          ]),
        ),
      _label('Injury time, most per half'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in kSkInjuries)
          SkChoice(
              label: m == 0 ? 'None' : '$m min',
              bg: V3.card,
              on: (d.inj / 60).round() == m,
              onTap: () => setState(() => d.inj = m * 60)),
      ]),
      _hint(
          'The clock keeps going into injury time. End the half when the ref blows. If you forget, it ends by itself when injury time is up.'),
    ]);
  }
}

String pad(int n) => n.toString().padLeft(2, '0');

/// The ⋯ menu's Match setup.
Future<void> showSkSetupSheet(BuildContext context, SkController ctl) {
  final d = ctl.draft();
  return showSkSheet<void>(context,
      title: 'Match setup',
      body: (ctx) =>
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SkSetupForm(ctl: ctl, draft: d),
            SkSheetButtons(
              left: SkButton(
                  label: 'Cancel',
                  height: 54,
                  tone: SkTone.soft,
                  onTap: () => Navigator.of(ctx).pop()),
              right: SkButton(
                  label: 'Save',
                  height: 54,
                  tone: SkTone.green,
                  onTap: () {
                    if (ctl.applySetup(d)) Navigator.of(ctx).pop();
                  }),
            ),
          ]));
}
