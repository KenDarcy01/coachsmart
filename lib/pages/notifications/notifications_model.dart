import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'notifications_widget.dart' show NotificationsWidget;
import 'package:flutter/material.dart';

class NotificationsModel extends FlutterFlowModel<NotificationsWidget> {
  ///  Local state fields for this page.

  bool? varReadFilter;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Notifications widget.
  ApiCallResponse? apiUserNotifications;
  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in IconButton widget.
  ApiCallResponse? outputUpdatedEvents;
  // Stores action output result for [Backend Call - Update Row(s)] action in Container widget.
  List<NotificationsRow>? outputUpdate;
  // Stores action output result for [Backend Call - Query Rows] action in Container widget.
  List<NotificationsRow>? outputUnreadNotifications;
  // Stores action output result for [Custom Action - updateAppBadge] action in Container widget.
  String? outputBadgeUpdate;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Icon widget.
  ApiCallResponse? apiUserNotifications1;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
