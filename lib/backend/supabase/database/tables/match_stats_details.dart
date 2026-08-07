import '../database.dart';

class MatchStatsDetailsTable extends SupabaseTable<MatchStatsDetailsRow> {
  @override
  String get tableName => 'match_stats_details';

  @override
  MatchStatsDetailsRow createRow(Map<String, dynamic> data) =>
      MatchStatsDetailsRow(data);
}

class MatchStatsDetailsRow extends SupabaseDataRow {
  MatchStatsDetailsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchStatsDetailsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get matchStatsId => getField<int>('match_stats_id');
  set matchStatsId(int? value) => setField<int>('match_stats_id', value);

  int? get count => getField<int>('count');
  set count(int? value) => setField<int>('count', value);

  int? get scoreType => getField<int>('score_type');
  set scoreType(int? value) => setField<int>('score_type', value);

  String get side => getField<String>('side')!;
  set side(String value) => setField<String>('side', value);

  int? get eventMinute => getField<int>('event_minute');
  set eventMinute(int? value) => setField<int>('event_minute', value);

  String? get timerStatus => getField<String>('timer_status');
  set timerStatus(String? value) => setField<String>('timer_status', value);
}
