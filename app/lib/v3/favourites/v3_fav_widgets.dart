// Small pieces shared by the Favourites, Build Session Plan, plan and My
// Plans pages.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../v3_theme.dart';
import 'v3_favourites_api.dart';

/// A snack bar in the page's toast style. [ms] 0 keeps it until replaced
/// (the page's spinning "Saving…" toast).
void favSnack(BuildContext context, String text,
    {bool warn = false, bool success = false, int? ms}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  final spin = ms == 0;
  m.showSnackBar(SnackBar(
    duration:
        Duration(milliseconds: spin ? 120000 : (ms ?? (warn ? 5000 : 2500))),
    backgroundColor: warn ? V3.amber : (success ? V3.green : V3.card2),
    content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (spin) ...[
        const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: V3.green)),
        const SizedBox(width: 10),
      ],
      Flexible(
        child: Text(text,
            textAlign: TextAlign.center,
            style: V3.inter(15,
                weight: FontWeight.w600,
                color: warn || success ? V3.bg : V3.text)),
      ),
    ]),
  ));
}

void favClearSnack(BuildContext context) =>
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

/// Asks which PDF to make: one sized for a phone, or A4 pages to print.
Future<PdfLayout?> pickPdfLayout(BuildContext context, String title) {
  Widget option(BuildContext ctx, PdfLayout l, IconData icon, String label,
          String sub) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: V3.card2,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.pop(ctx, l),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Icon(icon, color: V3.green, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: V3.inter(17, weight: FontWeight.w600)),
                        Text(sub, style: V3.inter(14, color: V3.muted)),
                      ]),
                ),
                const Icon(Icons.chevron_right, color: V3.muted),
              ]),
            ),
          ),
        ),
      );
  return showModalBottomSheet<PdfLayout>(
    context: context,
    backgroundColor: V3.card,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrab(),
              Text(title, style: V3.tight(19)),
              const SizedBox(height: 14),
              option(ctx, PdfLayout.phone, Icons.phone_iphone, 'PDF for phone',
                  'One column, easy to read and share'),
              option(ctx, PdfLayout.a4, Icons.print_outlined, 'A4 to print',
                  'Printable pages'),
            ]),
      ),
    ),
  );
}

/// Shares a PDF from the phone (the page's FlutterBridge sharePdf).
Future<void> sharePdfBytes(Uint8List bytes, String filename) =>
    Printing.sharePdf(bytes: bytes, filename: filename);

class SheetGrab extends StatelessWidget {
  const SheetGrab({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
      );
}

/// Full-page loading, empty or error state.
class FavStateView extends StatelessWidget {
  const FavStateView(
      {super.key, this.icon, this.title, this.body = '', this.loading = false});
  final String? icon, title;
  final String body;
  final bool loading;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(color: V3.green)),
              ),
            if (icon != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(icon!, style: const TextStyle(fontSize: 49)),
              ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(title!,
                    textAlign: TextAlign.center,
                    style: V3.tight(20, weight: FontWeight.w600)),
              ),
            if (body.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(body,
                    textAlign: TextAlign.center,
                    style: V3.inter(16, color: V3.muted, height: 1.5)),
              ),
          ]),
        ),
      );
}

/// Green filled (primary) or outlined button, 52 high.
class FavButton extends StatelessWidget {
  const FavButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.icon,
      this.primary = true,
      this.busy = false,
      this.danger = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary, busy, danger;

  @override
  Widget build(BuildContext context) {
    final fg = primary || danger ? (danger ? Colors.white : V3.bg) : V3.green;
    final child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          else if (icon != null)
            Icon(icon, size: 20, color: fg),
          if (busy || icon != null) const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: V3.inter(16, weight: FontWeight.w700, color: fg)),
          ),
        ]);
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final size = const Size(64, 52);
    if (primary || danger) {
      return FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
            minimumSize: size,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: danger ? const Color(0xFFD63031) : V3.green,
            disabledBackgroundColor:
                (danger ? const Color(0xFFD63031) : V3.green)
                    .withValues(alpha: 0.5),
            shape: shape),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
          minimumSize: size,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          side: const BorderSide(color: V3.green, width: 1.5),
          shape: shape),
      child: child,
    );
  }
}

/// The bar of buttons at the foot of a page.
class FavBottomBar extends StatelessWidget {
  const FavBottomBar({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
            color: V3.card, border: Border(top: BorderSide(color: V3.line))),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SafeArea(
          top: false,
          child: Row(children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              children[i],
            ]
          ]),
        ),
      );
}

/// The resting box that opens the voice panel (CSVoice.restHtml).
class VoiceRestBox extends StatelessWidget {
  const VoiceRestBox(
      {super.key,
      required this.label,
      required this.placeholder,
      required this.onTap});
  final String label, placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: V3.card2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: V3.green.withValues(alpha: 0.55), width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.toUpperCase(),
                          style: V3.inter(12,
                              weight: FontWeight.w700,
                              color: V3.green,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 3),
                      Text(placeholder,
                          style: V3.inter(16, color: V3.muted, height: 1.4)),
                    ]),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: V3.green, shape: BoxShape.circle),
                child: const Icon(Icons.mic_none, color: Colors.black87),
              ),
            ]),
          ),
        ),
      );
}

/// An uppercase field label.
class FavFieldLabel extends StatelessWidget {
  const FavFieldLabel(this.text, {super.key, this.color = V3.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: V3.inter(13,
                weight: FontWeight.w700, color: color, letterSpacing: 1)),
      );
}

/// The v3 app bar with the green chevron back.
PreferredSizeWidget favAppBar(BuildContext context, Widget title,
        {List<Widget> actions = const []}) =>
    AppBar(
      backgroundColor: V3.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, color: V3.green, size: 32),
          onPressed: () => Navigator.of(context).maybePop()),
      titleSpacing: 0,
      title: title,
      actions: [...actions, const SizedBox(width: 8)],
    );

/// The green "My Plans" pill in the header.
class MyPlansPill extends StatelessWidget {
  const MyPlansPill({super.key, required this.onTap, this.compact = false});
  final VoidCallback onTap;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          color: V3.greenTint,
          shape: const StadiumBorder(
              side: BorderSide(color: V3.green, width: 1.5)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.description_outlined,
                      color: V3.green, size: 20),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    Text('My Plans',
                        style: V3.inter(15,
                            weight: FontWeight.w700, color: V3.green)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
}
