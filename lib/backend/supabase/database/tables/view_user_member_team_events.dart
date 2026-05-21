import '../database.dart';

class ViewUserMemberTeamEventsTable
    extends SupabaseTable<ViewUserMemberTeamEventsRow> {
  @override
  String get tableName => 'view_user_member_team_events';

  @override
  ViewUserMemberTeamEventsRow createRow(Map<String, dynamic> data) =>
      ViewUserMemberTeamEventsRow(data);
}

class ViewUserMemberTeamEventsRow extends SupabaseDataRow {
  ViewUserMemberTeamEventsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewUserMemberTeamEventsTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

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

  int? get highestRoleGrade => getField<int>('highest_role_grade');
  set highestRoleGrade(int? value) =>
      setField<int>('highest_role_grade', value);

  String? get highestRoleNamePlural =>
      getField<String>('highest_role_name_plural');
  set highestRoleNamePlural(String? value) =>
      setField<String>('highest_role_name_plural', value);

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

  String? get meetTime => getField<String>('meet_time');
  set meetTime(String? value) => setField<String>('meet_time', value);

  String? get opposition => getField<String>('opposition');
  set opposition(String? value) => setField<String>('opposition', value);

  String? get locationName => getField<String>('location_name');
  set locationName(String? value) => setField<String>('location_name', value);
}
