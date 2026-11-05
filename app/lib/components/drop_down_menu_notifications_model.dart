import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'drop_down_menu_notifications_widget.dart'
    show DropDownMenuNotificationsWidget;
import 'package:flutter/material.dart';

class DropDownMenuNotificationsModel
    extends FlutterFlowModel<DropDownMenuNotificationsWidget> {
  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - Query Rows] action in replaceWidget widget.
  List<NotificationsRow>? outputUnreadNotifications;
  // Stores action output result for [Custom Action - updateAppBadge] action in replaceWidget widget.
  String? outputBadgeUpdate;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in replaceWidget widget.
  ApiCallResponse? apiUserNotificationsRefresh;
  // Stores action output result for [Backend Call - Query Rows] action in replaceWidget widget.
  List<NotificationsRow>? outputReadNotifications;
  // Stores action output result for [Custom Action - updateAppBadge] action in replaceWidget widget.
  String? outputBadgeUpdateRead;
  // Stores action output result for [Backend Call - API (getUserNotifications)] action in replaceWidget widget.
  ApiCallResponse? apiUserNotificationsRefreshRead;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
