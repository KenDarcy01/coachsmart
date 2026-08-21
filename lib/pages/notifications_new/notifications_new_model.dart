import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'notifications_new_widget.dart' show NotificationsNewWidget;
import 'package:flutter/material.dart';

class NotificationsNewModel extends FlutterFlowModel<NotificationsNewWidget> {
  ///  Local state fields for this page.

  bool? varReadFilter;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getUserNotifications)] action in NotificationsNew widget.
  ApiCallResponse? apiUserNotifications;
  // Stores action output result for [Backend Call - API (markAllNotifcationsRead)] action in NotificationsNew widget.
  ApiCallResponse? apiMarkAllNotificationAsRead;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in NotificationsNew widget.
  ApiCallResponse? apiUserNotificationsRead;
  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in IconButton widget.
  ApiCallResponse? outputUpdatedEvents;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Icon widget.
  ApiCallResponse? apiUserNotifications1;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<NotificationsRow>? queryNotification;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsExisting;
  // Stores action output result for [Backend Call - API (getTeamRoles)] action in Button widget.
  ApiCallResponse? apiRoleList;
  // Stores action output result for [Backend Call - API (markNotificationRead)] action in Button widget.
  ApiCallResponse? apiMarkNotificationReadAccepted;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsAccepted;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<NotificationsRow>? queryNotificationDeclined;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsDeclinedFail;
  // Stores action output result for [Backend Call - API (denyMemberJoin)] action in Button widget.
  ApiCallResponse? apiDenyJoin;
  // Stores action output result for [Backend Call - API (markNotificationRead)] action in Button widget.
  ApiCallResponse? apiMarkNotificationDeclined;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsDeclined;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<NotificationsRow>? queryNotificationAccess;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsExistingAccess;
  // Stores action output result for [Backend Call - API (confirmUserMemberAccess)] action in Button widget.
  ApiCallResponse? apiConfirmUserMemberAccess;
  // Stores action output result for [Backend Call - API (markNotificationRead)] action in Button widget.
  ApiCallResponse? apiMarkNotificationReadAcceptedAccess;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsAcceptedAccess;
  // Stores action output result for [Backend Call - Query Rows] action in Button widget.
  List<NotificationsRow>? queryNotificationDeclinedAccess;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsDeclinedFailAccess;
  // Stores action output result for [Backend Call - API (markNotificationRead)] action in Button widget.
  ApiCallResponse? apiMarkNotificationDeclinedAccess;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsDeclinedAccess;
  // Stores action output result for [Backend Call - API (markNotificationRead)] action in Button widget.
  ApiCallResponse? apiMarkNotificationReadAcceptedEvent;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in Button widget.
  ApiCallResponse? apiUserNotificationsAcceptedEvent;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
