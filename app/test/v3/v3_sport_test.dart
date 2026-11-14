import 'package:flutter_test/flutter_test.dart';

import 'package:coach_smart_v2/v3/game_upload/v3_game_upload_models.dart';
import 'package:coach_smart_v2/v3/games/v3_game_models.dart';
import 'package:coach_smart_v2/v3/sport/v3_sport.dart';

void main() {
  test('sport from club sport_id, GAA when unknown', () {
    expect(V3Sport.fromId(1), V3Sport.gaa);
    expect(V3Sport.fromId(2), V3Sport.soccer);
    expect(V3Sport.fromId(3), V3Sport.rugby);
    expect(V3Sport.fromId(null), V3Sport.gaa);
    expect(V3Sport.fromId(99), V3Sport.gaa);
  });

  test('scores read the sport\'s way', () {
    expect(V3Sport.gaa.score(1, 5), '1-05');
    expect(V3Sport.gaa.score(0, 12), '0-12');
    expect(V3Sport.soccer.score(2, 0), '6');
  });

  test('match start wording', () {
    expect(V3Sport.gaa.matchStart, 'Throw-in');
    expect(V3Sport.soccer.matchStart, 'Kick-off');
    expect(V3Sport.rugby.matchStart, 'Kick-off');
  });

  test('Camogie only for GAA female hurling', () {
    expect(V3Sport.gaa.codeLabel('Hurling', female: true), 'Camogie');
    expect(V3Sport.gaa.codeLabel('Hurling'), 'Hurling');
    expect(V3Sport.gaa.codeLabel('Football', female: true), 'Football');
    expect(V3Sport.rugby.codeLabel('Rugby', female: true), 'Rugby');
  });

  test('ball word: sliotar for hurling and camogie', () {
    expect(V3Sport.gaa.ballFor('Hurling'), 'sliotar');
    expect(V3Sport.gaa.ballFor('Camogie'), 'sliotar');
    expect(V3Sport.gaa.ballFor('Football'), 'ball');
    expect(V3Sport.rugby.ballFor('Rugby'), 'ball');
  });

  test('short club names', () {
    expect(V3Sport.gaa.shortClub('Clontarf GAA'), 'Clontarf');
    expect(V3Sport.gaa.shortClub('Kilmacud Crokes'), 'Kilmacud Crokes');
    expect(V3Sport.rugby.shortClub('Clontarf RFC'), 'Clontarf');
    expect(V3Sport.rugby.shortClub('Clontarf Rugby'), 'Clontarf');
    expect(V3Sport.soccer.shortClub('Clontarf FC'), 'Clontarf');
    expect(V3Sport.soccer.shortClub('FC'), 'FC');
  });

  test('games carry a sport, GAA when missing', () {
    expect(V3Game.fromJson({'game_id': 1, 'game_name': 'x'}).sportId, 1);
    final g = V3Game.fromJson({'game_id': 2, 'game_name': 'y', 'sport_id': 3});
    expect(g.sportId, 3);
    expect(g.copyWith(name: 'z').sportId, 3);
    expect(g.toJson()['sport_id'], 3);
  });

  test('game codes and skills per sport', () {
    expect(V3Sport.gaa.pickCode, isTrue);
    expect(V3Sport.soccer.pickCode, isFalse);
    expect(V3Sport.rugby.gameCodes, ['Rugby']);
    expect(guVisibleSkills(['Soccer'], sport: V3Sport.soccer),
        contains('First Touch'));
    expect(guVisibleSkills(['Rugby'], sport: V3Sport.rugby),
        isNot(contains('Handpass')));
    expect(guVisibleSkills(['Hurling']), isNot(contains('Kick Pass')));
    expect(
        guSaveProblem(name: 'x', type: 'Game', codes: [], sport: V3Sport.rugby),
        'Please select a Code (Rugby)');
    expect(guRevisePlaceholder(['Soccer'], sport: V3Sport.soccer),
        isNot(contains('kick')));
  });
}
