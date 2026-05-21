import '../database.dart';

class ViewUserHighestRoleTable extends SupabaseTable<ViewUserHighestRoleRow> {
  @override
  String get tableName => 'view_user_highest_role';

  @override
  ViewUserHighestRoleRow createRow(Map<String, dynamic> data) =>
      ViewUserHighestRoleRow(data);
}

class ViewUserHighestRoleRow extends SupabaseDataRow {
  ViewUserHighestRoleRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewUserHighestRoleTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get fullName => getField<String>('full_name');
  set fullName(String? value) => setField<String>('full_name', value);

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

  List<int> get userMembers => getListField<int>('user_members');
  set userMembers(List<int>? value) => setListField<int>('user_members', value);

  String? get onboarded => getField<String>('onboarded');
  set onboarded(String? value) => setField<String>('onboarded', value);
}
