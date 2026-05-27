import '../database.dart';

class ViewEventRemindersTable extends SupabaseTable<ViewEventRemindersRow> {
  @override
  String get tableName => 'view_event_reminders';

  @override
  ViewEventRemindersRow createRow(Map<String, dynamic> data) =>
      ViewEventRemindersRow(data);
}

class ViewEventRemindersRow extends SupabaseDataRow {
  ViewEventRemindersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewEventRemindersTable();

  int? get id => getField<int>('id');
  set id(int? value) => setField<int>('id', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get result => getField<String>('result');
  set result(String? value) => setField<String>('result', value);

  String? get usersFullName => getField<String>('users_full_name');
  set usersFullName(String? value) =>
      setField<String>('users_full_name', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);
}
