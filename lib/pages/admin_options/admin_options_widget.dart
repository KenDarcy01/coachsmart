import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'admin_options_model.dart';
export 'admin_options_model.dart';

class AdminOptionsWidget extends StatefulWidget {
  const AdminOptionsWidget({
    super.key,
    required this.eventID,
  });

  final int? eventID;

  static String routeName = 'AdminOptions';
  static String routePath = 'adminOptions';

  @override
  State<AdminOptionsWidget> createState() => _AdminOptionsWidgetState();
}

class _AdminOptionsWidgetState extends State<AdminOptionsWidget> {
  late AdminOptionsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminOptionsModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'AdminOptions'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('ADMIN_OPTIONS_AdminOptions_ON_INIT_STATE');
      logFirebaseEvent('AdminOptions_backend_call');
      _model.apiEventAdminDetail = await GetEventAdminDetailsCall.call(
        supabaseJWTtoken: currentJwtToken,
        pEventId: widget.eventID,
      );

      if ((_model.apiEventAdminDetail?.succeeded ?? true)) {
        logFirebaseEvent('AdminOptions_update_app_state');
        FFAppState().eventAdminDetail = EventAdminDetailStruct.maybeFromMap(
            (_model.apiEventAdminDetail?.jsonBody ?? ''))!;
        safeSetState(() {});
        logFirebaseEvent('AdminOptions_set_form_field');
        _model.switchUpdatesValue =
            FFAppState().eventAdminDetail.notifyAdminsChanges;
        logFirebaseEvent('AdminOptions_set_form_field');
        _model.switchAllChangesValue =
            FFAppState().eventAdminDetail.notifyAdminsAll;
        logFirebaseEvent('AdminOptions_set_form_field');
        safeSetState(() {
          _model.switchCarPoolValue = FFAppState().eventAdminDetail.carPooling;
        });
      } else {
        logFirebaseEvent('AdminOptions_show_snack_bar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (_model.apiEventAdminDetail?.jsonBody ?? '').toString(),
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
    });

    _model.switchUpdatesValue = false;
    _model.switchAllChangesValue = false;
    _model.switchCarPoolValue = false;
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
              logFirebaseEvent('ADMIN_OPTIONS_arrow_back_rounded_ICN_ON_');
              logFirebaseEvent('IconButton_navigate_back');
              context.safePop();
            },
          ),
          title: Text(
            'Admin Options',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight:
                        FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  fontSize: 18.0,
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).headlineMedium.fontWeight,
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
          child: Visibility(
            visible: _model.apiEventAdminDetail != null,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(15.0, 15.0, 15.0, 25.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 10.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      logFirebaseEvent(
                                          'ADMIN_OPTIONS_SEND_EVENT_REMINDER_BTN_ON');
                                      logFirebaseEvent('Button_backend_call');
                                      _model.apiPopulateNotifications =
                                          await PopulateEventNotificationsCall
                                              .call(
                                        supabaseJWTtoken: currentJwtToken,
                                        pEventIdParam: widget.eventID,
                                        pRoleLevel: 10,
                                        pRoleGrade: 10,
                                      );

                                      if ((_model.apiPopulateNotifications
                                              ?.succeeded ??
                                          true)) {
                                        logFirebaseEvent(
                                            'Button_show_snack_bar');
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Notifications Sent',
                                              style: TextStyle(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: isWeb ? 14.0 : 16.0,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            duration:
                                                Duration(milliseconds: 4000),
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .coachSmartGreen,
                                          ),
                                        );
                                      } else {
                                        logFirebaseEvent(
                                            'Button_show_snack_bar');
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              (_model.apiPopulateNotifications
                                                          ?.jsonBody ??
                                                      '')
                                                  .toString(),
                                              style: TextStyle(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            duration:
                                                Duration(milliseconds: 4000),
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .error,
                                          ),
                                        );
                                      }

                                      safeSetState(() {});
                                    },
                                    text: 'Send Event Reminder',
                                    icon: Icon(
                                      Icons.email_outlined,
                                      size: 25.0,
                                    ),
                                    options: FFButtonOptions(
                                      height: 40.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 0.0, 16.0, 0.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      color: FlutterFlowTheme.of(context)
                                          .coachSmartLightBlack,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .override(
                                            font: GoogleFonts.interTight(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .coachSmartGreen,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 10.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reminder History:',
                                  textAlign: TextAlign.start,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .coachSmartGrey,
                                        fontSize: isWeb == true ? 14.0 : 16.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ].divide(SizedBox(height: 10.0)),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final childrenReminders = FFAppState()
                                  .eventAdminDetail
                                  .reminders
                                  .toList();

                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                scrollDirection: Axis.vertical,
                                itemCount: childrenReminders.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 10.0),
                                itemBuilder: (context, childrenRemindersIndex) {
                                  final childrenRemindersItem =
                                      childrenReminders[childrenRemindersIndex];
                                  return Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .coachSmartLightBlack,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          10.0, 10.0, 10.0, 10.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            valueOrDefault<String>(
                                              childrenRemindersItem.createdAt,
                                              'created_at',
                                            ),
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .coachSmartGreen,
                                                  fontSize: isWeb == true
                                                      ? 14.0
                                                      : 16.0,
                                                  letterSpacing: 0.0,
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
                                          ),
                                          Text(
                                            valueOrDefault<String>(
                                              childrenRemindersItem
                                                  .userFullName,
                                              'user_name',
                                            ),
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
                                                  fontSize: isWeb == true
                                                      ? 14.0
                                                      : 16.0,
                                                  letterSpacing: 0.0,
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
                                          ),
                                          Text(
                                            valueOrDefault<String>(
                                              childrenRemindersItem.result,
                                              'result',
                                            ).maybeHandleOverflow(
                                              maxChars: 42,
                                              replacement: '…',
                                            ),
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .coachSmartGrey,
                                                  fontSize: isWeb == true
                                                      ? 14.0
                                                      : 16.0,
                                                  letterSpacing: 0.0,
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
                                          ),
                                        ].divide(SizedBox(height: 5.0)),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 10.0, 0.0, 0.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Notifications',
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            fontSize: 18.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 10.0, 0.0, 0.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Notify admins of attendance updates ONLY',
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            font: GoogleFonts
                                                                .inter(
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
                                                            fontSize:
                                                                isWeb == true
                                                                    ? 14.0
                                                                    : 16.0,
                                                            letterSpacing: 0.0,
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
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Switch.adaptive(
                                                value:
                                                    _model.switchUpdatesValue!,
                                                onChanged: (newValue) async {
                                                  safeSetState(() => _model
                                                          .switchUpdatesValue =
                                                      newValue);
                                                  if (newValue) {
                                                    logFirebaseEvent(
                                                        'ADMIN_OPTIONS_switchUpdates_ON_TOGGLE_ON');
                                                    logFirebaseEvent(
                                                        'switchUpdates_backend_call');
                                                    await EventsTable().update(
                                                      data: {
                                                        'notify_admins_changes':
                                                            true,
                                                      },
                                                      matchingRows: (rows) =>
                                                          rows.eqOrNull(
                                                        'event_id',
                                                        widget.eventID,
                                                      ),
                                                    );
                                                  } else {
                                                    logFirebaseEvent(
                                                        'ADMIN_OPTIONS_switchUpdates_ON_TOGGLE_OF');
                                                    logFirebaseEvent(
                                                        'switchUpdates_backend_call');
                                                    await EventsTable().update(
                                                      data: {
                                                        'notify_admins_changes':
                                                            false,
                                                      },
                                                      matchingRows: (rows) =>
                                                          rows.eqOrNull(
                                                        'event_id',
                                                        widget.eventID,
                                                      ),
                                                    );
                                                  }
                                                },
                                                activeColor:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                activeTrackColor:
                                                    FlutterFlowTheme.of(context)
                                                        .coachSmartGreen,
                                                inactiveTrackColor:
                                                    FlutterFlowTheme.of(context)
                                                        .coachSmartGrey,
                                                inactiveThumbColor:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'Notify the team admins when a member changes their attendance from accepted to declined or declined to accepted only',
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
                                        Divider(
                                          thickness: 1.0,
                                          color: Color(0xFF5A5A5A),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Notify admins of ALL attendance changes',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
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
                                                          fontSize:
                                                              isWeb == true
                                                                  ? 14.0
                                                                  : 16.0,
                                                          letterSpacing: 0.0,
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
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Switch.adaptive(
                                              value:
                                                  _model.switchAllChangesValue!,
                                              onChanged: (newValue) async {
                                                safeSetState(() => _model
                                                        .switchAllChangesValue =
                                                    newValue);
                                                if (newValue) {
                                                  logFirebaseEvent(
                                                      'ADMIN_OPTIONS_switchAllChanges_ON_TOGGLE');
                                                  logFirebaseEvent(
                                                      'switchAllChanges_backend_call');
                                                  await EventsTable().update(
                                                    data: {
                                                      'notify_admins_all': true,
                                                    },
                                                    matchingRows: (rows) =>
                                                        rows.eqOrNull(
                                                      'event_id',
                                                      widget.eventID,
                                                    ),
                                                  );
                                                } else {
                                                  logFirebaseEvent(
                                                      'ADMIN_OPTIONS_switchAllChanges_ON_TOGGLE');
                                                  logFirebaseEvent(
                                                      'switchAllChanges_backend_call');
                                                  await EventsTable().update(
                                                    data: {
                                                      'notify_admins_all':
                                                          false,
                                                    },
                                                    matchingRows: (rows) =>
                                                        rows.eqOrNull(
                                                      'event_id',
                                                      widget.eventID,
                                                    ),
                                                  );
                                                }
                                              },
                                              activeColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                              activeTrackColor:
                                                  FlutterFlowTheme.of(context)
                                                      .coachSmartGreen,
                                              inactiveTrackColor:
                                                  FlutterFlowTheme.of(context)
                                                      .coachSmartGrey,
                                              inactiveThumbColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                          ],
                                        ),
                                        Text(
                                          'Notify the team admins of ALL attendance updates. When a member accepts, declines or changes their attendance status',
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
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ].divide(SizedBox(height: 5.0)),
                      ),
                    ),
                  ),
                  if (FFAppState().eventAdminDetail.carPoolingAllowed == true)
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(15.0, 0.0, 15.0, 0.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Car Pooling',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  fontSize: 18.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 10.0, 0.0, 0.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Switch on Car Pooling for this event',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
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
                                Switch.adaptive(
                                  value: _model.switchCarPoolValue!,
                                  onChanged: (newValue) async {
                                    safeSetState(() =>
                                        _model.switchCarPoolValue = newValue);
                                    if (newValue) {
                                      logFirebaseEvent(
                                          'ADMIN_OPTIONS_switchCarPool_ON_TOGGLE_ON');
                                      logFirebaseEvent(
                                          'switchCarPool_backend_call');
                                      await EventsTable().update(
                                        data: {
                                          'car_pooling': true,
                                        },
                                        matchingRows: (rows) => rows.eqOrNull(
                                          'event_id',
                                          widget.eventID,
                                        ),
                                      );
                                      logFirebaseEvent(
                                          'switchCarPool_update_app_state');
                                      FFAppState().showCarPool = true;
                                      FFAppState().update(() {});
                                    } else {
                                      logFirebaseEvent(
                                          'ADMIN_OPTIONS_switchCarPool_ON_TOGGLE_OF');
                                      logFirebaseEvent(
                                          'switchCarPool_backend_call');
                                      await EventsTable().update(
                                        data: {
                                          'car_pooling': false,
                                        },
                                        matchingRows: (rows) => rows.eqOrNull(
                                          'event_id',
                                          widget.eventID,
                                        ),
                                      );
                                      logFirebaseEvent(
                                          'switchCarPool_update_app_state');
                                      FFAppState().showCarPool = false;
                                      FFAppState().update(() {});
                                    }
                                  },
                                  activeColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  activeTrackColor: FlutterFlowTheme.of(context)
                                      .coachSmartGreen,
                                  inactiveTrackColor:
                                      FlutterFlowTheme.of(context)
                                          .coachSmartGrey,
                                  inactiveThumbColor:
                                      FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                ),
                              ],
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
