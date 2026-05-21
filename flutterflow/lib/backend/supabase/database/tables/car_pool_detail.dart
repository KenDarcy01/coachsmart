import '../database.dart';

class CarPoolDetailTable extends SupabaseTable<CarPoolDetailRow> {
  @override
  String get tableName => 'car_pool_detail';

  @override
  CarPoolDetailRow createRow(Map<String, dynamic> data) =>
      CarPoolDetailRow(data);
}

class CarPoolDetailRow extends SupabaseDataRow {
  CarPoolDetailRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => CarPoolDetailTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get carPoolId => getField<int>('car_pool_id');
  set carPoolId(int? value) => setField<int>('car_pool_id', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get status => getField<String>('status');
  set status(String? value) => setField<String>('status', value);
}
