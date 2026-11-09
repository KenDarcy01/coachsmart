// The v3 sign-in screens build and lay out without touching the network.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:coach_smart_v2/v3/auth/v3_create_account_page.dart';
import 'package:coach_smart_v2/v3/auth/v3_reset_password_page.dart';
import 'package:coach_smart_v2/v3/auth/v3_sign_in_page.dart';
import 'package:coach_smart_v2/v3/auth/v3_verify_page.dart';
import 'package:coach_smart_v2/v3/auth/v3_auth_widgets.dart';

Widget _app(Widget page) => MaterialApp(home: page);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('sign in shows email, password and the links', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const V3SignInPage()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Sign in'), findsNWidgets(2)); // title and button
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.textContaining('Create an account'), findsOneWidget);
    expect(find.textContaining('Continue with'), findsNothing);
  });

  testWidgets('create account shows the live password rules', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const V3CreateAccountPage()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('8+ characters'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, '').last, 'Clontarf2026!');
    await tester.pump();
    expect(find.text('✓ a symbol'), findsOneWidget);
    expect(PasswordRules.ok('Clontarf2026!'), isTrue);
    expect(PasswordRules.ok('Clontarf2026'), isFalse);
  });

  testWidgets('verify shows six boxes and the address', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(_app(const V3VerifyPage(email: 'ken.darcy@gmail.com')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('ken.darcy@gmail.com', findRichText: true),
        findsOneWidget);
    expect(find.byType(V3CodeInput), findsOneWidget);
    expect(find.textContaining('Resend code'), findsOneWidget);
  });

  testWidgets('reset starts with email only', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const V3ResetPasswordPage()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Send code'), findsOneWidget);
    expect(find.text('Set new password'), findsNothing);
  });
}
