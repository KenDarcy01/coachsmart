import '../database.dart';

class ViewHomepageListviewTable extends SupabaseTable<ViewHomepageListviewRow> {
  @override
  String get tableName => 'view_homepage_listview';

  @override
  ViewHomepageListviewRow createRow(Map<String, dynamic> data) =>
      ViewHomepageListviewRow(data);
}

class ViewHomepageListviewRow extends SupabaseDataRow {
  ViewHomepageListviewRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewHomepageListviewTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get userFirstName => getField<String>('user_first_name');
  set userFirstName(String? value) =>
      setField<String>('user_first_name', value);

  String? get userLastName => getField<String>('user_last_name');
  set userLastName(String? value) => setField<String>('user_last_name', value);

  String? get phoneNumber => getField<String>('phone_number');
  set phoneNumber(String? value) => setField<String>('phone_number', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get memberFirstName => getField<String>('member_first_name');
  set memberFirstName(String? value) =>
      setField<String>('member_first_name', value);

  String? get memberLastName => getField<String>('member_last_name');
  set memberLastName(String? value) =>
      setField<String>('member_last_name', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  int? get clubId => getField<int>('club_id');
  set clubId(int? value) => setField<int>('club_id', value);

  String? get clubName => getField<String>('club_name');
  set clubName(String? value) => setField<String>('club_name', value);

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

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  DateTime? get eventDateTime => getField<DateTime>('event_date_time');
  set eventDateTime(DateTime? value) =>
      setField<DateTime>('event_date_time', value);

  DateTime? get eventDateCompare => getField<DateTime>('event_date_compare');
  set eventDateCompare(DateTime? value) =>
      setField<DateTime>('event_date_compare', value);

  String? get meetTime => getField<String>('meet_time');
  set meetTime(String? value) => setField<String>('meet_time', value);

  String? get opposition => getField<String>('opposition');
  set opposition(String? value) => setField<String>('opposition', value);

  String? get locationName => getField<String>('location_name');
  set locationName(String? value) => setField<String>('location_name', value);

  String? get eventLink => getField<String>('event_link');
  set eventLink(String? value) => setField<String>('event_link', value);

  String? get eventDetails => getField<String>('event_details');
  set eventDetails(String? value) => setField<String>('event_details', value);

  int? get audienceId => getField<int>('audience_id');
  set audienceId(int? value) => setField<int>('audience_id', value);

  bool? get requestAttendance => getField<bool>('request_attendance');
  set requestAttendance(bool? value) =>
      setField<bool>('request_attendance', value);

  int? get eventRoleGrade => getField<int>('event_role_grade');
  set eventRoleGrade(int? value) => setField<int>('event_role_grade', value);

  int? get eventRoleLevel => getField<int>('event_role_level');
  set eventRoleLevel(int? value) => setField<int>('event_role_level', value);

  String? get eventCode => getField<String>('event_code');
  set eventCode(String? value) => setField<String>('event_code', value);

  String? get eventType => getField<String>('event_type');
  set eventType(String? value) => setField<String>('event_type', value);

  String? get createdByUserId => getField<String>('created_by_user_id');
  set createdByUserId(String? value) =>
      setField<String>('created_by_user_id', value);

  String? get createdByFirstName => getField<String>('created_by_first_name');
  set createdByFirstName(String? value) =>
      setField<String>('created_by_first_name', value);

  String? get createdByLastName => getField<String>('created_by_last_name');
  set createdByLastName(String? value) =>
      setField<String>('created_by_last_name', value);

  String? get createdByPhoneNumber =>
      getField<String>('created_by_phone_number');
  set createdByPhoneNumber(String? value) =>
      setField<String>('created_by_phone_number', value);

  String? get createdByEmailAddress =>
      getField<String>('created_by_email_address');
  set createdByEmailAddress(String? value) =>
      setField<String>('created_by_email_address', value);

  List<int> get teamMembers => getListField<int>('team_members');
  set teamMembers(List<int>? value) => setListField<int>('team_members', value);
}
