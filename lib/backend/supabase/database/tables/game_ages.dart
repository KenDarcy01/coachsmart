import '../database.dart';

class GameAgesTable extends SupabaseTable<GameAgesRow> {
  @override
  String get tableName => 'game_ages';

  @override
  GameAgesRow createRow(Map<String, dynamic> data) => GameAgesRow(data);
}

class GameAgesRow extends SupabaseDataRow {
  GameAgesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => GameAgesTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get age => getField<String>('age');
  set age(String? value) => setField<String>('age', value);

  String? get comment => getField<String>('comment');
  set comment(String? value) => setField<String>('comment', value);

  String? get description => getField<String>('description');
  set description(String? value) => setField<String>('description', value);
}
