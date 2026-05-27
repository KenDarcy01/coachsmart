import '../database.dart';

class ViewTeamRolesTable extends SupabaseTable<ViewTeamRolesRow> {
  @override
  String get tableName => 'view_team_roles';

  @override
  ViewTeamRolesRow createRow(Map<String, dynamic> data) =>
      ViewTeamRolesRow(data);
}

class ViewTeamRolesRow extends SupabaseDataRow {
  ViewTeamRolesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewTeamRolesTable();

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  String? get teamUniqueCode => getField<String>('team_unique_code');
  set teamUniqueCode(String? value) =>
      setField<String>('team_unique_code', value);

  String? get teamUniqueCodeLowercase =>
      getField<String>('team_unique_code_lowercase');
  set teamUniqueCodeLowercase(String? value) =>
      setField<String>('team_unique_code_lowercase', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);

  String? get roleName => getField<String>('role_name');
  set roleName(String? value) => setField<String>('role_name', value);

  String? get roleNamePlural => getField<String>('role_name_plural');
  set roleNamePlural(String? value) =>
      setField<String>('role_name_plural', value);

  int? get roleLevel => getField<int>('role_level');
  set roleLevel(int? value) => setField<int>('role_level', value);

  int? get roleGrade => getField<int>('role_grade');
  set roleGrade(int? value) => setField<int>('role_grade', value);

  int? get roleListSeq => getField<int>('role_list_seq');
  set roleListSeq(int? value) => setField<int>('role_list_seq', value);

  int? get memberCount => getField<int>('member_count');
  set memberCount(int? value) => setField<int>('member_count', value);
}
