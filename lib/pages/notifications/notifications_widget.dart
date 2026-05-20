import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/components/drop_down_menu_notifications_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'notifications_model.dart';
export 'notifications_model.dart';

class NotificationsWidget extends StatefulWidget {
  const NotificationsWidget({super.key});

  static String routeName = 'Notifications';
  static String routePath = 'notifications';

  @override
  State<NotificationsWidget> createState() => _NotificationsWidgetState();
}

class _NotificationsWidgetState extends State<NotificationsWidget> {
  late NotificationsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NotificationsModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'Notifications'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('NOTIFICATIONS_Notifications_ON_INIT_STAT');
      logFirebaseEvent('Notifications_update_page_state');
      _model.varReadFilter = false;
      safeSetState(() {});
      logFirebaseEvent('Notifications_backend_call');
      _model.apiUserNotifications = await GetUserNotificationsCall.call(
        pUserId: currentUserUid,
      );

      logFirebaseEvent('Notifications_update_app_state');
      FFAppState().userNotifications =
          ((_model.apiUserNotifications?.jsonBody ?? '')
                  .toList()
                  .map<UserNotificationsStruct?>(
                      UserNotificationsStruct.maybeFromMap)
                  .toList() as Iterable<UserNotificationsStruct?>)
              .withoutNulls
              .toList()
              .cast<UserNotificationsStruct>();
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
              logFirebaseEvent('NOTIFICATIONS_arrow_back_rounded_ICN_ON_');
              logFirebaseEvent('IconButton_backend_call');
              _model.outputUpdatedEvents = await GetUserHomeEventsCall.call(
                pUserId: currentUserUid,
                supabaseJWTtoken: currentJwtToken,
              );

              logFirebaseEvent('IconButton_update_app_state');
              FFAppState().homePageEvents = UserEventsHomeStruct.maybeFromMap(
                  (_model.outputUpdatedEvents?.jsonBody ?? ''))!;
              logFirebaseEvent('IconButton_navigate_back');
              context.safePop();

              safeSetState(() {});
            },
          ),
          title: Text(
            'Notifications',
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
            visible: _model.apiUserNotifications != null,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Padding(
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
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 0.0, 10.0, 0.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Flexible(
                                        child: FFButtonWidget(
                                          onPressed: () async {
                                            logFirebaseEvent(
                                                'NOTIFICATIONS_Button_vax1ww3y_ON_TAP');
                                            logFirebaseEvent(
                                                'Button_update_page_state');
                                            _model.varReadFilter = false;
                                            safeSetState(() {});
                                          },
                                          text:
                                              'Unread ( ${FFAppState().userNotifications.where((e) => e.isRead == false).toList().length.toString()} )',
                                          options: FFButtonOptions(
                                            padding: EdgeInsets.all(10.0),
                                            iconPadding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 0.0),
                                            color: _model.varReadFilter == false
                                                ? FlutterFlowTheme.of(context)
                                                    .coachSmartGreen
                                                : FlutterFlowTheme.of(context)
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
                                                  color: _model.varReadFilter ==
                                                          false
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
                                        ),
                                      ),
                                      Flexible(
                                        child: FFButtonWidget(
                                          onPressed: () async {
                                            logFirebaseEvent(
                                                'NOTIFICATIONS_PAGE_READ_BTN_ON_TAP');
                                            logFirebaseEvent(
                                                'Button_update_page_state');
                                            _model.varReadFilter = true;
                                            safeSetState(() {});
                                          },
                                          text: 'Read',
                                          options: FFButtonOptions(
                                            padding: EdgeInsets.all(10.0),
                                            iconPadding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 0.0),
                                            color: _model.varReadFilter == true
                                                ? FlutterFlowTheme.of(context)
                                                    .coachSmartGreen
                                                : FlutterFlowTheme.of(context)
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
                                                  color: _model.varReadFilter ==
                                                          true
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
                                            borderSide: BorderSide(),
                                            borderRadius:
                                                BorderRadius.circular(24.0),
                                          ),
                                        ),
                                      ),
                                      Flexible(
                                        child: FFButtonWidget(
                                          onPressed: () async {
                                            logFirebaseEvent(
                                                'NOTIFICATIONS_PAGE_ALL_BTN_ON_TAP');
                                            logFirebaseEvent(
                                                'Button_update_page_state');
                                            _model.varReadFilter = null;
                                            safeSetState(() {});
                                          },
                                          text: 'All',
                                          options: FFButtonOptions(
                                            padding: EdgeInsets.all(10.0),
                                            iconPadding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    0.0, 0.0, 0.0, 0.0),
                                            color: _model.varReadFilter == null
                                                ? FlutterFlowTheme.of(context)
                                                    .coachSmartGreen
                                                : FlutterFlowTheme.of(context)
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
                                                  color: _model.varReadFilter ==
                                                          null
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
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 10.0)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final childNotifications = FFAppState()
                                      .userNotifications
                                      .where((e) =>
                                          (_model.varReadFilter == null) ||
                                          ((_model.varReadFilter == false) &&
                                              (e.isRead == false)) ||
                                          ((_model.varReadFilter == true) &&
                                              (e.isRead == true)))
                                      .toList();

                                  return ListView.separated(
                                    padding: EdgeInsets.zero,
                                    primary: false,
                                    shrinkWrap: true,
                                    scrollDirection: Axis.vertical,
                                    itemCount: childNotifications.length,
                                    separatorBuilder: (_, __) =>
                                        SizedBox(height: 10.0),
                                    itemBuilder:
                                        (context, childNotificationsIndex) {
                                      final childNotificationsItem =
                                          childNotifications[
                                              childNotificationsIndex];
                                      return InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          logFirebaseEvent(
                                              'NOTIFICATIONS_Container_2cqgu087_ON_TAP');
                                          if (childNotificationsItem.isRead ==
                                              false) {
                                            logFirebaseEvent(
                                                'Container_backend_call');
                                            await NotificationsTable().update(
                                              data: {
                                                'is_read': true,
                                                'when_read':
                                                    supaSerialize<DateTime>(
                                                        getCurrentTimestamp),
                                              },
                                              matchingRows: (rows) =>
                                                  rows.eqOrNull(
                                                'id',
                                                childNotificationsItem.id,
                                              ),
                                            );
                                            logFirebaseEvent(
                                                'Container_backend_call');
                                            _model.outputUnreadNotifications =
                                                await NotificationsTable()
                                                    .queryRows(
                                              queryFn: (q) => q
                                                  .eqOrNull(
                                                    'recipient_user_id',
                                                    currentUserUid,
                                                  )
                                                  .eqOrNull(
                                                    'is_read',
                                                    false,
                                                  ),
                                            );
                                            logFirebaseEvent(
                                                'Container_custom_action');
                                            _model.outputBadgeUpdate =
                                                await actions.updateAppBadge(
                                              _model.outputUnreadNotifications
                                                  ?.length,
                                            );
                                            logFirebaseEvent(
                                                'Container_navigate_to');

                                            context.pushNamed(
                                              NotificationDetailsWidget
                                                  .routeName,
                                              queryParameters: {
                                                'paramNotificationID':
                                                    serializeParam(
                                                  childNotificationsItem.id,
                                                  ParamType.int,
                                                ),
                                              }.withoutNulls,
                                            );
                                          } else {
                                            logFirebaseEvent(
                                                'Container_navigate_to');

                                            context.pushNamed(
                                              NotificationDetailsWidget
                                                  .routeName,
                                              queryParameters: {
                                                'paramNotificationID':
                                                    serializeParam(
                                                  childNotificationsItem.id,
                                                  ParamType.int,
                                                ),
                                              }.withoutNulls,
                                            );
                                          }

                                          safeSetState(() {});
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .coachSmartLightBlack,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        10.0, 0.0, 0.0, 0.0),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Container(
                                                          width: 10.0,
                                                          height: 48.0,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: childNotificationsItem
                                                                        .isRead ==
                                                                    false
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .coachSmartGreen
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        10.0),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    10.0,
                                                                    10.0,
                                                                    10.0,
                                                                    10.0),
                                                        child: Column(
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
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .spaceBetween,
                                                              children: [
                                                                Expanded(
                                                                  child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .max,
                                                                    children: [
                                                                      Expanded(
                                                                        child:
                                                                            Column(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children:
                                                                              [
                                                                            Row(
                                                                              mainAxisSize: MainAxisSize.max,
                                                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                              children: [
                                                                                Text(
                                                                                  valueOrDefault<String>(
                                                                                    childNotificationsItem.teamName,
                                                                                    'team_name',
                                                                                  ),
                                                                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                        font: GoogleFonts.inter(
                                                                                          fontWeight: FontWeight.w600,
                                                                                          fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                        ),
                                                                                        color: childNotificationsItem.isRead == false ? FlutterFlowTheme.of(context).coachSmartGreen : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                                        fontSize: isWeb == true ? 14.0 : 16.0,
                                                                                        letterSpacing: 0.0,
                                                                                        fontWeight: FontWeight.w600,
                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                      ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            Padding(
                                                                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 10.0, 0.0),
                                                                              child: Text(
                                                                                valueOrDefault<String>(
                                                                                  childNotificationsItem.appTitle,
                                                                                  'title',
                                                                                ),
                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                      font: GoogleFonts.inter(
                                                                                        fontWeight: FontWeight.normal,
                                                                                        fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                      ),
                                                                                      color: childNotificationsItem.isRead == false ? FlutterFlowTheme.of(context).primaryBackground : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                                      fontSize: isWeb == true ? 14.0 : 16.0,
                                                                                      letterSpacing: 0.0,
                                                                                      fontWeight: FontWeight.normal,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            ),
                                                                          ].divide(SizedBox(height: 7.0)),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  children: [
                                                                    Padding(
                                                                      padding: EdgeInsetsDirectional.fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          10.0,
                                                                          0.0),
                                                                      child:
                                                                          Text(
                                                                        valueOrDefault<
                                                                            String>(
                                                                          childNotificationsItem
                                                                              .timeLabel,
                                                                          'time_label',
                                                                        ),
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              font: GoogleFonts.inter(
                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                              color: FlutterFlowTheme.of(context).coachSmartGrey,
                                                                              fontSize: isWeb == true ? 12.0 : 14.0,
                                                                              letterSpacing: 0.0,
                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                      ),
                                                                    ),
                                                                    Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      children: [
                                                                        Row(
                                                                          mainAxisSize:
                                                                              MainAxisSize.max,
                                                                          children: [
                                                                            if (childNotificationsItem.isRead ==
                                                                                true)
                                                                              Builder(
                                                                                builder: (context) => InkWell(
                                                                                  splashColor: Colors.transparent,
                                                                                  focusColor: Colors.transparent,
                                                                                  hoverColor: Colors.transparent,
                                                                                  highlightColor: Colors.transparent,
                                                                                  onTap: () async {
                                                                                    logFirebaseEvent('NOTIFICATIONS_PAGE_Icon_ij9j1shv_ON_TAP');
                                                                                    logFirebaseEvent('Icon_alert_dialog');
                                                                                    await showAlignedDialog(
                                                                                      context: context,
                                                                                      isGlobal: false,
                                                                                      avoidOverflow: false,
                                                                                      targetAnchor: AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                      followerAnchor: AlignmentDirectional(1.0, -1.0).resolve(Directionality.of(context)),
                                                                                      builder: (dialogContext) {
                                                                                        return Material(
                                                                                          color: Colors.transparent,
                                                                                          child: WebViewAware(
                                                                                            child: GestureDetector(
                                                                                              onTap: () {
                                                                                                FocusScope.of(dialogContext).unfocus();
                                                                                                FocusManager.instance.primaryFocus?.unfocus();
                                                                                              },
                                                                                              child: DropDownMenuNotificationsWidget(
                                                                                                paramNotificationID: childNotificationsItem.id,
                                                                                                passBackRead: () async {
                                                                                                  logFirebaseEvent('_backend_call');
                                                                                                  _model.apiUserNotifications1 = await GetUserNotificationsCall.call(
                                                                                                    pUserId: currentUserUid,
                                                                                                  );

                                                                                                  logFirebaseEvent('_update_app_state');
                                                                                                  FFAppState().userNotifications = ((_model.apiUserNotifications1?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                                  safeSetState(() {});
                                                                                                },
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                    );

                                                                                    safeSetState(() {});
                                                                                  },
                                                                                  child: Icon(
                                                                                    Icons.more_vert,
                                                                                    color: childNotificationsItem.isRead == false ? FlutterFlowTheme.of(context).coachSmartGreen : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                                    size: 26.0,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            if (childNotificationsItem.isRead ==
                                                                                false)
                                                                              Builder(
                                                                                builder: (context) => InkWell(
                                                                                  splashColor: Colors.transparent,
                                                                                  focusColor: Colors.transparent,
                                                                                  hoverColor: Colors.transparent,
                                                                                  highlightColor: Colors.transparent,
                                                                                  onTap: () async {
                                                                                    logFirebaseEvent('NOTIFICATIONS_PAGE_Icon_x6gz7f4n_ON_TAP');
                                                                                    logFirebaseEvent('Icon_alert_dialog');
                                                                                    await showAlignedDialog(
                                                                                      context: context,
                                                                                      isGlobal: false,
                                                                                      avoidOverflow: false,
                                                                                      targetAnchor: AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                      followerAnchor: AlignmentDirectional(1.0, -1.0).resolve(Directionality.of(context)),
                                                                                      builder: (dialogContext) {
                                                                                        return Material(
                                                                                          color: Colors.transparent,
                                                                                          child: WebViewAware(
                                                                                            child: GestureDetector(
                                                                                              onTap: () {
                                                                                                FocusScope.of(dialogContext).unfocus();
                                                                                                FocusManager.instance.primaryFocus?.unfocus();
                                                                                              },
                                                                                              child: DropDownMenuNotificationsWidget(
                                                                                                paramNotificationID: childNotificationsItem.id,
                                                                                                passBackRead: () async {},
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                    );
                                                                                  },
                                                                                  child: Icon(
                                                                                    Icons.mail_outline,
                                                                                    color: childNotificationsItem.isRead == false ? FlutterFlowTheme.of(context).coachSmartGreen : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                                    size: 26.0,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                            if (childNotificationsItem.isRead ==
                                                                                true)
                                                                              Builder(
                                                                                builder: (context) => InkWell(
                                                                                  splashColor: Colors.transparent,
                                                                                  focusColor: Colors.transparent,
                                                                                  hoverColor: Colors.transparent,
                                                                                  highlightColor: Colors.transparent,
                                                                                  onTap: () async {
                                                                                    logFirebaseEvent('NOTIFICATIONS_PAGE_Icon_5wi1027e_ON_TAP');
                                                                                    logFirebaseEvent('Icon_alert_dialog');
                                                                                    await showAlignedDialog(
                                                                                      context: context,
                                                                                      isGlobal: false,
                                                                                      avoidOverflow: false,
                                                                                      targetAnchor: AlignmentDirectional(0.0, 0.0).resolve(Directionality.of(context)),
                                                                                      followerAnchor: AlignmentDirectional(1.0, -1.0).resolve(Directionality.of(context)),
                                                                                      builder: (dialogContext) {
                                                                                        return Material(
                                                                                          color: Colors.transparent,
                                                                                          child: WebViewAware(
                                                                                            child: GestureDetector(
                                                                                              onTap: () {
                                                                                                FocusScope.of(dialogContext).unfocus();
                                                                                                FocusManager.instance.primaryFocus?.unfocus();
                                                                                              },
                                                                                              child: DropDownMenuNotificationsWidget(
                                                                                                paramNotificationID: childNotificationsItem.id,
                                                                                                passBackRead: () async {},
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                    );
                                                                                  },
                                                                                  child: Icon(
                                                                                    Icons.drafts_outlined,
                                                                                    color: childNotificationsItem.isRead == true ? FlutterFlowTheme.of(context).coachSmartGrey : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                                    size: 26.0,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ].divide(SizedBox(
                                                                      height:
                                                                          7.0)),
                                                                ),
                                                              ],
                                                            ),
                                                          ].divide(SizedBox(
                                                              height: 7.0)),
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
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ].divide(SizedBox(height: 5.0)),
                      ),
                    ),
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
