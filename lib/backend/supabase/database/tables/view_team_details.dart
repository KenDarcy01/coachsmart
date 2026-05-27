import '../database.dart';

class ViewTeamDetailsTable extends SupabaseTable<ViewTeamDetailsRow> {
  @override
  String get tableName => 'view_team_details';

  @override
  ViewTeamDetailsRow createRow(Map<String, dynamic> data) =>
      ViewTeamDetailsRow(data);
}

class ViewTeamDetailsRow extends SupabaseDataRow {
  ViewTeamDetailsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewTeamDetailsTable();

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  String? get teamNameLowercase => getField<String>('team_name_lowercase');
  set teamNameLowercase(String? value) =>
      setField<String>('team_name_lowercase', value);

  String? get teamCode => getField<String>('team_code');
  set teamCode(String? value) => setField<String>('team_code', value);

  String? get teamCodeLowercase => getField<String>('team_code_lowercase');
  set teamCodeLowercase(String? value) =>
      setField<String>('team_code_lowercase', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);
}
