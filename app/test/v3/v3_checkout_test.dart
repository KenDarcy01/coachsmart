import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/event/v3_checkout_page.dart';

void main() {
  test('paying member names', () {
    expect(payingMemberName({'first_name': 'Aimee', 'last_name': 'Morris'}),
        'Aimee Morris');
    expect(payingMemberName({'member_name': 'Anna Ryan'}), 'Anna Ryan');
    expect(payingMemberName('x'), '');
  });

  testWidgets('checkout lists members and the total', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: V3CheckoutPage(
            eventId: 1,
            numPayments: 2,
            paymentAmount: 1000,
            checkoutUrl: 'https://example.com/pay',
            payingMembers: [
          {'first_name': 'Aimee', 'last_name': 'Morris'},
          {'first_name': 'Anna', 'last_name': 'Ryan'},
        ])));
    await tester.pumpAndSettle();
    expect(find.text('Aimee Morris'), findsOneWidget);
    expect(find.text('€10.00'), findsNWidgets(2));
    expect(find.text('€20.00'), findsOneWidget);
    expect(find.text('Pay now'), findsOneWidget);
  });

  testWidgets('failed page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: V3CheckoutFailedPage()));
    await tester.pumpAndSettle();
    expect(find.text('Payment not made'), findsOneWidget);
    expect(find.text('Back to Home'), findsOneWidget);
  });
}
