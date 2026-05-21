import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/components/drop_down_menu_attendance_widget.dart';
import '/components/drop_down_menu_export_widget.dart';
import '/components/drop_down_menu_squads_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'dart:async';
import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'attendee_list_admins_model.dart';
export 'attendee_list_admins_model.dart';

class AttendeeListAdminsWidget extends StatefulWidget {
  const AttendeeListAdminsWidget({
    super.key,
    required this.eventID,
    required this.responseID,
    required this.teamID,
    required this.eventRoleLevel,
    required this.userRoleLevel,
    required this.eventCodeId,
  });

  final int? eventID;
  final int? responseID;
  final int? teamID;
  final int? eventRoleLevel;
  final int? userRoleLevel;
  final int? eventCodeId;

  static String routeName = 'AttendeeListAdmins';
  static String routePath = 'attendeeListAdmins';

  @override
  State<AttendeeListAdminsWidget> createState() =>
      _AttendeeListAdminsWidgetState();
}

class _AttendeeListAdminsWidgetState extends State<AttendeeListAdminsWidget> {
  late AttendeeListAdminsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AttendeeListAdminsModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'AttendeeListAdmins'});
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiCallResponse>(
      future: (_model.apiRequestCompleter ??= Completer<ApiCallResponse>()
            ..complete(GetAttedanceSummaryByRoleAndSquadvTWOCall.call(
              pEventId: widget.eventID,
              pRoleGradeFilter: 10,
              pRoleLevelFilter: widget.eventRoleLevel,
              pRoleLevelExclude: 0,
              pResponseId: widget.responseID,
              supabaseJWTtoken: currentJwtToken,
            )))
          .future,
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).coachSmartMidBlack,
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).coachSmartGreen,
                  ),
                ),
              ),
            ),
          );
        }
        final attendeeListAdminsGetAttedanceSummaryByRoleAndSquadvTWOResponse =
            snapshot.data!;

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
                  logFirebaseEvent('ATTENDEE_LIST_ADMINS_arrow_back_rounded_');
                  logFirebaseEvent('IconButton_navigate_back');
                  context.safePop();
                },
              ),
              title: Text(
                () {
                  if (widget.responseID == 3) {
                    return 'Accepted';
                  } else if (widget.responseID == 4) {
                    return 'Declined';
                  } else {
                    return 'No Response';
                  }
                }(),
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
                      fontSize: isWeb == true ? 18.0 : 20.0,
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<List<MatchSquadsRow>>(
                        future: (_model.requestCompleter ??=
                                Completer<List<MatchSquadsRow>>()
                                  ..complete(MatchSquadsTable().querySingleRow(
                                    queryFn: (q) => q
                                        .eqOrNull(
                                          'event_id',
                                          widget.eventID,
                                        )
                                        .order('created_at'),
                                  )))
                            .future,
                        builder: (context, snapshot) {
                          // Customize what your widget looks like when it's loading.
                          if (!snapshot.hasData) {
                            return Center(
                              child: SizedBox(
                                width: 50.0,
                                height: 50.0,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    FlutterFlowTheme.of(context)
                                        .coachSmartGreen,
                                  ),
                                ),
                              ),
                            );
                          }
                          List<MatchSquadsRow> columnMatchSquadsRowList =
                              snapshot.data!;

                          final columnMatchSquadsRow =
                              columnMatchSquadsRowList.isNotEmpty
                                  ? columnMatchSquadsRowList.first
                                  : null;

                          return Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              if (widget.responseID == 3)
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      2.0, 10.0, 2.0, 10.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 0.0, 0.0, 10.0),
                                        child: Text(
                                          'Published: ${columnMatchSquadsRow?.matchSquadId != null ? dateTimeFormat("EEEE, MMMM dd \'at\' HH:mm", columnMatchSquadsRow?.createdAt) : 'Not yet published'}',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .coachSmartGrey,
                                                fontSize:
                                                    isWeb == true ? 14.0 : 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 10.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: FFButtonWidget(
                                                    onPressed: () async {
                                                      logFirebaseEvent(
                                                          'ATTENDEE_LIST_ADMINS_publishButton_ON_TA');
                                                      if (EventAttendanceStruct
                                                              .maybeFromMap(
                                                                  attendeeListAdminsGetAttedanceSummaryByRoleAndSquadvTWOResponse
                                                                      .jsonBody) !=
                                                          null) {
                                                        logFirebaseEvent(
                                                            'publishButton_backend_call');
                                                        _model.outputCreateMatchDaySquad =
                                                            await CreateMatchDaySquadFromAttendanceCall
                                                                .call(
                                                          supabaseJWTtoken:
                                                              currentJwtToken,
                                                          pEventId:
                                                              widget.eventID,
                                                          pUserId:
                                                              currentUserUid,
                                                        );

                                                        if ((_model
                                                                .outputCreateMatchDaySquad
                                                                ?.succeeded ??
                                                            true)) {
                                                          logFirebaseEvent(
                                                              'publishButton_refresh_database_request');
                                                          safeSetState(() =>
                                                              _model.requestCompleter =
                                                                  null);
                                                          await _model
                                                              .waitForRequestCompleted();
                                                        } else {
                                                          logFirebaseEvent(
                                                              'publishButton_show_snack_bar');
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                (_model.outputCreateMatchDaySquad
                                                                        ?.bodyText ??
                                                                    ''),
                                                                style:
                                                                    TextStyle(
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                ),
                                                              ),
                                                              duration: Duration(
                                                                  milliseconds:
                                                                      4000),
                                                              backgroundColor:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondary,
                                                            ),
                                                          );
                                                        }
                                                      }

                                                      safeSetState(() {});
                                                    },
                                                    text: 'Publish Teams',
                                                    icon: Icon(
                                                      Icons.publish,
                                                      size: 25.0,
                                                    ),
                                                    options: FFButtonOptions(
                                                      height: 45.0,
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  16.0,
                                                                  0.0,
                                                                  16.0,
                                                                  0.0),
                                                      iconPadding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  0.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      color: FlutterFlowTheme
                                                              .of(context)
                                                          .coachSmartLightBlack,
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
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .coachSmartGreen,
                                                                fontSize:
                                                                    isWeb ==
                                                                            true
                                                                        ? 14.0
                                                                        : 16.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontWeight,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                              ),
                                                      elevation: 0.0,
                                                      borderSide: BorderSide(
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .coachSmartGreen,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Builder(
                                                    builder: (context) =>
                                                        FFButtonWidget(
                                                      onPressed:
                                                          (columnMatchSquadsRow
                                                                      ?.matchSquadId ==
                                                                  null)
                                                              ? null
                                                              : () async {
                                                                  logFirebaseEvent(
                                                                      'ATTENDEE_LIST_ADMINS_exportButton_ON_TAP');
                                                                  logFirebaseEvent(
                                                                      'exportButton_alert_dialog');
                                                                  await showAlignedDialog(
                                                                    context:
                                                                        context,
                                                                    isGlobal:
                                                                        false,
                                                                    avoidOverflow:
                                                                        true,
                                                                    targetAnchor: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                    followerAnchor: AlignmentDirectional(
                                                                            0.0,
                                                                            0.0)
                                                                        .resolve(
                                                                            Directionality.of(context)),
                                                                    builder:
                                                                        (dialogContext) {
                                                                      return Material(
                                                                        color: Colors
                                                                            .transparent,
                                                                        child:
                                                                            WebViewAware(
                                                                          child:
                                                                              GestureDetector(
                                                                            onTap:
                                                                                () {
                                                                              FocusScope.of(dialogContext).unfocus();
                                                                              FocusManager.instance.primaryFocus?.unfocus();
                                                                            },
                                                                            child:
                                                                                DropDownMenuExportWidget(
                                                                              paramEventId: widget.eventID!,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
                                                                  );
                                                                },
                                                      text: 'Export Teams',
                                                      icon: Icon(
                                                        Icons.ios_share,
                                                        size: 25.0,
                                                      ),
                                                      options: FFButtonOptions(
                                                        height: 45.0,
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    16.0,
                                                                    0.0,
                                                                    16.0,
                                                                    0.0),
                                                        iconPadding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .coachSmartLightBlack,
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
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .coachSmartGreen,
                                                                  fontSize:
                                                                      isWeb ==
                                                                              true
                                                                          ? 14.0
                                                                          : 16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .titleSmall
                                                                      .fontStyle,
                                                                ),
                                                        elevation: 0.0,
                                                        borderSide: BorderSide(
                                                          color: columnMatchSquadsRow
                                                                      ?.matchSquadId ==
                                                                  null
                                                              ? FlutterFlowTheme
                                                                      .of(
                                                                          context)
                                                                  .coachSmartGrey
                                                              : FlutterFlowTheme
                                                                      .of(context)
                                                                  .coachSmartGreen,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8.0),
                                                        disabledColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .coachSmartLightBlack,
                                                        disabledTextColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .coachSmartGrey,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 10.0)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (columnMatchSquadsRow?.matchSquadId ==
                                          null)
                                        Text(
                                          '** Publish the teams to enable export',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .coachSmartGrey,
                                                fontSize:
                                                    isWeb == true ? 14.0 : 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 140.0,
                                    decoration: BoxDecoration(),
                                    child: Builder(
                                      builder: (context) {
                                        final childrenSquads =
                                            EventAttendanceStruct.maybeFromMap(
                                                        attendeeListAdminsGetAttedanceSummaryByRoleAndSquadvTWOResponse
                                                            .jsonBody)
                                                    ?.squads
                                                    .toList() ??
                                                [];

                                        return ListView.separated(
                                          padding: EdgeInsets.zero,
                                          primary: false,
                                          scrollDirection: Axis.horizontal,
                                          itemCount: childrenSquads.length,
                                          separatorBuilder: (_, __) =>
                                              SizedBox(width: 10.0),
                                          itemBuilder:
                                              (context, childrenSquadsIndex) {
                                            final childrenSquadsItem =
                                                childrenSquads[
                                                    childrenSquadsIndex];
                                            return Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Stack(
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                children: [
                                                  Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            0.0, 0.0),
                                                    child: InkWell(
                                                      splashColor:
                                                          Colors.transparent,
                                                      focusColor:
                                                          Colors.transparent,
                                                      hoverColor:
                                                          Colors.transparent,
                                                      highlightColor:
                                                          Colors.transparent,
                                                      onTap: () async {
                                                        logFirebaseEvent(
                                                            'ATTENDEE_LIST_ADMINS_Container_ql3ono4x_');
                                                        if (_model
                                                                .currentSquad !=
                                                            childrenSquadsItem
                                                                .squadId) {
                                                          logFirebaseEvent(
                                                              'Container_update_page_state');
                                                          _model.currentSquad =
                                                              childrenSquadsItem
                                                                  .squadId;
                                                          safeSetState(() {});
                                                        } else {
                                                          logFirebaseEvent(
                                                              'Container_update_page_state');
                                                          _model.currentSquad =
                                                              null;
                                                          safeSetState(() {});
                                                        }
                                                      },
                                                      child: Container(
                                                        width: 250.0,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .coachSmartLightBlack,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      8.0),
                                                          border: Border.all(
                                                            color: _model
                                                                        .currentSquad ==
                                                                    childrenSquadsItem
                                                                        .squadId
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .coachSmartGreen
                                                                : Color(
                                                                    0x00000000),
                                                          ),
                                                        ),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          children: [
                                                            Expanded(
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .spaceBetween,
                                                                children: [
                                                                  Expanded(
                                                                    child:
                                                                        Padding(
                                                                      padding: EdgeInsetsDirectional.fromSTEB(
                                                                          10.0,
                                                                          5.0,
                                                                          10.0,
                                                                          10.0),
                                                                      child:
                                                                          Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.max,
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.spaceEvenly,
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Padding(
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                0.0,
                                                                                0.0,
                                                                                0.0,
                                                                                5.0),
                                                                            child:
                                                                                Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                              crossAxisAlignment: CrossAxisAlignment.center,
                                                                              children: [
                                                                                Text(
                                                                                  valueOrDefault<String>(
                                                                                    childrenSquadsItem.squadName,
                                                                                    'squad_name',
                                                                                  ),
                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                        font: GoogleFonts.inter(
                                                                                          fontWeight: FontWeight.w500,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                        color: FlutterFlowTheme.of(context).coachSmartGreen,
                                                                                        fontSize: 17.0,
                                                                                        letterSpacing: 0.0,
                                                                                        fontWeight: FontWeight.w500,
                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                      ),
                                                                                ),
                                                                                Container(
                                                                                  width: 35.0,
                                                                                  height: 35.0,
                                                                                  clipBehavior: Clip.antiAlias,
                                                                                  decoration: BoxDecoration(
                                                                                    shape: BoxShape.circle,
                                                                                  ),
                                                                                  child: Image.network(
                                                                                    getJsonField(
                                                                                      childrenSquadsItem.toMap(),
                                                                                      r'''$.squad_image''',
                                                                                    ).toString(),
                                                                                    fit: BoxFit.cover,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          Padding(
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                0.0,
                                                                                0.0,
                                                                                0.0,
                                                                                5.0),
                                                                            child:
                                                                                Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                              children: [
                                                                                Text(
                                                                                  valueOrDefault<String>(
                                                                                    childrenSquadsItem.roleLevelCount.toString(),
                                                                                    '0',
                                                                                  ).maybeHandleOverflow(
                                                                                    maxChars: 6,
                                                                                  ),
                                                                                  style: FlutterFlowTheme.of(context).headlineLarge.override(
                                                                                        font: GoogleFonts.interTight(
                                                                                          fontWeight: FlutterFlowTheme.of(context).headlineLarge.fontWeight,
                                                                                          fontStyle: FlutterFlowTheme.of(context).headlineLarge.fontStyle,
                                                                                        ),
                                                                                        fontSize: isWeb == true ? 32.0 : 34.0,
                                                                                        letterSpacing: 0.0,
                                                                                        fontWeight: FlutterFlowTheme.of(context).headlineLarge.fontWeight,
                                                                                        fontStyle: FlutterFlowTheme.of(context).headlineLarge.fontStyle,
                                                                                      ),
                                                                                ),
                                                                                FFButtonWidget(
                                                                                  onPressed: (columnMatchSquadsRow?.matchSquadId == null)
                                                                                      ? null
                                                                                      : () async {
                                                                                          logFirebaseEvent('ATTENDEE_LIST_ADMINS_LINEUP_BTN_ON_TAP');
                                                                                          logFirebaseEvent('Button_navigate_to');

                                                                                          context.pushNamed(
                                                                                            TeamSelectorWidget.routeName,
                                                                                            queryParameters: {
                                                                                              'eventId': serializeParam(
                                                                                                widget.eventID,
                                                                                                ParamType.int,
                                                                                              ),
                                                                                              'teamId': serializeParam(
                                                                                                widget.teamID,
                                                                                                ParamType.int,
                                                                                              ),
                                                                                              'squadId': serializeParam(
                                                                                                childrenSquadsItem.squadId,
                                                                                                ParamType.int,
                                                                                              ),
                                                                                            }.withoutNulls,
                                                                                          );
                                                                                        },
                                                                                  text: 'Lineup',
                                                                                  icon: Icon(
                                                                                    Icons.list_alt_sharp,
                                                                                    size: 23.0,
                                                                                  ),
                                                                                  options: FFButtonOptions(
                                                                                    padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                                                                    iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                                                                    color: FlutterFlowTheme.of(context).coachSmartGreen,
                                                                                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                          font: GoogleFonts.interTight(
                                                                                            fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                            fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                          ),
                                                                                          color: FlutterFlowTheme.of(context).coachSmartLightBlack,
                                                                                          letterSpacing: 0.0,
                                                                                          fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                          fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                        ),
                                                                                    elevation: 0.0,
                                                                                    borderSide: BorderSide(
                                                                                      color: columnMatchSquadsRow?.matchSquadId == null ? FlutterFlowTheme.of(context).coachSmartGrey : Color(0x00000000),
                                                                                    ),
                                                                                    borderRadius: BorderRadius.circular(22.0),
                                                                                    disabledColor: FlutterFlowTheme.of(context).coachSmartLightBlack,
                                                                                    disabledTextColor: FlutterFlowTheme.of(context).coachSmartGrey,
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                          ),
                                                                          Container(
                                                                            width:
                                                                                170.0,
                                                                            child:
                                                                                Column(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              children: [
                                                                                Builder(
                                                                                  builder: (context) {
                                                                                    final childrenRoles = childrenSquadsItem.roles.where((e) => e.roleLevel != 10).toList();

                                                                                    return ListView.builder(
                                                                                      padding: EdgeInsets.zero,
                                                                                      shrinkWrap: true,
                                                                                      scrollDirection: Axis.vertical,
                                                                                      itemCount: childrenRoles.length,
                                                                                      itemBuilder: (context, childrenRolesIndex) {
                                                                                        final childrenRolesItem = childrenRoles[childrenRolesIndex];
                                                                                        return Text(
                                                                                          '${childrenRolesItem.roleNamePlural}: ${childrenRolesItem.memberCount.toString()}',
                                                                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                font: GoogleFonts.inter(
                                                                                                  fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                                ),
                                                                                                fontSize: isWeb == true ? 14.0 : 16.0,
                                                                                                letterSpacing: 0.0,
                                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
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
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      Flexible(
                        child: FutureBuilder<ApiCallResponse>(
                          future: GetEventAttendanceByRoleVTWOCall.call(
                            pEventId: widget.eventID,
                            pRoleGradeFilter: 10,
                            pRoleLevelFilter: widget.eventRoleLevel,
                            pRoleLevelExclude: 0,
                            pResponseId: widget.responseID,
                            supabaseJWTtoken: currentJwtToken,
                          ),
                          builder: (context, snapshot) {
                            // Customize what your widget looks like when it's loading.
                            if (!snapshot.hasData) {
                              return Center(
                                child: SizedBox(
                                  width: 50.0,
                                  height: 50.0,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      FlutterFlowTheme.of(context)
                                          .coachSmartGreen,
                                    ),
                                  ),
                                ),
                              );
                            }
                            final columnListWrapperGetEventAttendanceByRoleVTWOResponse =
                                snapshot.data!;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 10.0, 0.0, 0.0),
                                  child: Builder(
                                    builder: (context) {
                                      final childrenFilter =
                                          (columnListWrapperGetEventAttendanceByRoleVTWOResponse
                                                          .jsonBody
                                                          .toList()
                                                          .map<ListRolesStruct?>(
                                                              ListRolesStruct
                                                                  .maybeFromMap)
                                                          .toList()
                                                      as Iterable<
                                                          ListRolesStruct?>)
                                                  .withoutNulls
                                                  .toList() ??
                                              [];

                                      return Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children:
                                            List.generate(childrenFilter.length,
                                                (childrenFilterIndex) {
                                          final childrenFilterItem =
                                              childrenFilter[
                                                  childrenFilterIndex];
                                          return FFButtonWidget(
                                            onPressed: () async {
                                              logFirebaseEvent(
                                                  'ATTENDEE_LIST_ADMINS_Button_bpspcegl_ON_');
                                              if (_model.varFilterRole ==
                                                  childrenFilterItem.roleId) {
                                                logFirebaseEvent(
                                                    'Button_update_page_state');
                                                _model.varFilterRole = null;
                                                safeSetState(() {});
                                              } else {
                                                logFirebaseEvent(
                                                    'Button_update_page_state');
                                                _model.varFilterRole =
                                                    childrenFilterItem.roleId;
                                                safeSetState(() {});
                                              }
                                            },
                                            text: '${valueOrDefault<String>(
                                              childrenFilterItem.roleNamePlural,
                                              'role_name',
                                            )} (${childrenFilterItem.members.where((e) => (e.squadId == _model.currentSquad) || (_model.currentSquad == null)).toList().length.toString()})',
                                            options: FFButtonOptions(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      16.0, 15.0, 16.0, 15.0),
                                              iconPadding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              color: _model.varFilterRole ==
                                                      childrenFilterItem.roleId
                                                  ? FlutterFlowTheme.of(context)
                                                      .coachSmartGreen
                                                  : FlutterFlowTheme.of(context)
                                                      .coachSmartLightBlack,
                                              textStyle: FlutterFlowTheme.of(
                                                      context)
                                                  .titleSmall
                                                  .override(
                                                    font:
                                                        GoogleFonts.interTight(
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
                                                    color: _model
                                                                .varFilterRole ==
                                                            childrenFilterItem
                                                                .roleId
                                                        ? FlutterFlowTheme.of(
                                                                context)
                                                            .coachSmartLightBlack
                                                        : FlutterFlowTheme.of(
                                                                context)
                                                            .coachSmartWhite,
                                                    fontSize: isWeb == true
                                                        ? 14.0
                                                        : 16.0,
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
                                                  BorderRadius.circular(24.0),
                                            ),
                                          );
                                        }).divide(SizedBox(width: 10.0)),
                                      );
                                    },
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final childrenRoleList =
                                        (columnListWrapperGetEventAttendanceByRoleVTWOResponse
                                                        .jsonBody
                                                        .toList()
                                                        .map<ListRolesStruct?>(
                                                            ListRolesStruct
                                                                .maybeFromMap)
                                                        .toList()
                                                    as Iterable<
                                                        ListRolesStruct?>)
                                                .withoutNulls
                                                .where((e) =>
                                                    (e.roleId ==
                                                        _model.varFilterRole) ||
                                                    (_model.varFilterRole ==
                                                        null))
                                                .toList()
                                                .sortedList(
                                                    keyOf: (e) => e.roleLevel,
                                                    desc: false)
                                                .toList() ??
                                            [];

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children:
                                          List.generate(childrenRoleList.length,
                                              (childrenRoleListIndex) {
                                        final childrenRoleListItem =
                                            childrenRoleList[
                                                childrenRoleListIndex];
                                        return Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 0.0, 10.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 10.0, 0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      valueOrDefault<String>(
                                                        childrenRoleListItem
                                                            .roleNamePlural,
                                                        'role_name',
                                                      ),
                                                      textAlign:
                                                          TextAlign.start,
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                            ),
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .primaryBackground,
                                                            fontSize:
                                                                isWeb == true
                                                                    ? 18.0
                                                                    : 20.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Divider(
                                                thickness: 1.0,
                                                color: Color(0xFF4D4D4D),
                                              ),
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        10.0, 0.0, 0.0, 0.0),
                                                child: Builder(
                                                  builder: (context) {
                                                    final childrenMembers = childrenRoleListItem
                                                        .members
                                                        .sortedList(
                                                            keyOf: (e) =>
                                                                e.sortKey,
                                                            desc: false)
                                                        .where((e) =>
                                                            ((e.squadId ==
                                                                    _model
                                                                        .currentSquad) ||
                                                                (_model.currentSquad ==
                                                                    null)) &&
                                                            ((childrenRoleListItem
                                                                        .roleId ==
                                                                    _model
                                                                        .varFilterRole) ||
                                                                (_model.varFilterRole ==
                                                                    null)))
                                                        .toList();

                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: List.generate(
                                                          childrenMembers
                                                              .length,
                                                          (childrenMembersIndex) {
                                                        final childrenMembersItem =
                                                            childrenMembers[
                                                                childrenMembersIndex];
                                                        return Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      5.0),
                                                          child: InkWell(
                                                            splashColor: Colors
                                                                .transparent,
                                                            focusColor: Colors
                                                                .transparent,
                                                            hoverColor: Colors
                                                                .transparent,
                                                            highlightColor:
                                                                Colors
                                                                    .transparent,
                                                            onTap: () async {
                                                              logFirebaseEvent(
                                                                  'ATTENDEE_LIST_ADMINS_Row_lr5mhn56_ON_TAP');
                                                              logFirebaseEvent(
                                                                  'Row_navigate_to');

                                                              context.pushNamed(
                                                                MemberDetailsWidget
                                                                    .routeName,
                                                                queryParameters:
                                                                    {
                                                                  'memberID':
                                                                      serializeParam(
                                                                    childrenMembersItem
                                                                        .memberId,
                                                                    ParamType
                                                                        .int,
                                                                  ),
                                                                  'teamID':
                                                                      serializeParam(
                                                                    widget
                                                                        .teamID,
                                                                    ParamType
                                                                        .int,
                                                                  ),
                                                                }.withoutNulls,
                                                              );
                                                            },
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  child: Column(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.max,
                                                                        mainAxisAlignment:
                                                                            MainAxisAlignment.spaceBetween,
                                                                        children:
                                                                            [
                                                                          Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.max,
                                                                            children: [
                                                                              Text(
                                                                                valueOrDefault<String>(
                                                                                  childrenMembersItem.memberName,
                                                                                  'member_name',
                                                                                ),
                                                                                textAlign: TextAlign.start,
                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                      font: GoogleFonts.inter(
                                                                                        fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                      ),
                                                                                      fontSize: isWeb == true ? 16.0 : 18.0,
                                                                                      letterSpacing: 0.0,
                                                                                      fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ].divide(SizedBox(width: 10.0)),
                                                                      ),
                                                                      Builder(
                                                                        builder:
                                                                            (context) =>
                                                                                InkWell(
                                                                          splashColor:
                                                                              Colors.transparent,
                                                                          focusColor:
                                                                              Colors.transparent,
                                                                          hoverColor:
                                                                              Colors.transparent,
                                                                          highlightColor:
                                                                              Colors.transparent,
                                                                          onTap:
                                                                              () async {
                                                                            logFirebaseEvent('ATTENDEE_LIST_ADMINS_Row_5a7s76r6_ON_TAP');
                                                                            if (widget.userRoleLevel! >=
                                                                                100) {
                                                                              logFirebaseEvent('Row_alert_dialog');
                                                                              await showDialog(
                                                                                context: context,
                                                                                builder: (dialogContext) {
                                                                                  return Dialog(
                                                                                    elevation: 0,
                                                                                    insetPadding: EdgeInsets.zero,
                                                                                    backgroundColor: Colors.transparent,
                                                                                    alignment: AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                    child: WebViewAware(
                                                                                      child: GestureDetector(
                                                                                        onTap: () {
                                                                                          FocusScope.of(dialogContext).unfocus();
                                                                                          FocusManager.instance.primaryFocus?.unfocus();
                                                                                        },
                                                                                        child: DropDownMenuSquadsWidget(
                                                                                          parTeamID: widget.teamID!,
                                                                                          passBackSquadID: (outputSelectedSquadID) async {
                                                                                            logFirebaseEvent('_update_page_state');
                                                                                            _model.squadSelected = outputSelectedSquadID;
                                                                                            safeSetState(() {});
                                                                                            logFirebaseEvent('_close_dialog_drawer_etc');
                                                                                            Navigator.pop(context);
                                                                                          },
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              );

                                                                              logFirebaseEvent('Row_backend_call');
                                                                              _model.outputUpdatedCode = await GetUpdatedEventCodeCall.call(
                                                                                supabaseJWTtoken: currentJwtToken,
                                                                                pEventId: widget.eventID,
                                                                              );

                                                                              logFirebaseEvent('Row_backend_call');
                                                                              _model.outputExistingMemberSquad = await MemberSquadLinkTable().queryRows(
                                                                                queryFn: (q) => q
                                                                                    .eqOrNull(
                                                                                      'member_id',
                                                                                      childrenMembersItem.memberId,
                                                                                    )
                                                                                    .eqOrNull(
                                                                                      'team_id',
                                                                                      widget.teamID,
                                                                                    )
                                                                                    .eqOrNull(
                                                                                      'code_id',
                                                                                      (_model.outputUpdatedCode?.jsonBody ?? ''),
                                                                                    ),
                                                                              );
                                                                              if (_model.outputExistingMemberSquad!.length >= 1) {
                                                                                logFirebaseEvent('Row_backend_call');
                                                                                await MemberSquadLinkTable().update(
                                                                                  data: {
                                                                                    'squad_id': _model.squadSelected != null ? _model.squadSelected : childrenMembersItem.squadId,
                                                                                  },
                                                                                  matchingRows: (rows) => rows.eqOrNull(
                                                                                    'member_squad_id',
                                                                                    _model.outputExistingMemberSquad?.firstOrNull?.memberSquadId,
                                                                                  ),
                                                                                );
                                                                              } else {
                                                                                logFirebaseEvent('Row_backend_call');
                                                                                await MemberSquadLinkTable().insert({
                                                                                  'member_id': childrenMembersItem.memberId,
                                                                                  'team_id': widget.teamID,
                                                                                  'code_id': (_model.outputUpdatedCode?.jsonBody ?? ''),
                                                                                  'squad_id': _model.squadSelected != null ? _model.squadSelected : childrenMembersItem.squadId,
                                                                                });
                                                                              }

                                                                              logFirebaseEvent('Row_refresh_database_request');
                                                                              safeSetState(() => _model.apiRequestCompleter = null);
                                                                              await _model.waitForApiRequestCompleted();
                                                                            }

                                                                            safeSetState(() {});
                                                                          },
                                                                          child:
                                                                              Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
                                                                            children:
                                                                                [
                                                                              Container(
                                                                                width: 30.0,
                                                                                height: 30.0,
                                                                                decoration: BoxDecoration(
                                                                                  image: DecorationImage(
                                                                                    fit: BoxFit.cover,
                                                                                    image: Image.network(
                                                                                      getJsonField(
                                                                                        childrenMembersItem.toMap(),
                                                                                        r'''$.squad_image''',
                                                                                      ).toString(),
                                                                                    ).image,
                                                                                  ),
                                                                                  shape: BoxShape.circle,
                                                                                ),
                                                                              ),
                                                                              Text(
                                                                                valueOrDefault<String>(
                                                                                  childrenMembersItem.squadName,
                                                                                  'squad',
                                                                                ),
                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                      font: GoogleFonts.inter(
                                                                                        fontWeight: FontWeight.w600,
                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                      ),
                                                                                      color: FlutterFlowTheme.of(context).coachSmartGreen,
                                                                                      fontSize: isWeb ? 16.0 : 18.0,
                                                                                      letterSpacing: 0.0,
                                                                                      fontWeight: FontWeight.w600,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                              ),
                                                                            ].divide(SizedBox(width: 5.0)),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ].divide(SizedBox(
                                                                        height:
                                                                            10.0)),
                                                                  ),
                                                                ),
                                                                Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .spaceBetween,
                                                                      children: [
                                                                        Builder(
                                                                          builder: (context) =>
                                                                              InkWell(
                                                                            splashColor:
                                                                                Colors.transparent,
                                                                            focusColor:
                                                                                Colors.transparent,
                                                                            hoverColor:
                                                                                Colors.transparent,
                                                                            highlightColor:
                                                                                Colors.transparent,
                                                                            onTap:
                                                                                () async {
                                                                              logFirebaseEvent('ATTENDEE_LIST_ADMINS_Icon_i2cvddgn_ON_TA');
                                                                              logFirebaseEvent('Icon_alert_dialog');
                                                                              await showAlignedDialog(
                                                                                context: context,
                                                                                isGlobal: false,
                                                                                avoidOverflow: true,
                                                                                targetAnchor: AlignmentDirectional(-2.0, 1.0).resolve(Directionality.of(context)),
                                                                                followerAnchor: AlignmentDirectional(1.0, 0.0).resolve(Directionality.of(context)),
                                                                                builder: (dialogContext) {
                                                                                  return Material(
                                                                                    color: Colors.transparent,
                                                                                    child: WebViewAware(
                                                                                      child: GestureDetector(
                                                                                        onTap: () {
                                                                                          FocusScope.of(dialogContext).unfocus();
                                                                                          FocusManager.instance.primaryFocus?.unfocus();
                                                                                        },
                                                                                        child: DropDownMenuAttendanceWidget(
                                                                                          paramEventId: widget.eventID!,
                                                                                          paramMemberId: childrenMembersItem.memberId,
                                                                                          paramCurrentResponse: widget.responseID!,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  );
                                                                                },
                                                                              );
                                                                            },
                                                                            child:
                                                                                Icon(
                                                                              Icons.more_vert,
                                                                              color: FlutterFlowTheme.of(context).alternate,
                                                                              size: 30.0,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        Icon(
                                                                          Icons
                                                                              .chevron_right,
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryBackground,
                                                                          size:
                                                                              30.0,
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      }).divide(SizedBox(
                                                          height: 5.0)),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
