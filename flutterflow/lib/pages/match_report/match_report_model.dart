import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'dart:async';
import 'match_report_widget.dart' show MatchReportWidget;
import 'package:flutter/material.dart';

class MatchReportModel extends FlutterFlowModel<MatchReportWidget> {
  ///  Local state fields for this page.

  int? memberCount;

  int? currentSquad;

  int? currentRole;

  int? currentIndex;

  int? squadSelected;

  ///  State fields for stateful widgets in this page.

  // State field(s) for eventDetail widget.
  FocusNode? eventDetailFocusNode;
  TextEditingController? eventDetailTextController;
  String? Function(BuildContext, String?)? eventDetailTextControllerValidator;
  // Stores action output result for [Backend Call - Insert Row] action in Button widget.
  MatchReportsRow? outputCreatedMatchReport;
  Completer<List<ViewMatchReportsRow>>? requestCompleter;
  // Stores action output result for [Backend Call - API (send MatchReportToAdmins)] action in Button widget.
  ApiCallResponse? apiResultjx3;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    eventDetailFocusNode?.dispose();
    eventDetailTextController?.dispose();
  }

  /// Additional helper methods.
  Future waitForRequestCompleted({
    double minWait = 0,
    double maxWait = double.infinity,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      await Future.delayed(Duration(milliseconds: 50));
      final timeElapsed = stopwatch.elapsedMilliseconds;
      final requestComplete = requestCompleter?.isCompleted ?? false;
      if (timeElapsed > maxWait || (requestComplete && timeElapsed > minWait)) {
        break;
      }
    }
  }
}
