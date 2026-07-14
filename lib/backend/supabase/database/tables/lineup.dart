import '../database.dart';

class LineupTable extends SupabaseTable<LineupRow> {
  @override
  String get tableName => 'lineup';

  @override
  LineupRow createRow(Map<String, dynamic> data) => LineupRow(data);
}

class LineupRow extends SupabaseDataRow {
  LineupRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => LineupTable();

  int get lineupId => getField<int>('lineup_id')!;
  set lineupId(int value) => setField<int>('lineup_id', value);

  int get eventId => getField<int>('event_id')!;
  set eventId(int value) => setField<int>('event_id', value);

  int get teamId => getField<int>('team_id')!;
  set teamId(int value) => setField<int>('team_id', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  int get format => getField<int>('format')!;
  set format(int value) => setField<int>('format', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get createdBy => getField<String>('created_by');
  set createdBy(String? value) => setField<String>('created_by', value);
}
