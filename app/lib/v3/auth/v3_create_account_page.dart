// v3 Create account: name, email, password with live rules. On success the
// user types the 6-digit code from the confirmation email in the app.
import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'v3_auth_service.dart';
import 'v3_auth_widgets.dart';

class V3CreateAccountPage extends StatefulWidget {
  const V3CreateAccountPage({super.key});

  static String routeName = 'CreateAccount';
  static String routePath = 'createAccount';

  @override
  State<V3CreateAccountPage> createState() => _V3CreateAccountPageState();
}

class _V3CreateAccountPageState extends State<V3CreateAccountPage> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final first = _first.text.trim();
    final last = _last.text.trim();
    final email = _email.text.trim();
    if (first.isEmpty || last.isEmpty) {
      setState(() => _error = 'Enter your first and last name.');
      return;
    }
    if (!looksLikeEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (!PasswordRules.ok(_password.text)) {
      setState(() =>
          _error = 'Your password needs 8+ characters, a number and a symbol.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    GoRouter.of(context).prepareAuthEvent();
    final r = await V3AuthService.signUp(email, _password.text, first, last);
    if (!mounted) return;
    if (r.error != null) {
      setState(() {
        _busy = false;
        _error = r.error;
      });
      return;
    }
    if (r.signedIn) {
      await V3AuthService.ensureProfile(first, last);
      if (!mounted) return;
      context.goNamedAuth(V3HomePage.routeName, context.mounted);
      return;
    }
    setState(() => _busy = false);
    context.pushNamed(V3VerifyPage.routeName, queryParameters: {
      'email': email,
      'first': first,
      'last': last,
    });
  }

  @override
  Widget build(BuildContext context) {
    return V3AuthScaffold(
      children: [
        const V3AuthTitle('Create your account',
            subtitle:
                Text("Your name is shown to your team's coaches and admins.")),
        AutofillGroup(
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: V3Field(
                  label: 'First name',
                  controller: _first,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: V3Field(
                  label: 'Last name',
                  controller: _last,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.familyName],
                  textInputAction: TextInputAction.next,
                ),
              ),
            ]),
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
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _create(),
              trailing: V3EyeButton(
                  shown: _show, onTap: () => setState(() => _show = !_show)),
            ),
          ]),
        ),
        V3PasswordRuleChips(_password.text),
        V3ErrorText(_error),
        V3PrimaryButton(
            label: 'Create account', onPressed: _create, busy: _busy),
        const V3LegalLine(lead: 'By creating an account'),
        const SizedBox(height: 10),
        V3SwitchLine(
            text: 'Already have an account?',
            action: 'Sign in',
            onTap: () => context.safePop()),
      ],
    );
  }
}
