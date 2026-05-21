import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'home_page_widget.dart' show HomePageWidget;
import 'package:flutter/material.dart';

class HomePageModel extends FlutterFlowModel<HomePageWidget> {
  ///  Local state fields for this page.

  int? varSelectedClub = 0;

  int varSelectedTeam = 0;

  dynamic updatedEvent;

  int? listIndex;

  bool varShowHome = false;

  dynamic varAPIdetails;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in HomePage widget.
  ApiCallResponse? outputHomeLoad;
  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in scrollingColumn widget.
  ApiCallResponse? outputHomeRefresh;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
