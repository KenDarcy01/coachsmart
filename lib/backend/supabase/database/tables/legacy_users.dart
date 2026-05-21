import '../database.dart';

class LegacyUsersTable extends SupabaseTable<LegacyUsersRow> {
  @override
  String get tableName => 'legacy_users';

  @override
  LegacyUsersRow createRow(Map<String, dynamic> data) => LegacyUsersRow(data);
}

class LegacyUsersRow extends SupabaseDataRow {
  LegacyUsersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => LegacyUsersTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get legacyUserid => getField<String>('legacy_userid');
  set legacyUserid(String? value) => setField<String>('legacy_userid', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

  String? get memberFirstName => getField<String>('member_first_name');
  set memberFirstName(String? value) =>
      setField<String>('member_first_name', value);

  String? get memberLastName => getField<String>('member_last_name');
  set memberLastName(String? value) =>
      setField<String>('member_last_name', value);

  String? get userFirstName => getField<String>('user_first_name');
  set userFirstName(String? value) =>
      setField<String>('user_first_name', value);

  String? get userLastName => getField<String>('user_last_name');
  set userLastName(String? value) => setField<String>('user_last_name', value);

  String? get teamId => getField<String>('team_id');
  set teamId(String? value) => setField<String>('team_id', value);

  String? get role => getField<String>('role');
  set role(String? value) => setField<String>('role', value);

  bool? get processed => getField<bool>('processed');
  set processed(bool? value) => setField<bool>('processed', value);

  String? get phoneNumber => getField<String>('phone_number');
  set phoneNumber(String? value) => setField<String>('phone_number', value);
}
