// v3 Sign in: the first screen for anyone signed out. Email + password only
// (Ken, 2026-11-09: no Apple/Google or Face ID in the first version).
import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '../v3_theme.dart';
import 'v3_auth_service.dart';
import 'v3_auth_widgets.dart';

class V3SignInPage extends StatefulWidget {
  const V3SignInPage({super.key});

  // Same route as the v2 page so every existing redirect still lands here.
  static String routeName = 'Auth_Page';
  static String routePath = 'authPage';

  @override
  State<V3SignInPage> createState() => _V3SignInPageState();
}

class _V3SignInPageState extends State<V3SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    if (!looksLikeEmail(email)) {
      setState(() => _error = 'Enter the email address you registered with.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    GoRouter.of(context).prepareAuthEvent();
    var notConfirmed = false;
    final err = await V3AuthService.signIn(email, _password.text,
        notConfirmed: () => notConfirmed = true);
    if (!mounted) return;
    if (notConfirmed) {
      setState(() => _busy = false);
      await V3AuthService.resendSignUpCode(email);
      if (!mounted) return;
      context
          .pushNamed(V3VerifyPage.routeName, queryParameters: {'email': email});
      return;
    }
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    context.goNamedAuth(V3HomePage.routeName, context.mounted);
  }

  @override
  Widget build(BuildContext context) {
    return V3AuthScaffold(
      showBack: false,
      children: [
        Center(
          child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset('assets/images/Launcher_Icon_v2.png',
                  width: 56, height: 56),
            ),
            const SizedBox(height: 10),
            Text.rich(TextSpan(
              style: V3.tight(24, weight: FontWeight.w800, height: 1),
              children: [
                const TextSpan(text: 'COACH'),
                TextSpan(
                    text: 'SMART',
                    style:
                        V3.tight(24, weight: FontWeight.w800, color: V3.green)),
              ],
            )),
          ]),
        ),
        const V3AuthTitle('Sign in',
            subtitle: Text('Use the email you registered with CoachSmart.')),
        AutofillGroup(
          child: Column(children: [
            V3Field(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
            ),
            V3Field(
              label: 'Password',
              controller: _password,
              obscure: !_show,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(),
              trailing: V3EyeButton(
                  shown: _show, onTap: () => setState(() => _show = !_show)),
            ),
          ]),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.pushNamed(V3ResetPasswordPage.routeName,
                queryParameters: {
                  if (_email.text.trim().isNotEmpty) 'email': _email.text.trim()
                }),
            child: Text('Forgot password?',
                style: V3.inter(16, weight: FontWeight.w600, color: V3.green)),
          ),
        ),
        const SizedBox(height: 6),
        V3ErrorText(_error),
        V3PrimaryButton(label: 'Sign in', onPressed: _signIn, busy: _busy),
        const SizedBox(height: 28),
        V3SwitchLine(
            text: 'New to CoachSmart?',
            action: 'Create an account',
            onTap: () => context.pushNamed(V3CreateAccountPage.routeName)),
        const V3LegalLine(lead: 'By continuing'),
      ],
    );
  }
}
