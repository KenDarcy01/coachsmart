import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'drop_down_menu_attendance_model.dart';
export 'drop_down_menu_attendance_model.dart';

class DropDownMenuAttendanceWidget extends StatefulWidget {
  const DropDownMenuAttendanceWidget({
    super.key,
    required this.paramEventId,
    required this.paramMemberId,
    required this.paramCurrentResponse,
  });

  final int? paramEventId;
  final int? paramMemberId;
  final int? paramCurrentResponse;

  @override
  State<DropDownMenuAttendanceWidget> createState() =>
      _DropDownMenuAttendanceWidgetState();
}

class _DropDownMenuAttendanceWidgetState
    extends State<DropDownMenuAttendanceWidget> {
  late DropDownMenuAttendanceModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DropDownMenuAttendanceModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).coachSmartMidBlack,
        boxShadow: [
          BoxShadow(
            blurRadius: 4.0,
            color: Color(0x33000000),
            offset: Offset(
              0.0,
              2.0,
            ),
          )
        ],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              if ((widget.paramCurrentResponse == 4) ||
                  (widget.paramCurrentResponse == 0))
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(5.0, 5.0, 5.0, 0.0),
                    child: FFButtonWidget(
                      onPressed: () async {
                        logFirebaseEvent(
                            'DROP_DOWN_MENU_ATTENDANCE_ACCEPT_BTN_ON_');
                        logFirebaseEvent('Button_backend_call');
                        await EventAttendanceTable().insert({
                          'event_id': widget.paramEventId,
                          'member_id': widget.paramMemberId,
                          'response_id': 3,
                        });
                        logFirebaseEvent('Button_backend_call');
                        _model.apiUserEventDetails =
                            await GetUserEventDetailsCall.call(
                          supabaseJWTtoken: currentJwtToken,
                          pEventId: widget.paramEventId,
                          pUserId: currentUserUid,
                        );

                        logFirebaseEvent('Button_update_app_state');
                        FFAppState().userEventDetails =
                            UserEventDetailsStruct.maybeFromMap(
                                (_model.apiUserEventDetails?.jsonBody ?? ''))!;
                        logFirebaseEvent('Button_close_dialog_drawer_etc');
                        Navigator.pop(context);

                        safeSetState(() {});
                      },
                      text: 'Accept',
                      icon: FaIcon(
                        FontAwesomeIcons.check,
                        size: 15.0,
                      ),
                      options: FFButtonOptions(
                        height: 40.0,
                        padding: EdgeInsetsDirectional.fromSTEB(
                            16.0, 0.0, 16.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: FlutterFlowTheme.of(context).coachSmartGreen,
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color: Color(0xFF494949),
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                        elevation: 0.0,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              if ((widget.paramCurrentResponse == 3) ||
                  (widget.paramCurrentResponse == 0))
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(5.0, 0.0, 5.0, 5.0),
                    child: FFButtonWidget(
                      onPressed: () async {
                        logFirebaseEvent(
                            'DROP_DOWN_MENU_ATTENDANCE_DECLINE_BTN_ON');
                        logFirebaseEvent('Button_backend_call');
                        await EventAttendanceTable().insert({
                          'event_id': widget.paramEventId,
                          'member_id': widget.paramMemberId,
                          'response_id': 4,
                        });
                        logFirebaseEvent('Button_backend_call');
                        _model.apiUserEventDetails1 =
                            await GetUserEventDetailsCall.call(
                          supabaseJWTtoken: currentJwtToken,
                          pEventId: widget.paramEventId,
                          pUserId: currentUserUid,
                        );

                        logFirebaseEvent('Button_update_app_state');
                        FFAppState().userEventDetails =
                            UserEventDetailsStruct.maybeFromMap(
                                (_model.apiUserEventDetails1?.jsonBody ?? ''))!;
                        logFirebaseEvent('Button_close_dialog_drawer_etc');
                        Navigator.pop(context);

                        safeSetState(() {});
                      },
                      text: 'Decline',
                      icon: Icon(
                        Icons.close,
                        size: 27.0,
                      ),
                      options: FFButtonOptions(
                        height: 40.0,
                        padding: EdgeInsetsDirectional.fromSTEB(
                            16.0, 0.0, 16.0, 0.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: Color(0xFF8B0D15),
                        textStyle:
                            FlutterFlowTheme.of(context).titleSmall.override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                                  color: FlutterFlowTheme.of(context).alternate,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                        elevation: 0.0,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ].divide(SizedBox(height: 5.0)),
      ),
    );
  }
}
