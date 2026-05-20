import '../database.dart';

class MatchScoreTypesTable extends SupabaseTable<MatchScoreTypesRow> {
  @override
  String get tableName => 'match_score_types';

  @override
  MatchScoreTypesRow createRow(Map<String, dynamic> data) =>
      MatchScoreTypesRow(data);
}

class MatchScoreTypesRow extends SupabaseDataRow {
  MatchScoreTypesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchScoreTypesTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get scoreType => getField<String>('score_type');
  set scoreType(String? value) => setField<String>('score_type', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);
}
