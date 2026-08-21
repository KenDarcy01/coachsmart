import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'create_team_new_widget.dart' show CreateTeamNewWidget;
import 'package:flutter/material.dart';

class CreateTeamNewModel extends FlutterFlowModel<CreateTeamNewWidget> {
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

  // Stores action output result for [Backend Call - API (getUserTeamSummary)] action in IconButton widget.
  ApiCallResponse? apiTeamSummary;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
