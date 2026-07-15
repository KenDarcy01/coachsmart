import '../database.dart';

class UserGameLinkTable extends SupabaseTable<UserGameLinkRow> {
  @override
  String get tableName => 'user_game_link';

  @override
  UserGameLinkRow createRow(Map<String, dynamic> data) => UserGameLinkRow(data);
}

class UserGameLinkRow extends SupabaseDataRow {
  UserGameLinkRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => UserGameLinkTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get gameId => getField<int>('game_id');
  set gameId(int? value) => setField<int>('game_id', value);
}
