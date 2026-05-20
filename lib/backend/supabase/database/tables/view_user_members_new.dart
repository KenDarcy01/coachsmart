import '../database.dart';

class ViewUserMembersNewTable extends SupabaseTable<ViewUserMembersNewRow> {
  @override
  String get tableName => 'view_user_members_new';

  @override
  ViewUserMembersNewRow createRow(Map<String, dynamic> data) =>
      ViewUserMembersNewRow(data);
}

class ViewUserMembersNewRow extends SupabaseDataRow {
  ViewUserMembersNewRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => ViewUserMembersNewTable();

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  int? get userMemberId => getField<int>('user_member_id');
  set userMemberId(int? value) => setField<int>('user_member_id', value);

  DateTime? get createdAt => getField<DateTime>('created_at');
  set createdAt(DateTime? value) => setField<DateTime>('created_at', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);

  String? get memberFirstName => getField<String>('member_first_name');
  set memberFirstName(String? value) =>
      setField<String>('member_first_name', value);

  String? get memberLastName => getField<String>('member_last_name');
  set memberLastName(String? value) =>
      setField<String>('member_last_name', value);

  String? get memberProfilePic => getField<String>('member_profile_pic');
  set memberProfilePic(String? value) =>
      setField<String>('member_profile_pic', value);

  String? get uniqueMemberCode => getField<String>('unique_member_code');
  set uniqueMemberCode(String? value) =>
      setField<String>('unique_member_code', value);

  String? get emailAddress => getField<String>('email_address');
  set emailAddress(String? value) => setField<String>('email_address', value);

  String? get userFirstName => getField<String>('user_first_name');
  set userFirstName(String? value) =>
      setField<String>('user_first_name', value);

  String? get userLastName => getField<String>('user_last_name');
  set userLastName(String? value) => setField<String>('user_last_name', value);

  String? get phoneNumber => getField<String>('phone_number');
  set phoneNumber(String? value) => setField<String>('phone_number', value);

  int? get teamId => getField<int>('team_id');
  set teamId(int? value) => setField<int>('team_id', value);

  String? get teamName => getField<String>('team_name');
  set teamName(String? value) => setField<String>('team_name', value);

  int? get memberTeamId => getField<int>('member_team_id');
  set memberTeamId(int? value) => setField<int>('member_team_id', value);

  int? get roleId => getField<int>('role_id');
  set roleId(int? value) => setField<int>('role_id', value);

  String? get roleName => getField<String>('role_name');
  set roleName(String? value) => setField<String>('role_name', value);
}
