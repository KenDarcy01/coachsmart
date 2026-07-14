import '../database.dart';

class GamesTable extends SupabaseTable<GamesRow> {
  @override
  String get tableName => 'games';

  @override
  GamesRow createRow(Map<String, dynamic> data) => GamesRow(data);
}

class GamesRow extends SupabaseDataRow {
  GamesRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => GamesTable();

  int get gameId => getField<int>('game_id')!;
  set gameId(int value) => setField<int>('game_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get gameName => getField<String>('game_name');
  set gameName(String? value) => setField<String>('game_name', value);

  String? get gameImage => getField<String>('game_image');
  set gameImage(String? value) => setField<String>('game_image', value);

  List<String> get gameAge => getListField<String>('game_age');
  set gameAge(List<String>? value) => setListField<String>('game_age', value);

  List<String> get gameCode => getListField<String>('game_code');
  set gameCode(List<String>? value) => setListField<String>('game_code', value);

  List<String> get gameSkill => getListField<String>('game_skill');
  set gameSkill(List<String>? value) =>
      setListField<String>('game_skill', value);

  List<String> get gameType => getListField<String>('game_type');
  set gameType(List<String>? value) => setListField<String>('game_type', value);

  String? get gameSetup => getField<String>('game_setup');
  set gameSetup(String? value) => setField<String>('game_setup', value);

  String? get gameHowToPlay => getField<String>('game_how_to_play');
  set gameHowToPlay(String? value) =>
      setField<String>('game_how_to_play', value);

  String? get gameVariations => getField<String>('game_variations');
  set gameVariations(String? value) =>
      setField<String>('game_variations', value);

  String? get gameTeachingPoints => getField<String>('game_teaching_points');
  set gameTeachingPoints(String? value) =>
      setField<String>('game_teaching_points', value);

  String? get gamePdf => getField<String>('game_pdf');
  set gamePdf(String? value) => setField<String>('game_pdf', value);

  String? get gameVideo => getField<String>('game_video');
  set gameVideo(String? value) => setField<String>('game_video', value);

  String? get gameLink => getField<String>('game_link');
  set gameLink(String? value) => setField<String>('game_link', value);

  String? get gameDetailsImage => getField<String>('game_details_image');
  set gameDetailsImage(String? value) =>
      setField<String>('game_details_image', value);
}
