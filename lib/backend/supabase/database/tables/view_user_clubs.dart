import '../database.dart';

class ViewUserClubsTable extends SupabaseTable<ViewUserClubsRow> {
  @override
  String get tableName => 'view_user_clubs';

  @override
  ViewUserClubsRow createRow(Map<String, dynamic> data) =>
      ViewUserClubsRow(data);
}

class ViewUserClubsRow extends SupabaseDataRow {
  ViewUserClubsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewUserClubsTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

  String? get userFirstName => getField<String>('user_first_name');
  set userFirstName(String? value) =>
      setField<String>('user_first_name', value);

  String? get userLastName => getField<String>('user_last_name');
  set userLastName(String? value) => setField<String>('user_last_name', value);

  String? get userFullName => getField<String>('user_full_name');
  set userFullName(String? value) => setField<String>('user_full_name', value);

  int? get clubId => getField<int>('club_id');
  set clubId(int? value) => setField<int>('club_id', value);

  String? get clubName => getField<String>('club_name');
  set clubName(String? value) => setField<String>('club_name', value);

  String? get county => getField<String>('county');
  set county(String? value) => setField<String>('county', value);

  String? get banner => getField<String>('banner');
  set banner(String? value) => setField<String>('banner', value);

  String? get crest => getField<String>('crest');
  set crest(String? value) => setField<String>('crest', value);

  int? get sortOrder => getField<int>('sort_order');
  set sortOrder(int? value) => setField<int>('sort_order', value);
}
