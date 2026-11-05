import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'on_boarding_widget.dart' show OnBoardingWidget;
import 'package:flutter/material.dart';

class OnBoardingModel extends FlutterFlowModel<OnBoardingWidget> {
  ///  Local state fields for this page.

  bool varUserOboarded = true;

  ///  State fields for stateful widgets in this page.

  Stream<List<UsersRow>>? onBoardingSupabaseStream;
  // Stores action output result for [Backend Call - API (getUserOnboardingStatus)] action in onBoarding widget.
  ApiCallResponse? apiResult8lz;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
