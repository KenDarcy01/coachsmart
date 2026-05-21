import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'create_car_pool_widget.dart' show CreateCarPoolWidget;
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CreateCarPoolModel extends FlutterFlowModel<CreateCarPoolWidget> {
  ///  Local state fields for this page.

  bool varCreatePool = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getEventCarPools)] action in CreateCarPool widget.
  ApiCallResponse? outputGetEventCarPools;
  // Stores action output result for [Backend Call - Query Rows] action in CreateCarPool widget.
  List<CarPoolRow>? outputOpenCarPool;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  late MaskTextInputFormatter textFieldMask;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Backend Call - Insert Row] action in Button widget.
  CarPoolRow? outputCarPoolCreate;
  // Stores action output result for [Backend Call - API (getEventCarPools)] action in Button widget.
  ApiCallResponse? outputCreateCarPoolAPI;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}
