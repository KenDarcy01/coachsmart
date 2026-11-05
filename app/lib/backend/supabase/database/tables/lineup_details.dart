import '../database.dart';

class LineupDetailsTable extends SupabaseTable<LineupDetailsRow> {
  @override
  String get tableName => 'lineup_details';

  @override
  LineupDetailsRow createRow(Map<String, dynamic> data) =>
      LineupDetailsRow(data);
}

class LineupDetailsRow extends SupabaseDataRow {
  LineupDetailsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => LineupDetailsTable();

  int get lineupDetailId => getField<int>('lineup_detail_id')!;
  set lineupDetailId(int value) => setField<int>('lineup_detail_id', value);

  int get lineupId => getField<int>('lineup_id')!;
  set lineupId(int value) => setField<int>('lineup_id', value);

  int get memberId => getField<int>('member_id')!;
  set memberId(int value) => setField<int>('member_id', value);

  int get positionNum => getField<int>('position_num')!;
  set positionNum(int value) => setField<int>('position_num', value);

  bool get isSub => getField<bool>('is_sub')!;
  set isSub(bool value) => setField<bool>('is_sub', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get positionLabel => getField<String>('position_label');
  set positionLabel(String? value) => setField<String>('position_label', value);
}
