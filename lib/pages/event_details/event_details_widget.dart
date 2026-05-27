import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/components/drop_down_menu_edit_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'dart:async';
import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'event_details_model.dart';
export 'event_details_model.dart';

class EventDetailsWidget extends StatefulWidget {
  const EventDetailsWidget({
    super.key,
    required this.eventID,
    required this.fromSearch,
  });

  final int? eventID;
  final bool? fromSearch;

  static String routeName = 'EventDetails';
  static String routePath = 'eventDetails';

  @override
  State<EventDetailsWidget> createState() => _EventDetailsWidgetState();
}

class _EventDetailsWidgetState extends State<EventDetailsWidget> {
  late EventDetailsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EventDetailsModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'EventDetails'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('EVENT_DETAILS_EventDetails_ON_INIT_STATE');
      logFirebaseEvent('EventDetails_backend_call');
      _model.apiEventDetails = await GetUserEventDetailsCall.call(
        pEventId: widget.eventID,
        pUserId: currentUserUid,
        supabaseJWTtoken: currentJwtToken,
      );

      logFirebaseEvent('EventDetails_update_app_state');
      FFAppState().userEventDetails = UserEventDetailsStruct.maybeFromMap(
          (_model.apiEventDetails?.jsonBody ?? ''))!;
      safeSetState(() {});
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

    return FutureBuilder<ApiCallResponse>(
      future: (_model.apiRequestCompleter ??= Completer<ApiCallResponse>()
            ..complete(GetUserEventDetailsCall.call(
              pEventId: widget.eventID,
              pUserId: currentUserUid,
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
        final eventDetailsGetUserEventDetailsResponse = snapshot.data!;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).coachSmartMidBlack,
            appBar: AppBar(
              backgroundColor: FlutterFlowTheme.of(context).coachSmartMidBlack,
              automaticallyImplyLeading: false,
              leading: FlutterFlowIconButton(
                borderColor: Colors.transparent,
                borderRadius: 30.0,
                borderWidth: 1.0,
                buttonSize: 60.0,
                icon: Icon(
                  Icons.keyboard_backspace,
                  color: Color(0xFF87C232),
                  size: 30.0,
                ),
                onPressed: () async {
                  logFirebaseEvent('EVENT_DETAILS_keyboard_backspace_ICN_ON_');
                  if (widget.fromSearch == true) {
                    logFirebaseEvent('IconButton_navigate_back');
                    context.safePop();
                  } else {
                    logFirebaseEvent('IconButton_backend_call');
                    _model.outputUpdatedEvents =
                        await GetUserHomeEventsCall.call(
                      pUserId: currentUserUid,
                      supabaseJWTtoken: currentJwtToken,
                    );

                    logFirebaseEvent('IconButton_update_app_state');
                    FFAppState().homePageEvents =
                        UserEventsHomeStruct.maybeFromMap(
                            (_model.outputUpdatedEvents?.jsonBody ?? ''))!;
                    logFirebaseEvent('IconButton_navigate_back');
                    context.safePop();
                  }

                  safeSetState(() {});
                },
              ),
              title: Text(
                valueOrDefault<String>(
                  UserEventDetailsStruct.maybeFromMap(
                          eventDetailsGetUserEventDetailsResponse.jsonBody)
                      ?.eventTitle,
                  'event_title',
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
                      color: FlutterFlowTheme.of(context).alternate,
                      fontSize: 18.0,
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
              ),
              actions: [
                Visibility(
                  visible: UserEventDetailsStruct.maybeFromMap(
                              eventDetailsGetUserEventDetailsResponse.jsonBody)!
                          .userHighestRoleLevel >=
                      100,
                  child: Builder(
                    builder: (context) => Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 5.0, 0.0),
                      child: FlutterFlowIconButton(
                        borderRadius: 8.0,
                        buttonSize: 40.0,
                        fillColor:
                            FlutterFlowTheme.of(context).coachSmartMidBlack,
                        icon: Icon(
                          Icons.more_vert_sharp,
                          color: FlutterFlowTheme.of(context).coachSmartGreen,
                          size: 24.0,
                        ),
                        onPressed: () async {
                          logFirebaseEvent(
                              'EVENT_DETAILS_more_vert_sharp_ICN_ON_TAP');
                          logFirebaseEvent('IconButton_alert_dialog');
                          await showAlignedDialog(
                            context: context,
                            isGlobal: false,
                            avoidOverflow: true,
                            targetAnchor: AlignmentDirectional(0.0, 0.0)
                                .resolve(Directionality.of(context)),
                            followerAnchor: AlignmentDirectional(1.0, -1.0)
                                .resolve(Directionality.of(context)),
                            builder: (dialogContext) {
                              return Material(
                                color: Colors.transparent,
                                child: WebViewAware(
                                  child: GestureDetector(
                                    onTap: () {
                                      FocusScope.of(dialogContext).unfocus();
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                    },
                                    child: DropDownMenuEditWidget(
                                      paramEventID:
                                          UserEventDetailsStruct.maybeFromMap(
                                                  eventDetailsGetUserEventDetailsResponse
                                                      .jsonBody)!
                                              .eventId,
                                      paramRoleLevel:
                                          UserEventDetailsStruct.maybeFromMap(
                                                  eventDetailsGetUserEventDetailsResponse
                                                      .jsonBody)!
                                              .userHighestRoleLevel,
                                      paramEventType:
                                          UserEventDetailsStruct.maybeFromMap(
                                                  eventDetailsGetUserEventDetailsResponse
                                                      .jsonBody)!
                                              .eventType,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
              centerTitle: true,
              elevation: 2.0,
            ),
            body: SafeArea(
              top: true,
              child: Visibility(
                visible: _model.apiEventDetails != null,
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(15.0, 0.0, 15.0, 0.0),
                  child: SingleChildScrollView(
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((widget.fromSearch == false) &&
                            (UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.requestAttendance ==
                                true))
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 10.0, 0.0, 0.0),
                            child: Builder(
                              builder: (context) {
                                final dynamicMembers = UserEventDetailsStruct
                                            .maybeFromMap(
                                                eventDetailsGetUserEventDetailsResponse
                                                    .jsonBody)
                                        ?.teamMembers
                                        .where((e) =>
                                            e.roleLevel >=
                                            UserEventDetailsStruct.maybeFromMap(
                                                    eventDetailsGetUserEventDetailsResponse
                                                        .jsonBody)!
                                                .eventRoleLevel)
                                        .toList()
                                        .sortedList(
                                            keyOf: (e) => e.roleLevel,
                                            desc: false)
                                        .toList() ??
                                    [];

                                return Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: List.generate(dynamicMembers.length,
                                      (dynamicMembersIndex) {
                                    final dynamicMembersItem =
                                        dynamicMembers[dynamicMembersIndex];
                                    return Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: FFButtonWidget(
                                            onPressed: () async {
                                              logFirebaseEvent(
                                                  'EVENT_DETAILS_PAGE_acceptButton_ON_TAP');
                                              logFirebaseEvent(
                                                  'acceptButton_backend_call');
                                              _model.outputInsertRow =
                                                  await EventAttendanceTable()
                                                      .insert({
                                                'event_id': widget.eventID,
                                                'member_id':
                                                    dynamicMembersItem.memberId,
                                                'response_id': 3,
                                              });
                                              logFirebaseEvent(
                                                  'acceptButton_refresh_database_request');
                                              safeSetState(() => _model
                                                  .apiRequestCompleter = null);
                                              await _model
                                                  .waitForApiRequestCompleted();
                                              logFirebaseEvent(
                                                  'acceptButton_backend_call');
                                              _model.apiEventDetailsAccept =
                                                  await GetUserEventDetailsCall
                                                      .call(
                                                pEventId: widget.eventID,
                                                pUserId: currentUserUid,
                                                supabaseJWTtoken:
                                                    currentJwtToken,
                                              );

                                              logFirebaseEvent(
                                                  'acceptButton_update_app_state');
                                              FFAppState().userEventDetails =
                                                  UserEventDetailsStruct
                                                      .maybeFromMap((_model
                                                              .apiEventDetailsAccept
                                                              ?.jsonBody ??
                                                          ''))!;
                                              safeSetState(() {});
                                              logFirebaseEvent(
                                                  'acceptButton_backend_call');
                                              _model.apiResultiwz2A =
                                                  await NotifyAdminsAttendanceChangeCall
                                                      .call(
                                                supabaseJWTtoken:
                                                    currentJwtToken,
                                                pMemberIdParam:
                                                    dynamicMembersItem.memberId,
                                                pEventIdParam:
                                                    UserEventDetailsStruct
                                                            .maybeFromMap(
                                                                eventDetailsGetUserEventDetailsResponse
                                                                    .jsonBody)
                                                        ?.eventId,
                                                pResponseId: 3,
                                                pAttendanceId: _model
                                                    .outputInsertRow
                                                    ?.attendanceId,
                                              );

                                              safeSetState(() {});
                                            },
                                            text: '${valueOrDefault<String>(
                                              dynamicMembersItem.firstName,
                                              'first_name',
                                            )}${dynamicMembersItem.memberPaid == 1 ? ' €' : ''}',
                                            icon: Icon(
                                              Icons.check,
                                              size: 24.0,
                                            ),
                                            options: FFButtonOptions(
                                              height: 40.0,
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      16.0, 0.0, 16.0, 0.0),
                                              iconPadding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              iconColor: dynamicMembersItem
                                                          .responseId ==
                                                      3
                                                  ? FlutterFlowTheme.of(context)
                                                      .primaryText
                                                  : FlutterFlowTheme.of(context)
                                                      .coachSmartGrey,
                                              color: dynamicMembersItem
                                                          .responseId ==
                                                      3
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
                                                    color: dynamicMembersItem
                                                                .responseId ==
                                                            3
                                                        ? FlutterFlowTheme.of(
                                                                context)
                                                            .primaryText
                                                        : FlutterFlowTheme.of(
                                                                context)
                                                            .coachSmartGrey,
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
                                              borderSide: BorderSide(
                                                color: dynamicMembersItem
                                                            .responseId ==
                                                        3
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .coachSmartGreen
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .coachSmartGrey,
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                            showLoadingIndicator: false,
                                          ),
                                        ),
                                        Expanded(
                                          child: FFButtonWidget(
                                            onPressed: () async {
                                              logFirebaseEvent(
                                                  'EVENT_DETAILS_PAGE_declineButton_ON_TAP');
                                              logFirebaseEvent(
                                                  'declineButton_backend_call');
                                              _model.outputInsertRow1 =
                                                  await EventAttendanceTable()
                                                      .insert({
                                                'event_id': widget.eventID,
                                                'member_id':
                                                    dynamicMembersItem.memberId,
                                                'response_id': 4,
                                              });
                                              logFirebaseEvent(
                                                  'declineButton_refresh_database_request');
                                              safeSetState(() => _model
                                                  .apiRequestCompleter = null);
                                              await _model
                                                  .waitForApiRequestCompleted();
                                              logFirebaseEvent(
                                                  'declineButton_backend_call');
                                              _model.apiEventDetailsDecline =
                                                  await GetUserEventDetailsCall
                                                      .call(
                                                pEventId: widget.eventID,
                                                pUserId: currentUserUid,
                                                supabaseJWTtoken:
                                                    currentJwtToken,
                                              );

                                              logFirebaseEvent(
                                                  'declineButton_update_app_state');
                                              FFAppState().userEventDetails =
                                                  UserEventDetailsStruct
                                                      .maybeFromMap((_model
                                                              .apiEventDetailsDecline
                                                              ?.jsonBody ??
                                                          ''))!;
                                              safeSetState(() {});
                                              logFirebaseEvent(
                                                  'declineButton_backend_call');
                                              _model.apiResultiwz2B =
                                                  await NotifyAdminsAttendanceChangeCall
                                                      .call(
                                                supabaseJWTtoken:
                                                    currentJwtToken,
                                                pMemberIdParam:
                                                    dynamicMembersItem.memberId,
                                                pEventIdParam:
                                                    UserEventDetailsStruct
                                                            .maybeFromMap(
                                                                eventDetailsGetUserEventDetailsResponse
                                                                    .jsonBody)
                                                        ?.eventId,
                                                pResponseId: 4,
                                                pAttendanceId: _model
                                                    .outputInsertRow1
                                                    ?.attendanceId,
                                              );

                                              safeSetState(() {});
                                            },
                                            text: valueOrDefault<String>(
                                              dynamicMembersItem.firstName,
                                              'first_name',
                                            ),
                                            icon: Icon(
                                              Icons.clear,
                                              size: 24.0,
                                            ),
                                            options: FFButtonOptions(
                                              height: 40.0,
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      16.0, 0.0, 16.0, 0.0),
                                              iconPadding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 0.0, 0.0),
                                              iconColor: dynamicMembersItem
                                                          .responseId ==
                                                      4
                                                  ? FlutterFlowTheme.of(context)
                                                      .coachSmartGrey
                                                  : FlutterFlowTheme.of(context)
                                                      .coachSmartGrey,
                                              color: dynamicMembersItem
                                                          .responseId ==
                                                      4
                                                  ? Color(0xFF92010B)
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
                                                    color: dynamicMembersItem
                                                                .responseId ==
                                                            4
                                                        ? FlutterFlowTheme.of(
                                                                context)
                                                            .coachSmartGrey
                                                        : FlutterFlowTheme.of(
                                                                context)
                                                            .coachSmartGrey,
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
                                              borderSide: BorderSide(
                                                color: dynamicMembersItem
                                                            .responseId ==
                                                        4
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .coachSmartGrey,
                                                width: 1.0,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                            showLoadingIndicator: false,
                                          ),
                                        ),
                                      ].divide(SizedBox(width: 15.0)),
                                    );
                                  }).divide(SizedBox(height: 8.0)),
                                );
                              },
                            ),
                          ),
                        Divider(
                          thickness: 1.0,
                          color: Color(0xFF585757),
                        ),
                        if (UserEventDetailsStruct.maybeFromMap(
                                    eventDetailsGetUserEventDetailsResponse
                                        .jsonBody)
                                ?.paymentRequired ==
                            true)
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 10.0, 0.0, 10.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: FFButtonWidget(
                                        onPressed: () async {
                                          logFirebaseEvent(
                                              'EVENT_DETAILS_PAGE_payNowButton_ON_TAP');
                                          if (UserEventDetailsStruct.maybeFromMap(
                                                      eventDetailsGetUserEventDetailsResponse
                                                          .jsonBody)!
                                                  .teamMembers
                                                  .where((e) =>
                                                      (e.responseId == 3) &&
                                                      (e.roleLevel == 10) &&
                                                      (e.memberPaid != 1))
                                                  .toList()
                                                  .length >
                                              0) {
                                            logFirebaseEvent(
                                                'payNowButton_update_page_state');
                                            _model.payingMembers = [];
                                            logFirebaseEvent(
                                                'payNowButton_update_page_state');
                                            _model.payingMemberIds = [];
                                            for (int loop1Index = 0;
                                                loop1Index <
                                                    UserEventDetailsStruct
                                                            .maybeFromMap(
                                                                eventDetailsGetUserEventDetailsResponse
                                                                    .jsonBody)!
                                                        .teamMembers
                                                        .where((e) =>
                                                            (e
                                                                    .roleLevel ==
                                                                10) &&
                                                            (e.responseId ==
                                                                3) &&
                                                            (e.memberPaymentStatus !=
                                                                'confirmed'))
                                                        .toList()
                                                        .length;
                                                loop1Index++) {
                                              final currentLoop1Item =
                                                  UserEventDetailsStruct
                                                          .maybeFromMap(
                                                              eventDetailsGetUserEventDetailsResponse
                                                                  .jsonBody)!
                                                      .teamMembers
                                                      .where((e) =>
                                                          (e.roleLevel == 10) &&
                                                          (e.responseId == 3) &&
                                                          (e.memberPaymentStatus !=
                                                              'confirmed'))
                                                      .toList()[loop1Index];
                                              logFirebaseEvent(
                                                  'payNowButton_update_page_state');
                                              _model.addToPayingMembers(
                                                  TeamMembersStruct
                                                          .maybeFromMap(
                                                              currentLoop1Item
                                                                  .toMap())!
                                                      .toMap());
                                              logFirebaseEvent(
                                                  'payNowButton_update_page_state');
                                              _model.addToPayingMemberIds(
                                                  currentLoop1Item.memberId);
                                            }
                                            logFirebaseEvent(
                                                'payNowButton_custom_action');
                                            _model.outputSupabaseToken =
                                                await actions
                                                    .fetchSupabaseAccessToken();
                                            logFirebaseEvent(
                                                'payNowButton_backend_call');
                                            _model.outputCheckoutUrl =
                                                await CreateCheckoutSessionVersionTwoCall
                                                    .call(
                                              supabaseAccessToken:
                                                  _model.outputSupabaseToken,
                                              appEventID: widget.eventID,
                                              appUserID: currentUserUid,
                                              productName: UserEventDetailsStruct
                                                      .maybeFromMap(
                                                          eventDetailsGetUserEventDetailsResponse
                                                              .jsonBody)
                                                  ?.eventTitle,
                                              amount: UserEventDetailsStruct.maybeFromMap(
                                                          eventDetailsGetUserEventDetailsResponse
                                                              .jsonBody)!
                                                      .paymentAmount *
                                                  (UserEventDetailsStruct.maybeFromMap(
                                                              eventDetailsGetUserEventDetailsResponse
                                                                  .jsonBody)!
                                                          .teamMembers
                                                          .where((e) =>
                                                              (e.responseId ==
                                                                  3) &&
                                                              (e.roleLevel ==
                                                                  10))
                                                          .toList()
                                                          .length -
                                                      UserEventDetailsStruct.maybeFromMap(
                                                              eventDetailsGetUserEventDetailsResponse
                                                                  .jsonBody)!
                                                          .teamMembers
                                                          .where((e) => e.memberPaid == 1)
                                                          .toList()
                                                          .length),
                                              appSuccessUrl:
                                                  'https://my.coachsmart.app/checkoutSuccess',
                                              appCancelUrl:
                                                  'https://my.coachsmart.app/cehckoutFailed',
                                              memberIdsList:
                                                  _model.payingMemberIds,
                                              unitPrice: UserEventDetailsStruct
                                                      .maybeFromMap(
                                                          eventDetailsGetUserEventDetailsResponse
                                                              .jsonBody)
                                                  ?.paymentAmount,
                                            );

                                            logFirebaseEvent(
                                                'payNowButton_navigate_to');

                                            context.pushNamed(
                                              CheckoutWidget.routeName,
                                              queryParameters: {
                                                'paramEventId': serializeParam(
                                                  widget.eventID,
                                                  ParamType.int,
                                                ),
                                                'paramNumPayments':
                                                    serializeParam(
                                                  UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)!
                                                          .teamMembers
                                                          .where((e) =>
                                                              (e.responseId ==
                                                                  3) &&
                                                              (e.roleLevel ==
                                                                  10))
                                                          .toList()
                                                          .length -
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)!
                                                          .eventPaid,
                                                  ParamType.int,
                                                ),
                                                'paramPaymentAmount':
                                                    serializeParam(
                                                  UserEventDetailsStruct
                                                          .maybeFromMap(
                                                              eventDetailsGetUserEventDetailsResponse
                                                                  .jsonBody)
                                                      ?.paymentAmount,
                                                  ParamType.int,
                                                ),
                                                'paramCheckoutUrl':
                                                    serializeParam(
                                                  StripeCheckoutStruct
                                                          .maybeFromMap((_model
                                                                  .outputCheckoutUrl
                                                                  ?.jsonBody ??
                                                              ''))
                                                      ?.checkoutUrl,
                                                  ParamType.String,
                                                ),
                                                'paramPayingMembers':
                                                    serializeParam(
                                                  _model.payingMembers,
                                                  ParamType.JSON,
                                                  isList: true,
                                                ),
                                              }.withoutNulls,
                                            );
                                          } else {
                                            if (UserEventDetailsStruct.maybeFromMap(
                                                        eventDetailsGetUserEventDetailsResponse
                                                            .jsonBody)!
                                                    .teamMembers
                                                    .where((e) =>
                                                        (e.responseId == 3) &&
                                                        (e.roleLevel == 10))
                                                    .toList()
                                                    .length >
                                                0) {
                                              logFirebaseEvent(
                                                  'payNowButton_show_snack_bar');
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'You have paid all of the necessary payments already',
                                                    style: TextStyle(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  duration: Duration(
                                                      milliseconds: 4000),
                                                  backgroundColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .error,
                                                ),
                                              );
                                            } else {
                                              logFirebaseEvent(
                                                  'payNowButton_show_snack_bar');
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'You need to accept for a player before you can pay',
                                                    style: TextStyle(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  duration: Duration(
                                                      milliseconds: 4000),
                                                  backgroundColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .error,
                                                ),
                                              );
                                            }
                                          }

                                          safeSetState(() {});
                                        },
                                        text:
                                            'Checkout (${(int varToPay, int varAmount) {
                                          return "€" +
                                              ((varToPay * varAmount) / 100)
                                                  .toStringAsFixed(2);
                                        }(UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.teamMembers.where((e) => (e.responseId == 3) && (e.roleLevel == 10) && (e.memberPaid != 1)).toList().length, UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.paymentAmount)})',
                                        icon: Icon(
                                          Icons.shopping_cart_checkout,
                                          size: 24.0,
                                        ),
                                        options: FFButtonOptions(
                                          width: 170.0,
                                          height: 40.0,
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          iconPadding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 0.0, 0.0),
                                          color: FlutterFlowTheme.of(context)
                                              .coachSmartLightBlack,
                                          textStyle: FlutterFlowTheme.of(
                                                  context)
                                              .titleSmall
                                              .override(
                                                font: GoogleFonts.interTight(
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
                                                    FlutterFlowTheme.of(context)
                                                        .coachSmartGreen,
                                                fontSize:
                                                    isWeb == true ? 16.0 : 18.0,
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
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .coachSmartGreen,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                thickness: 1.0,
                                color: Color(0xFF585757),
                              ),
                            ],
                          ),
                        if ((UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.carPoolingEnabled ==
                                true) ||
                            (FFAppState().showCarPool == true))
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 10.0, 0.0, 10.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: FFButtonWidget(
                                        onPressed: () async {
                                          logFirebaseEvent(
                                              'EVENT_DETAILS_PAGE_payNowButton_ON_TAP');
                                          logFirebaseEvent(
                                              'payNowButton_navigate_to');

                                          context.pushNamed(
                                            CreateCarPoolWidget.routeName,
                                            queryParameters: {
                                              'paramEventID': serializeParam(
                                                widget.eventID,
                                                ParamType.int,
                                              ),
                                              'paramRoleLevel': serializeParam(
                                                UserEventDetailsStruct.maybeFromMap(
                                                        eventDetailsGetUserEventDetailsResponse
                                                            .jsonBody)
                                                    ?.userHighestRoleLevel,
                                                ParamType.int,
                                              ),
                                            }.withoutNulls,
                                          );
                                        },
                                        text: 'Car Pooling',
                                        icon: FaIcon(
                                          FontAwesomeIcons.carSide,
                                          size: 20.0,
                                        ),
                                        options: FFButtonOptions(
                                          width: 170.0,
                                          height: 40.0,
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          iconPadding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 0.0, 0.0),
                                          color: FlutterFlowTheme.of(context)
                                              .coachSmartLightBlack,
                                          textStyle: FlutterFlowTheme.of(
                                                  context)
                                              .titleSmall
                                              .override(
                                                font: GoogleFonts.interTight(
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
                                                    FlutterFlowTheme.of(context)
                                                        .coachSmartGreen,
                                                fontSize:
                                                    isWeb == true ? 16.0 : 18.0,
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
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .coachSmartGreen,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                thickness: 1.0,
                                color: Color(0xFF585757),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    valueOrDefault<String>(
                                      FFAppState().userEventDetails.eventTitle,
                                      'event_title',
                                    ),
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
                                          fontSize: isWeb == true ? 16.0 : 18.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                  Text(
                                    valueOrDefault<String>(
                                      FFAppState()
                                          .userEventDetails
                                          .eventDateTimeFormatted,
                                      'event_date_time',
                                    ),
                                    textAlign: TextAlign.start,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .coachSmartGrey,
                                          fontSize: isWeb == true ? 15.0 : 17.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          thickness: 1.0,
                          color: Color(0xFF585757),
                        ),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            logFirebaseEvent(
                                'EVENT_DETAILS_PAGE_Row_2jgov414_ON_TAP');
                            logFirebaseEvent('Row_launch_map');
                            await launchMap(
                              address: valueOrDefault<String>(
                                FFAppState().userEventDetails.locationPin,
                                'location_pin',
                              ),
                              title: FFAppState().userEventDetails.locationName,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Location',
                                      textAlign: TextAlign.start,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .coachSmartGrey,
                                            fontSize:
                                                isWeb == true ? 15.0 : 17.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    Text(
                                      valueOrDefault<String>(
                                        FFAppState()
                                            .userEventDetails
                                            .locationName,
                                        'location_name',
                                      ),
                                      textAlign: TextAlign.start,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            fontSize:
                                                isWeb == true ? 16.0 : 18.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.location_on,
                                color: FlutterFlowTheme.of(context)
                                    .coachSmartGreen,
                                size: 25.0,
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          thickness: 1.0,
                          color: Color(0xFF585757),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  valueOrDefault<String>(
                                    FFAppState().userEventDetails.createdBy,
                                    'created_by',
                                  ),
                                  textAlign: TextAlign.start,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.normal,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .coachSmartGrey,
                                        fontSize: isWeb == true ? 15.0 : 17.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.normal,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                                Text(
                                  valueOrDefault<String>(
                                    FFAppState()
                                        .userEventDetails
                                        .createdByPhoneNumber,
                                    'phone_number',
                                  ),
                                  textAlign: TextAlign.start,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.normal,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        fontSize: isWeb == true ? 16.0 : 18.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.normal,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Icon(
                                  Icons.three_p_outlined,
                                  color: FlutterFlowTheme.of(context)
                                      .coachSmartGreen,
                                  size: 25.0,
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 0.0, 0.0, 0.0),
                                  child: Icon(
                                    Icons.phone,
                                    color: FlutterFlowTheme.of(context)
                                        .coachSmartGreen,
                                    size: 25.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Divider(
                          thickness: 1.0,
                          color: Color(0xFF585757),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 10.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Type:',
                                    textAlign: TextAlign.start,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          fontSize: isWeb == true ? 16.0 : 18.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                              Text(
                                valueOrDefault<String>(
                                  FFAppState().userEventDetails.eventType,
                                  'event_type',
                                ),
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.normal,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .coachSmartGrey,
                                      fontSize: isWeb == true ? 16.0 : 18.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 10.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Code:',
                                    textAlign: TextAlign.start,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          fontSize: isWeb == true ? 16.0 : 18.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                              Text(
                                valueOrDefault<String>(
                                  FFAppState().userEventDetails.eventCode,
                                  'event_code',
                                ),
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.normal,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .coachSmartGrey,
                                      fontSize: isWeb == true ? 16.0 : 18.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.opposition !=
                                null &&
                            UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.opposition !=
                                '')
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 10.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Opposition:',
                                      textAlign: TextAlign.start,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            fontSize:
                                                isWeb == true ? 16.0 : 18.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Text(
                                      valueOrDefault<String>(
                                        FFAppState()
                                            .userEventDetails
                                            .opposition,
                                        'opposition',
                                      ).maybeHandleOverflow(
                                        maxChars: 30,
                                        replacement: '…',
                                      ),
                                      textAlign: TextAlign.start,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .coachSmartGrey,
                                            fontSize:
                                                isWeb == true ? 16.0 : 18.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                  ],
                                ),
                              ].divide(SizedBox(width: 5.0)),
                            ),
                          ),
                        if (UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.meetTime !=
                                null &&
                            UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.meetTime !=
                                '')
                          Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Meeting Time:',
                                    textAlign: TextAlign.start,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          fontSize: isWeb == true ? 16.0 : 18.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      valueOrDefault<String>(
                                        FFAppState().userEventDetails.meetTime,
                                        'meet_time',
                                      ),
                                      textAlign: TextAlign.end,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .coachSmartGrey,
                                            fontSize:
                                                isWeb == true ? 16.0 : 18.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ].divide(SizedBox(width: 5.0)),
                          ),
                        Divider(
                          thickness: 1.0,
                          color: Color(0xFF585757),
                        ),
                        if (UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.eventLink !=
                                null &&
                            UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.eventLink !=
                                '')
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              logFirebaseEvent(
                                  'EVENT_DETAILS_Column_cy0opkl4_ON_TAP');
                              logFirebaseEvent('Column_launch_u_r_l');
                              await launchURL(valueOrDefault<String>(
                                FFAppState().userEventDetails.eventLink,
                                'event_link',
                              ));
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 5.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Event Link:',
                                        textAlign: TextAlign.start,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.normal,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              fontSize:
                                                  isWeb == true ? 16.0 : 18.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 5.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.link,
                                        color: FlutterFlowTheme.of(context)
                                            .coachSmartGreen,
                                        size: 24.0,
                                      ),
                                      Flexible(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Text(
                                              valueOrDefault<String>(
                                                FFAppState()
                                                    .userEventDetails
                                                    .eventLink,
                                                'event_link',
                                              ),
                                              textAlign: TextAlign.start,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .coachSmartGrey,
                                                        fontSize: 14.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
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
                                    ].divide(SizedBox(width: 5.0)),
                                  ),
                                ),
                                Divider(
                                  thickness: 1.0,
                                  color: Color(0xFF585757),
                                ),
                              ],
                            ),
                          ),
                        if (UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.eventImage !=
                                null &&
                            UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.eventImage !=
                                '')
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              logFirebaseEvent(
                                  'EVENT_DETAILS_Column_odtz01r0_ON_TAP');
                              logFirebaseEvent('Column_launch_u_r_l');
                              await launchURL(
                                  UserEventDetailsStruct.maybeFromMap(
                                          eventDetailsGetUserEventDetailsResponse
                                              .jsonBody)!
                                      .eventLink);
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 10.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Event Image:',
                                        textAlign: TextAlign.start,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.normal,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              fontSize:
                                                  isWeb == true ? 16.0 : 18.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
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
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.network(
                                        UserEventDetailsStruct.maybeFromMap(
                                                eventDetailsGetUserEventDetailsResponse
                                                    .jsonBody)!
                                            .eventImage,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(
                                  thickness: 1.0,
                                  color: Color(0xFF585757),
                                ),
                              ],
                            ),
                          ),
                        if (UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.eventDetails !=
                                null &&
                            UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.eventDetails !=
                                '')
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 5.0),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Color(0xFF20291F),
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context)
                                      .coachSmartWhite,
                                  width: 0.5,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 5.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          10.0, 10.0, 0.0, 0.0),
                                      child: Text(
                                        'Event Details:',
                                        textAlign: TextAlign.start,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.normal,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              fontSize:
                                                  isWeb == true ? 15.0 : 17.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          10.0, 10.0, 10.0, 10.0),
                                      child: Text(
                                        valueOrDefault<String>(
                                          FFAppState()
                                              .userEventDetails
                                              .eventDetails,
                                          'event_details',
                                        ),
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if ((UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)!
                                    .userHighestRoleLevel >=
                                20) &&
                            (UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.requestAttendance ==
                                true))
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 5.0, 0.0, 5.0),
                                      child: Text(
                                        'Attendance',
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              fontSize:
                                                  isWeb == true ? 16.0 : 18.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(
                                  thickness: 1.0,
                                  color: Color(0xFF585757),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 10.0, 0.0, 10.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xFF1F291B),
                                            borderRadius:
                                                BorderRadius.circular(10.0),
                                          ),
                                          child: InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              logFirebaseEvent(
                                                  'EVENT_DETAILS_Column_hm4r4ldb_ON_TAP');
                                              if ((UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)!
                                                          .userHighestRoleLevel >=
                                                      100) &&
                                                  (UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamHasSquads ==
                                                      true)) {
                                                logFirebaseEvent(
                                                    'Column_navigate_to');

                                                context.pushNamed(
                                                  AttendeeListAdminsWidget
                                                      .routeName,
                                                  queryParameters: {
                                                    'eventID': serializeParam(
                                                      widget.eventID,
                                                      ParamType.int,
                                                    ),
                                                    'responseID':
                                                        serializeParam(
                                                      3,
                                                      ParamType.int,
                                                    ),
                                                    'teamID': serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamId,
                                                      ParamType.int,
                                                    ),
                                                    'eventRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.eventRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                    'userRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.userHighestRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                    'eventCodeId':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.codeId,
                                                      ParamType.int,
                                                    ),
                                                  }.withoutNulls,
                                                );
                                              } else {
                                                logFirebaseEvent(
                                                    'Column_navigate_to');

                                                context.pushNamed(
                                                  AttendeeListWidget.routeName,
                                                  queryParameters: {
                                                    'eventID': serializeParam(
                                                      widget.eventID,
                                                      ParamType.int,
                                                    ),
                                                    'responseID':
                                                        serializeParam(
                                                      3,
                                                      ParamType.int,
                                                    ),
                                                    'teamID': serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamId,
                                                      ParamType.int,
                                                    ),
                                                    'eventRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.eventRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                  }.withoutNulls,
                                                );
                                              }
                                            },
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 10.0, 0.0, 0.0),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'Attending',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .normal,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .coachSmartWhite,
                                                                  fontSize:
                                                                      isWeb ==
                                                                              true
                                                                          ? 14.0
                                                                          : 16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                    ].divide(
                                                        SizedBox(width: 10.0)),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      width: 25.0,
                                                      height: 25.0,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Color(0xFF6AB500),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Text(
                                                          valueOrDefault<
                                                              String>(
                                                            FFAppState()
                                                                .userEventDetails
                                                                .acceptedPlayerCount
                                                                .toString(),
                                                            '0',
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .coachSmartWhite,
                                                                fontSize: 28.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ].divide(
                                                      SizedBox(width: 10.0)),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    10.0),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Builder(
                                                              builder:
                                                                  (context) {
                                                                final childrenAccepted = FFAppState()
                                                                    .userEventDetails
                                                                    .acceptedAttendanceSummary
                                                                    .where((e) =>
                                                                        e.roleLevel !=
                                                                        10)
                                                                    .toList();

                                                                return ListView
                                                                    .separated(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  shrinkWrap:
                                                                      true,
                                                                  scrollDirection:
                                                                      Axis.vertical,
                                                                  itemCount:
                                                                      childrenAccepted
                                                                          .length,
                                                                  separatorBuilder: (_,
                                                                          __) =>
                                                                      SizedBox(
                                                                          height:
                                                                              3.0),
                                                                  itemBuilder:
                                                                      (context,
                                                                          childrenAcceptedIndex) {
                                                                    final childrenAcceptedItem =
                                                                        childrenAccepted[
                                                                            childrenAcceptedIndex];
                                                                    return Text(
                                                                      '${valueOrDefault<String>(
                                                                        childrenAcceptedItem
                                                                            .roleNamePlural,
                                                                        'role_name',
                                                                      )}: ${valueOrDefault<String>(
                                                                        childrenAcceptedItem
                                                                            .memberCount
                                                                            .toString(),
                                                                        'role_level',
                                                                      )}',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                            fontSize: isWeb == true
                                                                                ? 12.0
                                                                                : 14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                          ].divide(SizedBox(
                                                              height: 5.0)),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ].divide(SizedBox(height: 7.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xFF2E3238),
                                            borderRadius:
                                                BorderRadius.circular(10.0),
                                          ),
                                          child: InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              logFirebaseEvent(
                                                  'EVENT_DETAILS_Column_9ugm8zen_ON_TAP');
                                              if ((UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)!
                                                          .userHighestRoleLevel >=
                                                      100) &&
                                                  (UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamHasSquads ==
                                                      true)) {
                                                logFirebaseEvent(
                                                    'Column_navigate_to');

                                                context.pushNamed(
                                                  AttendeeListAdminsWidget
                                                      .routeName,
                                                  queryParameters: {
                                                    'eventID': serializeParam(
                                                      widget.eventID,
                                                      ParamType.int,
                                                    ),
                                                    'responseID':
                                                        serializeParam(
                                                      0,
                                                      ParamType.int,
                                                    ),
                                                    'teamID': serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamId,
                                                      ParamType.int,
                                                    ),
                                                    'eventRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.eventRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                    'userRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.userHighestRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                    'eventCodeId':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.codeId,
                                                      ParamType.int,
                                                    ),
                                                  }.withoutNulls,
                                                );
                                              } else {
                                                logFirebaseEvent(
                                                    'Column_navigate_to');

                                                context.pushNamed(
                                                  AttendeeListWidget.routeName,
                                                  queryParameters: {
                                                    'eventID': serializeParam(
                                                      widget.eventID,
                                                      ParamType.int,
                                                    ),
                                                    'responseID':
                                                        serializeParam(
                                                      0,
                                                      ParamType.int,
                                                    ),
                                                    'teamID': serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamId,
                                                      ParamType.int,
                                                    ),
                                                    'eventRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.eventRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                  }.withoutNulls,
                                                );
                                              }
                                            },
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 10.0, 0.0, 0.0),
                                                  child: Text(
                                                    'No Response',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .coachSmartWhite,
                                                          fontSize:
                                                              isWeb == true
                                                                  ? 14.0
                                                                  : 16.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      width: 20.0,
                                                      height: 20.0,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Color(0xFFBFBFBC),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Text(
                                                      valueOrDefault<String>(
                                                        FFAppState()
                                                            .userEventDetails
                                                            .noResponsePlayerCount
                                                            .toString(),
                                                        '0',
                                                      ),
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
                                                                .coachSmartWhite,
                                                            fontSize: 28.0,
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
                                                  ].divide(
                                                      SizedBox(width: 10.0)),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    10.0),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Builder(
                                                              builder:
                                                                  (context) {
                                                                final childrenNoResponse = FFAppState()
                                                                    .userEventDetails
                                                                    .noResponseAttendanceSummary
                                                                    .where((e) =>
                                                                        e.roleLevel !=
                                                                        10)
                                                                    .toList();

                                                                return ListView
                                                                    .separated(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  shrinkWrap:
                                                                      true,
                                                                  scrollDirection:
                                                                      Axis.vertical,
                                                                  itemCount:
                                                                      childrenNoResponse
                                                                          .length,
                                                                  separatorBuilder: (_,
                                                                          __) =>
                                                                      SizedBox(
                                                                          height:
                                                                              3.0),
                                                                  itemBuilder:
                                                                      (context,
                                                                          childrenNoResponseIndex) {
                                                                    final childrenNoResponseItem =
                                                                        childrenNoResponse[
                                                                            childrenNoResponseIndex];
                                                                    return Text(
                                                                      '${childrenNoResponseItem.roleNamePlural}: ${childrenNoResponseItem.memberCount.toString()}',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                            fontSize: isWeb == true
                                                                                ? 12.0
                                                                                : 14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                          ].divide(SizedBox(
                                                              height: 5.0)),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ].divide(SizedBox(height: 7.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Color(0xFF471911),
                                            borderRadius:
                                                BorderRadius.circular(10.0),
                                          ),
                                          child: InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              logFirebaseEvent(
                                                  'EVENT_DETAILS_Column_pholrsbl_ON_TAP');
                                              if ((UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)!
                                                          .userHighestRoleLevel >=
                                                      100) &&
                                                  (UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamHasSquads ==
                                                      true)) {
                                                logFirebaseEvent(
                                                    'Column_navigate_to');

                                                context.pushNamed(
                                                  AttendeeListAdminsWidget
                                                      .routeName,
                                                  queryParameters: {
                                                    'eventID': serializeParam(
                                                      widget.eventID,
                                                      ParamType.int,
                                                    ),
                                                    'responseID':
                                                        serializeParam(
                                                      4,
                                                      ParamType.int,
                                                    ),
                                                    'teamID': serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamId,
                                                      ParamType.int,
                                                    ),
                                                    'eventRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.eventRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                    'userRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.userHighestRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                    'eventCodeId':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.codeId,
                                                      ParamType.int,
                                                    ),
                                                  }.withoutNulls,
                                                );
                                              } else {
                                                logFirebaseEvent(
                                                    'Column_navigate_to');

                                                context.pushNamed(
                                                  AttendeeListWidget.routeName,
                                                  queryParameters: {
                                                    'eventID': serializeParam(
                                                      widget.eventID,
                                                      ParamType.int,
                                                    ),
                                                    'responseID':
                                                        serializeParam(
                                                      4,
                                                      ParamType.int,
                                                    ),
                                                    'teamID': serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.teamId,
                                                      ParamType.int,
                                                    ),
                                                    'eventRoleLevel':
                                                        serializeParam(
                                                      UserEventDetailsStruct
                                                              .maybeFromMap(
                                                                  eventDetailsGetUserEventDetailsResponse
                                                                      .jsonBody)
                                                          ?.eventRoleLevel,
                                                      ParamType.int,
                                                    ),
                                                  }.withoutNulls,
                                                );
                                              }
                                            },
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 10.0, 0.0, 0.0),
                                                  child: Text(
                                                    'Declined',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .coachSmartWhite,
                                                          fontSize:
                                                              isWeb == true
                                                                  ? 14.0
                                                                  : 16.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      width: 20.0,
                                                      height: 20.0,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Color(0xFFCC000D),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    Text(
                                                      valueOrDefault<String>(
                                                        FFAppState()
                                                            .userEventDetails
                                                            .declinedPlayerCount
                                                            .toString(),
                                                        '0',
                                                      ),
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
                                                                .coachSmartWhite,
                                                            fontSize: 28.0,
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
                                                  ].divide(
                                                      SizedBox(width: 10.0)),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    0.0,
                                                                    0.0,
                                                                    10.0),
                                                        child: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .start,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Builder(
                                                              builder:
                                                                  (context) {
                                                                final childrenDeclined = FFAppState()
                                                                    .userEventDetails
                                                                    .declinedAttendanceSummary
                                                                    .where((e) =>
                                                                        e.roleLevel !=
                                                                        10)
                                                                    .toList();

                                                                return ListView
                                                                    .separated(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  shrinkWrap:
                                                                      true,
                                                                  scrollDirection:
                                                                      Axis.vertical,
                                                                  itemCount:
                                                                      childrenDeclined
                                                                          .length,
                                                                  separatorBuilder: (_,
                                                                          __) =>
                                                                      SizedBox(
                                                                          height:
                                                                              3.0),
                                                                  itemBuilder:
                                                                      (context,
                                                                          childrenDeclinedIndex) {
                                                                    final childrenDeclinedItem =
                                                                        childrenDeclined[
                                                                            childrenDeclinedIndex];
                                                                    return Text(
                                                                      '${childrenDeclinedItem.roleNamePlural}: ${childrenDeclinedItem.memberCount.toString()}',
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                            fontSize: isWeb == true
                                                                                ? 12.0
                                                                                : 14.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                            ),
                                                          ].divide(SizedBox(
                                                              height: 5.0)),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ].divide(SizedBox(height: 7.0)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 10.0)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if ((UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)!
                                    .userHighestRoleLevel >=
                                100) &&
                            (UserEventDetailsStruct.maybeFromMap(
                                        eventDetailsGetUserEventDetailsResponse
                                            .jsonBody)
                                    ?.paymentRequired ==
                                true))
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 30.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 5.0, 0.0, 5.0),
                                      child: Text(
                                        'Payments',
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(
                                  thickness: 1.0,
                                  color: Color(0xFF585757),
                                ),
                                Container(
                                  width: double.infinity,
                                  constraints: BoxConstraints(
                                    maxWidth: 370.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .coachSmartMidBlack,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      0.0, 0.0, 0.0, 12.0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Total Balance',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .coachSmartGrey,
                                                                  fontSize:
                                                                      isWeb ==
                                                                              true
                                                                          ? 14.0
                                                                          : 16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                      Text(
                                                        (int varAmount) {
                                                          return "€" +
                                                              ((varAmount) /
                                                                      100)
                                                                  .toStringAsFixed(
                                                                      2);
                                                        }(UserEventDetailsStruct
                                                                .maybeFromMap(
                                                                    eventDetailsGetUserEventDetailsResponse
                                                                        .jsonBody)!
                                                            .newGrossAmount),
                                                        textAlign:
                                                            TextAlign.end,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .displaySmall
                                                                .override(
                                                                  font: GoogleFonts
                                                                      .interTight(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .displaySmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .displaySmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .alternate,
                                                                  fontSize:
                                                                      isWeb ==
                                                                              true
                                                                          ? 20.0
                                                                          : 22.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .displaySmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .displaySmall
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                      Text(
                                                        'Net: ${(int varNetAmount) {
                                                          return "€" +
                                                              ((varNetAmount) /
                                                                      100)
                                                                  .toStringAsFixed(
                                                                      2);
                                                        }(UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.newNetAmount)}',
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelMedium
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .coachSmartGrey,
                                                                  fontSize:
                                                                      isWeb ==
                                                                              true
                                                                          ? 14.0
                                                                          : 16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .fontStyle,
                                                                ),
                                                      ),
                                                    ].divide(
                                                        SizedBox(height: 4.0)),
                                                  ),
                                                  FFButtonWidget(
                                                    onPressed: () async {
                                                      logFirebaseEvent(
                                                          'EVENT_DETAILS_PAYMENT_DETAILS_BTN_ON_TAP');
                                                      logFirebaseEvent(
                                                          'Button_navigate_to');

                                                      context.pushNamed(
                                                        PaymentTransactionsWidget
                                                            .routeName,
                                                        queryParameters: {
                                                          'paramEventID':
                                                              serializeParam(
                                                            widget.eventID,
                                                            ParamType.int,
                                                          ),
                                                        }.withoutNulls,
                                                      );
                                                    },
                                                    text: 'Payment Details',
                                                    options: FFButtonOptions(
                                                      height: 36.0,
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
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .coachSmartGreen,
                                                      textStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                font:
                                                                    GoogleFonts
                                                                        .inter(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .fontStyle,
                                                                ),
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .coachSmartLightBlack,
                                                                fontSize:
                                                                    isWeb ==
                                                                            true
                                                                        ? 14.0
                                                                        : 16.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontStyle: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                              ),
                                                      elevation: 3.0,
                                                      borderSide: BorderSide(
                                                        color:
                                                            Colors.transparent,
                                                        width: 1.0,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12.0),
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
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      0.0, 12.0, 0.0, 12.0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Paid (${UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)?.newNumPayments.toString()}) vs Accepted (${UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)?.acceptedPlayerCount.toString()})',
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .labelMedium
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .labelMedium
                                                                              .fontStyle,
                                                                        ),
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .coachSmartGrey,
                                                                        fontSize: isWeb ==
                                                                                true
                                                                            ? 14.0
                                                                            : 16.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .labelMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .labelMedium
                                                                            .fontStyle,
                                                                      ),
                                                                ),
                                                                RichText(
                                                                  textScaler: MediaQuery.of(
                                                                          context)
                                                                      .textScaler,
                                                                  text:
                                                                      TextSpan(
                                                                    children: [
                                                                      TextSpan(
                                                                        text: (int
                                                                                varTotalPayments,
                                                                            int varTotalAccepted) {
                                                                          return varTotalAccepted == 0
                                                                              ? "0%"
                                                                              : (varTotalPayments / varTotalAccepted * 100.0).round().toString() + '%';
                                                                        }(UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.newNumPayments, UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.acceptedPlayerCount),
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              20.0,
                                                                        ),
                                                                      )
                                                                    ],
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .displaySmall
                                                                        .override(
                                                                          font:
                                                                              GoogleFonts.interTight(
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).displaySmall.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).displaySmall.fontStyle,
                                                                          ),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).alternate,
                                                                          fontSize: isWeb == true
                                                                              ? 20.0
                                                                              : 22.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .displaySmall
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .displaySmall
                                                                              .fontStyle,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ].divide(SizedBox(
                                                                  height: 5.0)),
                                                            ),
                                                          ],
                                                        ),
                                                        Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Expanded(
                                                                  child:
                                                                      Padding(
                                                                    padding: EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            8.0,
                                                                            0.0,
                                                                            0.0),
                                                                    child:
                                                                        LinearPercentIndicator(
                                                                      percent: ((UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.newNumPayments / UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.acceptedPlayerCount)) >
                                                                              1.0
                                                                          ? 1.0
                                                                          : ((UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.newNumPayments /
                                                                              UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!.acceptedPlayerCount)),
                                                                      lineHeight:
                                                                          12.0,
                                                                      animation:
                                                                          true,
                                                                      animateFromLastPercent:
                                                                          true,
                                                                      progressColor:
                                                                          FlutterFlowTheme.of(context)
                                                                              .coachSmartGreen,
                                                                      backgroundColor:
                                                                          Color(
                                                                              0xFF013801),
                                                                      barRadius:
                                                                          Radius.circular(
                                                                              16.0),
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          8.0,
                                                                          0.0,
                                                                          0.0),
                                                              child: RichText(
                                                                textScaler: MediaQuery.of(
                                                                        context)
                                                                    .textScaler,
                                                                text: TextSpan(
                                                                  children: [
                                                                    TextSpan(
                                                                      text:
                                                                          'Projected Total: ',
                                                                      style:
                                                                          TextStyle(),
                                                                    ),
                                                                    TextSpan(
                                                                      text: (int varAmount,
                                                                              int
                                                                                  varAccepted) {
                                                                        return "€" +
                                                                            (varAccepted == 0
                                                                                ? "0.00"
                                                                                : ((varAmount * varAccepted) / 100).toStringAsFixed(2));
                                                                      }(
                                                                          UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!
                                                                              .paymentAmount,
                                                                          UserEventDetailsStruct.maybeFromMap(eventDetailsGetUserEventDetailsResponse.jsonBody)!
                                                                              .acceptedPlayerCount),
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FontWeight.bold,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                    )
                                                                  ],
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelMedium
                                                                      .override(
                                                                        font: GoogleFonts
                                                                            .inter(
                                                                          fontWeight: FlutterFlowTheme.of(context)
                                                                              .labelMedium
                                                                              .fontWeight,
                                                                          fontStyle: FlutterFlowTheme.of(context)
                                                                              .labelMedium
                                                                              .fontStyle,
                                                                        ),
                                                                        fontSize: isWeb ==
                                                                                true
                                                                            ? 14.0
                                                                            : 16.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .labelMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .labelMedium
                                                                            .fontStyle,
                                                                      ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ].divide(SizedBox(
                                                          height: 4.0)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Divider(
                                              thickness: 1.0,
                                              color: Color(0xFF585757),
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
                      ],
                    ),
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
