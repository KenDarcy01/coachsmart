import '../database.dart';

class ViewUserTeamsTable extends SupabaseTable<ViewUserTeamsRow> {
  @override
  String get tableName => 'view_user_teams';

  @override
  ViewUserTeamsRow createRow(Map<String, dynamic> data) =>
      ViewUserTeamsRow(data);
}

class ViewUserTeamsRow extends SupabaseDataRow {
  ViewUserTeamsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewUserTeamsTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  String? get teamUniqueCode => getField<String>('team_unique_code');
  set teamUniqueCode(String? value) =>
      setField<String>('team_unique_code', value);

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
}
