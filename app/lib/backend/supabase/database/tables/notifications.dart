import '../database.dart';

class NotificationsTable extends SupabaseTable<NotificationsRow> {
  @override
  String get tableName => 'notifications';

  @override
  NotificationsRow createRow(Map<String, dynamic> data) =>
      NotificationsRow(data);
}

class NotificationsRow extends SupabaseDataRow {
  NotificationsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => NotificationsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String get recipientUserId => getField<String>('recipient_user_id')!;
  set recipientUserId(String value) =>
      setField<String>('recipient_user_id', value);

  bool get isRead => getField<bool>('is_read')!;
  set isRead(bool value) => setField<bool>('is_read', value);

  DateTime? get whenRead => getField<DateTime>('when_read');
  set whenRead(DateTime? value) => setField<DateTime>('when_read', value);

  String? get linkPage => getField<String>('link_page');
  set linkPage(String? value) => setField<String>('link_page', value);

  String? get image => getField<String>('image');
  set image(String? value) => setField<String>('image', value);

  bool? get isDelivered => getField<bool>('is_delivered');
  set isDelivered(bool? value) => setField<bool>('is_delivered', value);

  String? get deliveryMethod => getField<String>('delivery_method');
  set deliveryMethod(String? value) =>
      setField<String>('delivery_method', value);

  String? get pushTitle => getField<String>('push_title');
  set pushTitle(String? value) => setField<String>('push_title', value);

  String? get pushBody => getField<String>('push_body');
  set pushBody(String? value) => setField<String>('push_body', value);

  String? get emailTitle => getField<String>('email_title');
  set emailTitle(String? value) => setField<String>('email_title', value);

  String? get emailBody => getField<String>('email_body');
  set emailBody(String? value) => setField<String>('email_body', value);

  String? get appTitle => getField<String>('app_title');
  set appTitle(String? value) => setField<String>('app_title', value);

  String? get appBody => getField<String>('app_body');
  set appBody(String? value) => setField<String>('app_body', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);
}
