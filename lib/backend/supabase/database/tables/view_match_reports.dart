import '../database.dart';

class ViewMatchReportsTable extends SupabaseTable<ViewMatchReportsRow> {
  @override
  String get tableName => 'view_match_reports';

  @override
  ViewMatchReportsRow createRow(Map<String, dynamic> data) =>
      ViewMatchReportsRow(data);
}

class ViewMatchReportsRow extends SupabaseDataRow {
  ViewMatchReportsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewMatchReportsTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get reportAuthor => getField<String>('report_author');
  set reportAuthor(String? value) => setField<String>('report_author', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  DateTime? get eventDateTime => getField<DateTime>('event_date_time');
  set eventDateTime(DateTime? value) =>
      setField<DateTime>('event_date_time', value);

  String? get matchReport => getField<String>('match_report');
  set matchReport(String? value) => setField<String>('match_report', value);

  int? get id => getField<int>('id');
  set id(int? value) => setField<int>('id', value);
}
