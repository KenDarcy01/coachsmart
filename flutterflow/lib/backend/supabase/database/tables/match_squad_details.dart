import '../database.dart';

class MatchSquadDetailsTable extends SupabaseTable<MatchSquadDetailsRow> {
  @override
  String get tableName => 'match_squad_details';

  @override
  MatchSquadDetailsRow createRow(Map<String, dynamic> data) =>
      MatchSquadDetailsRow(data);
}

class MatchSquadDetailsRow extends SupabaseDataRow {
  MatchSquadDetailsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchSquadDetailsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);

  int? get matchSquadId => getField<int>('match_squad_id');
  set matchSquadId(int? value) => setField<int>('match_squad_id', value);
}
