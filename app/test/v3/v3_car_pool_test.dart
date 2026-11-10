import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/carpool/v3_car_pool_models.dart';
import 'package:coach_smart_v2/v3/carpool/v3_car_pool_page.dart';
import 'package:coach_smart_v2/v3/carpool/v3_car_pools_page.dart';

Map<String, dynamic> pools() => {
      'current_user_has_pool': false,
      'current_user_role_level': 30,
      'car_pools': [
        {
          'car_pool_id': 1,
          'driver_user_id': 'u1',
          'driver_name': 'Mary Byrne',
          'total_seats': 4,
          'reserved_seats': 2,
          'free_seats': 2,
          'created_at': '2026-11-01',
        },
        {
          'car_pool_id': 2,
          'driver_user_id': 'u2',
          'driver_name': 'Tom Walsh',
          'total_seats': 3,
          'reserved_seats': 3,
          'free_seats': 0,
          'created_at': '2026-11-02',
        },
      ],
    };

Map<String, dynamic> pool() => {
      'status': 'open',
      'event_id': 9,
      'car_pool_id': 1,
      'driver_name': 'Mary Byrne',
      'driver_user_id': 'u1',
      'driver_email': 'mary@example.com',
      'driver_phone': '0870000000',
      'total_seats': 4,
      'reserved_seats': 2,
      'free_seats': 2,
      'event_title': 'Football Match v Raheny',
      'team_name': 'Boys 2014',
      'event_date_formatted': 'Sat 7 Nov, 10:00',
      'associated_players_count': 1,
      'user_associated_members': [
        {'member_id': 101, 'member_name': 'Seán Byrne', 'profile_pic': ''}
      ],
      'reservations': [
        {
          'reservation_id': 11,
          'member_id': 102,
          'member_name': 'Cillian Walsh',
          'profile_pic': '',
          'reserved_at': '',
          'member_belongs_to_user': true,
          'associated_user_email': 'tom@example.com',
          'status': 'reserved',
        },
        {
          'reservation_id': 12,
          'member_id': 103,
          'member_name': 'Old One',
          'profile_pic': '',
          'reserved_at': '',
          'member_belongs_to_user': false,
          'associated_user_email': '',
          'status': 'cancelled',
        },
      ],
    };

void main() {
  test('helpers', () {
    expect(seatsLine(4, 2), '4 seats · 2 free');
    expect(seatsLine(1, 0), '1 seat · full');
    expect(nameInitials('Mary Byrne'), 'MB');
    expect(poolStatusLine(0, 3), 'This car pool is full.');
    expect(poolStatusLine(2, 0), 'No seats reserved yet.');
  });

  testWidgets('pools list with offer button', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: V3CarPoolsPage(eventId: 9, roleLevel: 30, testData: pools())));
    await tester.pumpAndSettle();
    expect(find.text('Offer a car pool'), findsOneWidget);
    expect(find.text('Mary Byrne'), findsOneWidget);
    expect(find.text('2 free'), findsOneWidget);
    expect(find.text('Full'), findsOneWidget);
    await tester.tap(find.text('Offer a car pool'));
    await tester.pumpAndSettle();
    expect(find.text('How many spare seats?'), findsOneWidget);
    expect(find.text('Offer 3 seats'), findsOneWidget);
  });

  testWidgets('pool detail shows tiles, reserve and only live seats',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: V3CarPoolPage(eventId: 9, carPoolId: 1, testData: pool())));
    await tester.pumpAndSettle();
    expect(find.text("Mary Byrne's car"), findsOneWidget);
    expect(find.text('Reserve a seat'), findsOneWidget);
    expect(find.text('Cillian Walsh'), findsOneWidget);
    expect(find.text('Old One'), findsNothing);
    expect(find.text('Cancel seat'), findsOneWidget);
    expect(find.text('Delete car pool'), findsNothing);
  });
}
