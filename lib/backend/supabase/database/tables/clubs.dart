import '../database.dart';

class ClubsTable extends SupabaseTable<ClubsRow> {
  @override
  String get tableName => 'clubs';

  @override
  ClubsRow createRow(Map<String, dynamic> data) => ClubsRow(data);
}

class ClubsRow extends SupabaseDataRow {
  ClubsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ClubsTable();

  int get clubId => getField<int>('club_id')!;
  set clubId(int value) => setField<int>('club_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get clubName => getField<String>('club_name');
  set clubName(String? value) => setField<String>('club_name', value);

  String? get county => getField<String>('county');
  set county(String? value) => setField<String>('county', value);

  String? get banner => getField<String>('banner');
  set banner(String? value) => setField<String>('banner', value);

  String? get crest => getField<String>('crest');
  set crest(String? value) => setField<String>('crest', value);

  int? get sportId => getField<int>('sport_id');
  set sportId(int? value) => setField<int>('sport_id', value);

  int? get defaultClub => getField<int>('default_club');
  set defaultClub(int? value) => setField<int>('default_club', value);

  String? get chairperson => getField<String>('chairperson');
  set chairperson(String? value) => setField<String>('chairperson', value);

  String? get secretary => getField<String>('secretary');
  set secretary(String? value) => setField<String>('secretary', value);

  String? get clubNameTranslated => getField<String>('club_name_translated');
  set clubNameTranslated(String? value) =>
      setField<String>('club_name_translated', value);
}
