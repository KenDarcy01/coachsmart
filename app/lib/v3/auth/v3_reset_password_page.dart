// v3 Reset your password: email, then the 6-digit code plus the new
// password on the same screen (Ken, 2026-11-09). Replaces the emailed link
// that opened my.coachsmart.app.
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
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _show = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
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
      _notice = err == null ? 'A new code is on its way.' : null;
    });
  }

  Future<void> _setPassword() async {
    if (_code.text.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    if (!PasswordRules.ok(_password.text)) {
      setState(() => _error =
          'Your new password needs 8+ characters, a number and a symbol.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    GoRouter.of(context).prepareAuthEvent();
    var err = await V3AuthService.verifyRecovery(_email.text, _code.text);
    if (err == null) err = await V3AuthService.setPassword(_password.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: V3.card2,
        content: Text('Password changed. You are signed in.',
            style: V3.inter(15, weight: FontWeight.w500))));
    context.goNamedAuth(V3HomePage.routeName, context.mounted);
  }

  @override
  Widget build(BuildContext context) {
    final email = _email.text.trim();
    return V3AuthScaffold(
      children: [
        V3AuthTitle('Reset your password',
            subtitle: _sent
                ? Text.rich(TextSpan(children: [
                    const TextSpan(text: 'We sent a 6-digit code to '),
                    TextSpan(
                        text: email,
                        style:
                            V3.inter(16, weight: FontWeight.w700, height: 1.4)),
                    const TextSpan(
                        text:
                            '. Enter it and choose a new password, all here in the app.'),
                  ]))
                : const Text(
                    "Enter your email and we'll send a 6-digit code. You'll set the new password right here in the app.")),
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
                        _code.clear();
                        _password.clear();
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
          V3PrimaryButton(label: 'Send code', onPressed: _send, busy: _busy),
        ] else ...[
          Text('Code from the email', style: V3.inter(15, color: V3.muted)),
          const SizedBox(height: 8),
          V3CodeInput(controller: _code, autofocus: true),
          const SizedBox(height: 16),
          V3Field(
            label: 'New password',
            controller: _password,
            hint: 'At least 8 characters',
            obscure: !_show,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _setPassword(),
            trailing: V3EyeButton(
                shown: _show, onTap: () => setState(() => _show = !_show)),
          ),
          V3PasswordRuleChips(_password.text),
          V3ErrorText(_error),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(_notice!,
                  style:
                      V3.inter(15, color: V3.green, weight: FontWeight.w500)),
            ),
          V3PrimaryButton(
              label: 'Set new password', onPressed: _setPassword, busy: _busy),
          const SizedBox(height: 10),
          Center(child: V3ResendButton(onResend: _resend)),
        ],
      ],
    );
  }
}
