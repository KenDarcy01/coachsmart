import '../database.dart';

class ViewMemberResponseListTable
    extends SupabaseTable<ViewMemberResponseListRow> {
  @override
  String get tableName => 'view_member_response_list';

  @override
  ViewMemberResponseListRow createRow(Map<String, dynamic> data) =>
      ViewMemberResponseListRow(data);
}

class ViewMemberResponseListRow extends SupabaseDataRow {
  ViewMemberResponseListRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewMemberResponseListTable();

  int? get idx => getField<int>('idx');
  set idx(int? value) => setField<int>('idx', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

  String? get phoneNumber => getField<String>('phone_number');
  set phoneNumber(String? value) => setField<String>('phone_number', value);

  String? get userFirstName => getField<String>('user_first_name');
  set userFirstName(String? value) =>
      setField<String>('user_first_name', value);

  String? get userLastName => getField<String>('user_last_name');
  set userLastName(String? value) => setField<String>('user_last_name', value);

  String? get userFullName => getField<String>('user_full_name');
  set userFullName(String? value) => setField<String>('user_full_name', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get memberFirstName => getField<String>('member_first_name');
  set memberFirstName(String? value) =>
      setField<String>('member_first_name', value);

  String? get memberLastName => getField<String>('member_last_name');
  set memberLastName(String? value) =>
      setField<String>('member_last_name', value);

  String? get memberFullName => getField<String>('member_full_name');
  set memberFullName(String? value) =>
      setField<String>('member_full_name', value);

  String? get memberProfilePic => getField<String>('member_profile_pic');
  set memberProfilePic(String? value) =>
      setField<String>('member_profile_pic', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);

  String? get roleName => getField<String>('role_name');
  set roleName(String? value) => setField<String>('role_name', value);

  int? get roleLevel => getField<int>('role_level');
  set roleLevel(int? value) => setField<int>('role_level', value);

  int? get roleGrade => getField<int>('role_grade');
  set roleGrade(int? value) => setField<int>('role_grade', value);
}
