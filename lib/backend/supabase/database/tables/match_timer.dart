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

  int get homeGoals => getField<int>('home_goals')!;
  set homeGoals(int value) => setField<int>('home_goals', value);

  int get homePoints => getField<int>('home_points')!;
  set homePoints(int value) => setField<int>('home_points', value);

  int get homeTwoPtrs => getField<int>('home_two_ptrs')!;
  set homeTwoPtrs(int value) => setField<int>('home_two_ptrs', value);

  int get awayGoals => getField<int>('away_goals')!;
  set awayGoals(int value) => setField<int>('away_goals', value);

  int get awayPoints => getField<int>('away_points')!;
  set awayPoints(int value) => setField<int>('away_points', value);

  int get awayTwoPtrs => getField<int>('away_two_ptrs')!;
  set awayTwoPtrs(int value) => setField<int>('away_two_ptrs', value);

  int get injurySeconds => getField<int>('injury_seconds')!;
  set injurySeconds(int value) => setField<int>('injury_seconds', value);
}
