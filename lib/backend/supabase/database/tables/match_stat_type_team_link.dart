import '../database.dart';

class MatchStatTypeTeamLinkTable
    extends SupabaseTable<MatchStatTypeTeamLinkRow> {
  @override
  String get tableName => 'match_stat_type_team_link';

  @override
  MatchStatTypeTeamLinkRow createRow(Map<String, dynamic> data) =>
      MatchStatTypeTeamLinkRow(data);
}

class MatchStatTypeTeamLinkRow extends SupabaseDataRow {
  MatchStatTypeTeamLinkRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchStatTypeTeamLinkTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get matchScoreTypeId => getField<int>('match_score_type_id');
  set matchScoreTypeId(int? value) =>
      setField<int>('match_score_type_id', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  bool? get status => getField<bool>('status');
  set status(bool? value) => setField<bool>('status', value);
}
