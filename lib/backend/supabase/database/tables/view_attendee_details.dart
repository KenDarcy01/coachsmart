import '../database.dart';

class ViewAttendeeDetailsTable extends SupabaseTable<ViewAttendeeDetailsRow> {
  @override
  String get tableName => 'view_attendee_details';

  @override
  ViewAttendeeDetailsRow createRow(Map<String, dynamic> data) =>
      ViewAttendeeDetailsRow(data);
}

class ViewAttendeeDetailsRow extends SupabaseDataRow {
  ViewAttendeeDetailsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewAttendeeDetailsTable();

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  DateTime? get eventDateTime => getField<DateTime>('event_date_time');
  set eventDateTime(DateTime? value) =>
      setField<DateTime>('event_date_time', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get firstName => getField<String>('first_name');
  set firstName(String? value) => setField<String>('first_name', value);

  String? get lastName => getField<String>('last_name');
  set lastName(String? value) => setField<String>('last_name', value);

  String? get fullMemberName => getField<String>('full_member_name');
  set fullMemberName(String? value) =>
      setField<String>('full_member_name', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

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

  String? get squadGrade => getField<String>('squad_grade');
  set squadGrade(String? value) => setField<String>('squad_grade', value);

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
