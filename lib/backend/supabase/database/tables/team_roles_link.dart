import '../database.dart';

class TeamRolesLinkTable extends SupabaseTable<TeamRolesLinkRow> {
  @override
  String get tableName => 'team_roles_link';

  @override
  TeamRolesLinkRow createRow(Map<String, dynamic> data) =>
      TeamRolesLinkRow(data);
}

class TeamRolesLinkRow extends SupabaseDataRow {
  TeamRolesLinkRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => TeamRolesLinkTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);
}
