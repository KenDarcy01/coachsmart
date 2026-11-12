// v3 Reset your password: the email carries a link to the reset page on
// my.coachsmart.app, the same as v2 (Ken, 2026-11-12). The in-app 6-digit
// code version is parked until the email templates carry a code.
import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_auth_service.dart';
import 'v3_auth_widgets.dart';

class V3ResetPasswordPage extends StatefulWidget {
  const V3ResetPasswordPage({super.key, this.email = ''});
  final String email;

  // Same route as the v2 page so the "Forgot password" links still work.
  static String routeName = 'ForgotPassword';
  static String routePath = 'forgotPassword';

  @override
  State<V3ResetPasswordPage> createState() => _V3ResetPasswordPageState();
}

class _V3ResetPasswordPageState extends State<V3ResetPasswordPage> {
  late final _email = TextEditingController(text: widget.email);
  bool _sent = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!looksLikeEmail(email)) {
      setState(() => _error = 'Enter the email address you registered with.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final err = await V3AuthService.sendRecoveryCode(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _sent = err == null;
    });
  }

  Future<void> _resend() async {
    final err = await V3AuthService.sendRecoveryCode(_email.text);
    if (!mounted) return;
    setState(() {
      _error = err;
      _notice = err == null ? 'A new email is on its way.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = _email.text.trim();
    return V3AuthScaffold(
      children: [
        V3AuthTitle('Reset your password',
            subtitle: _sent
                ? Text.rich(TextSpan(children: [
                    const TextSpan(text: 'We sent a link to '),
                    TextSpan(
                        text: email,
                        style:
                            V3.inter(16, weight: FontWeight.w700, height: 1.4)),
                    const TextSpan(
                        text:
                            '. Tap it to choose a new password, then come back here and sign in with it.'),
                  ]))
                : const Text(
                    "Enter your email and we'll send you a link to choose a new password.")),
        V3Field(
          label: 'Email',
          controller: _email,
          enabled: !_sent,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _send(),
          trailing: _sent
              ? TextButton(
                  onPressed: () => setState(() {
                        _sent = false;
                        _error = null;
                        _notice = null;
                      }),
                  child: Text('Change',
                      style: V3.inter(15,
                          weight: FontWeight.w600, color: V3.green)))
              : null,
        ),
        if (!_sent) ...[
          V3ErrorText(_error),
          V3PrimaryButton(label: 'Send link', onPressed: _send, busy: _busy),
        ] else ...[
          Text(
            "Can't see it? Check your spam or junk folder.",
            style: V3.inter(15, color: V3.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          V3ErrorText(_error),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(_notice!,
                  style:
                      V3.inter(15, color: V3.green, weight: FontWeight.w500)),
            ),
          V3PrimaryButton(
              label: 'Back to sign in',
              onPressed: () => context.goNamed(V3SignInPage.routeName)),
          const SizedBox(height: 10),
          Center(
              child: V3ResendButton(onResend: _resend, label: 'Resend email')),
        ],
      ],
    );
  }
}
