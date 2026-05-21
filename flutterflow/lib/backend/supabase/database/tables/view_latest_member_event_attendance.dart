import '../database.dart';

class ViewLatestMemberEventAttendanceTable
    extends SupabaseTable<ViewLatestMemberEventAttendanceRow> {
  @override
  String get tableName => 'view_latest_member_event_attendance';

  @override
  ViewLatestMemberEventAttendanceRow createRow(Map<String, dynamic> data) =>
      ViewLatestMemberEventAttendanceRow(data);
}

class ViewLatestMemberEventAttendanceRow extends SupabaseDataRow {
  ViewLatestMemberEventAttendanceRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewLatestMemberEventAttendanceTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get firstName => getField<String>('first_name');
  set firstName(String? value) => setField<String>('first_name', value);

  String? get lastName => getField<String>('last_name');
  set lastName(String? value) => setField<String>('last_name', value);

  int? get highestRoleId => getField<int>('highest_role_id');
  set highestRoleId(int? value) => setField<int>('highest_role_id', value);

  String? get highestRoleName => getField<String>('highest_role_name');
  set highestRoleName(String? value) =>
      setField<String>('highest_role_name', value);

  int? get highestRoleLevel => getField<int>('highest_role_level');
  set highestRoleLevel(int? value) =>
      setField<int>('highest_role_level', value);

  String? get highestRoleNamePlural =>
      getField<String>('highest_role_name_plural');
  set highestRoleNamePlural(String? value) =>
      setField<String>('highest_role_name_plural', value);

  int? get highestRoleGrade => getField<int>('highest_role_grade');
  set highestRoleGrade(int? value) =>
      setField<int>('highest_role_grade', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  DateTime? get responseCreatedAt => getField<DateTime>('response_created_at');
  set responseCreatedAt(DateTime? value) =>
      setField<DateTime>('response_created_at', value);

  int? get attendanceId => getField<int>('attendance_id');
  set attendanceId(int? value) => setField<int>('attendance_id', value);

  int? get responseId => getField<int>('response_id');
  set responseId(int? value) => setField<int>('response_id', value);

  String? get responseValue => getField<String>('response_value');
  set responseValue(String? value) => setField<String>('response_value', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);
}
