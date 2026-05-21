import '../database.dart';

class UserMemberLinkTable extends SupabaseTable<UserMemberLinkRow> {
  @override
  String get tableName => 'user_member_link';

  @override
  UserMemberLinkRow createRow(Map<String, dynamic> data) =>
      UserMemberLinkRow(data);
}

class UserMemberLinkRow extends SupabaseDataRow {
  UserMemberLinkRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => UserMemberLinkTable();

  int get userMemberId => getField<int>('user_member_id')!;
  set userMemberId(int value) => setField<int>('user_member_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);
}
