import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'drop_down_menu_roles_model.dart';
export 'drop_down_menu_roles_model.dart';

class DropDownMenuRolesWidget extends StatefulWidget {
  const DropDownMenuRolesWidget({
    super.key,
    required this.parTeamId,
    required this.parMemberId,
    required this.parMemberTeamId,
  });

  final int? parTeamId;
  final int? parMemberId;
  final int? parMemberTeamId;

  @override
  State<DropDownMenuRolesWidget> createState() =>
      _DropDownMenuRolesWidgetState();
}

class _DropDownMenuRolesWidgetState extends State<DropDownMenuRolesWidget> {
  late DropDownMenuRolesModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DropDownMenuRolesModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).coachSmartLightBlack,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(15.0, 15.0, 15.0, 15.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  'Assign Roles (at least 1)',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        fontSize: 18.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ],
            ),
            Divider(
              thickness: 2.0,
              color: FlutterFlowTheme.of(context).coachSmartGreen,
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Builder(
                    builder: (context) {
                      final childRole = FFAppState().joinRoles.toList();

                      return Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        alignment: WrapAlignment.start,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        direction: Axis.horizontal,
                        runAlignment: WrapAlignment.start,
                        verticalDirection: VerticalDirection.down,
                        clipBehavior: Clip.none,
                        children:
                            List.generate(childRole.length, (childRoleIndex) {
                          final childRoleItem = childRole[childRoleIndex];
                          return FFButtonWidget(
                            onPressed: () async {
                              logFirebaseEvent(
                                  'DROP_DOWN_MENU_ROLES_Button_y4hav379_ON_');
                              if (functions.checkIfMemberHasRole(
                                      _model.selectedRoles.toList(),
                                      childRoleItem.roleId) ==
                                  false) {
                                logFirebaseEvent(
                                    'Button_update_component_state');
                                _model.addToSelectedRoles(childRoleItem.roleId);
                                safeSetState(() {});
                              } else {
                                logFirebaseEvent(
                                    'Button_update_component_state');
                                _model.removeFromSelectedRoles(
                                    childRoleItem.roleId);
                                safeSetState(() {});
                              }
                            },
                            text: valueOrDefault<String>(
                              childRoleItem.roleName,
                              'role',
                            ),
                            options: FFButtonOptions(
                              padding: EdgeInsets.all(16.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: functions.checkIfMemberHasRole(
                                      _model.selectedRoles.toList(),
                                      childRoleItem.roleId)!
                                  ? FlutterFlowTheme.of(context).coachSmartGreen
                                  : FlutterFlowTheme.of(context)
                                      .coachSmartMidBlack,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: functions.checkIfMemberHasRole(
                                            _model.selectedRoles.toList(),
                                            childRoleItem.roleId)!
                                        ? FlutterFlowTheme.of(context)
                                            .coachSmartLightBlack
                                        : FlutterFlowTheme.of(context)
                                            .coachSmartWhite,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderRadius: BorderRadius.circular(24.0),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  Divider(
                    thickness: 1.0,
                    color: Color(0xFF494848),
                  ),
                  FFButtonWidget(
                    onPressed: () async {
                      logFirebaseEvent(
                          'DROP_DOWN_MENU_ROLES_CONFIRM_BTN_ON_TAP');
                      logFirebaseEvent('Button_backend_call');
                      _model.apiConfirm = await ConfirmMemberJoinCall.call(
                        supabaseJWTtoken: currentJwtToken,
                        pMemberTeamId: widget.parMemberTeamId,
                        pRoleIdsList: _model.selectedRoles,
                      );

                      if ((_model.apiConfirm?.succeeded ?? true)) {
                        logFirebaseEvent('Button_backend_call');
                        _model.apiPendingRequests =
                            await GetUserTeamSummaryCall.call(
                          supabaseJWTtoken: currentJwtToken,
                          pUserId: currentUserUid,
                        );

                        logFirebaseEvent('Button_update_app_state');
                        FFAppState().userTeamSummary =
                            UserTeamSummaryStruct.maybeFromMap(
                                (_model.apiPendingRequests?.jsonBody ?? ''))!;
                        logFirebaseEvent('Button_backend_call');
                        _model.apiJoinRequests =
                            await GetPendingTeamRequestsCall.call(
                          supabaseJWTtoken: currentJwtToken,
                          pTeamId: widget.parTeamId,
                        );

                        logFirebaseEvent('Button_update_app_state');
                        FFAppState().joinRequests =
                            JoinRequestsStruct.maybeFromMap(
                                (_model.apiJoinRequests?.jsonBody ?? ''))!;
                        FFAppState().update(() {});
                      } else {
                        logFirebaseEvent('Button_show_snack_bar');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              (_model.apiConfirm?.bodyText ?? ''),
                              style: TextStyle(
                                color: FlutterFlowTheme.of(context).primaryText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            duration: Duration(milliseconds: 4000),
                            backgroundColor: FlutterFlowTheme.of(context).error,
                          ),
                        );
                      }

                      logFirebaseEvent('Button_close_dialog_drawer_etc');
                      Navigator.pop(context);

                      safeSetState(() {});
                    },
                    text: 'Confirm',
                    icon: Icon(
                      Icons.done,
                      size: 25.0,
                    ),
                    options: FFButtonOptions(
                      width: double.infinity,
                      height: 40.0,
                      padding:
                          EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).coachSmartMidBlack,
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
                      borderSide: BorderSide(
                        color: Color(0xFF3A3939),
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ].divide(SizedBox(height: 10.0)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
