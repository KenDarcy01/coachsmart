import '../database.dart';

class MatchStatsTable extends SupabaseTable<MatchStatsRow> {
  @override
  String get tableName => 'match_stats';

  @override
  MatchStatsRow createRow(Map<String, dynamic> data) => MatchStatsRow(data);
}

class MatchStatsRow extends SupabaseDataRow {
  MatchStatsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchStatsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get opposition => getField<String>('opposition');
  set opposition(String? value) => setField<String>('opposition', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  int? get timerStart => getField<int>('timer_start');
  set timerStart(int? value) => setField<int>('timer_start', value);

  int? get timerEnd => getField<int>('timer_end');
  set timerEnd(int? value) => setField<int>('timer_end', value);

  bool? get timerRunning => getField<bool>('timer_running');
  set timerRunning(bool? value) => setField<bool>('timer_running', value);

  DateTime? get finalisedAt => getField<DateTime>('finalised_at');
  set finalisedAt(DateTime? value) => setField<DateTime>('finalised_at', value);
}
