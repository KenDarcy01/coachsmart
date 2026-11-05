import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'car_pool_details_widget.dart' show CarPoolDetailsWidget;
import 'dart:async';
import 'package:flutter/material.dart';

class CarPoolDetailsModel extends FlutterFlowModel<CarPoolDetailsWidget> {
  ///  Local state fields for this page.

  int? varMemberID;

  ///  State fields for stateful widgets in this page.

  // State field(s) for DropDown widget.
  int? dropDownValue;
  FormFieldController<int>? dropDownValueController;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<CarPoolDetailRow>? outputExistingCarPool;
  Completer<ApiCallResponse>? apiRequestCompleter;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<MembersRow>? outputMemberReservation;
  // Stores action output result for [Backend Call - API (sendEmail)] action in Button widget.
  ApiCallResponse? apiResult28;
  // Stores action output result for [Backend Call - API (sendEmail)] action in Button widget.
  ApiCallResponse? apiResult29;
  // Stores action output result for [Backend Call - Delete Row(s)] action in Button widget.
  List<CarPoolDetailRow>? outputReservation;
  // Stores action output result for [Backend Call - API (sendEmail)] action in Button widget.
  ApiCallResponse? apiResult26;
  // Stores action output result for [Backend Call - API (sendEmail)] action in Button widget.
  ApiCallResponse? apiResult27;
  // Stores action output result for [Backend Call - Update Row(s)] action in Button widget.
  List<CarPoolDetailRow>? outputDeleteReservations;
  // Stores action output result for [Backend Call - API (getEventCarPools)] action in Button widget.
  ApiCallResponse? outputCreateCarPoolAPI;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}

  /// Additional helper methods.
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
