import '../database.dart';

class ViewTeamMembersTable extends SupabaseTable<ViewTeamMembersRow> {
  @override
  String get tableName => 'view_team_members';

  @override
  ViewTeamMembersRow createRow(Map<String, dynamic> data) =>
      ViewTeamMembersRow(data);
}

class ViewTeamMembersRow extends SupabaseDataRow {
  ViewTeamMembersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewTeamMembersTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get uniqueMemberCode => getField<String>('unique_member_code');
  set uniqueMemberCode(String? value) =>
      setField<String>('unique_member_code', value);

  String? get firstName => getField<String>('first_name');
  set firstName(String? value) => setField<String>('first_name', value);

  String? get lastName => getField<String>('last_name');
  set lastName(String? value) => setField<String>('last_name', value);

  String? get memberFullName => getField<String>('member_full_name');
  set memberFullName(String? value) =>
      setField<String>('member_full_name', value);

  String? get lowerCaseFullname => getField<String>('lower_case_fullname');
  set lowerCaseFullname(String? value) =>
      setField<String>('lower_case_fullname', value);

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

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  String? get squadName => getField<String>('squad_name');
  set squadName(String? value) => setField<String>('squad_name', value);
}
