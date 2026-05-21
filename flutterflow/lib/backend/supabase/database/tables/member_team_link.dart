import '../database.dart';

class MemberTeamLinkTable extends SupabaseTable<MemberTeamLinkRow> {
  @override
  String get tableName => 'member_team_link';

  @override
  MemberTeamLinkRow createRow(Map<String, dynamic> data) =>
      MemberTeamLinkRow(data);
}

class MemberTeamLinkRow extends SupabaseDataRow {
  MemberTeamLinkRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MemberTeamLinkTable();

  int get memberTeamId => getField<int>('member_team_id')!;
  set memberTeamId(int value) => setField<int>('member_team_id', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  String? get memberTeamCode => getField<String>('member_team_code');
  set memberTeamCode(String? value) =>
      setField<String>('member_team_code', value);
}
