import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'search_page_widget.dart' show SearchPageWidget;
import 'package:flutter/material.dart';

class SearchPageModel extends FlutterFlowModel<SearchPageWidget> {
  ///  Local state fields for this page.

  int varSelectedTeam = 0;

  int varSelectedType = 0;

  int varSelectedCode = 0;

  ///  State fields for stateful widgets in this page.

  // State field(s) for locationInput widget.
  FocusNode? locationInputFocusNode;
  TextEditingController? locationInputTextController;
  String? Function(BuildContext, String?)? locationInputTextControllerValidator;
  // Stores action output result for [Backend Call - API (getEventsList)] action in Button widget.
  ApiCallResponse? apiResultEvents;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    locationInputFocusNode?.dispose();
    locationInputTextController?.dispose();
  }
}
