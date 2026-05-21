import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'team_members_widget.dart' show TeamMembersWidget;
import 'package:flutter/material.dart';

class TeamMembersModel extends FlutterFlowModel<TeamMembersWidget> {
  ///  Local state fields for this page.

  int? squadSelected;

  int? codeSelected;

  String? searchMember = ' ';

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getTeamMembersByRole)] action in TeamMembers widget.
  ApiCallResponse? apiGetTeamMembersByRole;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Backend Call - Query Rows] action in Row widget.
  List<MemberSquadLinkRow>? outputExistingCodeRecord;
  // Stores action output result for [Backend Call - Insert Row] action in Row widget.
  MemberSquadLinkRow? outputInsertSquadLink;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
