import '../database.dart';

class ViewEventAttendanceDetailsTable
    extends SupabaseTable<ViewEventAttendanceDetailsRow> {
  @override
  String get tableName => 'view_event_attendance_details';

  @override
  ViewEventAttendanceDetailsRow createRow(Map<String, dynamic> data) =>
      ViewEventAttendanceDetailsRow(data);
}

class ViewEventAttendanceDetailsRow extends SupabaseDataRow {
  ViewEventAttendanceDetailsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewEventAttendanceDetailsTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

  String? get userFirstName => getField<String>('user_first_name');
  set userFirstName(String? value) =>
      setField<String>('user_first_name', value);

  String? get userLastName => getField<String>('user_last_name');
  set userLastName(String? value) => setField<String>('user_last_name', value);

  String? get fullUserName => getField<String>('full_user_name');
  set fullUserName(String? value) => setField<String>('full_user_name', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  DateTime? get eventDateTime => getField<DateTime>('event_date_time');
  set eventDateTime(DateTime? value) =>
      setField<DateTime>('event_date_time', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get memberFirstName => getField<String>('member_first_name');
  set memberFirstName(String? value) =>
      setField<String>('member_first_name', value);

  String? get memberLastName => getField<String>('member_last_name');
  set memberLastName(String? value) =>
      setField<String>('member_last_name', value);

  String? get fullMemberName => getField<String>('full_member_name');
  set fullMemberName(String? value) =>
      setField<String>('full_member_name', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);

  String? get roleName => getField<String>('role_name');
  set roleName(String? value) => setField<String>('role_name', value);

  int? get roleLevel => getField<int>('role_level');
  set roleLevel(int? value) => setField<int>('role_level', value);

  String? get roleNamePlural => getField<String>('role_name_plural');
  set roleNamePlural(String? value) =>
      setField<String>('role_name_plural', value);

  int? get roleGrade => getField<int>('role_grade');
  set roleGrade(int? value) => setField<int>('role_grade', value);

  int? get roleListSeq => getField<int>('role_list_seq');
  set roleListSeq(int? value) => setField<int>('role_list_seq', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  String? get squadName => getField<String>('squad_name');
  set squadName(String? value) => setField<String>('squad_name', value);

  String? get squadImage => getField<String>('squad_image');
  set squadImage(String? value) => setField<String>('squad_image', value);

  int? get responseId => getField<int>('response_id');
  set responseId(int? value) => setField<int>('response_id', value);

  DateTime? get attendanceCreatedAt =>
      getField<DateTime>('attendance_created_at');
  set attendanceCreatedAt(DateTime? value) =>
      setField<DateTime>('attendance_created_at', value);

  String? get responseIcon => getField<String>('response_icon');
  set responseIcon(String? value) => setField<String>('response_icon', value);

  String? get displayValue => getField<String>('display_value');
  set displayValue(String? value) => setField<String>('display_value', value);

  String? get responseStatus => getField<String>('response_status');
  set responseStatus(String? value) =>
      setField<String>('response_status', value);
}
