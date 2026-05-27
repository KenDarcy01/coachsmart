import '../database.dart';

class RemindersTable extends SupabaseTable<RemindersRow> {
  @override
  String get tableName => 'reminders';

  @override
  RemindersRow createRow(Map<String, dynamic> data) => RemindersRow(data);
}

class RemindersRow extends SupabaseDataRow {
  RemindersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => RemindersTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get result => getField<String>('result');
  set result(String? value) => setField<String>('result', value);
}
