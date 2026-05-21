import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'edit_user_widget.dart' show EditUserWidget;
import 'package:flutter/material.dart';

class EditUserModel extends FlutterFlowModel<EditUserWidget> {
  ///  Local state fields for this page.

  int? memberCount;

  int? currentSquad;

  int? currentRole;

  int? currentIndex;

  int? squadSelected;

  ///  State fields for stateful widgets in this page.

  // State field(s) for userFirstName widget.
  FocusNode? userFirstNameFocusNode;
  TextEditingController? userFirstNameTextController;
  String? Function(BuildContext, String?)? userFirstNameTextControllerValidator;
  // State field(s) for userLastName widget.
  FocusNode? userLastNameFocusNode;
  TextEditingController? userLastNameTextController;
  String? Function(BuildContext, String?)? userLastNameTextControllerValidator;
  // State field(s) for userPhoneNumber widget.
  FocusNode? userPhoneNumberFocusNode;
  TextEditingController? userPhoneNumberTextController;
  String? Function(BuildContext, String?)?
      userPhoneNumberTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    userFirstNameFocusNode?.dispose();
    userFirstNameTextController?.dispose();

    userLastNameFocusNode?.dispose();
    userLastNameTextController?.dispose();

    userPhoneNumberFocusNode?.dispose();
    userPhoneNumberTextController?.dispose();
  }
}
