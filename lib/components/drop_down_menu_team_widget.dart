import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'drop_down_menu_team_model.dart';
export 'drop_down_menu_team_model.dart';

class DropDownMenuTeamWidget extends StatefulWidget {
  const DropDownMenuTeamWidget({
    super.key,
    required this.paramTeamID,
  });

  final int? paramTeamID;

  @override
  State<DropDownMenuTeamWidget> createState() => _DropDownMenuTeamWidgetState();
}

class _DropDownMenuTeamWidgetState extends State<DropDownMenuTeamWidget> {
  late DropDownMenuTeamModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DropDownMenuTeamModel());

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
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(12.0, 12.0, 0.0, 0.0),
              child: Text(
                'Team Menu',
                textAlign: TextAlign.start,
                style: FlutterFlowTheme.of(context).labelMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).coachSmartGreen,
                      fontSize: 18.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelMedium.fontStyle,
                    ),
              ),
            ),
            Divider(
              thickness: 2.0,
              indent: 10.0,
              endIndent: 10.0,
              color: Color(0xFF474747),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(10.0, 10.0, 10.0, 15.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: FFButtonWidget(
                      onPressed: () async {
                        logFirebaseEvent(
                            'DROP_DOWN_MENU_TEAM_EXPORT_TEAM_DETAILS_');
                        logFirebaseEvent('Button_backend_call');
                        _model.apiResultced = await ExportTeamListXLSCall.call(
                          pTeamId: widget.paramTeamID,
                          userEmail: currentUserEmail,
                        );

                        logFirebaseEvent('Button_dismiss_dialog');
                        Navigator.pop(context);

                        safeSetState(() {});
                      },
                      text: 'Export Team Details',
                      icon: Icon(
                        Icons.ios_share,
                        size: 30.0,
                      ),
                      options: FFButtonOptions(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            15.0, 15.0, 15.0, 15.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color:
                            FlutterFlowTheme.of(context).coachSmartLightBlack,
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
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                        elevation: 0.0,
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
