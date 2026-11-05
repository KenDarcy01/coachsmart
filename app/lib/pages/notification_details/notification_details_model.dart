import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'notification_details_widget.dart' show NotificationDetailsWidget;
import 'package:flutter/material.dart';

class NotificationDetailsModel
    extends FlutterFlowModel<NotificationDetailsWidget> {
  ///  Local state fields for this page.

  int? memberCount;

  int? currentSquad;

  int? currentRole;

  int? currentIndex;

  int? squadSelected;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getUserNotifications)] action in IconButton widget.
  ApiCallResponse? apiUserNotifications2;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
