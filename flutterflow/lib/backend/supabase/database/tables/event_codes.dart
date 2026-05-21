import '../database.dart';

class EventCodesTable extends SupabaseTable<EventCodesRow> {
  @override
  String get tableName => 'event_codes';

  @override
  EventCodesRow createRow(Map<String, dynamic> data) => EventCodesRow(data);
}

class EventCodesRow extends SupabaseDataRow {
  EventCodesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => EventCodesTable();

  int get codeId => getField<int>('code_id')!;
  set codeId(int value) => setField<int>('code_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get eventCode => getField<String>('event_code');
  set eventCode(String? value) => setField<String>('event_code', value);
}
