import '../database.dart';

class EventResponseTypeTable extends SupabaseTable<EventResponseTypeRow> {
  @override
  String get tableName => 'event_response_type';

  @override
  EventResponseTypeRow createRow(Map<String, dynamic> data) =>
      EventResponseTypeRow(data);
}

class EventResponseTypeRow extends SupabaseDataRow {
  EventResponseTypeRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => EventResponseTypeTable();

  int get responseId => getField<int>('response_id')!;
  set responseId(int value) => setField<int>('response_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get responseValue => getField<String>('response_value');
  set responseValue(String? value) => setField<String>('response_value', value);

  String? get responseIcon => getField<String>('response_icon');
  set responseIcon(String? value) => setField<String>('response_icon', value);

  String? get displayValue => getField<String>('display_value');
  set displayValue(String? value) => setField<String>('display_value', value);

  String? get iconLink => getField<String>('icon_link');
  set iconLink(String? value) => setField<String>('icon_link', value);
}
