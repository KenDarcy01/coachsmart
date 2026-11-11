import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/join_team/v3_join_team_api.dart';
import 'package:coach_smart_v2/v3/join_team/v3_join_team_models.dart';
import 'package:coach_smart_v2/v3/join_team/v3_join_team_page.dart';

/// A fake backend: records calls and answers with canned data.
class FakeApi extends JoinTeamApi {
  FakeApi({this.createAnswer, this.accessAnswer, this.lookupAnswer});
  final dynamic createAnswer, accessAnswer, lookupAnswer;
  final calls = <String>[];

  @override
  Future<({String firstName, String lastName, String email})> me() async =>
      (firstName: 'Ken', lastName: 'Darcy', email: 'ken@example.com');

  @override
  Future<dynamic> teamByCode(String code) async {
    calls.add('team:$code');
    return code == 'ABC123' ? {'team_name': 'U12 Girls'} : null;
  }

  @override
  Future<dynamic> createMemberByCode(
      {required String firstName,
      required String lastName,
      required String code}) async {
    calls.add('create:$firstName $lastName:$code');
    return createAnswer;
  }

  @override
  Future<dynamic> requestMemberAccess(int memberId, String code) async {
    calls.add('access:$memberId:$code');
    return accessAnswer;
  }

  @override
  Future<dynamic> lookupMemberByCode(String memberCode) async {
    calls.add('lookup:$memberCode');
    return lookupAnswer;
  }

  @override
  Future<void> requestNewTeam(Map<String, dynamic> body) async {
    calls.add('newteam:${body['club_name']}:${body['county']}');
  }
}

Future<void> pumpPage(WidgetTester tester, FakeApi api) async {
  tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: V3JoinTeamPage(api: api)));
  await tester.pumpAndSettle();
}

void main() {
  group('models', () {
    test('codes and the live lookup', () {
      expect(cleanCode('  abc12 '), 'ABC12');
      expect(shouldLookUp('ab'), isFalse);
      expect(shouldLookUp('abc'), isTrue);
      expect(teamNameFromLookup({'team_name': 'U12'}), 'U12');
      expect(teamNameFromLookup({'team_name': ''}), isNull);
      expect(teamNameFromLookup(null), isNull);
      expect(requestButtonLabel(null), 'Request to Join');
      expect(requestButtonLabel('U12'), 'Request to Join U12');
    });

    test('create_new_member_by_code answers', () {
      JoinResult r(Map m, [String? t]) =>
          JoinResult.fromRpc(m, resolvedTeam: t, memberName: 'Aoife Ryan');
      expect(r({'status': 'pending', 'team_name': 'U12'}).outcome,
          JoinOutcome.pending);
      expect(r({'status': 'pending'}, 'U14').teamName, 'U14');
      expect(r({'status': 'pending'}).teamName, 'the team');
      expect(r({'status': 'error', 'message': 'Bad code'}).message, 'Bad code');
      expect(r({'status': 'already_member'}, 'U12').message,
          'Aoife Ryan is already linked to your account on U12.');
      final d = r({'status': 'duplicate', 'member_id': 9, 'team_name': 'U12'});
      expect(d.outcome, JoinOutcome.duplicate);
      expect(d.memberId, 9);
      expect(r({'status': 'duplicate'}).memberId, isNull);
      expect(
          r({'status': 'already_pending'}).outcome, JoinOutcome.alreadyPending);
      expect(r({'status': 'pending_other'}).outcome, JoinOutcome.pendingOther);
      expect(r({}).outcome, JoinOutcome.unknown);
    });

    test('member code lookup and access request', () {
      expect(MemberLookup.fromRpc(null).error, kTryAgain);
      expect(MemberLookup.fromRpc({'status': 'not_found'}).error,
          'No member found with that code. Please check and try again.');
      final f = MemberLookup.fromRpc({
        'status': 'found',
        'member_id': 4,
        'first_name': 'Aoife',
        'last_name': 'Ryan',
        'team_name': 'U12',
        'team_code': 'ABC123'
      });
      expect(f.found, isTrue);
      expect(f.name, 'Aoife Ryan');
      expect(f.teamCode, 'ABC123');
      expect(accessRequestError({'success': true}), isNull);
      expect(accessRequestError({'success': false, 'message': 'No'}), 'No');
      expect(accessRequestError(null), kTryAgain);
    });

    test('new team form and done text', () {
      expect(newTeamError(club: '', county: 'Cork'),
          'Please enter your club name.');
      expect(newTeamError(club: 'Clontarf', county: ''),
          'Please select your county.');
      expect(newTeamError(club: 'Clontarf', county: 'Dublin'), isNull);
      expect(
          newTeamBody(
              name: ' Ken ',
              email: 'k@x.ie',
              club: 'Clontarf',
              county: 'Dublin',
              notes: ' ')['notes'],
          isNull);
      expect(kCounties.length, 32);
      expect(doneText(1), contains('Your request has been sent.'));
      expect(doneText(2), contains('Your requests have been sent.'));
      expect(isEndStep(JoinStep.sent), isTrue);
      expect(isEndStep(JoinStep.code), isFalse);
    });
  });

  testWidgets('join as myself: live lookup, request sent, all set',
      (tester) async {
    final api =
        FakeApi(createAnswer: {'status': 'pending', 'team_name': 'U12 Girls'});
    await pumpPage(tester, api);
    expect(find.text('Join or set up a team'), findsOneWidget);
    await tester.tap(find.text('Join as myself'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the team joining code'), findsOneWidget);
    expect(find.textContaining('Joining as Ken Darcy', findRichText: true),
        findsOneWidget);

    // Empty code is caught before any call.
    await tester.tap(find.text('Request to Join'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter the team joining code.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'abc123');
    await tester.pump();
    expect(find.text('Looking up code…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('U12 Girls'), findsOneWidget);
    expect(find.text('Request to Join U12 Girls'), findsOneWidget);

    await tester.tap(find.text('Request to Join U12 Girls'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('create:Ken Darcy:ABC123'));
    expect(find.text('Request sent!'), findsOneWidget);

    await tester.tap(find.text("I'm done for now"));
    await tester.pumpAndSettle();
    expect(find.text("You're all set!"), findsOneWidget);
    expect(find.textContaining('Your request has been sent.'), findsOneWidget);
  });

  testWidgets('someone else: duplicate, request access to their profile',
      (tester) async {
    final api = FakeApi(createAnswer: {
      'status': 'duplicate',
      'member_id': 42,
      'team_name': 'U12 Girls'
    }, accessAnswer: {
      'success': true
    });
    await pumpPage(tester, api);
    await tester.tap(find.text('Register someone else'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
        find.text('Please enter their first and last name.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Aoife');
    await tester.enterText(find.byType(TextField).at(1), 'Ryan');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zz9');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Code not recognised'), findsOneWidget);
    await tester.tap(find.text('Request to Join'));
    await tester.pumpAndSettle();
    expect(find.text('Already on the roster'), findsOneWidget);
    expect(find.text('Aoife Ryan'), findsOneWidget);

    await tester.tap(find.text('Yes — request access to their profile'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('access:42:ZZ9'));
    expect(find.text('Request sent!'), findsOneWidget);

    // Add another person goes back to the start with the new heading.
    await tester.tap(find.text('Add another person'));
    await tester.pumpAndSettle();
    expect(find.text('Register another person?'), findsOneWidget);
  });

  testWidgets('member code: not found, then found and denied', (tester) async {
    final api = FakeApi(lookupAnswer: {
      'status': 'found',
      'member_id': 7,
      'first_name': 'Sean',
      'last_name': 'Byrne',
      'team_name': 'U10 Boys',
      'team_code': 'TEAM10'
    });
    await pumpPage(tester, api);
    await tester.tap(find.text('Register someone else'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use it instead'));
    await tester.pumpAndSettle();
    expect(find.text('Use their member code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'mb1');
    await tester.tap(find.text('Find Member'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('lookup:MB1'));
    expect(find.text('Sean Byrne'), findsOneWidget);
    await tester.tap(find.text('No — enter a different name'));
    await tester.pumpAndSettle();
    expect(find.text('Use their member code'), findsOneWidget);
  });

  testWidgets('already pending and pending other show their screens',
      (tester) async {
    final api = FakeApi(createAnswer: {'status': 'pending_other'});
    await pumpPage(tester, api);
    await tester.tap(find.text('Join as myself'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.tap(find.text('Request to Join'));
    await tester.pumpAndSettle();
    expect(find.text('Already submitted by someone else'), findsOneWidget);
  });

  testWidgets('new team request: checks then sends', (tester) async {
    final api = FakeApi();
    await pumpPage(tester, api);
    await tester.tap(find.text('Set up a new team'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your team on CoachSmart'), findsOneWidget);
    expect(find.text('Ken Darcy'), findsOneWidget);
    await tester.tap(find.text('Send Request'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your club name.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), 'Clontarf GAA');
    await tester.tap(find.text('Select county…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dublin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Request'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('newteam:Clontarf GAA:Dublin'));
    expect(find.text('Request received!'), findsOneWidget);
    expect(find.textContaining('ken@example.com', findRichText: true),
        findsOneWidget);
  });
}
