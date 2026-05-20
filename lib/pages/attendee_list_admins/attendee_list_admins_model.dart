import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'attendee_list_admins_widget.dart' show AttendeeListAdminsWidget;
import 'dart:async';
import 'package:flutter/material.dart';

class AttendeeListAdminsModel
    extends FlutterFlowModel<AttendeeListAdminsWidget> {
  ///  Local state fields for this page.

  int? memberCount;

  int? currentSquad;

  int? currentRole;

  int? currentIndex;

  int? squadSelected;

  int? varFilterRole;

  bool varMatchTeamsCreated = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (createMatchDaySquadFromAttendance)] action in publishButton widget.
  ApiCallResponse? outputCreateMatchDaySquad;
  Completer<List<MatchSquadsRow>>? requestCompleter;
  // Stores action output result for [Backend Call - API (getUpdatedEventCode)] action in Row widget.
  ApiCallResponse? outputUpdatedCode;
  // Stores action output result for [Backend Call - Query Rows] action in Row widget.
  List<MemberSquadLinkRow>? outputExistingMemberSquad;
  Completer<ApiCallResponse>? apiRequestCompleter;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}

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

  Future waitForApiRequestCompleted({
    double minWait = 0,
    double maxWait = double.infinity,
  }) async {
    final stopwatch = Stopwatch()..start();
    while (true) {
      await Future.delayed(Duration(milliseconds: 50));
      final timeElapsed = stopwatch.elapsedMilliseconds;
      final requestComplete = apiRequestCompleter?.isCompleted ?? false;
      if (timeElapsed > maxWait || (requestComplete && timeElapsed > minWait)) {
        break;
      }
    }
  }
}
