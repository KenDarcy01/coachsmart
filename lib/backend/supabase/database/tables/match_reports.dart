import '../database.dart';

class MatchReportsTable extends SupabaseTable<MatchReportsRow> {
  @override
  String get tableName => 'match_reports';

  @override
  MatchReportsRow createRow(Map<String, dynamic> data) => MatchReportsRow(data);
}

class MatchReportsRow extends SupabaseDataRow {
  MatchReportsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchReportsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get matchReport => getField<String>('match_report');
  set matchReport(String? value) => setField<String>('match_report', value);
}
