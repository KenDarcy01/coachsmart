import 'package:flutter_test/flutter_test.dart';
import 'package:coach_smart_v2/v3/sport/v3_team_gender.dart';

void main() {
  test('Hurling reads Camogie only on a female team', () {
    expect(V3TeamGender.codeFor('Hurling', true), 'Camogie');
    expect(V3TeamGender.codeFor('Hurling', false), 'Hurling');
    expect(V3TeamGender.codeFor('Football', true), 'Football');
  });

  test('code() uses the remembered team gender', () {
    V3TeamGender.remember(901, true);
    V3TeamGender.remember(902, false);
    expect(V3TeamGender.code('Hurling', 901), 'Camogie');
    expect(V3TeamGender.code('Hurling', 902), 'Hurling');
    expect(V3TeamGender.code('Hurling', 903), 'Hurling');
    expect(V3TeamGender.code('Hurling', null), 'Hurling');
  });

  test('default title matches the home list', () {
    String t(String title, String code, String type,
            [String opp = '', bool f = false]) =>
        V3TeamGender.defaultTitle(
            title: title, code: code, type: type, opposition: opp, female: f);
    expect(t('', 'Hurling', 'Training', '', true), 'Camogie Training');
    expect(t('', 'Hurling', 'Training'), 'Hurling Training');
    expect(t('', 'Hurling', 'Match', 'Raheny', true), 'Camogie Match (Raheny)');
    expect(t('', 'Football', 'Training', 'Raheny'), 'Football Training');
    expect(t('Hurling blitz', 'Hurling', 'Match', '', true), 'Camogie blitz');
    expect(t('Hurling blitz', 'Hurling', 'Match'), 'Hurling blitz');
    expect(t('', '', 'Match'), 'Match');
  });
}
