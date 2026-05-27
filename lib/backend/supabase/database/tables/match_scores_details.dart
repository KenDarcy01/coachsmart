import '../database.dart';

class MatchScoresDetailsTable extends SupabaseTable<MatchScoresDetailsRow> {
  @override
  String get tableName => 'match_scores_details';

  @override
  MatchScoresDetailsRow createRow(Map<String, dynamic> data) =>
      MatchScoresDetailsRow(data);
}

class MatchScoresDetailsRow extends SupabaseDataRow {
  MatchScoresDetailsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchScoresDetailsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get matchScoresId => getField<int>('match_scores_id');
  set matchScoresId(int? value) => setField<int>('match_scores_id', value);

  int? get count => getField<int>('count');
  set count(int? value) => setField<int>('count', value);

  int? get scoreType => getField<int>('score_type');
  set scoreType(int? value) => setField<int>('score_type', value);
}
