import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'join_team_widget.dart' show JoinTeamWidget;
import 'package:flutter/material.dart';

class JoinTeamModel extends FlutterFlowModel<JoinTeamWidget> {
  ///  Local state fields for this page.

  bool? existingMember;

  bool? userHasMembers;

  int? choiceSelected;

  String? joiningCodePageVar;

  int? memberIdPageVar;

  String? varTeamName;

  bool varJoiningCodeBool = false;

  bool? varJoinaTeam;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - Query Rows] action in JoinTeam widget.
  List<ViewTeamDetailsRow>? outputTeamDetails;
  // Stores action output result for [Backend Call - Query Rows] action in JoinTeam widget.
  List<ViewUserTeamMembersRow>? userMembers;
  // State field(s) for teamCodeInput widget.
  FocusNode? teamCodeInputFocusNode;
  TextEditingController? teamCodeInputTextController;
  String? Function(BuildContext, String?)? teamCodeInputTextControllerValidator;
  // Stores action output result for [Backend Call - Query Rows] action in teamCodeInput widget.
  List<ViewTeamDetailsRow>? outputTeamInput;
  // State field(s) for memberFirstNameInput widget.
  FocusNode? memberFirstNameInputFocusNode;
  TextEditingController? memberFirstNameInputTextController;
  String? Function(BuildContext, String?)?
      memberFirstNameInputTextControllerValidator;
  // State field(s) for memberLastNameInput widget.
  FocusNode? memberLastNameInputFocusNode;
  TextEditingController? memberLastNameInputTextController;
  String? Function(BuildContext, String?)?
      memberLastNameInputTextControllerValidator;
  // Stores action output result for [Backend Call - API (createNewMemberByCode)] action in joinTeamButton widget.
  ApiCallResponse? apiResultw31;
  // Stores action output result for [Backend Call - API (getTeamMembersByRole)] action in joinTeamButton widget.
  ApiCallResponse? apiGetTeamMembersByRole;
  // State field(s) for memberCodeInput widget.
  FocusNode? memberCodeInputFocusNode;
  TextEditingController? memberCodeInputTextController;
  String? Function(BuildContext, String?)?
      memberCodeInputTextControllerValidator;
  // Stores action output result for [Backend Call - Query Rows] action in joinTeamButton widget.
  List<MembersRow>? outputMemberCode;
  // Stores action output result for [Backend Call - Query Rows] action in joinTeamButton widget.
  List<UserMemberLinkRow>? outputExistingMember;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    teamCodeInputFocusNode?.dispose();
    teamCodeInputTextController?.dispose();

    memberFirstNameInputFocusNode?.dispose();
    memberFirstNameInputTextController?.dispose();

    memberLastNameInputFocusNode?.dispose();
    memberLastNameInputTextController?.dispose();

    memberCodeInputFocusNode?.dispose();
    memberCodeInputTextController?.dispose();
  }
}
