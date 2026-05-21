import '/backend/api_requests/api_calls.dart';
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
  // State field(s) for shareEmail widget.
  FocusNode? shareEmailFocusNode;
  TextEditingController? shareEmailTextController;
  String? Function(BuildContext, String?)? shareEmailTextControllerValidator;
  // Stores action output result for [Backend Call - API (sendEmail)] action in createTeamButton widget.
  ApiCallResponse? outputEmailSend;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    shareEmailFocusNode?.dispose();
    shareEmailTextController?.dispose();
  }
}
