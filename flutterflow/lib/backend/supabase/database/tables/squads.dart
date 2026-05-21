import '../database.dart';

class SquadsTable extends SupabaseTable<SquadsRow> {
  @override
  String get tableName => 'squads';

  @override
  SquadsRow createRow(Map<String, dynamic> data) => SquadsRow(data);
}

class SquadsRow extends SupabaseDataRow {
  SquadsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => SquadsTable();

  int get squadId => getField<int>('squad_id')!;
  set squadId(int value) => setField<int>('squad_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get squadName => getField<String>('squad_name');
  set squadName(String? value) => setField<String>('squad_name', value);

  String? get grade => getField<String>('grade');
  set grade(String? value) => setField<String>('grade', value);

  String? get squadColour => getField<String>('squad_colour');
  set squadColour(String? value) => setField<String>('squad_colour', value);

  String? get squadImage => getField<String>('squad_image');
  set squadImage(String? value) => setField<String>('squad_image', value);

  int? get squadListSeq => getField<int>('squad_list_seq');
  set squadListSeq(int? value) => setField<int>('squad_list_seq', value);
}
