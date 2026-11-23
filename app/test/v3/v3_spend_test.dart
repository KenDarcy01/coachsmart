import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/spend/v3_spend_models.dart';
import 'package:coach_smart_v2/v3/spend/v3_spend_page.dart';
import 'package:coach_smart_v2/v3/spend/v3_gear_page.dart';

Map<String, dynamic> sample() => {
      'team': {'team_id': 73, 'team_name': 'Clontarf Boys 2013', 'club_id': 1},
      'club': {'club_id': 1, 'club_name': 'Clontarf GAA'},
      'season': 2026,
      'budget': 1000,
      'used': 612.5,
      'waiting': 40,
      'categories': ['Ref fee', 'Travel', 'Other'],
      'expenses': [
        {
          'expense_id': 1,
          'spent_on': '2026-11-21',
          'amount': 40,
          'shop': 'Referee',
          'category': 'Ref fee',
          'payback': 'bank',
          'status': 'submitted',
          'by': 'Ken D',
          'mine': true,
          'has_receipt': true,
          'created_at': '2026-11-21T10:00:00Z',
        },
        {
          'expense_id': 2,
          'spent_on': '2026-11-15',
          'amount': 220,
          'category': 'Travel',
          'payback': 'bank',
          'status': 'paid',
          'by': 'Ken D',
          'created_at': '2026-11-15T10:00:00Z',
        },
      ],
      'gear': [
        {
          'gear_request_id': 5,
          'status': 'approved',
          'by': 'Seán M',
          'total': 186,
          'created_at': '2026-11-19T10:00:00Z',
          'lines': [
            {'name': 'Footballs, size 4', 'qty': 6, 'unit_price': 21},
            {'name': 'Bibs (set of 10)', 'qty': 2, 'unit_price': 30},
          ],
        },
      ],
      'items': [
        {
          'gear_item_id': 10,
          'name': 'Footballs, size 4',
          'category': 'Balls',
          'unit_price': 21
        },
        {
          'gear_item_id': 11,
          'name': 'Cones (set of 50)',
          'category': 'Training kit'
        },
      ],
      'events': [
        {
          'event_id': 9,
          'opposition': 'St Vincents',
          'event_date_time': '2026-11-21T11:00:00Z'
        },
      ],
    };

void main() {
  test('models: money, budget, recent order, status labels', () {
    final d = SpendData.fromJson(sample());
    expect(spendEuro(18.4), '€18.40');
    expect(spendEuro(1000, short: true), '€1,000');
    expect(spendEuro(1234567.5), '€1,234,567.50');
    expect(d.left, 387.5);
    expect(d.usedShare, closeTo(.6125, .0001));
    expect(d.recent.first.expense?.id, 1);
    expect(d.recent[1].gear?.summary,
        '6 × Footballs, size 4, 2 × Bibs (set of 10)');
    expect(d.expenses.first.pill.label, 'Waiting for the club');
    expect(d.gear.first.pill.label, 'Approved, being ordered');
    expect(d.expenses[1].pill.label, 'Paid back');
    expect(d.eventOn(DateTime(2026, 11, 21))?.label,
        'Match v St Vincents (Sat 21 Nov)');
    expect(d.eventOn(DateTime(2026, 11, 20)), isNull);
  });

  testWidgets('team page shows the buttons, budget and items', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: V3SpendPage(teamId: 73, testData: sample())));
    await tester.pumpAndSettle();
    expect(find.text('Add expense'), findsOneWidget);
    expect(find.text('Request gear'), findsOneWidget);
    expect(find.text('€612.50 of €1,000 used'), findsOneWidget);
    expect(find.text('€387.50 left'), findsOneWidget);
    expect(find.text('Ref fee, Referee'), findsOneWidget);
    expect(find.text('Waiting for the club'), findsOneWidget);
  });

  testWidgets('gear page counts items and totals the price', (tester) async {
    final d = SpendData.fromJson(sample());
    await tester.pumpWidget(MaterialApp(home: V3GearPage(teamId: 73, data: d)));
    await tester.pumpAndSettle();
    expect(find.text('Pick what you need'), findsOneWidget);
    final plus = find.descendant(
        of: find.byKey(const ValueKey('gear-10')),
        matching: find.byIcon(Icons.add));
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    expect(find.text('Request 2 items · €42'), findsOneWidget);
  });
}
