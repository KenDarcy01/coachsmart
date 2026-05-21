import '../database.dart';

class CarPoolTable extends SupabaseTable<CarPoolRow> {
  @override
  String get tableName => 'car_pool';

  @override
  CarPoolRow createRow(Map<String, dynamic> data) => CarPoolRow(data);
}

class CarPoolRow extends SupabaseDataRow {
  CarPoolRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => CarPoolTable();

  int get carPoolId => getField<int>('car_pool_id')!;
  set carPoolId(int value) => setField<int>('car_pool_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get numberOfSeats => getField<int>('number_of_seats');
  set numberOfSeats(int? value) => setField<int>('number_of_seats', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);
}
