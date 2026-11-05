import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'validate_page_widget.dart' show ValidatePageWidget;
import 'package:flutter/material.dart';

class ValidatePageModel extends FlutterFlowModel<ValidatePageWidget> {
  ///  Local state fields for this page.

  bool varValidateEmail = false;

  ///  State fields for stateful widgets in this page.

  // State field(s) for TabBar widget.
  TabController? tabBarController;
  int get tabBarCurrentIndex =>
      tabBarController != null ? tabBarController!.index : 0;
  int get tabBarPreviousIndex =>
      tabBarController != null ? tabBarController!.previousIndex : 0;

  // Stores action output result for [Backend Call - Query Rows] action in login widget.
  List<UsersRow>? outputQueryUser;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    tabBarController?.dispose();
  }
}
