import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'dart:async';
import 'event_details_widget.dart' show EventDetailsWidget;
import 'package:flutter/material.dart';

class EventDetailsModel extends FlutterFlowModel<EventDetailsWidget> {
  ///  Local state fields for this page.

  List<String> emailReceipients = [];
  void addToEmailReceipients(String item) => emailReceipients.add(item);
  void removeFromEmailReceipients(String item) => emailReceipients.remove(item);
  void removeAtIndexFromEmailReceipients(int index) =>
      emailReceipients.removeAt(index);
  void insertAtIndexInEmailReceipients(int index, String item) =>
      emailReceipients.insert(index, item);
  void updateEmailReceipientsAtIndex(int index, Function(String) updateFn) =>
      emailReceipients[index] = updateFn(emailReceipients[index]);

  String? stripeCheckoutUrl;

  List<dynamic> payingMembers = [];
  void addToPayingMembers(dynamic item) => payingMembers.add(item);
  void removeFromPayingMembers(dynamic item) => payingMembers.remove(item);
  void removeAtIndexFromPayingMembers(int index) =>
      payingMembers.removeAt(index);
  void insertAtIndexInPayingMembers(int index, dynamic item) =>
      payingMembers.insert(index, item);
  void updatePayingMembersAtIndex(int index, Function(dynamic) updateFn) =>
      payingMembers[index] = updateFn(payingMembers[index]);

  List<int> payingMemberIds = [];
  void addToPayingMemberIds(int item) => payingMemberIds.add(item);
  void removeFromPayingMemberIds(int item) => payingMemberIds.remove(item);
  void removeAtIndexFromPayingMemberIds(int index) =>
      payingMemberIds.removeAt(index);
  void insertAtIndexInPayingMemberIds(int index, int item) =>
      payingMemberIds.insert(index, item);
  void updatePayingMemberIdsAtIndex(int index, Function(int) updateFn) =>
      payingMemberIds[index] = updateFn(payingMemberIds[index]);

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getUserEventDetails)] action in EventDetails widget.
  ApiCallResponse? apiEventDetails;
  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in IconButton widget.
  ApiCallResponse? outputUpdatedEvents;
  // Stores action output result for [Backend Call - Insert Row] action in acceptButton widget.
  EventAttendanceRow? outputInsertRow;
  Completer<ApiCallResponse>? apiRequestCompleter;
  // Stores action output result for [Backend Call - API (getUserEventDetails)] action in acceptButton widget.
  ApiCallResponse? apiEventDetailsAccept;
  // Stores action output result for [Backend Call - API (notifyAdminsAttendanceChange)] action in acceptButton widget.
  ApiCallResponse? apiResultiwz2A;
  // Stores action output result for [Backend Call - Insert Row] action in declineButton widget.
  EventAttendanceRow? outputInsertRow1;
  // Stores action output result for [Backend Call - API (getUserEventDetails)] action in declineButton widget.
  ApiCallResponse? apiEventDetailsDecline;
  // Stores action output result for [Backend Call - API (notifyAdminsAttendanceChange)] action in declineButton widget.
  ApiCallResponse? apiResultiwz2B;
  // Stores action output result for [Custom Action - fetchSupabaseAccessToken] action in payNowButton widget.
  String? outputSupabaseToken;
  // Stores action output result for [Backend Call - API (createCheckoutSessionVersionTwo)] action in payNowButton widget.
  ApiCallResponse? outputCheckoutUrl;

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
