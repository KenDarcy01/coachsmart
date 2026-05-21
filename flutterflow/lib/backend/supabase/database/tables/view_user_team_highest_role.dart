import '../database.dart';

class ViewUserTeamHighestRoleTable
    extends SupabaseTable<ViewUserTeamHighestRoleRow> {
  @override
  String get tableName => 'view_user_team_highest_role';

  @override
  ViewUserTeamHighestRoleRow createRow(Map<String, dynamic> data) =>
      ViewUserTeamHighestRoleRow(data);
}

class ViewUserTeamHighestRoleRow extends SupabaseDataRow {
  ViewUserTeamHighestRoleRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewUserTeamHighestRoleTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get userFullName => getField<String>('user_full_name');
  set userFullName(String? value) => setField<String>('user_full_name', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

  String? get phoneNumber => getField<String>('phone_number');
  set phoneNumber(String? value) => setField<String>('phone_number', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  String? get teamUniqueCode => getField<String>('team_unique_code');
  set teamUniqueCode(String? value) =>
      setField<String>('team_unique_code', value);

  String? get lowerCaseTeamCode => getField<String>('lower_case_team_code');
  set lowerCaseTeamCode(String? value) =>
      setField<String>('lower_case_team_code', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);

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
}
