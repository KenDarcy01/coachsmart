import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/onboarding/v3_onboarding_backend.dart';
import 'package:coach_smart_v2/v3/onboarding/v3_onboarding_models.dart';
import 'package:coach_smart_v2/v3/onboarding/v3_onboarding_page.dart';

class FakeBackend implements OnboardingBackend {
  Map<String, dynamic>? user = {
    'user_id': 'u1',
    'first_name': 'Ken',
    'last_name': 'Darcy'
  };
  List<dynamic> owned = [];
  bool active = false;
  List<dynamic> pendingJoin = [];
  List<dynamic> pendingAccess = [];
  dynamic joinResult = {'status': 'pending', 'team_name': 'U12 Girls'};
  dynamic accessResult = {'success': true};
  dynamic lookupResult;
  String? newTeamError;
  final calls = <String>[];
  final statuses = <String>[];
  final status = StreamController<String?>.broadcast();

  @override
  String get userId => 'u1';
  @override
  String get email => 'ken@example.com';
  @override
  Future<Map<String, dynamic>?> loadUser() async => user;
  @override
  Future<List<dynamic>> ownedMembers() async => owned;
  @override
  Future<bool> hasActiveTeamLink(List<int> ids) async => active;
  @override
  Future<List<dynamic>> pendingJoinRequests(List<int> ids) async => pendingJoin;
  @override
  Future<List<dynamic>> pendingAccessRequests() async => pendingAccess;
  @override
  Future<void> saveDetails(String f, String l) async => calls.add('save $f $l');
  @override
  Future<dynamic> teamByCode(String code) async {
    calls.add('team $code');
    return code == 'ABC123' ? {'team_name': 'U12 Girls'} : null;
  }

  @override
  Future<dynamic> createMemberByCode(String f, String l, String code) async {
    calls.add('join $f $l $code');
    return joinResult;
  }

  @override
  Future<dynamic> requestMemberAccess(int id, String code) async {
    calls.add('access $id $code');
    return accessResult;
  }

  @override
  Future<dynamic> lookupMemberByCode(String c) async => lookupResult;
  @override
  Future<void> updateOnboardingStatus(String s) async => statuses.add(s);
  @override
  Future<String?> requestNewTeam(Map<String, dynamic> body) async {
    calls.add('newteam ${body['club_name']} ${body['county']}');
    return newTeamError;
  }

  @override
  Stream<String?> onboardingStatus() => status.stream;
}

Widget _app(FakeBackend b, {VoidCallback? onFinished}) =>
    MaterialApp(home: V3OnboardingPage(testBackend: b, onFinished: onFinished));

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1290, 4200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  group('models', () {
    test('needs details without a first name', () {
      expect(obNeedsDetails(null), isTrue);
      expect(obNeedsDetails({'first_name': '  '}), isTrue);
      expect(obNeedsDetails({'first_name': 'Ken'}), isFalse);
    });

    test('route decision', () {
      expect(obDecideRoute(ownedIds: [], hasActiveLink: false, pendingCount: 0),
          ObRoute.who);
      expect(obDecideRoute(ownedIds: [1], hasActiveLink: true, pendingCount: 2),
          ObRoute.home);
      expect(
          obDecideRoute(ownedIds: [1], hasActiveLink: false, pendingCount: 1),
          ObRoute.pendingStatus);
      expect(
          obDecideRoute(ownedIds: [1], hasActiveLink: false, pendingCount: 0),
          ObRoute.who);
    });

    test('pending items', () {
      final items = obPendingItems([
        {
          'member_id': 4,
          'teams': {'team_name': 'U10 Boys'},
          'members': {'first_name': 'Tom', 'last_name': 'Darcy'}
        }
      ], [
        {
          'members': {
            'first_name': 'Amy',
            'last_name': 'Darcy',
            'member_team_link': [
              {
                'status': 'pending',
                'teams': {'team_name': 'X'}
              },
              {
                'status': 'active',
                'teams': {'team_name': 'U14 Girls'}
              },
            ]
          }
        },
        {
          'members': {'first_name': 'Sam', 'last_name': 'Darcy'}
        }
      ]);
      expect(items[0].label, 'Join request pending for U10 Boys');
      expect(items[0].isLink, isFalse);
      expect(items[1].label, 'Account link request pending for U14 Girls');
      expect(items[2].label, 'Account link request pending for your team');
      expect(items[1].name, 'Amy Darcy');
    });

    test('join result parsing and team fallbacks', () {
      expect(obParseJoin({'status': 'error', 'message': 'Bad code'}).message,
          'Bad code');
      final d = obParseJoin({'status': 'duplicate', 'member_id': 9},
          resolvedTeamName: 'U8');
      expect(d.kind, ObJoinKind.duplicate);
      expect(d.memberId, 9);
      expect(d.teamName, 'U8');
      expect(obParseJoin({'status': 'pending'}).teamName, 'the team');
      expect(obParseJoin({'status': 'already_pending'}).kind,
          ObJoinKind.alreadyPending);
      expect(obParseJoin({'status': 'pending_other'}).kind,
          ObJoinKind.pendingOther);
    });

    test('member lookup', () {
      expect(obParseMemberLookup(null).error, obTryAgain);
      expect(obParseMemberLookup({'status': 'not_found'}).error,
          'No member found with that code. Please check and try again.');
      final f = obParseMemberLookup({
        'status': 'found',
        'member_id': 3,
        'first_name': 'Aoife',
        'last_name': 'Kelly',
        'team_name': 'U12 Girls',
        'team_code': 'ABC123'
      });
      expect(f.error, isNull);
      expect(f.name, 'Aoife Kelly');
      expect(f.teamCode, 'ABC123');
    });

    test('access, code and new team helpers', () {
      expect(obAccessError({'success': true}), isNull);
      expect(obAccessError({'success': false, 'message': 'No'}), 'No');
      expect(obAccessError(null), obTryAgain);
      expect(obShouldLookUp('AB'), isFalse);
      expect(obShouldLookUp('ABC'), isTrue);
      expect(obJoinLabel(null), 'Request to Join');
      expect(obJoinLabel('U8'), 'Request to Join U8');
      expect(obNewTeamProblem(club: '', county: 'Cork'),
          'Please enter your club name.');
      expect(obNewTeamProblem(club: 'X', county: ''),
          'Please select your county.');
      expect(
          obNewTeamBody(
              name: 'K',
              email: 'e',
              club: ' X ',
              county: 'Cork',
              notes: ' ')['notes'],
          isNull);
      expect(obNewTeamError({'error': 'Nope'}), 'Nope');
      expect(obNewTeamError(null), 'Something went wrong');
      expect(obCounties.length, 32);
    });

    test('history does not go back past who into details', () {
      final h = ObHistory()
        ..push(ObScreen.details)
        ..push(ObScreen.who)
        ..push(ObScreen.who)
        ..push(ObScreen.code);
      expect(h.stack.length, 3);
      expect(h.back(hasFirstName: true), ObScreen.who);
      expect(h.back(hasFirstName: true), ObScreen.who);
      expect(h.stack, [ObScreen.who]);
      expect(h.back(hasFirstName: true), isNull);
      final h2 = ObHistory()
        ..push(ObScreen.details)
        ..push(ObScreen.who);
      expect(h2.back(hasFirstName: false), ObScreen.details);
    });

    test('progress', () {
      expect(obProgress(ObScreen.code, codeTotal: 4)!.label, 'Step 4 of 4');
      expect(obProgress(ObScreen.sent), isNull);
    });
  });

  group('page', () {
    testWidgets('no name asks for it, then saves and shows the choices',
        (tester) async {
      _tall(tester);
      final b = FakeBackend()..user = null;
      await tester.pumpWidget(_app(b));
      await tester.pumpAndSettle();
      expect(find.text("Welcome! Let's get you set up."), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(
          find.text('Please enter your first and last name.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Ken');
      await tester.enterText(find.byType(TextField).at(1), 'Darcy');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(b.calls, contains('save Ken Darcy'));
      expect(find.text('How would you like to get started?'), findsOneWidget);
    });

    testWidgets('join as myself: code preview, request sent', (tester) async {
      _tall(tester);
      final b = FakeBackend();
      await tester.pumpWidget(_app(b));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join as myself'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      expect(find.text('Joining as Ken Darcy', findRichText: true),
          findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('team-code')), 'abc123');
      await tester.pump();
      expect(find.text('Looking up code…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Request to Join U12 Girls'), findsOneWidget);
      await tester.tap(find.text('Request to Join U12 Girls'));
      await tester.pumpAndSettle();
      expect(b.calls, contains('join Ken Darcy ABC123'));
      expect(b.statuses, ['pending']);
      expect(find.text('Request sent!'), findsOneWidget);
      await tester.tap(find.text('Add another person'));
      await tester.pumpAndSettle();
      expect(find.text('Register another person?'), findsOneWidget);
    });

    testWidgets('someone else already on the roster: request access',
        (tester) async {
      _tall(tester);
      final b = FakeBackend()
        ..joinResult = {
          'status': 'duplicate',
          'member_id': 42,
          'team_name': 'U12 Girls'
        };
      await tester.pumpWidget(_app(b));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Register someone else'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Aoife');
      await tester.enterText(find.byType(TextField).at(1), 'Darcy');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 4 OF 4'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('team-code')), 'XY');
      await tester.tap(find.text('Request to Join'));
      await tester.pumpAndSettle();
      expect(find.text('Already on the roster'), findsOneWidget);
      await tester.tap(find.text('Yes — request access to their profile'));
      await tester.pumpAndSettle();
      expect(b.calls, contains('access 42 XY'));
      expect(find.text('Request sent!'), findsOneWidget);
    });

    testWidgets('pending requests show the status screen; approval goes home',
        (tester) async {
      _tall(tester);
      var finished = 0;
      final b = FakeBackend()
        ..owned = [
          {'member_id': 5}
        ]
        ..pendingJoin = [
          {
            'member_id': 5,
            'teams': {'team_name': 'U10 Boys'},
            'members': {'first_name': 'Tom', 'last_name': 'Darcy'}
          }
        ];
      await tester.pumpWidget(_app(b, onFinished: () => finished++));
      await tester.pumpAndSettle();
      expect(find.text('Join request pending for U10 Boys'), findsOneWidget);
      await tester.tap(find.text('Check approval status'));
      await tester.pumpAndSettle();
      expect(find.text('Still waiting — no approvals yet. Check back soon.'),
          findsOneWidget);
      b.status.add('active');
      await tester.pumpAndSettle();
      expect(find.text("You're approved"), findsOneWidget);
      b.active = true;
      await tester.tap(find.text('Check approval status'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });

    testWidgets('new team request', (tester) async {
      _tall(tester);
      final b = FakeBackend();
      await tester.pumpWidget(_app(b));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set up a new team'));
      await tester.pumpAndSettle();
      expect(find.text('Ken Darcy'), findsOneWidget);
      await tester.tap(find.text('Send Request'));
      await tester.pump();
      expect(find.text('Please enter your club name.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(2), 'Ballytown GAA');
      await tester.tap(find.byKey(const ValueKey('county')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cork'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Request'));
      await tester.pumpAndSettle();
      expect(b.calls, contains('newteam Ballytown GAA Cork'));
      expect(find.text('Request received!'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('How would you like to get started?'), findsOneWidget);
    });
  });
}
