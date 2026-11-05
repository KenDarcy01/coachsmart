import '../database.dart';

class MatchSquadsTable extends SupabaseTable<MatchSquadsRow> {
  @override
  String get tableName => 'match_squads';

  @override
  MatchSquadsRow createRow(Map<String, dynamic> data) => MatchSquadsRow(data);
}

class MatchSquadsRow extends SupabaseDataRow {
  MatchSquadsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchSquadsTable();

  int get matchSquadId => getField<int>('match_squad_id')!;
  set matchSquadId(int value) => setField<int>('match_squad_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);
}
