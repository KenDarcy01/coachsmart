import '/flutter_flow/flutter_flow_util.dart';
import 'drop_down_menu_edit_widget.dart' show DropDownMenuEditWidget;
import 'package:flutter/material.dart';

class DropDownMenuEditModel extends FlutterFlowModel<DropDownMenuEditWidget> {
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

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
