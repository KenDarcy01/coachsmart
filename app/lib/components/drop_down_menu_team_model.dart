import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'drop_down_menu_team_widget.dart' show DropDownMenuTeamWidget;
import 'package:flutter/material.dart';

class DropDownMenuTeamModel extends FlutterFlowModel<DropDownMenuTeamWidget> {
  ///  Local state fields for this component.

  String? varCurrentEmailAddress;

  List<String> reminderEmailList = [];
  void addToReminderEmailList(String item) => reminderEmailList.add(item);
  void removeFromReminderEmailList(String item) =>
      reminderEmailList.remove(item);
  void removeAtIndexFromReminderEmailList(int index) =>
      reminderEmailList.removeAt(index);
  void insertAtIndexInReminderEmailList(int index, String item) =>
      reminderEmailList.insert(index, item);
  void updateReminderEmailListAtIndex(int index, Function(String) updateFn) =>
      reminderEmailList[index] = updateFn(reminderEmailList[index]);

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - API (exportTeamListXLS)] action in Button widget.
  ApiCallResponse? apiResultced;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
