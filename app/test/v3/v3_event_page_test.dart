// Lays out the v3 event page with a full RPC-shaped payload so layout errors
// (infinite sizes, overflows) fail here instead of on Ken's phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:coach_smart_v2/v3/event/v3_event_page.dart';

Map<String, dynamic> payload({
  String type = 'Match',
  int role = 100,
  bool paid = true,
  int members = 2,
}) =>
    {
      'event_id': 1,
      'team_id': 5,
      'squad_id': 2,
      'squad_name': 'A squad',
      'event_status': 'active',
      'team_has_squads': true,
      'audience_id': 1,
      'event_role_level': 10,
      'event_link': 'https://dublingaa.ie/fixtures',
      'event_title': 'Football Match v Raheny',
      'team_name': 'Clontarf GAA Boys 2014',
      'event_date_time_formatted': 'Saturday, 07 November, 2099 at 10:00',
      'meet_time': '09:30',
      'event_type': type,
      'event_code': 'Football',
      'code_id': 3,
      'location_name': 'Seafield',
      'location_pin': 'https://maps.app.goo.gl/x',
      'opposition': 'Raheny',
      'event_details': 'Wear the white jerseys.',
      'home_away': 'Home',
      'request_attendance': true,
      'notify_admins_changes': true,
      'notify_admins_all': false,
      'created_by': 'Ken Darcy',
      'created_by_phone_number': '',
      'total_count': 19,
      'user_highest_role_level': role,
      'car_pooling_enabled': true,
      'payment_required': paid,
      'payment_amount': 1000,
      'event_paid': 1,
      'total_payments': 14,
      'total_amount_paid': 14000,
      'total_net_amount': 13600,
      'event_image': '',
      'new_gross_amount': 14000,
      'new_net_amount': 13600,
      'new_num_payments': 14,
      'accepted_player_count': 14,
      'declined_player_count': 3,
      'no_response_player_count': 2,
      'team_members': [
        for (var i = 0; i < members; i++)
          {
            'member_id': 10 + i,
            'first_name': i == 0 ? 'Aoife' : 'Seán',
            'last_name': 'Darcy',
            'profile_pic': '',
            'role_name': 'Player',
            'role_level': 10,
            'response_id': i == 0 ? 3 : 0,
            'attendance_status': '',
            'attendance_icon': '',
            'member_paid': i == 0 ? 1 : 0,
            'member_payment_id': 0,
            'member_payment_status': i == 0 ? 'confirmed' : '',
          }
      ],
      'accepted_attendance_summary': [
        {
          'role_id': 1,
          'role_name': 'Coach',
          'role_level': 100,
          'member_count': 3,
          'role_name_plural': 'Coaches'
        },
      ],
      'declined_attendance_summary': [],
      'no_response_attendance_summary': [
        {
          'role_id': 1,
          'role_name': 'Coach',
          'role_level': 100,
          'member_count': 1,
          'role_name_plural': 'Coaches'
        },
      ],
    };

Future<void> pump(WidgetTester tester, Map<String, dynamic> data) async {
  await tester.pumpWidget(MaterialApp(
    home: V3EventPage(eventID: 1, fromSearch: false, testData: data),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => tester_binding());

  testWidgets('admin on a paid match shows every section', (tester) async {
    await pump(tester, payload());
    expect(tester.takeException(), isNull);
    expect(find.text('YOUR REPLY'), findsOneWidget);
    expect(find.text('Attending'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Ken Darcy'), 300);
    expect(find.text('Ken Darcy'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ATTENDANCE'), 300);
    expect(tester.takeException(), isNull);
  });

  testWidgets('player on a free training session shows details',
      (tester) async {
    await pump(
        tester, payload(type: 'Training', role: 10, paid: false, members: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('DETAILS'), findsOneWidget);
    expect(find.text('Ken Darcy'), findsOneWidget);
  });
}

void tester_binding() {
  TestWidgetsFlutterBinding.ensureInitialized();
}
