import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'create_team_widget.dart' show CreateTeamWidget;
import 'package:flutter/material.dart';

class CreateTeamModel extends FlutterFlowModel<CreateTeamWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for teamNameInput widget.
  FocusNode? teamNameInputFocusNode;
  TextEditingController? teamNameInputTextController;
  String? Function(BuildContext, String?)? teamNameInputTextControllerValidator;
  // State field(s) for dropDownClub widget.
  int? dropDownClubValue;
  FormFieldController<int>? dropDownClubValueController;
  // State field(s) for SwitchJuvenile widget.
  bool? switchJuvenileValue;
  // State field(s) for SwitchFemale widget.
  bool? switchFemaleValue;
  // Stores action output result for [Backend Call - Insert Row] action in createTeamButton widget.
  TeamsRow? newTeamRow;
  // Stores action output result for [Backend Call - Query Rows] action in createTeamButton widget.
  List<RolesRow>? outputQueryPlayer;
  // Stores action output result for [Backend Call - Query Rows] action in createTeamButton widget.
  List<RolesRow>? outputQueryAdmin;
  // Stores action output result for [Backend Call - Query Rows] action in createTeamButton widget.
  List<RolesRow>? outputQueryCoach;
  // Stores action output result for [Backend Call - Query Rows] action in createTeamButton widget.
  List<RolesRow>? outputQueryFLO;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    teamNameInputFocusNode?.dispose();
    teamNameInputTextController?.dispose();
  }
}
