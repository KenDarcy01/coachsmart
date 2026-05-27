import '../database.dart';

class ViewMemberEventCountTable extends SupabaseTable<ViewMemberEventCountRow> {
  @override
  String get tableName => 'view_member_event_count';

  @override
  ViewMemberEventCountRow createRow(Map<String, dynamic> data) =>
      ViewMemberEventCountRow(data);
}

class ViewMemberEventCountRow extends SupabaseDataRow {
  ViewMemberEventCountRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewMemberEventCountTable();

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get firstName => getField<String>('first_name');
  set firstName(String? value) => setField<String>('first_name', value);

  String? get lastName => getField<String>('last_name');
  set lastName(String? value) => setField<String>('last_name', value);

  int? get acceptedCount => getField<int>('accepted_count');
  set acceptedCount(int? value) => setField<int>('accepted_count', value);

  int? get declinedCount => getField<int>('declined_count');
  set declinedCount(int? value) => setField<int>('declined_count', value);

  int? get totalEventsResponded => getField<int>('total_events_responded');
  set totalEventsResponded(int? value) =>
      setField<int>('total_events_responded', value);

  double? get acceptanceRate => getField<double>('acceptance_rate');
  set acceptanceRate(double? value) =>
      setField<double>('acceptance_rate', value);

  double? get declineRate => getField<double>('decline_rate');
  set declineRate(double? value) => setField<double>('decline_rate', value);

  int? get eventCount => getField<int>('event_count');
  set eventCount(int? value) => setField<int>('event_count', value);
}
