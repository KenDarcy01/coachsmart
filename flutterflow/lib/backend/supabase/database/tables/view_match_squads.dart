import '../database.dart';

class ViewMatchSquadsTable extends SupabaseTable<ViewMatchSquadsRow> {
  @override
  String get tableName => 'view_match_squads';

  @override
  ViewMatchSquadsRow createRow(Map<String, dynamic> data) =>
      ViewMatchSquadsRow(data);
}

class ViewMatchSquadsRow extends SupabaseDataRow {
  ViewMatchSquadsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewMatchSquadsTable();

  int? get matchSquadId => getField<int>('match_squad_id');
  set matchSquadId(int? value) => setField<int>('match_squad_id', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  DateTime? get eventDateTime => getField<DateTime>('event_date_time');
  set eventDateTime(DateTime? value) =>
      setField<DateTime>('event_date_time', value);

  String? get formattedEventDateTime =>
      getField<String>('formatted_event_date_time');
  set formattedEventDateTime(String? value) =>
      setField<String>('formatted_event_date_time', value);

  String? get fullMemberName => getField<String>('full_member_name');
  set fullMemberName(String? value) =>
      setField<String>('full_member_name', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  String? get squadName => getField<String>('squad_name');
  set squadName(String? value) => setField<String>('squad_name', value);

  String? get grade => getField<String>('grade');
  set grade(String? value) => setField<String>('grade', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  int? get squadListSeq => getField<int>('squad_list_seq');
  set squadListSeq(int? value) => setField<int>('squad_list_seq', value);

  String? get roleName => getField<String>('role_name');
  set roleName(String? value) => setField<String>('role_name', value);

  String? get roleNamePlural => getField<String>('role_name_plural');
  set roleNamePlural(String? value) =>
      setField<String>('role_name_plural', value);

  int? get roleListSeq => getField<int>('role_list_seq');
  set roleListSeq(int? value) => setField<int>('role_list_seq', value);

  int? get roleLevel => getField<int>('role_level');
  set roleLevel(int? value) => setField<int>('role_level', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);
}
