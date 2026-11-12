// v3 Check your email: sign-up is confirmed by tapping the link in the
// email, the same as v2 (Ken, 2026-11-12). The 6-digit code version is
// parked until the email templates carry a code.
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
  String? _error;
  String? _notice;

  Future<void> _resend() async {
    final err = await V3AuthService.resendSignUpCode(widget.email);
    if (!mounted) return;
    setState(() {
      _error = err;
      _notice = err == null ? 'A new email is on its way.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return V3AuthScaffold(
      children: [
        V3AuthTitle('Check your email',
            subtitle: Text.rich(TextSpan(children: [
              const TextSpan(text: 'We sent a link to '),
              TextSpan(
                  text: widget.email,
                  style: V3.inter(16, weight: FontWeight.w700, height: 1.4)),
              const TextSpan(
                  text:
                      '. Tap it to confirm your account, then come back here and sign in.'),
            ]))),
        Text(
          "Can't see it? Check your spam or junk folder.",
          style: V3.inter(15, color: V3.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        V3ErrorText(_error),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(_notice!,
                style: V3.inter(15, color: V3.green, weight: FontWeight.w500)),
          ),
        V3PrimaryButton(
            label: 'Go to sign in',
            onPressed: () => context.goNamed(V3SignInPage.routeName)),
        const SizedBox(height: 10),
        Center(child: V3ResendButton(onResend: _resend, label: 'Resend email')),
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
      ],
    );
  }
}
