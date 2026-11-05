import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'edit_event_widget.dart' show EditEventWidget;
import 'package:flutter/material.dart';

class EditEventModel extends FlutterFlowModel<EditEventWidget> {
  ///  Local state fields for this page.

  int? stateEventTypeID;

  int? stateEventCodeID;

  String? stateEventTypeName;

  String? stateEventCodeName;

  /// Linked ot the Role
  int? stateAudienceID;

  DateTime? dateTimePicked;

  String? buttonText = 'Cancel Event';

  String? stateImageLink;

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // Stores action output result for [Backend Call - API (getUserEventEditDetail)] action in EditEvent widget.
  ApiCallResponse? apiEventDetails;
  // State field(s) for oppositionInput widget.
  FocusNode? oppositionInputFocusNode;
  TextEditingController? oppositionInputTextController;
  String? Function(BuildContext, String?)?
      oppositionInputTextControllerValidator;
  // State field(s) for eventTitleInput widget.
  FocusNode? eventTitleInputFocusNode;
  TextEditingController? eventTitleInputTextController;
  String? Function(BuildContext, String?)?
      eventTitleInputTextControllerValidator;
  DateTime? datePicked;
  // State field(s) for meetingInput widget.
  FocusNode? meetingInputFocusNode;
  TextEditingController? meetingInputTextController;
  String? Function(BuildContext, String?)? meetingInputTextControllerValidator;
  // State field(s) for locationInput widget.
  FocusNode? locationInputFocusNode;
  TextEditingController? locationInputTextController;
  String? Function(BuildContext, String?)? locationInputTextControllerValidator;
  // State field(s) for locationPinInput widget.
  FocusNode? locationPinInputFocusNode;
  TextEditingController? locationPinInputTextController;
  String? Function(BuildContext, String?)?
      locationPinInputTextControllerValidator;
  // State field(s) for eventLinkInput widget.
  FocusNode? eventLinkInputFocusNode;
  TextEditingController? eventLinkInputTextController;
  String? Function(BuildContext, String?)?
      eventLinkInputTextControllerValidator;
  // State field(s) for switchRequestAttendance widget.
  bool? switchRequestAttendanceValue;
  bool isDataUploading_uploadDataDlb1 = false;
  FFUploadedFile uploadedLocalFile_uploadDataDlb1 =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');

  // State field(s) for eventDetail widget.
  FocusNode? eventDetailFocusNode;
  TextEditingController? eventDetailTextController;
  String? Function(BuildContext, String?)? eventDetailTextControllerValidator;
  bool isDataUploading_uploadData1g9 = false;
  FFUploadedFile uploadedLocalFile_uploadData1g9 =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadData1g9 = '';

  // Stores action output result for [Backend Call - API (getUserEventDetails)] action in Button widget.
  ApiCallResponse? apiUpdateEventDetails;
  // Stores action output result for [Backend Call - Update Row(s)] action in Button widget.
  List<EventsRow>? outputCancelled1;
  // Stores action output result for [Backend Call - Update Row(s)] action in Button widget.
  List<EventAttendanceRow>? outputCancelledAttendance1;
  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in Button widget.
  ApiCallResponse? outputUpdatedEventsCancel1;
  // Stores action output result for [Backend Call - Update Row(s)] action in Button widget.
  List<EventsRow>? outputCancelled;
  // Stores action output result for [Backend Call - Update Row(s)] action in Button widget.
  List<EventAttendanceRow>? outputCancelledAttendance;
  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in Button widget.
  ApiCallResponse? outputUpdatedEventsCancel;
  // Stores action output result for [Backend Call - Update Row(s)] action in Button widget.
  List<EventsRow>? outputDeleted;
  // Stores action output result for [Backend Call - Update Row(s)] action in Button widget.
  List<EventAttendanceRow>? outputDeletedAttendance;
  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in Button widget.
  ApiCallResponse? outputUpdatedEventsDelete;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    oppositionInputFocusNode?.dispose();
    oppositionInputTextController?.dispose();

    eventTitleInputFocusNode?.dispose();
    eventTitleInputTextController?.dispose();

    meetingInputFocusNode?.dispose();
    meetingInputTextController?.dispose();

    locationInputFocusNode?.dispose();
    locationInputTextController?.dispose();

    locationPinInputFocusNode?.dispose();
    locationPinInputTextController?.dispose();

    eventLinkInputFocusNode?.dispose();
    eventLinkInputTextController?.dispose();

    eventDetailFocusNode?.dispose();
    eventDetailTextController?.dispose();
  }
}
