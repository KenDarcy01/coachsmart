import '../database.dart';

class MemberTeamRoleLinkTable extends SupabaseTable<MemberTeamRoleLinkRow> {
  @override
  String get tableName => 'member_team_role_link';

  @override
  MemberTeamRoleLinkRow createRow(Map<String, dynamic> data) =>
      MemberTeamRoleLinkRow(data);
}

class MemberTeamRoleLinkRow extends SupabaseDataRow {
  MemberTeamRoleLinkRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MemberTeamRoleLinkTable();

  int get memberTeamRoleId => getField<int>('member_team_role_id')!;
  set memberTeamRoleId(int value) =>
      setField<int>('member_team_role_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get memberTeamId => getField<int>('member_team_id');
  set memberTeamId(int? value) => setField<int>('member_team_id', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);
}
