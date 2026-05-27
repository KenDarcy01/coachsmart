import '../database.dart';

class MemberSquadLinkTable extends SupabaseTable<MemberSquadLinkRow> {
  @override
  String get tableName => 'member_squad_link';

  @override
  MemberSquadLinkRow createRow(Map<String, dynamic> data) =>
      MemberSquadLinkRow(data);
}

class MemberSquadLinkRow extends SupabaseDataRow {
  MemberSquadLinkRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MemberSquadLinkTable();

  int get memberSquadId => getField<int>('member_squad_id')!;
  set memberSquadId(int value) => setField<int>('member_squad_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  int? get codeId => getField<int>('code_id');
  set codeId(int? value) => setField<int>('code_id', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);
}
