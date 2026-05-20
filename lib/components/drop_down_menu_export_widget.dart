import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'drop_down_menu_export_model.dart';
export 'drop_down_menu_export_model.dart';

class DropDownMenuExportWidget extends StatefulWidget {
  const DropDownMenuExportWidget({
    super.key,
    required this.paramEventId,
  });

  final int? paramEventId;

  @override
  State<DropDownMenuExportWidget> createState() =>
      _DropDownMenuExportWidgetState();
}

class _DropDownMenuExportWidgetState extends State<DropDownMenuExportWidget> {
  late DropDownMenuExportModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DropDownMenuExportModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('DROP_DOWN_MENU_EXPORT_dropDownMenuExport');
      logFirebaseEvent('dropDownMenuExport_backend_call');
      _model.outputQueryRecentMatchSquad = await MatchSquadsTable().queryRows(
        queryFn: (q) => q
            .eqOrNull(
              'event_id',
              widget.paramEventId,
            )
            .order('match_squad_id'),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Container(
        width: double.infinity,
        height: 275.0,
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
        child: Align(
          alignment: AlignmentDirectional(0.0, 0.0),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(15.0, 0.0, 15.0, 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(12.0, 12.0, 0.0, 0.0),
                  child: Text(
                    'Export Options',
                    textAlign: TextAlign.start,
                    style: FlutterFlowTheme.of(context).labelMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).coachSmartGreen,
                          fontSize: isWeb == true ? 18.0 : 20.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .fontStyle,
                        ),
                  ),
                ),
                Divider(
                  thickness: 2.0,
                  indent: 10.0,
                  endIndent: 10.0,
                  color: Color(0xFF474747),
                ),
                Align(
                  alignment: AlignmentDirectional(-1.0, 0.0),
                  child: FFButtonWidget(
                    onPressed: () async {
                      logFirebaseEvent(
                          'DROP_DOWN_MENU_EXPORT_GOOGLE_SHEETS_BTN_');
                      logFirebaseEvent('Button_backend_call');
                      _model.apiResultp9uCopy1Copy2 =
                          await ExportEdgeFunctionGoogleSheetCall.call(
                        eventID: widget.paramEventId,
                        userEmail: currentUserEmail,
                        matchSquadId: _model.outputQueryRecentMatchSquad
                            ?.firstOrNull?.matchSquadId,
                      );

                      logFirebaseEvent('Button_close_dialog_drawer_etc');
                      Navigator.pop(context);

                      safeSetState(() {});
                    },
                    text: 'Google Sheets',
                    icon: FaIcon(
                      FontAwesomeIcons.gofore,
                      size: 26.0,
                    ),
                    options: FFButtonOptions(
                      width: double.infinity,
                      height: 50.0,
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).coachSmartLightBlack,
                      textStyle: FlutterFlowTheme.of(context)
                          .titleSmall
                          .override(
                            font: GoogleFonts.interTight(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).coachSmartWhite,
                            fontSize: isWeb == true ? 16.0 : 18.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                      elevation: 0.0,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: FFButtonWidget(
                    onPressed: () async {
                      logFirebaseEvent(
                          'DROP_DOWN_MENU_EXPORT_MICROSOFT_EXCEL_BT');
                      logFirebaseEvent('Button_backend_call');
                      _model.apiResultp9uCopy1Copy = await ExportToXLSCall.call(
                        eventId: widget.paramEventId,
                        matchSquadId: _model.outputQueryRecentMatchSquad
                            ?.firstOrNull?.matchSquadId,
                        userEmail: currentUserEmail,
                      );

                      logFirebaseEvent('Button_close_dialog_drawer_etc');
                      Navigator.pop(context);

                      safeSetState(() {});
                    },
                    text: 'Microsoft Excel',
                    icon: FaIcon(
                      FontAwesomeIcons.fileExcel,
                      size: 26.0,
                    ),
                    options: FFButtonOptions(
                      width: double.infinity,
                      height: 50.0,
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).coachSmartLightBlack,
                      textStyle: FlutterFlowTheme.of(context)
                          .titleSmall
                          .override(
                            font: GoogleFonts.interTight(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).coachSmartWhite,
                            fontSize: isWeb == true ? 16.0 : 18.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                      elevation: 0.0,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: FFButtonWidget(
                    onPressed: () async {
                      logFirebaseEvent(
                          'DROP_DOWN_MENU_EXPORT_C_S_V_FILE_BTN_ON_');
                      logFirebaseEvent('Button_backend_call');
                      _model.apiResultvxd = await ExportToCSVCall.call(
                        eventId: widget.paramEventId,
                        matchSquadId: _model.outputQueryRecentMatchSquad
                            ?.firstOrNull?.matchSquadId,
                        userEmail: currentUserEmail,
                      );

                      logFirebaseEvent('Button_close_dialog_drawer_etc');
                      Navigator.pop(context);

                      safeSetState(() {});
                    },
                    text: 'CSV File',
                    icon: FaIcon(
                      FontAwesomeIcons.fileCsv,
                      size: 26.0,
                    ),
                    options: FFButtonOptions(
                      width: double.infinity,
                      height: 50.0,
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).coachSmartLightBlack,
                      textStyle: FlutterFlowTheme.of(context)
                          .titleSmall
                          .override(
                            font: GoogleFonts.interTight(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).coachSmartWhite,
                            fontSize: isWeb == true ? 16.0 : 18.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                      elevation: 0.0,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
              ].divide(SizedBox(height: 10.0)),
            ),
          ),
        ),
      ),
    );
  }
}
