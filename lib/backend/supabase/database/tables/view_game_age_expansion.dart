import '../database.dart';

class ViewGameAgeExpansionTable extends SupabaseTable<ViewGameAgeExpansionRow> {
  @override
  String get tableName => 'view_game_age_expansion';

  @override
  ViewGameAgeExpansionRow createRow(Map<String, dynamic> data) =>
      ViewGameAgeExpansionRow(data);
}

class ViewGameAgeExpansionRow extends SupabaseDataRow {
  ViewGameAgeExpansionRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewGameAgeExpansionTable();

  int? get gameId => getField<int>('game_id');
  set gameId(int? value) => setField<int>('game_id', value);

  String? get gameName => getField<String>('game_name');
  set gameName(String? value) => setField<String>('game_name', value);

  String? get gameImage => getField<String>('game_image');
  set gameImage(String? value) => setField<String>('game_image', value);

  String? get gameCode => getField<String>('game_code');
  set gameCode(String? value) => setField<String>('game_code', value);

  String? get gameSkill => getField<String>('game_skill');
  set gameSkill(String? value) => setField<String>('game_skill', value);

  String? get gameType => getField<String>('game_type');
  set gameType(String? value) => setField<String>('game_type', value);

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

  String? get gameAgeExpanded => getField<String>('game_age_expanded');
  set gameAgeExpanded(String? value) =>
      setField<String>('game_age_expanded', value);
}
