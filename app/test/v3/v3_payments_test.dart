import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/event/v3_payments_models.dart';
import 'package:coach_smart_v2/v3/event/v3_payments_page.dart';

Map<String, dynamic> paid(int id, String member, String user, int amount) => {
      'payment_id': id,
      'member_id': id,
      'member_full_name': member,
      'user_full_name': user,
      'payment_date': '04 Nov 2026',
      'amount_paid': amount,
      'net_amount': amount - 45,
      'fee_amount': 45,
    };

Map<String, dynamic> unpaid(int id, String member) => {
      'member_id': id,
      'member_full_name': member,
      'role_name': 'Player',
      'role_level': 10,
    };

PaymentsData sample() => PaymentsData.fromJson(
      paidRows: [
        paid(1, 'Caoimhe Byrne', 'Mary Byrne', 1000),
        paid(2, 'Aimee Morris', 'Jane Morris', 1000),
      ],
      unpaidRows: [unpaid(3, 'Ella Walsh'), unpaid(4, 'Fiadh Nolan')],
      price: 1000,
      title: 'Football Match v Raheny',
    );

void main() {
  test('totals, labels and ordering', () {
    final d = sample();
    expect(d.collected, 2000);
    expect(d.toClub, 1910);
    expect(d.stillToPay, 2000);
    expect(d.paid.first.memberName, 'Aimee Morris');
    expect(d.paid.first.subtitle, 'Paid by Jane Morris · Wed 4 Nov');
    expect(d.remindLabel, "Remind the 2 who haven't paid");
    expect(euro(955), '€9.55');
    expect(nameInitials("Grace O'Neill"), 'GO');
    expect(paidDateLabel('bad'), 'bad');
    final one = PaymentsData(
        paid: const [],
        unpaid: [UnpaidRow.fromJson(unpaid(1, 'A B'))],
        price: 500);
    expect(one.remindLabel, "Remind the 1 who hasn't paid");
    expect(one.stillToPay, 500);
  });

  testWidgets('page shows totals, tabs, rows and the reminder button',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: V3PaymentsPage(eventId: 1, testData: sample())));
    await tester.pumpAndSettle();
    expect(find.text('Football Match v Raheny'), findsOneWidget);
    expect(find.text('Collected'), findsOneWidget);
    expect(find.text('€20.00'), findsNWidgets(2));
    expect(find.text('€19.10'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Not paid'), findsOneWidget);
    expect(find.text('Aimee Morris'), findsOneWidget);
    expect(find.text('net €9.55'), findsNWidgets(2));
    await tester.tap(find.text('Not paid'));
    await tester.pumpAndSettle();
    expect(find.text('Ella Walsh'), findsOneWidget);
    expect(find.text("Remind the 2 who haven't paid"), findsOneWidget);
    await tester.tap(find.text("Remind the 2 who haven't paid"));
    await tester.pumpAndSettle();
    expect(find.text('Send payment reminders?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Send payment reminders?'), findsNothing);
  });
}
