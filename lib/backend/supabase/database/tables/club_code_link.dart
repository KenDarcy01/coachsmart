import '../database.dart';

class ClubCodeLinkTable extends SupabaseTable<ClubCodeLinkRow> {
  @override
  String get tableName => 'club_code_link';

  @override
  ClubCodeLinkRow createRow(Map<String, dynamic> data) => ClubCodeLinkRow(data);
}

class ClubCodeLinkRow extends SupabaseDataRow {
  ClubCodeLinkRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ClubCodeLinkTable();

  int get clubCodeId => getField<int>('club_code_id')!;
  set clubCodeId(int value) => setField<int>('club_code_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get clubId => getField<int>('club_id');
  set clubId(int? value) => setField<int>('club_id', value);

  int? get codeId => getField<int>('code_id');
  set codeId(int? value) => setField<int>('code_id', value);
}
