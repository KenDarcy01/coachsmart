// Thin wrapper over Supabase auth for the v3 screens. Messages are the
// plain-English ones users see.
import '/backend/supabase/supabase.dart';
import '/v3/tracking/v3_track.dart';

const kConfirmedUrl =
    'https://coach-smart-new-mpqa5l.web.app/auth/confirmed.html';

class V3AuthService {
  static GoTrueClient get _auth => SupaFlow.client.auth;

  /// Returns null on success, else a message. [notConfirmed] is set when the
  /// account exists but the email was never confirmed.
  static Future<String?> signIn(String email, String password,
      {void Function()? notConfirmed}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
      V3Track.event('login', {'method': 'email'});
      return null;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('not confirmed')) {
        notConfirmed?.call();
        return 'Your email address has not been confirmed yet.';
      }
      if (m.contains('banned')) {
        return 'This account has been deleted. Please contact support if you believe this is an error.';
      }
      try {
        final exists = await SupaFlow.client
            .rpc('check_email_exists', params: {'p_email': email.trim()});
        return exists == false
            ? 'No account found with that email address.'
            : 'Incorrect password. Please try again.';
      } catch (_) {
        return e.message;
      }
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Creates the account. Returns (error, signedIn): signedIn is true when
  /// the project does not require email confirmation.
  static Future<({String? error, bool signedIn})> signUp(
      String email, String password, String first, String last) async {
    try {
      V3Track.event('sign_up_started');
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: kConfirmedUrl,
        data: {'first_name': first.trim(), 'last_name': last.trim()},
      );
      // Supabase answers quietly for an existing email; no identities is
      // the only sign the account already exists.
      if (res.user != null && (res.user!.identities?.isEmpty ?? true)) {
        return (
          error:
              'An account with this email already exists. Please sign in instead.',
          signedIn: false
        );
      }
      return (error: null, signedIn: res.session != null);
    } on AuthException catch (e) {
      return (error: e.message, signedIn: false);
    } catch (_) {
      return (
        error: 'Something went wrong. Please try again.',
        signedIn: false
      );
    }
  }

  static Future<String?> resendSignUpCode(String email) async {
    try {
      await _auth.resend(
          type: OtpType.signup,
          email: email.trim(),
          emailRedirectTo: kConfirmedUrl);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  static Future<String?> verifySignUp(String email, String code) =>
      _verify(email, code, OtpType.signup);

  static Future<String?> verifyRecovery(String email, String code) =>
      _verify(email, code, OtpType.recovery);

  static Future<String?> _verify(String email, String code, OtpType t) async {
    try {
      final res =
          await _auth.verifyOTP(type: t, token: code, email: email.trim());
      if (res.session == null) return 'That code did not work. Try again.';
      return null;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('expired') || m.contains('invalid')) {
        return 'That code is wrong or has expired. Check the email or send a new one.';
      }
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  static Future<String?> sendRecoveryCode(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  static Future<String?> setPassword(String password) async {
    try {
      await _auth.updateUser(UserAttributes(password: password));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    }
  }

  /// Makes sure the signed-in user has a public.users row carrying the name
  /// given at sign-up. The confirm trigger creates the row with the email
  /// only; older accounts may have no row at all.
  static Future<void> ensureProfile(String first, String last) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final rows = await UsersTable()
          .queryRows(queryFn: (q) => q.eq('user_id', user.id), limit: 1);
      final f = first.trim();
      final l = last.trim();
      if (rows.isEmpty) {
        await UsersTable().insert({
          'user_id': user.id,
          'email_address': user.email,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          if (f.isNotEmpty) 'first_name': f,
          if (l.isNotEmpty) 'last_name': l,
        });
      } else if ((rows.first.firstName ?? '').isEmpty && f.isNotEmpty) {
        await UsersTable().update(
            data: {'first_name': f, 'last_name': l},
            matchingRows: (q) => q.eq('user_id', user.id));
      }
    } catch (_) {
      // Home copes with a missing name; onboarding asks again.
    }
  }
}
