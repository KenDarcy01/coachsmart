import '../database.dart';

class ViewMembersNoResponseTable
    extends SupabaseTable<ViewMembersNoResponseRow> {
  @override
  String get tableName => 'view_members_no_response';

  @override
  ViewMembersNoResponseRow createRow(Map<String, dynamic> data) =>
      ViewMembersNoResponseRow(data);
}

class ViewMembersNoResponseRow extends SupabaseDataRow {
  ViewMembersNoResponseRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewMembersNoResponseTable();

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get firstName => getField<String>('first_name');
  set firstName(String? value) => setField<String>('first_name', value);

  String? get lastName => getField<String>('last_name');
  set lastName(String? value) => setField<String>('last_name', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  String? get squadName => getField<String>('squad_name');
  set squadName(String? value) => setField<String>('squad_name', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  DateTime? get eventDateTime => getField<DateTime>('event_date_time');
  set eventDateTime(DateTime? value) =>
      setField<DateTime>('event_date_time', value);
}
