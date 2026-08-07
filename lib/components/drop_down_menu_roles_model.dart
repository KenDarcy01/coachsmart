import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'drop_down_menu_roles_widget.dart' show DropDownMenuRolesWidget;
import 'package:flutter/material.dart';

class DropDownMenuRolesModel extends FlutterFlowModel<DropDownMenuRolesWidget> {
  ///  Local state fields for this component.

  List<int> selectedRoles = [];
  void addToSelectedRoles(int item) => selectedRoles.add(item);
  void removeFromSelectedRoles(int item) => selectedRoles.remove(item);
  void removeAtIndexFromSelectedRoles(int index) =>
      selectedRoles.removeAt(index);
  void insertAtIndexInSelectedRoles(int index, int item) =>
      selectedRoles.insert(index, item);
  void updateSelectedRolesAtIndex(int index, Function(int) updateFn) =>
      selectedRoles[index] = updateFn(selectedRoles[index]);

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - API (confirmMemberJoin)] action in Button widget.
  ApiCallResponse? apiConfirm;
  // Stores action output result for [Backend Call - API (getUserTeamSummary)] action in Button widget.
  ApiCallResponse? apiPendingRequests;
  // Stores action output result for [Backend Call - API (getPendingTeamRequests)] action in Button widget.
  ApiCallResponse? apiJoinRequests;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
