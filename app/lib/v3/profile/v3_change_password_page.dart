// v3 Change password: new password twice, the sign-up rules, saved with the
// current session (no email round trip). Replaces Update_Password in v3.
import 'package:flutter/material.dart';

import '/backend/supabase/supabase.dart';
import '../auth/v3_auth_widgets.dart';
import '../v3_theme.dart';

class V3ChangePasswordPage extends StatefulWidget {
  const V3ChangePasswordPage({super.key, this.email = ''});
  final String email;

  @override
  State<V3ChangePasswordPage> createState() => _V3ChangePasswordPageState();
}

class _V3ChangePasswordPageState extends State<V3ChangePasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready =>
      PasswordRules.ok(_password.text) && _password.text == _confirm.text;

  Future<void> _save() async {
    if (!PasswordRules.ok(_password.text)) {
      setState(() =>
          _error = 'Your password needs 8+ characters, a number and a symbol.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'The two passwords are not the same.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupaFlow.client.auth
          .updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password changed',
              textAlign: TextAlign.center, style: V3.inter(14, color: V3.bg)),
          backgroundColor: V3.green));
      Navigator.of(context).maybePop();
    } on AuthException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message.toLowerCase().contains('same')
            ? 'That is your current password. Choose a different one.'
            : 'The password could not be changed. Please try again.';
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'The password could not be changed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: V3.bg,
      appBar: AppBar(
        backgroundColor: V3.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: V3.green, size: 40),
            onPressed: () => Navigator.of(context).maybePop()),
        title: Text('Change password', style: V3.tight(20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
              widget.email.isEmpty
                  ? 'Choose a new password. You stay signed in on this phone.'
                  : 'Choose a new password for ${widget.email}. You stay signed in on this phone.',
              style: V3.inter(14, color: V3.muted, height: 1.45)),
          const SizedBox(height: 18),
          V3Field(
            label: 'New password',
            controller: _password,
            obscure: !_show,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            trailing: V3EyeButton(
                shown: _show, onTap: () => setState(() => _show = !_show)),
          ),
          const SizedBox(height: 8),
          V3PasswordRuleChips(_password.text),
          const SizedBox(height: 14),
          V3Field(
            label: 'Confirm new password',
            controller: _confirm,
            obscure: !_show,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          if (_confirm.text.isNotEmpty && _confirm.text != _password.text)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('The two passwords are not the same yet.',
                  style: V3.inter(13, color: V3.muted)),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            V3ErrorText(_error!),
          ],
          const SizedBox(height: 22),
          V3PrimaryButton(
              label: 'Change password',
              onPressed: _ready ? _save : null,
              busy: _busy),
        ],
      ),
    );
  }
}
