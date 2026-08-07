import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'user_member_details_model.dart';
export 'user_member_details_model.dart';

class UserMemberDetailsWidget extends StatefulWidget {
  const UserMemberDetailsWidget({
    super.key,
    required this.memberID,
    required this.teamID,
    required this.memberFullName,
    required this.teamName,
    required this.uniqueMemberCode,
  });

  final int? memberID;
  final int? teamID;
  final String? memberFullName;
  final String? teamName;
  final String? uniqueMemberCode;

  static String routeName = 'UserMemberDetails';
  static String routePath = 'UserMemberDetails';

  @override
  State<UserMemberDetailsWidget> createState() =>
      _UserMemberDetailsWidgetState();
}

class _UserMemberDetailsWidgetState extends State<UserMemberDetailsWidget> {
  late UserMemberDetailsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UserMemberDetailsModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'UserMemberDetails'});
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).coachSmartMidBlack,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryText,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF87C232),
              size: 30.0,
            ),
            onPressed: () async {
              logFirebaseEvent('USER_MEMBER_DETAILS_arrow_back_rounded_I');
              logFirebaseEvent('IconButton_navigate_back');
              context.pop();
            },
          ),
          title: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                valueOrDefault<String>(
                  widget.memberFullName,
                  'full_name',
                ),
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      fontSize: 18.0,
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
              ),
              Text(
                '(${widget.teamName})',
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).coachSmartGrey,
                      fontSize: 12.0,
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
              ),
            ],
          ),
          actions: [],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(15.0, 0.0, 15.0, 0.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 10.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: FFButtonWidget(
                            onPressed: () async {
                              logFirebaseEvent(
                                  'USER_MEMBER_DETAILS_createTeamButton_ON_');
                              logFirebaseEvent('createTeamButton_backend_call');
                              _model.outputMemberLink =
                                  await MemberTeamLinkTable().queryRows(
                                queryFn: (q) => q
                                    .eqOrNull(
                                      'member_id',
                                      widget.memberID,
                                    )
                                    .eqOrNull(
                                      'team_id',
                                      widget.teamID,
                                    ),
                              );
                              logFirebaseEvent('createTeamButton_backend_call');
                              await MemberTeamRoleLinkTable().delete(
                                matchingRows: (rows) => rows.eqOrNull(
                                  'member_team_id',
                                  _model.outputMemberLink?.firstOrNull
                                      ?.memberTeamId,
                                ),
                              );
                              logFirebaseEvent('createTeamButton_backend_call');
                              await MemberTeamLinkTable().delete(
                                matchingRows: (rows) => rows
                                    .eqOrNull(
                                      'member_id',
                                      widget.memberID,
                                    )
                                    .eqOrNull(
                                      'team_id',
                                      widget.teamID,
                                    ),
                              );
                              // Also member of another team?
                              logFirebaseEvent(
                                  'createTeamButton_Alsomemberofanotherteam');
                              _model.outputMemberTeamLink =
                                  await MemberTeamLinkTable().queryRows(
                                queryFn: (q) => q
                                    .eqOrNull(
                                      'member_id',
                                      widget.memberID,
                                    )
                                    .neqOrNull(
                                      'team_id',
                                      widget.teamID,
                                    ),
                              );
                              if (!(_model.outputMemberTeamLink != null &&
                                  (_model.outputMemberTeamLink)!.isNotEmpty)) {
                                logFirebaseEvent(
                                    'createTeamButton_backend_call');
                                await UserMemberLinkTable().delete(
                                  matchingRows: (rows) => rows.eqOrNull(
                                    'member_id',
                                    widget.memberID,
                                  ),
                                );
                                logFirebaseEvent(
                                    'createTeamButton_backend_call');
                                await EventAttendanceTable().delete(
                                  matchingRows: (rows) => rows.eqOrNull(
                                    'member_id',
                                    widget.memberID,
                                  ),
                                );
                                logFirebaseEvent(
                                    'createTeamButton_backend_call');
                                await MembersTable().delete(
                                  matchingRows: (rows) => rows.eqOrNull(
                                    'member_id',
                                    widget.memberID,
                                  ),
                                );
                              }
                              logFirebaseEvent(
                                  'createTeamButton_show_snack_bar');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Member Removed Successfully',
                                    style: TextStyle(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                  backgroundColor: FlutterFlowTheme.of(context)
                                      .coachSmartGreen,
                                ),
                              );
                              logFirebaseEvent(
                                  'createTeamButton_navigate_back');
                              context.safePop();

                              safeSetState(() {});
                            },
                            text: 'Leave this Team',
                            icon: Icon(
                              Icons.emoji_people,
                              size: 24.0,
                            ),
                            options: FFButtonOptions(
                              width: 170.0,
                              height: 40.0,
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 0.0, 16.0, 0.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context)
                                  .coachSmartMidBlack,
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
                                    color: FlutterFlowTheme.of(context)
                                        .coachSmartGreen,
                                    fontSize: 14.0,
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
                                color: FlutterFlowTheme.of(context)
                                    .coachSmartGreen,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            showLoadingIndicator: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    thickness: 1.0,
                    color: Color(0xFF585757),
                  ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 10.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget.uniqueMemberCode,
                            'member_code',
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context)
                                        .coachSmartGreen,
                                    fontSize: 20.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
