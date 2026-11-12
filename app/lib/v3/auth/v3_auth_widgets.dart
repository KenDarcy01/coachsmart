// Shared pieces for the v3 sign-in screens, drawn from the approved mockups
// (/mnt/project-files/coachsmart/app-v3/auth/auth.html).
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '../v3_theme.dart';

const kTermsUrl = 'https://coachsmart.app/terms.html';
const kPrivacyUrl = 'https://coachsmart.app/privacy.html';

/// Dark page with an optional back chevron and a scrolling 20px-padded body.
class V3AuthScaffold extends StatelessWidget {
  const V3AuthScaffold(
      {super.key, required this.children, this.showBack = true});
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (showBack)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: const Icon(Icons.chevron_left,
                        color: V3.green, size: 40),
                    onPressed: () => context.safePop(),
                  ),
                )
              else
                const SizedBox(height: 40),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class V3AuthTitle extends StatelessWidget {
  const V3AuthTitle(this.title, {super.key, this.subtitle});
  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: V3.tight(30, weight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          DefaultTextStyle(
              style: V3.inter(16, color: V3.muted, height: 1.4),
              child: subtitle!),
        ],
      ]),
    );
  }
}

/// Label above a dark rounded text field; green border while focused.
class V3Field extends StatelessWidget {
  const V3Field({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.trailing,
    this.autofillHints,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? trailing;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c, width: 1.5));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: V3.inter(15, color: V3.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          obscureText: obscure,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          autocorrect: false,
          style: V3.inter(17, weight: FontWeight.w500),
          cursorColor: V3.green,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: V3.inter(17, color: const Color(0xFF6F737C)),
            filled: true,
            fillColor: V3.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            enabledBorder: border(V3.line),
            disabledBorder: border(V3.line),
            focusedBorder: border(V3.green),
            suffixIcon: trailing,
            suffixIconColor: V3.muted,
          ),
        ),
      ]),
    );
  }
}

/// Eye toggle for password fields.
class V3EyeButton extends StatelessWidget {
  const V3EyeButton({super.key, required this.shown, required this.onTap});
  final bool shown;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(shown ? Icons.visibility_off_outlined : Icons.visibility,
            color: V3.muted, size: 22),
      );
}

/// Full-width green button, 56px, with a spinner while busy.
class V3PrimaryButton extends StatelessWidget {
  const V3PrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.busy = false});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: V3.green,
          disabledBackgroundColor: V3.green.withValues(alpha: .45),
          foregroundColor: V3.bg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child:
                    CircularProgressIndicator(strokeWidth: 2.5, color: V3.bg))
            : Text(label,
                style: V3.inter(18, weight: FontWeight.w700, color: V3.bg)),
      ),
    );
  }
}

/// "Resend code · 0:42" that becomes a tappable link when the timer ends.
class V3ResendButton extends StatefulWidget {
  const V3ResendButton(
      {super.key,
      required this.onResend,
      this.seconds = 60,
      this.label = 'Resend code'});
  final Future<void> Function() onResend;
  final int seconds;
  final String label;
  @override
  State<V3ResendButton> createState() => _V3ResendButtonState();
}

class _V3ResendButtonState extends State<V3ResendButton> {
  late int _left = widget.seconds;
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _left = widget.seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _left > 0;
    final mm = (_left ~/ 60).toString();
    final ss = (_left % 60).toString().padLeft(2, '0');
    return TextButton(
      onPressed: waiting || _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await widget.onResend();
              } finally {
                if (mounted) {
                  setState(() => _busy = false);
                  _start();
                }
              }
            },
      child: Text(
        waiting ? '${widget.label} · $mm:$ss' : widget.label,
        style: V3.inter(16,
            weight: FontWeight.w600,
            color: waiting ? V3.green.withValues(alpha: .7) : V3.green),
      ),
    );
  }
}

/// Six code boxes driven by one hidden text field, so the keyboard's
/// one-time-code suggestion and paste both work.
class V3CodeInput extends StatefulWidget {
  const V3CodeInput(
      {super.key, required this.controller, this.onCompleted, this.autofocus});
  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool? autofocus;
  @override
  State<V3CodeInput> createState() => _V3CodeInputState();
}

class _V3CodeInputState extends State<V3CodeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(() => setState(() {}));
  }

  void _changed() {
    setState(() {});
    if (widget.controller.text.length == 6) {
      widget.onCompleted?.call(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(children: [
        Row(children: [
          for (var i = 0; i < 6; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: V3.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _focus.hasFocus && i == text.length
                          ? V3.green
                          : V3.line,
                      width: 1.5),
                ),
                child: Text(i < text.length ? text[i] : '',
                    style: V3.tight(26, weight: FontWeight.w700)),
              ),
            ),
          ],
        ]),
        // The real field: invisible, but it owns the keyboard.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus ?? false,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              showCursor: false,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Live password rule chips: 8+ characters, a number, a symbol.
class PasswordRules {
  static bool longEnough(String p) => p.length >= 8;
  static bool hasNumber(String p) => RegExp(r'\d').hasMatch(p);
  static bool hasSymbol(String p) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(p);
  static bool ok(String p) => longEnough(p) && hasNumber(p) && hasSymbol(p);
}

class V3PasswordRuleChips extends StatelessWidget {
  const V3PasswordRuleChips(this.password, {super.key});
  final String password;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool on) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: on ? V3.greenTint : V3.card2,
              borderRadius: BorderRadius.circular(8)),
          child: Text(on ? '✓ $label' : label,
              style: V3.inter(13.5,
                  weight: FontWeight.w600, color: on ? V3.green : V3.muted)),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 20),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        chip('8+ characters', PasswordRules.longEnough(password)),
        chip('a number', PasswordRules.hasNumber(password)),
        chip('a symbol', PasswordRules.hasSymbol(password)),
      ]),
    );
  }
}

/// Small print with tappable Terms of Service and Privacy Policy.
class V3LegalLine extends StatelessWidget {
  const V3LegalLine({super.key, required this.lead});
  final String lead;

  @override
  Widget build(BuildContext context) {
    TextSpan link(String text, String url) => TextSpan(
        text: text,
        style: const TextStyle(decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () => launchURL(url));
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Text.rich(
        TextSpan(
          style: V3.inter(13.5, color: V3.muted, height: 1.45),
          children: [
            TextSpan(text: '$lead you agree to our '),
            link('Terms of Service', kTermsUrl),
            const TextSpan(text: ' and '),
            link('Privacy Policy', kPrivacyUrl),
            const TextSpan(text: '.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// "New to CoachSmart? Create an account" style line.
class V3SwitchLine extends StatelessWidget {
  const V3SwitchLine(
      {super.key,
      required this.text,
      required this.action,
      required this.onTap});
  final String text;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
        child: TextButton(
          onPressed: onTap,
          child: Text.rich(TextSpan(
            style: V3.inter(16, color: V3.muted),
            children: [
              TextSpan(text: '$text '),
              TextSpan(
                  text: action,
                  style:
                      V3.inter(16, weight: FontWeight.w700, color: V3.green)),
            ],
          )),
        ),
      );
}

/// Red inline error under a form.
class V3ErrorText extends StatelessWidget {
  const V3ErrorText(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null || message!.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(message!,
              style: V3.inter(15, color: V3.redText, weight: FontWeight.w500)),
        );
}

bool looksLikeEmail(String s) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s.trim());
