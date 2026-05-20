import '../database.dart';

class EventAttendanceTable extends SupabaseTable<EventAttendanceRow> {
  @override
  String get tableName => 'event_attendance';

  @override
  EventAttendanceRow createRow(Map<String, dynamic> data) =>
      EventAttendanceRow(data);
}

class EventAttendanceRow extends SupabaseDataRow {
  EventAttendanceRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => EventAttendanceTable();

  int get attendanceId => getField<int>('attendance_id')!;
  set attendanceId(int value) => setField<int>('attendance_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  int? get responseId => getField<int>('response_id');
  set responseId(int? value) => setField<int>('response_id', value);
}
