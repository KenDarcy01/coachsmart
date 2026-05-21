import '../database.dart';

class TeamsTable extends SupabaseTable<TeamsRow> {
  @override
  String get tableName => 'teams';

  @override
  TeamsRow createRow(Map<String, dynamic> data) => TeamsRow(data);
}

class TeamsRow extends SupabaseDataRow {
  TeamsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => TeamsTable();

  int get teamId => getField<int>('team_id')!;
  set teamId(int value) => setField<int>('team_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  String? get destFolder => getField<String>('dest_folder');
  set destFolder(String? value) => setField<String>('dest_folder', value);

  String? get teamUniqueCode => getField<String>('team_unique_code');
  set teamUniqueCode(String? value) =>
      setField<String>('team_unique_code', value);

  bool? get teamJuvenile => getField<bool>('team_juvenile');
  set teamJuvenile(bool? value) => setField<bool>('team_juvenile', value);

  bool? get teamFemale => getField<bool>('team_female');
  set teamFemale(bool? value) => setField<bool>('team_female', value);

  int? get clubId => getField<int>('club_id');
  set clubId(int? value) => setField<int>('club_id', value);

  String? get profilePic => getField<String>('profile_pic');
  set profilePic(String? value) => setField<String>('profile_pic', value);

  bool? get carPoolingAllowed => getField<bool>('car_pooling_allowed');
  set carPoolingAllowed(bool? value) =>
      setField<bool>('car_pooling_allowed', value);

  bool? get showAdvert => getField<bool>('show_advert');
  set showAdvert(bool? value) => setField<bool>('show_advert', value);
}
