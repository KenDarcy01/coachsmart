import '../database.dart';

class RolesTable extends SupabaseTable<RolesRow> {
  @override
  String get tableName => 'roles';

  @override
  RolesRow createRow(Map<String, dynamic> data) => RolesRow(data);
}

class RolesRow extends SupabaseDataRow {
  RolesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => RolesTable();

  int get roleId => getField<int>('role_id')!;
  set roleId(int value) => setField<int>('role_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

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

  bool? get showAudience => getField<bool>('show_audience');
  set showAudience(bool? value) => setField<bool>('show_audience', value);
}
