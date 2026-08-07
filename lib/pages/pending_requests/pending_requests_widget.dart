import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/components/drop_down_menu_roles_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'pending_requests_model.dart';
export 'pending_requests_model.dart';

class PendingRequestsWidget extends StatefulWidget {
  const PendingRequestsWidget({
    super.key,
    required this.paramTeamID,
  });

  final int? paramTeamID;

  static String routeName = 'PendingRequests';
  static String routePath = 'pendingRequests';

  @override
  State<PendingRequestsWidget> createState() => _PendingRequestsWidgetState();
}

class _PendingRequestsWidgetState extends State<PendingRequestsWidget> {
  late PendingRequestsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PendingRequestsModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'PendingRequests'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('PENDING_REQUESTS_PendingRequests_ON_INIT');
      logFirebaseEvent('PendingRequests_backend_call');
      _model.apiJoinRequests = await GetPendingTeamRequestsCall.call(
        supabaseJWTtoken: currentJwtToken,
        pTeamId: widget.paramTeamID,
      );

      if ((_model.apiJoinRequests?.succeeded ?? true)) {
        logFirebaseEvent('PendingRequests_update_app_state');
        FFAppState().joinRequests = JoinRequestsStruct.maybeFromMap(
            (_model.apiJoinRequests?.jsonBody ?? ''))!;
        safeSetState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

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
              logFirebaseEvent('PENDING_REQUESTS_arrow_back_rounded_ICN_');
              logFirebaseEvent('IconButton_navigate_back');
              context.safePop();
            },
          ),
          title: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Text(
                'Pending Requests',
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
            ],
          ),
          actions: [],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (FFAppState().joinRequests.memberRequests.length > 0)
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(15.0, 0.0, 15.0, 0.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 15.0, 0.0, 15.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'New Members',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      fontSize: 18.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final childMemberRequests = FFAppState()
                                .joinRequests
                                .memberRequests
                                .toList();

                            return ListView.builder(
                              padding: EdgeInsets.zero,
                              primary: false,
                              shrinkWrap: true,
                              scrollDirection: Axis.vertical,
                              itemCount: childMemberRequests.length,
                              itemBuilder: (context, childMemberRequestsIndex) {
                                final childMemberRequestsItem =
                                    childMemberRequests[
                                        childMemberRequestsIndex];
                                return Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 5.0, 0.0, 5.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .coachSmartLightBlack,
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          10.0, 10.0, 10.0, 10.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 5.0,
                                                    height: 40.0,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .coachSmartGreen,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  5.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                '${childMemberRequestsItem.firstName} ${childMemberRequestsItem.lastName}',
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                      fontSize:
                                                                          16.0,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Text(
                                                                'Requesting: ${valueOrDefault<String>(
                                                                  childMemberRequestsItem
                                                                      .requestingUserName,
                                                                  'requested_by',
                                                                )}',
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .coachSmartGrey,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ].divide(SizedBox(
                                                            height: 5.0)),
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Icon(
                                                          Icons.chevron_right,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .alternate,
                                                          size: 30.0,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 5.0)),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Builder(
                                                builder: (context) =>
                                                    FFButtonWidget(
                                                  onPressed: () async {
                                                    logFirebaseEvent(
                                                        'PENDING_REQUESTS_PAGE_APPROVE_BTN_ON_TAP');
                                                    logFirebaseEvent(
                                                        'Button_backend_call');
                                                    _model.apiRoleList =
                                                        await GetTeamRolesCall
                                                            .call(
                                                      supabaseJWTtoken:
                                                          currentJwtToken,
                                                      pTeamId:
                                                          widget.paramTeamID,
                                                    );

                                                    logFirebaseEvent(
                                                        'Button_update_app_state');
                                                    FFAppState()
                                                        .joinRoles = ((_model
                                                                    .apiRoleList
                                                                    ?.jsonBody ??
                                                                '')
                                                            .toList()
                                                            .map<GetTeamRolesStruct?>(
                                                                GetTeamRolesStruct
                                                                    .maybeFromMap)
                                                            .toList() as Iterable<GetTeamRolesStruct?>)
                                                        .withoutNulls
                                                        .toList()
                                                        .cast<GetTeamRolesStruct>();
                                                    logFirebaseEvent(
                                                        'Button_alert_dialog');
                                                    await showDialog(
                                                      context: context,
                                                      builder: (dialogContext) {
                                                        return Dialog(
                                                          elevation: 0,
                                                          insetPadding:
                                                              EdgeInsets.zero,
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                          alignment: AlignmentDirectional(
                                                                  0.0, 0.0)
                                                              .resolve(
                                                                  Directionality.of(
                                                                      context)),
                                                          child: WebViewAware(
                                                            child:
                                                                GestureDetector(
                                                              onTap: () {
                                                                FocusScope.of(
                                                                        dialogContext)
                                                                    .unfocus();
                                                                FocusManager
                                                                    .instance
                                                                    .primaryFocus
                                                                    ?.unfocus();
                                                              },
                                                              child:
                                                                  DropDownMenuRolesWidget(
                                                                parTeamId: widget
                                                                    .paramTeamID!,
                                                                parMemberId:
                                                                    childMemberRequestsItem
                                                                        .memberId,
                                                                parMemberTeamId:
                                                                    childMemberRequestsItem
                                                                        .memberTeamId,
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    );

                                                    safeSetState(() {});
                                                  },
                                                  text: 'Approve',
                                                  icon: Icon(
                                                    Icons.check,
                                                    size: 25.0,
                                                  ),
                                                  options: FFButtonOptions(
                                                    width: 120.0,
                                                    height: 35.0,
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(16.0, 0.0,
                                                                16.0, 0.0),
                                                    iconPadding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .coachSmartGreen,
                                                    textStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .titleSmall
                                                            .override(
                                                              font: GoogleFonts
                                                                  .interTight(
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                              ),
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .coachSmartLightBlack,
                                                              fontSize: 14.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontWeight,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontStyle,
                                                            ),
                                                    elevation: 0.0,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8.0),
                                                  ),
                                                ),
                                              ),
                                              FFButtonWidget(
                                                onPressed: () async {
                                                  logFirebaseEvent(
                                                      'PENDING_REQUESTS_PAGE_DECLINE_BTN_ON_TAP');
                                                  logFirebaseEvent(
                                                      'Button_backend_call');
                                                  _model.apiDenyJoin =
                                                      await DenyMemberJoinCall
                                                          .call(
                                                    supabaseJWTtoken:
                                                        currentJwtToken,
                                                    pMemberTeamId:
                                                        childMemberRequestsItem
                                                            .memberTeamId,
                                                  );

                                                  if ((_model.apiDenyJoin
                                                          ?.succeeded ??
                                                      true)) {
                                                    logFirebaseEvent(
                                                        'Button_backend_call');
                                                    _model.apiPendingRequestsDeny =
                                                        await GetUserTeamSummaryCall
                                                            .call(
                                                      supabaseJWTtoken:
                                                          currentJwtToken,
                                                      pUserId: currentUserUid,
                                                    );

                                                    logFirebaseEvent(
                                                        'Button_update_app_state');
                                                    FFAppState()
                                                            .userTeamSummary =
                                                        UserTeamSummaryStruct
                                                            .maybeFromMap((_model
                                                                    .apiPendingRequestsDeny
                                                                    ?.jsonBody ??
                                                                ''))!;
                                                    logFirebaseEvent(
                                                        'Button_backend_call');
                                                    _model.apiJoinRequestsDeny =
                                                        await GetPendingTeamRequestsCall
                                                            .call(
                                                      supabaseJWTtoken:
                                                          currentJwtToken,
                                                      pTeamId:
                                                          widget.paramTeamID,
                                                    );

                                                    logFirebaseEvent(
                                                        'Button_update_app_state');
                                                    FFAppState().joinRequests =
                                                        JoinRequestsStruct
                                                            .maybeFromMap((_model
                                                                    .apiJoinRequestsDeny
                                                                    ?.jsonBody ??
                                                                ''))!;
                                                    FFAppState().update(() {});
                                                  }

                                                  safeSetState(() {});
                                                },
                                                text: 'Decline',
                                                icon: Icon(
                                                  Icons.close,
                                                  size: 25.0,
                                                ),
                                                options: FFButtonOptions(
                                                  width: 120.0,
                                                  height: 35.0,
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          16.0, 0.0, 16.0, 0.0),
                                                  iconPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(0.0, 0.0,
                                                              0.0, 0.0),
                                                  color: Color(0xFF9C0508),
                                                  textStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .titleSmall
                                                      .override(
                                                        font: GoogleFonts
                                                            .interTight(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                        fontSize: 14.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontStyle,
                                                      ),
                                                  elevation: 0.0,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 10.0)),
                                          ),
                                        ].divide(SizedBox(height: 10.0)),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                if (FFAppState().joinRequests.accessRequests.length > 0)
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(15.0, 15.0, 15.0, 0.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 10.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Shared Access',
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      fontSize: 18.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Builder(
                          builder: (context) {
                            final childAccessRequests = FFAppState()
                                .joinRequests
                                .accessRequests
                                .toList();

                            return ListView.builder(
                              padding: EdgeInsets.zero,
                              primary: false,
                              shrinkWrap: true,
                              scrollDirection: Axis.vertical,
                              itemCount: childAccessRequests.length,
                              itemBuilder: (context, childAccessRequestsIndex) {
                                final childAccessRequestsItem =
                                    childAccessRequests[
                                        childAccessRequestsIndex];
                                return Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 5.0, 0.0, 5.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .coachSmartLightBlack,
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          10.0, 10.0, 10.0, 10.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 5.0,
                                                    height: 40.0,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .coachSmartGreen,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Flexible(
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  5.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                '${childAccessRequestsItem.firstName} ${childAccessRequestsItem.lastName}',
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Text(
                                                                'Requesting: ${valueOrDefault<String>(
                                                                  childAccessRequestsItem
                                                                      .requestingUserName,
                                                                  'requested_by',
                                                                )}',
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .inter(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .coachSmartGrey,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .fontStyle,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                        ].divide(SizedBox(
                                                            height: 5.0)),
                                                      ),
                                                    ),
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Icon(
                                                          Icons.chevron_right,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .alternate,
                                                          size: 30.0,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 5.0)),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              FFButtonWidget(
                                                onPressed: () async {
                                                  logFirebaseEvent(
                                                      'PENDING_REQUESTS_PAGE_APPROVE_BTN_ON_TAP');
                                                  logFirebaseEvent(
                                                      'Button_backend_call');
                                                  _model.apiConfirmMemberAccess =
                                                      await ConfirmUserMemberAccessCall
                                                          .call(
                                                    supabaseJWTtoken:
                                                        currentJwtToken,
                                                    pUserMemberId:
                                                        childAccessRequestsItem
                                                            .userMemberId,
                                                  );

                                                  if ((_model
                                                          .apiConfirmMemberAccess
                                                          ?.succeeded ??
                                                      true)) {
                                                    logFirebaseEvent(
                                                        'Button_backend_call');
                                                    _model.apiPendingRequestsConfirm1 =
                                                        await GetUserTeamSummaryCall
                                                            .call(
                                                      supabaseJWTtoken:
                                                          currentJwtToken,
                                                      pUserId: currentUserUid,
                                                    );

                                                    logFirebaseEvent(
                                                        'Button_update_app_state');
                                                    FFAppState()
                                                            .userTeamSummary =
                                                        UserTeamSummaryStruct
                                                            .maybeFromMap((_model
                                                                    .apiPendingRequestsConfirm1
                                                                    ?.jsonBody ??
                                                                ''))!;
                                                    logFirebaseEvent(
                                                        'Button_backend_call');
                                                    _model.apiJoinRequestsConfirm1 =
                                                        await GetPendingTeamRequestsCall
                                                            .call(
                                                      supabaseJWTtoken:
                                                          currentJwtToken,
                                                      pTeamId:
                                                          widget.paramTeamID,
                                                    );

                                                    logFirebaseEvent(
                                                        'Button_update_app_state');
                                                    FFAppState().joinRequests =
                                                        JoinRequestsStruct
                                                            .maybeFromMap((_model
                                                                    .apiJoinRequestsConfirm1
                                                                    ?.jsonBody ??
                                                                ''))!;
                                                    FFAppState().update(() {});
                                                  }

                                                  safeSetState(() {});
                                                },
                                                text: 'Approve',
                                                icon: Icon(
                                                  Icons.check,
                                                  size: 25.0,
                                                ),
                                                options: FFButtonOptions(
                                                  width: 120.0,
                                                  height: 35.0,
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          16.0, 0.0, 16.0, 0.0),
                                                  iconPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(0.0, 0.0,
                                                              0.0, 0.0),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .coachSmartGreen,
                                                  textStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleSmall
                                                          .override(
                                                            font: GoogleFonts
                                                                .interTight(
                                                              fontWeight:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontWeight,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontStyle,
                                                            ),
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .coachSmartLightBlack,
                                                            fontSize: 14.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                  elevation: 0.0,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                              ),
                                              FFButtonWidget(
                                                onPressed: () async {
                                                  logFirebaseEvent(
                                                      'PENDING_REQUESTS_PAGE_DECLINE_BTN_ON_TAP');
                                                  logFirebaseEvent(
                                                      'Button_backend_call');
                                                  _model.apiResults5qCopy =
                                                      await DenyUserMemberAccessCall
                                                          .call(
                                                    supabaseJWTtoken:
                                                        currentJwtToken,
                                                    pUserMemberId:
                                                        childAccessRequestsItem
                                                            .userMemberId,
                                                  );

                                                  if ((_model.apiResults5qCopy
                                                          ?.succeeded ??
                                                      true)) {
                                                    logFirebaseEvent(
                                                        'Button_backend_call');
                                                    _model.apiPendingRequestsDenyCopy =
                                                        await GetUserTeamSummaryCall
                                                            .call(
                                                      supabaseJWTtoken:
                                                          currentJwtToken,
                                                      pUserId: currentUserUid,
                                                    );

                                                    logFirebaseEvent(
                                                        'Button_update_app_state');
                                                    FFAppState()
                                                            .userTeamSummary =
                                                        UserTeamSummaryStruct
                                                            .maybeFromMap((_model
                                                                    .apiPendingRequestsDenyCopy
                                                                    ?.jsonBody ??
                                                                ''))!;
                                                    logFirebaseEvent(
                                                        'Button_backend_call');
                                                    _model.apiJoinRequestsDenyCopy =
                                                        await GetPendingTeamRequestsCall
                                                            .call(
                                                      supabaseJWTtoken:
                                                          currentJwtToken,
                                                      pTeamId:
                                                          widget.paramTeamID,
                                                    );

                                                    logFirebaseEvent(
                                                        'Button_update_app_state');
                                                    FFAppState().joinRequests =
                                                        JoinRequestsStruct
                                                            .maybeFromMap((_model
                                                                    .apiJoinRequestsDenyCopy
                                                                    ?.jsonBody ??
                                                                ''))!;
                                                    FFAppState().update(() {});
                                                  }

                                                  safeSetState(() {});
                                                },
                                                text: 'Decline',
                                                icon: Icon(
                                                  Icons.close,
                                                  size: 25.0,
                                                ),
                                                options: FFButtonOptions(
                                                  width: 120.0,
                                                  height: 35.0,
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          16.0, 0.0, 16.0, 0.0),
                                                  iconPadding:
                                                      EdgeInsetsDirectional
                                                          .fromSTEB(0.0, 0.0,
                                                              0.0, 0.0),
                                                  color: Color(0xFFB20307),
                                                  textStyle: FlutterFlowTheme
                                                          .of(context)
                                                      .titleSmall
                                                      .override(
                                                        font: GoogleFonts
                                                            .interTight(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .alternate,
                                                        fontSize: 14.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .titleSmall
                                                                .fontStyle,
                                                      ),
                                                  elevation: 0.0,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          8.0),
                                                ),
                                              ),
                                            ].divide(SizedBox(width: 10.0)),
                                          ),
                                        ].divide(SizedBox(height: 10.0)),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
