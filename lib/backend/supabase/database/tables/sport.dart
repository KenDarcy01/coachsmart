import '../database.dart';

class SportTable extends SupabaseTable<SportRow> {
  @override
  String get tableName => 'sport';

  @override
  SportRow createRow(Map<String, dynamic> data) => SportRow(data);
}

class SportRow extends SupabaseDataRow {
  SportRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => SportTable();

  int get sportId => getField<int>('sport_id')!;
  set sportId(int value) => setField<int>('sport_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get sportName => getField<String>('sport_name');
  set sportName(String? value) => setField<String>('sport_name', value);

  String? get sportCrest => getField<String>('sport_crest');
  set sportCrest(String? value) => setField<String>('sport_crest', value);
}
