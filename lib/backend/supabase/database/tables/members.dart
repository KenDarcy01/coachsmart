import '../database.dart';

class MembersTable extends SupabaseTable<MembersRow> {
  @override
  String get tableName => 'members';

  @override
  MembersRow createRow(Map<String, dynamic> data) => MembersRow(data);
}

class MembersRow extends SupabaseDataRow {
  MembersRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => MembersTable();

  int get memberId => getField<int>('member_id')!;
  set memberId(int value) => setField<int>('member_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get firstName => getField<String>('first_name');
  set firstName(String? value) => setField<String>('first_name', value);

  String? get lastName => getField<String>('last_name');
  set lastName(String? value) => setField<String>('last_name', value);

  String? get profilePic => getField<String>('profile_pic');
  set profilePic(String? value) => setField<String>('profile_pic', value);

  String? get uniqueMemberCode => getField<String>('unique_member_code');
  set uniqueMemberCode(String? value) =>
      setField<String>('unique_member_code', value);

  DateTime? get dateOfBirth => getField<DateTime>('date_of_birth');
  set dateOfBirth(DateTime? value) =>
      setField<DateTime>('date_of_birth', value);

  String? get membershipNum => getField<String>('membership_num');
  set membershipNum(String? value) => setField<String>('membership_num', value);

  String? get nameTranslated => getField<String>('name_translated');
  set nameTranslated(String? value) =>
      setField<String>('name_translated', value);
}
