import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'user_member_details_widget.dart' show UserMemberDetailsWidget;
import 'package:flutter/material.dart';

class UserMemberDetailsModel extends FlutterFlowModel<UserMemberDetailsWidget> {
  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - Query Rows] action in createTeamButton widget.
  List<MemberTeamLinkRow>? outputMemberLink;
  // Stores action output result for [Backend Call - Delete Row(s)] action in createTeamButton widget.
  List<MemberTeamLinkRow>? outputDelete;
  // Stores action output result for [Backend Call - Query Rows] action in createTeamButton widget.
  List<MemberTeamLinkRow>? outputMemberTeamLink;
  // Stores action output result for [Backend Call - Delete Row(s)] action in createTeamButton widget.
  List<UserMemberLinkRow>? outputDeleteUserMemberLink;
  // Stores action output result for [Backend Call - Delete Row(s)] action in createTeamButton widget.
  List<EventAttendanceRow>? outputDeleteEventAttendance;
  // Stores action output result for [Backend Call - Delete Row(s)] action in createTeamButton widget.
  List<MembersRow>? outputDeleteMember;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
