// v3 Score keeper: the building blocks — big score buttons, the score
// board, shirts, steppers, choice chips, the bottom bar buttons and the
// slide-up sheet. Sized for pitch-side: big text, 52px+ targets.
import 'package:flutter/material.dart';

import '../match_stats/v3_match_charts.dart' show kOppRed;
import '../match_stats/v3_match_stats_models.dart';
import '../v3_theme.dart';

const skRed = kOppRed;

/// Numbers in the condensed face the web page uses (Bebas Neue there).
TextStyle skNum(double size, {Color color = V3.text}) =>
    V3.tight(size, weight: FontWeight.w700, color: color, height: 1);

TextStyle skCaps({Color color = V3.muted, double size = 13}) =>
    V3.inter(size, weight: FontWeight.w600, color: color, letterSpacing: 2);

/// One stat button: name on the left, count on the right. Scores are
/// tinted: goals green, 2 pointers amber.
class SkBigButton extends StatefulWidget {
  const SkBigButton(
      {super.key,
      required this.label,
      required this.count,
      required this.value,
      required this.onTap,
      required this.onLongPress,
      this.dim = false});

  final String label;
  final int count;
  final int? value;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool dim;

  @override
  State<SkBigButton> createState() => _SkBigButtonState();
}

class _SkBigButtonState extends State<SkBigButton> {
  bool _down = false;
  bool _flash = false;

  void _tap() {
    widget.onTap();
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.value ?? 0;
    final (Color tint, Color edge, Color num) = switch (v) {
      3 => (V3.green, V3.green.withValues(alpha: .35), V3.green),
      2 => (V3.amber, V3.amber.withValues(alpha: .35), V3.amber),
      _ => (Colors.transparent, const Color(0x14FFFFFF), V3.muted),
    };
    return Semantics(
      button: true,
      label: '${widget.label}, ${widget.count}',
      hint: 'Tap to add one. Press and hold to take one off.',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: _tap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: const Duration(milliseconds: 80),
          child: AnimatedOpacity(
            opacity: widget.dim ? .45 : 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              height: 66,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: V3.card,
                gradient: v == 3 || v == 2
                    ? LinearGradient(colors: [
                        tint.withValues(alpha: .22),
                        tint.withValues(alpha: .07)
                      ])
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: _flash ? V3.green : edge, width: _flash ? 3 : 1.5),
              ),
              child: Row(children: [
                Expanded(
                    child: Text(widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: V3.inter(19, weight: FontWeight.w700))),
                const SizedBox(width: 6),
                Text('${widget.count}', style: skNum(34, color: num)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The score board: our name, score and points, the lead, theirs.
class SkBoard extends StatelessWidget {
  const SkBoard(
      {super.key,
      required this.us,
      required this.opp,
      required this.w,
      this.tag,
      this.sub,
      this.footer});

  final String us;
  final String opp;
  final Walk w;
  final String? tag; // HT / FT
  final String? sub;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final d = w.usT - w.oppT;
    final (String txt, Color fg, Color bg) = tag != null
        ? (tag!, V3.green, V3.green.withValues(alpha: .15))
        : d == 0
            ? ('Level', V3.muted, V3.card2)
            : d > 0
                ? ('▲ $d', V3.green, V3.green.withValues(alpha: .15))
                : ('▲ ${-d}', skRed, skRed.withValues(alpha: .15));
    Widget side(String name, String score, int pts) => Expanded(
          child: Column(children: [
            Text(name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: skCaps()),
            const SizedBox(height: 6),
            FittedBox(
                fit: BoxFit.scaleDown, child: Text(score, style: skNum(54))),
            const SizedBox(height: 4),
            Text('$pts pts', style: V3.inter(15, color: V3.muted)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      decoration: BoxDecoration(
          color: V3.card, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(sub!,
                textAlign: TextAlign.center,
                style: V3.inter(16, color: V3.muted)),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          side(us, w.us, w.usT),
          Container(
            constraints: const BoxConstraints(minWidth: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(txt,
                textAlign: TextAlign.center,
                style: V3.inter(15, weight: FontWeight.w700, color: fg)),
          ),
          side(opp, w.opp, w.oppT),
        ]),
        if (footer != null) footer!,
      ]),
    );
  }
}

/// A player as a shirt: number over a short name.
class SkShirt extends StatelessWidget {
  const SkShirt(
      {super.key,
      required this.number,
      required this.name,
      required this.selected,
      required this.onTap});
  final String number;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: V3.card2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: selected ? V3.green : Colors.transparent, width: 2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(number, style: skNum(26)),
            const SizedBox(height: 3),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(13, color: V3.muted)),
          ]),
        ),
      ),
    );
  }
}

/// Shirts in a grid, about five to a row.
class SkShirtGrid extends StatelessWidget {
  const SkShirtGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / 72).floor().clamp(3, 8);
      final w = (box.maxWidth - (cols - 1) * 6) / cols;
      return Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in children) SizedBox(width: w, child: c),
      ]);
    });
  }
}

/// – n +
class SkStepper extends StatelessWidget {
  const SkStepper(
      {super.key,
      required this.value,
      required this.onMinus,
      required this.onPlus,
      this.label = ''});
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final String label;

  @override
  Widget build(BuildContext context) {
    Widget b(String t, VoidCallback f, String l) => Semantics(
          button: true,
          label: l,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: f,
            child: SizedBox(
                width: 56,
                height: 56,
                child: Center(
                    child: Text(t,
                        style: V3.inter(26,
                            weight: FontWeight.w500, color: V3.muted)))),
          ),
        );
    return Container(
      decoration: BoxDecoration(
          color: V3.card2, borderRadius: BorderRadius.circular(14)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        b('–', onMinus, 'One less $label'.trim()),
        SizedBox(
            width: 46,
            child:
                Text('$value', textAlign: TextAlign.center, style: skNum(32))),
        b('+', onPlus, 'One more $label'.trim()),
      ]),
    );
  }
}

/// A row of choices; the one picked has a green (or red) edge.
class SkChoice extends StatelessWidget {
  const SkChoice(
      {super.key,
      required this.label,
      required this.on,
      required this.onTap,
      this.red = false,
      this.bg = V3.card2});
  final String label;
  final bool on;
  final VoidCallback onTap;
  final bool red;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final c = red ? skRed : V3.green;
    return Material(
      color: on ? c.withValues(alpha: .1) : bg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: on ? c : Colors.transparent, width: 1.5)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Text(label,
              style: V3.inter(16,
                  weight: FontWeight.w600, color: on ? c : V3.text)),
        ),
      ),
    );
  }
}

enum SkTone { plain, soft, green, amber, red }

/// The big bottom bar and sheet buttons.
class SkButton extends StatelessWidget {
  const SkButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.tone = SkTone.plain,
      this.icon,
      this.height = 60,
      this.pulse = false,
      this.textColor});
  final String label;
  final VoidCallback? onTap;
  final SkTone tone;
  final IconData? icon;
  final double height;
  final bool pulse;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      SkTone.green => (V3.green, V3.bg),
      SkTone.amber => (V3.amber, V3.bg),
      SkTone.red => (V3.red, Colors.white),
      SkTone.plain => (V3.card, textColor ?? V3.text),
      SkTone.soft => (V3.card2, textColor ?? V3.text),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: pulse
            ? [
                BoxShadow(
                    color: V3.amber.withValues(alpha: .6), spreadRadius: 4)
              ]
            : const [],
      ),
      child: Material(
        color: onTap == null ? bg.withValues(alpha: .4) : bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 24),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: V3.inter(height >= 58 ? 19 : 17,
                        weight: FontWeight.w700, color: fg)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Section heading in a sheet: green for us, red for them.
class SkSec extends StatelessWidget {
  const SkSec(this.text, {super.key, this.red = false});
  final String text;
  final bool red;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700,
                color: red ? skRed : V3.green,
                letterSpacing: 2)),
      );
}

/// Opens a slide-up sheet with a grab bar, title and close button.
Future<T?> showSkSheet<T>(BuildContext context,
    {String? title,
    required Widget Function(BuildContext) body,
    bool close = true}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: V3.card,
    barrierColor: Colors.black.withValues(alpha: .55),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .88),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            18, 10, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFF3A414D),
                      borderRadius: BorderRadius.circular(3))),
            ),
            if (title != null) SkSheetHead(title, close: close),
            body(ctx),
          ],
        ),
      ),
    ),
  );
}

/// Two buttons side by side at the foot of a sheet.
class SkSheetButtons extends StatelessWidget {
  const SkSheetButtons({super.key, required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(children: [
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right),
        ]),
      );
}

/// A sheet's title with its close button.
class SkSheetHead extends StatelessWidget {
  const SkSheetHead(this.title, {super.key, this.close = true, this.sub});
  final String title;
  final bool close;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
            child: Text(title, style: V3.tight(22, weight: FontWeight.w700))),
        if (close)
          Semantics(
            button: true,
            label: 'Close',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: V3.card2, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.close, color: V3.muted, size: 22),
              ),
            ),
          ),
      ]),
      if (sub != null && sub!.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: Text(sub!, style: V3.inter(16, color: V3.muted)),
        ),
    ]);
  }
}
