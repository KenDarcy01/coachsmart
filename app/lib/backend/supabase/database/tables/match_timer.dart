import '../database.dart';

class MatchTimerTable extends SupabaseTable<MatchTimerRow> {
  @override
  String get tableName => 'match_timer';

  @override
  MatchTimerRow createRow(Map<String, dynamic> data) => MatchTimerRow(data);
}

class MatchTimerRow extends SupabaseDataRow {
  MatchTimerRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchTimerTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  int get eventId => getField<int>('event_id')!;
  set eventId(int value) => setField<int>('event_id', value);

  String get userId => getField<String>('user_id')!;
  set userId(String value) => setField<String>('user_id', value);

  DateTime? get startedAt => getField<DateTime>('started_at');
  set startedAt(DateTime? value) => setField<DateTime>('started_at', value);

  int get elapsedSeconds => getField<int>('elapsed_seconds')!;
  set elapsedSeconds(int value) => setField<int>('elapsed_seconds', value);

  String get status => getField<String>('status')!;
  set status(String value) => setField<String>('status', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  DateTime get updatedAt => getField<DateTime>('updated_at')!;
  set updatedAt(DateTime value) => setField<DateTime>('updated_at', value);

  int get durationSeconds => getField<int>('duration_seconds')!;
  set durationSeconds(int value) => setField<int>('duration_seconds', value);

  String? get opposition => getField<String>('opposition');
  set opposition(String? value) => setField<String>('opposition', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  int get injurySeconds => getField<int>('injury_seconds')!;
  set injurySeconds(int value) => setField<int>('injury_seconds', value);

  int get currentHalf => getField<int>('current_half')!;
  set currentHalf(int value) => setField<int>('current_half', value);
}
