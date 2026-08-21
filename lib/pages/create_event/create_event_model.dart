import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'create_event_widget.dart' show CreateEventWidget;
import 'package:flutter/material.dart';

class CreateEventModel extends FlutterFlowModel<CreateEventWidget> {
  ///  Local state fields for this page.

  int? stateEventTypeID;

  int? stateEventCodeID;

  String? stateEventTypeName;

  String? stateEventCodeName;

  /// Linked ot the Role
  int? stateAudienceID;

  int? stateSquadID;

  int? stateEventTeamID;

  int? stateRecurringWeek;

  String? stateImageLink;

  ///  State fields for stateful widgets in this page.

  // State field(s) for eventOppositionInput widget.
  FocusNode? eventOppositionInputFocusNode;
  TextEditingController? eventOppositionInputTextController;
  String? Function(BuildContext, String?)?
      eventOppositionInputTextControllerValidator;
  // State field(s) for eventTitleInput widget.
  FocusNode? eventTitleInputFocusNode;
  TextEditingController? eventTitleInputTextController;
  String? Function(BuildContext, String?)?
      eventTitleInputTextControllerValidator;
  DateTime? datePicked;
  // State field(s) for switchRecurringEvent widget.
  bool? switchRecurringEventValue;
  // State field(s) for numberWeeksInput widget.
  FocusNode? numberWeeksInputFocusNode;
  TextEditingController? numberWeeksInputTextController;
  String? Function(BuildContext, String?)?
      numberWeeksInputTextControllerValidator;
  // State field(s) for eventMeetTimeInput widget.
  FocusNode? eventMeetTimeInputFocusNode;
  TextEditingController? eventMeetTimeInputTextController;
  String? Function(BuildContext, String?)?
      eventMeetTimeInputTextControllerValidator;
  // State field(s) for locationInput widget.
  FocusNode? locationInputFocusNode;
  TextEditingController? locationInputTextController;
  String? Function(BuildContext, String?)? locationInputTextControllerValidator;
  // State field(s) for locationPinInput widget.
  FocusNode? locationPinInputFocusNode;
  TextEditingController? locationPinInputTextController;
  String? Function(BuildContext, String?)?
      locationPinInputTextControllerValidator;
  // State field(s) for switchRequestAttendance widget.
  bool? switchRequestAttendanceValue;
  bool isDataUploading_uploadDataDlb = false;
  FFUploadedFile uploadedLocalFile_uploadDataDlb =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');

  // State field(s) for eventDetail widget.
  FocusNode? eventDetailFocusNode;
  TextEditingController? eventDetailTextController;
  String? Function(BuildContext, String?)? eventDetailTextControllerValidator;
  bool isDataUploading_uploadData79m = false;
  FFUploadedFile uploadedLocalFile_uploadData79m =
      FFUploadedFile(bytes: Uint8List.fromList([]), originalFilename: '');
  String uploadedFileUrl_uploadData79m = '';

  // Stores action output result for [Backend Call - API (createRecurringEvents)] action in Button widget.
  ApiCallResponse? apiCreateEvent;
  // Stores action output result for [Backend Call - API (getUserHomeEvents)] action in Button widget.
  ApiCallResponse? outputUpdatedEvents;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    eventOppositionInputFocusNode?.dispose();
    eventOppositionInputTextController?.dispose();

    eventTitleInputFocusNode?.dispose();
    eventTitleInputTextController?.dispose();

    numberWeeksInputFocusNode?.dispose();
    numberWeeksInputTextController?.dispose();

    eventMeetTimeInputFocusNode?.dispose();
    eventMeetTimeInputTextController?.dispose();

    locationInputFocusNode?.dispose();
    locationInputTextController?.dispose();

    locationPinInputFocusNode?.dispose();
    locationPinInputTextController?.dispose();

    eventDetailFocusNode?.dispose();
    eventDetailTextController?.dispose();
  }
}
