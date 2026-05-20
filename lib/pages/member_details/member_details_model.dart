import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'member_details_widget.dart' show MemberDetailsWidget;
import 'package:flutter/material.dart';

class MemberDetailsModel extends FlutterFlowModel<MemberDetailsWidget> {
  ///  Local state fields for this page.

  MemberTeamDetailsStruct? memberTeamDetails;
  void updateMemberTeamDetailsStruct(
      Function(MemberTeamDetailsStruct) updateFn) {
    updateFn(memberTeamDetails ??= MemberTeamDetailsStruct());
  }

  List<int> selectedRoles = [];
  void addToSelectedRoles(int item) => selectedRoles.add(item);
  void removeFromSelectedRoles(int item) => selectedRoles.remove(item);
  void removeAtIndexFromSelectedRoles(int index) =>
      selectedRoles.removeAt(index);
  void insertAtIndexInSelectedRoles(int index, int item) =>
      selectedRoles.insert(index, item);
  void updateSelectedRolesAtIndex(int index, Function(int) updateFn) =>
      selectedRoles[index] = updateFn(selectedRoles[index]);

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getMemberTeamDetails)] action in MemberDetails widget.
  ApiCallResponse? apiMemberTeamDetails;
  // Stores action output result for [Backend Call - API (removeMemberFromTeam)] action in createTeamButton widget.
  ApiCallResponse? apiResultj6g;
  // Stores action output result for [Backend Call - API (getTeamMembersByRole)] action in createTeamButton widget.
  ApiCallResponse? apiGetTeamMembersByRole;
  // State field(s) for memberFirstName widget.
  FocusNode? memberFirstNameFocusNode;
  TextEditingController? memberFirstNameTextController;
  String? Function(BuildContext, String?)?
      memberFirstNameTextControllerValidator;
  // State field(s) for memberLastName widget.
  FocusNode? memberLastNameFocusNode;
  TextEditingController? memberLastNameTextController;
  String? Function(BuildContext, String?)?
      memberLastNameTextControllerValidator;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<MemberTeamLinkRow>? outputMemberTeamLink;
  // Stores action output result for [Backend Call - Delete Row(s)] action in Button widget.
  List<MemberTeamRoleLinkRow>? outputDeleteMemberTeamRole;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<MemberTeamLinkRow>? outputMemberTeamLink1;
  // Stores action output result for [Backend Call - API (getMemberTeamDetails)] action in Button widget.
  ApiCallResponse? apiRefreshGetMemberTeamDetails;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    memberFirstNameFocusNode?.dispose();
    memberFirstNameTextController?.dispose();

    memberLastNameFocusNode?.dispose();
    memberLastNameTextController?.dispose();
  }
}
