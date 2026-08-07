import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'pending_requests_widget.dart' show PendingRequestsWidget;
import 'package:flutter/material.dart';

class PendingRequestsModel extends FlutterFlowModel<PendingRequestsWidget> {
  ///  Local state fields for this page.

  bool varCreatePool = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getPendingTeamRequests)] action in PendingRequests widget.
  ApiCallResponse? apiJoinRequests;
  // Stores action output result for [Backend Call - API (getTeamRoles)] action in Button widget.
  ApiCallResponse? apiRoleList;
  // Stores action output result for [Backend Call - API (denyMemberJoin)] action in Button widget.
  ApiCallResponse? apiDenyJoin;
  // Stores action output result for [Backend Call - API (getUserTeamSummary)] action in Button widget.
  ApiCallResponse? apiPendingRequestsDeny;
  // Stores action output result for [Backend Call - API (getPendingTeamRequests)] action in Button widget.
  ApiCallResponse? apiJoinRequestsDeny;
  // Stores action output result for [Backend Call - API (confirmUserMemberAccess)] action in Button widget.
  ApiCallResponse? apiConfirmMemberAccess;
  // Stores action output result for [Backend Call - API (getUserTeamSummary)] action in Button widget.
  ApiCallResponse? apiPendingRequestsConfirm1;
  // Stores action output result for [Backend Call - API (getPendingTeamRequests)] action in Button widget.
  ApiCallResponse? apiJoinRequestsConfirm1;
  // Stores action output result for [Backend Call - API (denyUserMemberAccess)] action in Button widget.
  ApiCallResponse? apiResults5qCopy;
  // Stores action output result for [Backend Call - API (getUserTeamSummary)] action in Button widget.
  ApiCallResponse? apiPendingRequestsDenyCopy;
  // Stores action output result for [Backend Call - API (getPendingTeamRequests)] action in Button widget.
  ApiCallResponse? apiJoinRequestsDenyCopy;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
