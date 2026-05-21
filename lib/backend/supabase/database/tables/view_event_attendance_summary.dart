import '../database.dart';

class ViewEventAttendanceSummaryTable
    extends SupabaseTable<ViewEventAttendanceSummaryRow> {
  @override
  String get tableName => 'view_event_attendance_summary';

  @override
  ViewEventAttendanceSummaryRow createRow(Map<String, dynamic> data) =>
      ViewEventAttendanceSummaryRow(data);
}

class ViewEventAttendanceSummaryRow extends SupabaseDataRow {
  ViewEventAttendanceSummaryRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewEventAttendanceSummaryTable();

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  DateTime? get eventDateTime => getField<DateTime>('event_date_time');
  set eventDateTime(DateTime? value) =>
      setField<DateTime>('event_date_time', value);

  String? get meetTime => getField<String>('meet_time');
  set meetTime(String? value) => setField<String>('meet_time', value);

  String? get opposition => getField<String>('opposition');
  set opposition(String? value) => setField<String>('opposition', value);

  String? get locationName => getField<String>('location_name');
  set locationName(String? value) => setField<String>('location_name', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);

  String? get roleName => getField<String>('role_name');
  set roleName(String? value) => setField<String>('role_name', value);

  int? get roleLevel => getField<int>('role_level');
  set roleLevel(int? value) => setField<int>('role_level', value);

  int? get roleGrade => getField<int>('role_grade');
  set roleGrade(int? value) => setField<int>('role_grade', value);

  String? get roleNamePlural => getField<String>('role_name_plural');
  set roleNamePlural(String? value) =>
      setField<String>('role_name_plural', value);

  int? get roleListSeq => getField<int>('role_list_seq');
  set roleListSeq(int? value) => setField<int>('role_list_seq', value);

  int? get acceptedAttendeesCount => getField<int>('accepted_attendees_count');
  set acceptedAttendeesCount(int? value) =>
      setField<int>('accepted_attendees_count', value);

  int? get declinedAttendeesCount => getField<int>('declined_attendees_count');
  set declinedAttendeesCount(int? value) =>
      setField<int>('declined_attendees_count', value);

  int? get noResponseCount => getField<int>('no_response_count');
  set noResponseCount(int? value) => setField<int>('no_response_count', value);
}
