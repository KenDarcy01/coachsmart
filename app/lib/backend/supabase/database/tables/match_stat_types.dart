import '../database.dart';

class MatchStatTypesTable extends SupabaseTable<MatchStatTypesRow> {
  @override
  String get tableName => 'match_stat_types';

  @override
  MatchStatTypesRow createRow(Map<String, dynamic> data) =>
      MatchStatTypesRow(data);
}

class MatchStatTypesRow extends SupabaseDataRow {
  MatchStatTypesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchStatTypesTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get scoreType => getField<String>('score_type');
  set scoreType(String? value) => setField<String>('score_type', value);

  int? get scoreCategory => getField<int>('score_category');
  set scoreCategory(int? value) => setField<int>('score_category', value);

  bool? get status => getField<bool>('status');
  set status(bool? value) => setField<bool>('status', value);

  int? get scoreValue => getField<int>('score_value');
  set scoreValue(int? value) => setField<int>('score_value', value);

  String? get abbreviatedName => getField<String>('abbreviated_name');
  set abbreviatedName(String? value) =>
      setField<String>('abbreviated_name', value);
}
