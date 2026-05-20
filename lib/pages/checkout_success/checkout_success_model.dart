import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'checkout_success_widget.dart' show CheckoutSuccessWidget;
import 'package:flutter/material.dart';

class CheckoutSuccessModel extends FlutterFlowModel<CheckoutSuccessWidget> {
  ///  Local state fields for this page.

  bool varSessionLoaded = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - fetchSupabaseAccessToken] action in CheckoutSuccess widget.
  String? outputSupabaseToken;
  // Stores action output result for [Backend Call - API (getCheckoutSessionDetails)] action in CheckoutSuccess widget.
  ApiCallResponse? outputSessionDetails;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
