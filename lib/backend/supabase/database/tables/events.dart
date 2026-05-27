import '../database.dart';

class EventsTable extends SupabaseTable<EventsRow> {
  @override
  String get tableName => 'events';

  @override
  EventsRow createRow(Map<String, dynamic> data) => EventsRow(data);
}

class EventsRow extends SupabaseDataRow {
  EventsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => EventsTable();

  int get eventId => getField<int>('event_id')!;
  set eventId(int value) => setField<int>('event_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  String? get meetTime => getField<String>('meet_time');
  set meetTime(String? value) => setField<String>('meet_time', value);

  String? get opposition => getField<String>('opposition');
  set opposition(String? value) => setField<String>('opposition', value);

  String? get eventDetails => getField<String>('event_details');
  set eventDetails(String? value) => setField<String>('event_details', value);

  String? get locationPin => getField<String>('location_pin');
  set locationPin(String? value) => setField<String>('location_pin', value);

  String? get locationName => getField<String>('location_name');
  set locationName(String? value) => setField<String>('location_name', value);

  String? get homeAway => getField<String>('home_away');
  set homeAway(String? value) => setField<String>('home_away', value);

  String? get createdBy => getField<String>('created_by');
  set createdBy(String? value) => setField<String>('created_by', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  DateTime? get eventDateTime => getField<DateTime>('event_date_time');
  set eventDateTime(DateTime? value) =>
      setField<DateTime>('event_date_time', value);

  int? get eventCodeId => getField<int>('event_code_id');
  set eventCodeId(int? value) => setField<int>('event_code_id', value);

  int? get eventTypeId => getField<int>('event_type_id');
  set eventTypeId(int? value) => setField<int>('event_type_id', value);

  int? get audienceId => getField<int>('audience_id');
  set audienceId(int? value) => setField<int>('audience_id', value);

  bool? get requestAttendance => getField<bool>('request_attendance');
  set requestAttendance(bool? value) =>
      setField<bool>('request_attendance', value);

  int? get squadId => getField<int>('squad_id');
  set squadId(int? value) => setField<int>('squad_id', value);

  DateTime? get eventDateTime2 => getField<DateTime>('event_date_time_2');
  set eventDateTime2(DateTime? value) =>
      setField<DateTime>('event_date_time_2', value);

  String? get eventLink => getField<String>('event_link');
  set eventLink(String? value) => setField<String>('event_link', value);

  bool? get notifyAdminsChanges => getField<bool>('notify_admins_changes');
  set notifyAdminsChanges(bool? value) =>
      setField<bool>('notify_admins_changes', value);

  bool? get notifyAdminsAll => getField<bool>('notify_admins_all');
  set notifyAdminsAll(bool? value) =>
      setField<bool>('notify_admins_all', value);

  bool? get paymentRequired => getField<bool>('payment_required');
  set paymentRequired(bool? value) => setField<bool>('payment_required', value);

  int? get paymentAmount => getField<int>('payment_amount');
  set paymentAmount(int? value) => setField<int>('payment_amount', value);

  String? get eventImage => getField<String>('event_image');
  set eventImage(String? value) => setField<String>('event_image', value);

  bool? get carPooling => getField<bool>('car_pooling');
  set carPooling(bool? value) => setField<bool>('car_pooling', value);
}
