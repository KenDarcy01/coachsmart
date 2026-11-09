// v3 Check your email: the 6-digit code from the sign-up email, typed in the
// app. Falls back gracefully if the email only carried a link.
import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_auth_service.dart';
import 'v3_auth_widgets.dart';

class V3VerifyPage extends StatefulWidget {
  const V3VerifyPage(
      {super.key, required this.email, this.first = '', this.last = ''});
  final String email;
  final String first;
  final String last;

  static String routeName = 'VerifyEmail';
  static String routePath = 'verifyEmail';

  @override
  State<V3VerifyPage> createState() => _V3VerifyPageState();
}

class _V3VerifyPageState extends State<V3VerifyPage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_code.text.length != 6 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    GoRouter.of(context).prepareAuthEvent();
    final err = await V3AuthService.verifySignUp(widget.email, _code.text);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    await V3AuthService.ensureProfile(widget.first, widget.last);
    if (!mounted) return;
    context.goNamedAuth(V3HomePage.routeName, context.mounted);
  }

  Future<void> _resend() async {
    final err = await V3AuthService.resendSignUpCode(widget.email);
    if (!mounted) return;
    setState(() {
      _error = err;
      _notice = err == null ? 'A new code is on its way.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return V3AuthScaffold(
      children: [
        V3AuthTitle('Check your email',
            subtitle: Text.rich(TextSpan(children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                  text: widget.email,
                  style: V3.inter(16, weight: FontWeight.w700, height: 1.4)),
              const TextSpan(
                  text:
                      ". Enter it here and you're in, no need to leave the app."),
            ]))),
        V3CodeInput(
            controller: _code,
            autofocus: true,
            onCompleted: (_) => _continue()),
        const SizedBox(height: 20),
        V3ErrorText(_error),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(_notice!,
                style: V3.inter(15, color: V3.green, weight: FontWeight.w500)),
          ),
        V3PrimaryButton(
            label: 'Continue',
            onPressed: _code.text.length == 6 ? _continue : null,
            busy: _busy),
        const SizedBox(height: 10),
        Center(child: V3ResendButton(onResend: _resend)),
        const SizedBox(height: 6),
        Center(
          child: Text.rich(TextSpan(
            style: V3.inter(14.5, color: V3.muted),
            children: [
              const TextSpan(text: 'Wrong address? '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: () => context.safePop(),
                  child: Text('Change email',
                      style: V3.inter(14.5, color: V3.text).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: V3.text)),
                ),
              ),
            ],
          )),
        ),
        const SizedBox(height: 24),
        Text(
          'If the email only has a link, tapping it confirms your account too. Then come back and sign in.',
          textAlign: TextAlign.center,
          style: V3.inter(13.5, color: V3.muted, height: 1.4),
        ),
      ],
    );
  }
}
