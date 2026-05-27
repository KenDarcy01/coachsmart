import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'admin_options_widget.dart' show AdminOptionsWidget;
import 'package:flutter/material.dart';

class AdminOptionsModel extends FlutterFlowModel<AdminOptionsWidget> {
  ///  Local state fields for this page.

  int? memberCount;

  int? currentSquad;

  int? currentRole;

  int? currentIndex;

  int? squadSelected;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getEventAdminDetails)] action in AdminOptions widget.
  ApiCallResponse? apiEventAdminDetail;
  // Stores action output result for [Backend Call - API (populateEventNotifications)] action in Button widget.
  ApiCallResponse? apiPopulateNotifications;
  // Stores action output result for [Backend Call - API (getEventAdminDetails)] action in Button widget.
  ApiCallResponse? apiUpdateAdminDetail;
  // State field(s) for switchUpdates widget.
  bool? switchUpdatesValue;
  // State field(s) for switchAllChanges widget.
  bool? switchAllChangesValue;
  // State field(s) for switchCarPool widget.
  bool? switchCarPoolValue;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
