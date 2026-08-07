import '../database.dart';

class MatchStatCategoriesTable extends SupabaseTable<MatchStatCategoriesRow> {
  @override
  String get tableName => 'match_stat_categories';

  @override
  MatchStatCategoriesRow createRow(Map<String, dynamic> data) =>
      MatchStatCategoriesRow(data);
}

class MatchStatCategoriesRow extends SupabaseDataRow {
  MatchStatCategoriesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MatchStatCategoriesTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get scoreCategory => getField<String>('score_category');
  set scoreCategory(String? value) => setField<String>('score_category', value);
}
