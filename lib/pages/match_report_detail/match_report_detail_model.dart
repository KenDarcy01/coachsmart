import '/flutter_flow/flutter_flow_util.dart';
import 'match_report_detail_widget.dart' show MatchReportDetailWidget;
import 'package:flutter/material.dart';

class MatchReportDetailModel extends FlutterFlowModel<MatchReportDetailWidget> {
  ///  Local state fields for this page.

  int? memberCount;

  int? currentSquad;

  int? currentRole;

  int? currentIndex;

  int? squadSelected;

  ///  State fields for stateful widgets in this page.

  // State field(s) for eventDetail widget.
  FocusNode? eventDetailFocusNode;
  TextEditingController? eventDetailTextController;
  String? Function(BuildContext, String?)? eventDetailTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    eventDetailFocusNode?.dispose();
    eventDetailTextController?.dispose();
  }
}
