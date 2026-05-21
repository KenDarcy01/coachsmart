import '../database.dart';

class EventTypesTable extends SupabaseTable<EventTypesRow> {
  @override
  String get tableName => 'event_types';

  @override
  EventTypesRow createRow(Map<String, dynamic> data) => EventTypesRow(data);
}

class EventTypesRow extends SupabaseDataRow {
  EventTypesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => EventTypesTable();

  int get eventTypeId => getField<int>('event_type_id')!;
  set eventTypeId(int value) => setField<int>('event_type_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get eventType => getField<String>('event_type');
  set eventType(String? value) => setField<String>('event_type', value);
}
