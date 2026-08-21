import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/components/drop_down_menu_notifications_widget.dart';
import '/components/drop_down_menu_roles_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:aligned_dialog/aligned_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'notifications_new_model.dart';
export 'notifications_new_model.dart';

class NotificationsNewWidget extends StatefulWidget {
  const NotificationsNewWidget({super.key});

  static String routeName = 'NotificationsNew';
  static String routePath = 'notificationsNew';

  @override
  State<NotificationsNewWidget> createState() => _NotificationsNewWidgetState();
}

class _NotificationsNewWidgetState extends State<NotificationsNewWidget> {
  late NotificationsNewModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NotificationsNewModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'NotificationsNew'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('NOTIFICATIONS_NEW_NotificationsNew_ON_IN');
      logFirebaseEvent('NotificationsNew_update_page_state');
      _model.varReadFilter = false;
      safeSetState(() {});
      logFirebaseEvent('NotificationsNew_backend_call');
      _model.apiUserNotifications = await GetUserNotificationsCall.call(
        pUserId: currentUserUid,
      );

      logFirebaseEvent('NotificationsNew_update_app_state');
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
      logFirebaseEvent('NotificationsNew_wait__delay');
      await Future.delayed(
        Duration(
          milliseconds: 2000,
        ),
      );
      logFirebaseEvent('NotificationsNew_backend_call');
      _model.apiMarkAllNotificationAsRead =
          await MarkAllNotifcationsReadCall.call(
        supabaseJWTtoken: currentJwtToken,
        pUserId: currentUserUid,
      );

      if ((_model.apiMarkAllNotificationAsRead?.succeeded ?? true)) {
        logFirebaseEvent('NotificationsNew_backend_call');
        _model.apiUserNotificationsRead = await GetUserNotificationsCall.call(
          pUserId: currentUserUid,
        );

        logFirebaseEvent('NotificationsNew_update_app_state');
        FFAppState().userNotifications =
            ((_model.apiUserNotificationsRead?.jsonBody ?? '')
                    .toList()
                    .map<UserNotificationsStruct?>(
                        UserNotificationsStruct.maybeFromMap)
                    .toList() as Iterable<UserNotificationsStruct?>)
                .withoutNulls
                .toList()
                .cast<UserNotificationsStruct>();
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
              logFirebaseEvent('NOTIFICATIONS_NEW_arrow_back_rounded_ICN');
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
            visible: FFAppState().userNotifications.length > 0,
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
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final childNotifications = FFAppState()
                                      .userNotifications
                                      .take(30)
                                      .toList()
                                      .sortedList(
                                          keyOf: (e) => e.createdAt, desc: true)
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
                                      return Container(
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
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Container(
                                                        width: 10.0,
                                                        height: 50.0,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: childNotificationsItem
                                                                      .isRead ==
                                                                  false
                                                              ? FlutterFlowTheme
                                                                      .of(
                                                                          context)
                                                                  .coachSmartGreen
                                                              : FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryText,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      10.0),
                                                          shape: BoxShape
                                                              .rectangle,
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
                                                                            mainAxisSize:
                                                                                MainAxisSize.max,
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.spaceBetween,
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
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                0.0,
                                                                                0.0,
                                                                                10.0,
                                                                                0.0),
                                                                            child:
                                                                                Text(
                                                                              valueOrDefault<String>(
                                                                                childNotificationsItem.appTitle,
                                                                                'title',
                                                                              ),
                                                                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                    font: GoogleFonts.inter(
                                                                                      fontWeight: FontWeight.w600,
                                                                                      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                    ),
                                                                                    color: childNotificationsItem.isRead == false ? FlutterFlowTheme.of(context).primaryBackground : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                                    fontSize: isWeb == true ? 14.0 : 16.0,
                                                                                    letterSpacing: 0.0,
                                                                                    fontWeight: FontWeight.w600,
                                                                                    fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                  ),
                                                                              overflow: TextOverflow.visible,
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
                                                                    padding: EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            0.0,
                                                                            10.0,
                                                                            0.0),
                                                                    child: Text(
                                                                      valueOrDefault<
                                                                          String>(
                                                                        childNotificationsItem
                                                                            .timeLabel,
                                                                        'time_label',
                                                                      ),
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                            color:
                                                                                FlutterFlowTheme.of(context).coachSmartGrey,
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
                                                                          if ((childNotificationsItem.action != 'approve_member') &&
                                                                              (childNotificationsItem.action != 'approve_access'))
                                                                            Builder(
                                                                              builder: (context) => InkWell(
                                                                                splashColor: Colors.transparent,
                                                                                focusColor: Colors.transparent,
                                                                                hoverColor: Colors.transparent,
                                                                                highlightColor: Colors.transparent,
                                                                                onTap: () async {
                                                                                  logFirebaseEvent('NOTIFICATIONS_NEW_Icon_01ex6d50_ON_TAP');
                                                                                  logFirebaseEvent('Icon_alert_dialog');
                                                                                  await showAlignedDialog(
                                                                                    context: context,
                                                                                    isGlobal: false,
                                                                                    avoidOverflow: true,
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
                                                                                              paramNotificationStatus: childNotificationsItem.isRead,
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
                                                                            Icon(
                                                                              Icons.mail_outline,
                                                                              color: childNotificationsItem.isRead == false ? FlutterFlowTheme.of(context).coachSmartGreen : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                              size: 26.0,
                                                                            ),
                                                                          if (childNotificationsItem.isRead ==
                                                                              true)
                                                                            Icon(
                                                                              Icons.drafts_outlined,
                                                                              color: childNotificationsItem.isRead == true ? FlutterFlowTheme.of(context).coachSmartGrey : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                              size: 26.0,
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
                                                          Divider(
                                                            thickness: 1.0,
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .coachSmartGrey,
                                                          ),
                                                          Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        0.0,
                                                                        0.0,
                                                                        10.0),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              children: [
                                                                Text(
                                                                  valueOrDefault<
                                                                      String>(
                                                                    childNotificationsItem
                                                                        .appBody,
                                                                    'app_body',
                                                                  ),
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
                                                                        color: childNotificationsItem.isRead ==
                                                                                false
                                                                            ? FlutterFlowTheme.of(context).primaryBackground
                                                                            : FlutterFlowTheme.of(context).coachSmartGrey,
                                                                        fontSize: isWeb ==
                                                                                true
                                                                            ? 14.0
                                                                            : 16.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .fontStyle,
                                                                      ),
                                                                ),
                                                              ].divide(SizedBox(
                                                                  height:
                                                                      10.0)),
                                                            ),
                                                          ),
                                                          if (childNotificationsItem
                                                                  .action ==
                                                              'approve_member')
                                                            Padding(
                                                              padding:
                                                                  EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          10.0),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: [
                                                                  Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .max,
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Builder(
                                                                        builder:
                                                                            (context) =>
                                                                                FFButtonWidget(
                                                                          onPressed: (childNotificationsItem.isRead == true)
                                                                              ? null
                                                                              : () async {
                                                                                  logFirebaseEvent('NOTIFICATIONS_NEW_APPROVE_BTN_ON_TAP');
                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.queryNotification = await NotificationsTable().queryRows(
                                                                                    queryFn: (q) => q.eqOrNull(
                                                                                      'id',
                                                                                      childNotificationsItem.id,
                                                                                    ),
                                                                                  );
                                                                                  if (_model.queryNotification?.firstOrNull?.isRead == true) {
                                                                                    logFirebaseEvent('Button_show_snack_bar');
                                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                                      SnackBar(
                                                                                        content: Text(
                                                                                          'Request already confirmed by a different Admin',
                                                                                          style: TextStyle(
                                                                                            color: FlutterFlowTheme.of(context).primaryText,
                                                                                          ),
                                                                                          textAlign: TextAlign.center,
                                                                                        ),
                                                                                        duration: Duration(milliseconds: 4000),
                                                                                        backgroundColor: FlutterFlowTheme.of(context).error,
                                                                                      ),
                                                                                    );
                                                                                    logFirebaseEvent('Button_backend_call');
                                                                                    _model.apiUserNotificationsExisting = await GetUserNotificationsCall.call(
                                                                                      pUserId: currentUserUid,
                                                                                      pLimit: 50,
                                                                                    );

                                                                                    logFirebaseEvent('Button_update_app_state');
                                                                                    FFAppState().userNotifications = ((_model.apiUserNotificationsExisting?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                    safeSetState(() {});
                                                                                  } else {
                                                                                    logFirebaseEvent('Button_backend_call');
                                                                                    _model.apiRoleList = await GetTeamRolesCall.call(
                                                                                      supabaseJWTtoken: currentJwtToken,
                                                                                      pTeamId: childNotificationsItem.teamId,
                                                                                    );

                                                                                    logFirebaseEvent('Button_update_app_state');
                                                                                    FFAppState().joinRoles = ((_model.apiRoleList?.jsonBody ?? '').toList().map<GetTeamRolesStruct?>(GetTeamRolesStruct.maybeFromMap).toList() as Iterable<GetTeamRolesStruct?>).withoutNulls.toList().cast<GetTeamRolesStruct>();
                                                                                    logFirebaseEvent('Button_alert_dialog');
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
                                                                                              child: DropDownMenuRolesWidget(
                                                                                                parTeamId: childNotificationsItem.teamId,
                                                                                                parMemberId: childNotificationsItem.memberId,
                                                                                                parMemberTeamId: childNotificationsItem.actionRefId,
                                                                                              ),
                                                                                            ),
                                                                                          ),
                                                                                        );
                                                                                      },
                                                                                    );

                                                                                    logFirebaseEvent('Button_backend_call');
                                                                                    _model.apiMarkNotificationReadAccepted = await MarkNotificationReadCall.call(
                                                                                      supabaseJWTtoken: currentJwtToken,
                                                                                      pNotificationId: childNotificationsItem.id,
                                                                                    );

                                                                                    logFirebaseEvent('Button_backend_call');
                                                                                    _model.apiUserNotificationsAccepted = await GetUserNotificationsCall.call(
                                                                                      pUserId: currentUserUid,
                                                                                      pLimit: 50,
                                                                                    );

                                                                                    logFirebaseEvent('Button_update_app_state');
                                                                                    FFAppState().userNotifications = ((_model.apiUserNotificationsAccepted?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                    safeSetState(() {});
                                                                                  }

                                                                                  safeSetState(() {});
                                                                                },
                                                                          text:
                                                                              'Approve',
                                                                          icon:
                                                                              Icon(
                                                                            Icons.check,
                                                                            size:
                                                                                25.0,
                                                                          ),
                                                                          options:
                                                                              FFButtonOptions(
                                                                            width:
                                                                                120.0,
                                                                            height:
                                                                                35.0,
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                16.0,
                                                                                0.0,
                                                                                16.0,
                                                                                0.0),
                                                                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                                                                0.0,
                                                                                0.0,
                                                                                0.0,
                                                                                0.0),
                                                                            color:
                                                                                FlutterFlowTheme.of(context).coachSmartGreen,
                                                                            textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                                                                  font: GoogleFonts.interTight(
                                                                                    fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                    fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                  ),
                                                                                  color: FlutterFlowTheme.of(context).coachSmartLightBlack,
                                                                                  fontSize: 14.0,
                                                                                  letterSpacing: 0.0,
                                                                                  fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                ),
                                                                            elevation:
                                                                                0.0,
                                                                            borderRadius:
                                                                                BorderRadius.circular(8.0),
                                                                            disabledColor:
                                                                                FlutterFlowTheme.of(context).coachSmartMidBlack,
                                                                            disabledTextColor:
                                                                                FlutterFlowTheme.of(context).coachSmartGrey,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      FFButtonWidget(
                                                                        onPressed: (childNotificationsItem.isRead ==
                                                                                true)
                                                                            ? null
                                                                            : () async {
                                                                                logFirebaseEvent('NOTIFICATIONS_NEW_DECLINE_BTN_ON_TAP');
                                                                                logFirebaseEvent('Button_backend_call');
                                                                                _model.queryNotificationDeclined = await NotificationsTable().queryRows(
                                                                                  queryFn: (q) => q.eqOrNull(
                                                                                    'id',
                                                                                    childNotificationsItem.id,
                                                                                  ),
                                                                                );
                                                                                if (_model.queryNotificationDeclined?.firstOrNull?.isRead == true) {
                                                                                  logFirebaseEvent('Button_show_snack_bar');
                                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                                    SnackBar(
                                                                                      content: Text(
                                                                                        'Request already confirmed by a different Admin',
                                                                                        style: TextStyle(
                                                                                          color: FlutterFlowTheme.of(context).primaryText,
                                                                                        ),
                                                                                        textAlign: TextAlign.center,
                                                                                      ),
                                                                                      duration: Duration(milliseconds: 4000),
                                                                                      backgroundColor: FlutterFlowTheme.of(context).error,
                                                                                    ),
                                                                                  );
                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiUserNotificationsDeclinedFail = await GetUserNotificationsCall.call(
                                                                                    pUserId: currentUserUid,
                                                                                    pLimit: 50,
                                                                                  );

                                                                                  logFirebaseEvent('Button_update_app_state');
                                                                                  FFAppState().userNotifications = ((_model.apiUserNotificationsDeclinedFail?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                  safeSetState(() {});
                                                                                } else {
                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiDenyJoin = await DenyMemberJoinCall.call(
                                                                                    supabaseJWTtoken: currentJwtToken,
                                                                                    pMemberTeamId: childNotificationsItem.actionRefId,
                                                                                  );

                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiMarkNotificationDeclined = await MarkNotificationReadCall.call(
                                                                                    supabaseJWTtoken: currentJwtToken,
                                                                                    pNotificationId: childNotificationsItem.id,
                                                                                  );

                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiUserNotificationsDeclined = await GetUserNotificationsCall.call(
                                                                                    pUserId: currentUserUid,
                                                                                    pLimit: 50,
                                                                                  );

                                                                                  logFirebaseEvent('Button_update_app_state');
                                                                                  FFAppState().userNotifications = ((_model.apiUserNotificationsDeclined?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                  safeSetState(() {});
                                                                                }

                                                                                safeSetState(() {});
                                                                              },
                                                                        text:
                                                                            'Decline',
                                                                        icon:
                                                                            Icon(
                                                                          Icons
                                                                              .close,
                                                                          size:
                                                                              25.0,
                                                                        ),
                                                                        options:
                                                                            FFButtonOptions(
                                                                          width:
                                                                              120.0,
                                                                          height:
                                                                              35.0,
                                                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                                              16.0,
                                                                              0.0,
                                                                              16.0,
                                                                              0.0),
                                                                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                                                                              0.0,
                                                                              0.0,
                                                                              0.0,
                                                                              0.0),
                                                                          color:
                                                                              Color(0xFF9C0508),
                                                                          textStyle: FlutterFlowTheme.of(context)
                                                                              .titleSmall
                                                                              .override(
                                                                                font: GoogleFonts.interTight(
                                                                                  fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                ),
                                                                                color: FlutterFlowTheme.of(context).alternate,
                                                                                fontSize: 14.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                              ),
                                                                          elevation:
                                                                              0.0,
                                                                          borderRadius:
                                                                              BorderRadius.circular(8.0),
                                                                          disabledColor:
                                                                              FlutterFlowTheme.of(context).coachSmartMidBlack,
                                                                          disabledTextColor:
                                                                              FlutterFlowTheme.of(context).coachSmartGrey,
                                                                        ),
                                                                      ),
                                                                    ].divide(SizedBox(
                                                                        width:
                                                                            10.0)),
                                                                  ),
                                                                ].divide(SizedBox(
                                                                    height:
                                                                        10.0)),
                                                              ),
                                                            ),
                                                          if (childNotificationsItem
                                                                  .action ==
                                                              'approve_access')
                                                            Padding(
                                                              padding:
                                                                  EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          10.0),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: [
                                                                  Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .max,
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      FFButtonWidget(
                                                                        onPressed: (childNotificationsItem.isRead ==
                                                                                true)
                                                                            ? null
                                                                            : () async {
                                                                                logFirebaseEvent('NOTIFICATIONS_NEW_APPROVE_BTN_ON_TAP');
                                                                                logFirebaseEvent('Button_backend_call');
                                                                                _model.queryNotificationAccess = await NotificationsTable().queryRows(
                                                                                  queryFn: (q) => q.eqOrNull(
                                                                                    'id',
                                                                                    childNotificationsItem.id,
                                                                                  ),
                                                                                );
                                                                                if (_model.queryNotificationAccess?.firstOrNull?.isRead == true) {
                                                                                  logFirebaseEvent('Button_show_snack_bar');
                                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                                    SnackBar(
                                                                                      content: Text(
                                                                                        'Request already confirmed by a different Admin',
                                                                                        style: TextStyle(
                                                                                          color: FlutterFlowTheme.of(context).primaryText,
                                                                                        ),
                                                                                        textAlign: TextAlign.center,
                                                                                      ),
                                                                                      duration: Duration(milliseconds: 4000),
                                                                                      backgroundColor: FlutterFlowTheme.of(context).error,
                                                                                    ),
                                                                                  );
                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiUserNotificationsExistingAccess = await GetUserNotificationsCall.call(
                                                                                    pUserId: currentUserUid,
                                                                                    pLimit: 50,
                                                                                  );

                                                                                  logFirebaseEvent('Button_update_app_state');
                                                                                  FFAppState().userNotifications = ((_model.apiUserNotificationsExistingAccess?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                  safeSetState(() {});
                                                                                } else {
                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiConfirmUserMemberAccess = await ConfirmUserMemberAccessCall.call(
                                                                                    supabaseJWTtoken: currentJwtToken,
                                                                                    pUserMemberId: childNotificationsItem.actionRefId,
                                                                                  );

                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiMarkNotificationReadAcceptedAccess = await MarkNotificationReadCall.call(
                                                                                    supabaseJWTtoken: currentJwtToken,
                                                                                    pNotificationId: childNotificationsItem.id,
                                                                                  );

                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiUserNotificationsAcceptedAccess = await GetUserNotificationsCall.call(
                                                                                    pUserId: currentUserUid,
                                                                                    pLimit: 50,
                                                                                  );

                                                                                  logFirebaseEvent('Button_update_app_state');
                                                                                  FFAppState().userNotifications = ((_model.apiUserNotificationsAcceptedAccess?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                  safeSetState(() {});
                                                                                }

                                                                                safeSetState(() {});
                                                                              },
                                                                        text:
                                                                            'Approve',
                                                                        icon:
                                                                            Icon(
                                                                          Icons
                                                                              .check,
                                                                          size:
                                                                              25.0,
                                                                        ),
                                                                        options:
                                                                            FFButtonOptions(
                                                                          width:
                                                                              120.0,
                                                                          height:
                                                                              35.0,
                                                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                                              16.0,
                                                                              0.0,
                                                                              16.0,
                                                                              0.0),
                                                                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                                                                              0.0,
                                                                              0.0,
                                                                              0.0,
                                                                              0.0),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).coachSmartGreen,
                                                                          textStyle: FlutterFlowTheme.of(context)
                                                                              .titleSmall
                                                                              .override(
                                                                                font: GoogleFonts.interTight(
                                                                                  fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                ),
                                                                                color: FlutterFlowTheme.of(context).coachSmartLightBlack,
                                                                                fontSize: 14.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                              ),
                                                                          elevation:
                                                                              0.0,
                                                                          borderRadius:
                                                                              BorderRadius.circular(8.0),
                                                                          disabledColor:
                                                                              FlutterFlowTheme.of(context).coachSmartMidBlack,
                                                                          disabledTextColor:
                                                                              FlutterFlowTheme.of(context).coachSmartGrey,
                                                                        ),
                                                                      ),
                                                                      FFButtonWidget(
                                                                        onPressed: (childNotificationsItem.isRead ==
                                                                                true)
                                                                            ? null
                                                                            : () async {
                                                                                logFirebaseEvent('NOTIFICATIONS_NEW_DECLINE_BTN_ON_TAP');
                                                                                logFirebaseEvent('Button_backend_call');
                                                                                _model.queryNotificationDeclinedAccess = await NotificationsTable().queryRows(
                                                                                  queryFn: (q) => q.eqOrNull(
                                                                                    'id',
                                                                                    childNotificationsItem.id,
                                                                                  ),
                                                                                );
                                                                                if (_model.queryNotificationDeclinedAccess?.firstOrNull?.isRead == true) {
                                                                                  logFirebaseEvent('Button_show_snack_bar');
                                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                                    SnackBar(
                                                                                      content: Text(
                                                                                        'Request already confirmed by a different Admin',
                                                                                        style: TextStyle(
                                                                                          color: FlutterFlowTheme.of(context).primaryText,
                                                                                        ),
                                                                                        textAlign: TextAlign.center,
                                                                                      ),
                                                                                      duration: Duration(milliseconds: 4000),
                                                                                      backgroundColor: FlutterFlowTheme.of(context).error,
                                                                                    ),
                                                                                  );
                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiUserNotificationsDeclinedFailAccess = await GetUserNotificationsCall.call(
                                                                                    pUserId: currentUserUid,
                                                                                    pLimit: 50,
                                                                                  );

                                                                                  logFirebaseEvent('Button_update_app_state');
                                                                                  FFAppState().userNotifications = ((_model.apiUserNotificationsDeclinedFailAccess?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                  safeSetState(() {});
                                                                                } else {
                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  await DenyUserMemberAccessCall.call(
                                                                                    supabaseJWTtoken: currentJwtToken,
                                                                                    pUserMemberId: childNotificationsItem.actionRefId,
                                                                                  );

                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiMarkNotificationDeclinedAccess = await MarkNotificationReadCall.call(
                                                                                    supabaseJWTtoken: currentJwtToken,
                                                                                    pNotificationId: childNotificationsItem.id,
                                                                                  );

                                                                                  logFirebaseEvent('Button_backend_call');
                                                                                  _model.apiUserNotificationsDeclinedAccess = await GetUserNotificationsCall.call(
                                                                                    pUserId: currentUserUid,
                                                                                    pLimit: 50,
                                                                                  );

                                                                                  logFirebaseEvent('Button_update_app_state');
                                                                                  FFAppState().userNotifications = ((_model.apiUserNotificationsDeclinedAccess?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                  safeSetState(() {});
                                                                                }

                                                                                safeSetState(() {});
                                                                              },
                                                                        text:
                                                                            'Decline',
                                                                        icon:
                                                                            Icon(
                                                                          Icons
                                                                              .close,
                                                                          size:
                                                                              25.0,
                                                                        ),
                                                                        options:
                                                                            FFButtonOptions(
                                                                          width:
                                                                              120.0,
                                                                          height:
                                                                              35.0,
                                                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                                              16.0,
                                                                              0.0,
                                                                              16.0,
                                                                              0.0),
                                                                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                                                                              0.0,
                                                                              0.0,
                                                                              0.0,
                                                                              0.0),
                                                                          color:
                                                                              Color(0xFF9C0508),
                                                                          textStyle: FlutterFlowTheme.of(context)
                                                                              .titleSmall
                                                                              .override(
                                                                                font: GoogleFonts.interTight(
                                                                                  fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                ),
                                                                                color: FlutterFlowTheme.of(context).alternate,
                                                                                fontSize: 14.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                              ),
                                                                          elevation:
                                                                              0.0,
                                                                          borderRadius:
                                                                              BorderRadius.circular(8.0),
                                                                          disabledColor:
                                                                              FlutterFlowTheme.of(context).coachSmartMidBlack,
                                                                          disabledTextColor:
                                                                              FlutterFlowTheme.of(context).coachSmartGrey,
                                                                        ),
                                                                      ),
                                                                    ].divide(SizedBox(
                                                                        width:
                                                                            10.0)),
                                                                  ),
                                                                ].divide(SizedBox(
                                                                    height:
                                                                        10.0)),
                                                              ),
                                                            ),
                                                          if (childNotificationsItem
                                                                  .action ==
                                                              'attend')
                                                            Padding(
                                                              padding:
                                                                  EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          10.0),
                                                              child: Column(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: [
                                                                  Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .max,
                                                                    mainAxisAlignment:
                                                                        MainAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      FFButtonWidget(
                                                                        onPressed: (childNotificationsItem.isRead ==
                                                                                true)
                                                                            ? null
                                                                            : () async {
                                                                                logFirebaseEvent('NOTIFICATIONS_NEW_EVENT_DETAILS_BTN_ON_T');
                                                                                logFirebaseEvent('Button_backend_call');
                                                                                _model.apiMarkNotificationReadAcceptedEvent = await MarkNotificationReadCall.call(
                                                                                  supabaseJWTtoken: currentJwtToken,
                                                                                  pNotificationId: childNotificationsItem.id,
                                                                                );

                                                                                logFirebaseEvent('Button_backend_call');
                                                                                _model.apiUserNotificationsAcceptedEvent = await GetUserNotificationsCall.call(
                                                                                  pUserId: currentUserUid,
                                                                                  pLimit: 50,
                                                                                );

                                                                                logFirebaseEvent('Button_update_app_state');
                                                                                FFAppState().userNotifications = ((_model.apiUserNotificationsAcceptedEvent?.jsonBody ?? '').toList().map<UserNotificationsStruct?>(UserNotificationsStruct.maybeFromMap).toList() as Iterable<UserNotificationsStruct?>).withoutNulls.toList().cast<UserNotificationsStruct>();
                                                                                safeSetState(() {});
                                                                                logFirebaseEvent('Button_navigate_to');

                                                                                context.pushNamed(
                                                                                  EventDetailsWidget.routeName,
                                                                                  queryParameters: {
                                                                                    'eventID': serializeParam(
                                                                                      childNotificationsItem.eventId,
                                                                                      ParamType.int,
                                                                                    ),
                                                                                    'fromSearch': serializeParam(
                                                                                      false,
                                                                                      ParamType.bool,
                                                                                    ),
                                                                                  }.withoutNulls,
                                                                                );

                                                                                safeSetState(() {});
                                                                              },
                                                                        text:
                                                                            'Event Details',
                                                                        icon:
                                                                            Icon(
                                                                          Icons
                                                                              .keyboard_arrow_right,
                                                                          size:
                                                                              25.0,
                                                                        ),
                                                                        options:
                                                                            FFButtonOptions(
                                                                          width:
                                                                              120.0,
                                                                          height:
                                                                              35.0,
                                                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                                              16.0,
                                                                              0.0,
                                                                              0.0,
                                                                              0.0),
                                                                          iconAlignment:
                                                                              IconAlignment.end,
                                                                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                                                                              0.0,
                                                                              0.0,
                                                                              0.0,
                                                                              0.0),
                                                                          color:
                                                                              FlutterFlowTheme.of(context).coachSmartGreen,
                                                                          textStyle: FlutterFlowTheme.of(context)
                                                                              .titleSmall
                                                                              .override(
                                                                                font: GoogleFonts.interTight(
                                                                                  fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                                ),
                                                                                color: FlutterFlowTheme.of(context).coachSmartLightBlack,
                                                                                fontSize: 14.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FlutterFlowTheme.of(context).titleSmall.fontWeight,
                                                                                fontStyle: FlutterFlowTheme.of(context).titleSmall.fontStyle,
                                                                              ),
                                                                          elevation:
                                                                              0.0,
                                                                          borderRadius:
                                                                              BorderRadius.circular(8.0),
                                                                          disabledColor:
                                                                              FlutterFlowTheme.of(context).coachSmartMidBlack,
                                                                          disabledTextColor:
                                                                              FlutterFlowTheme.of(context).coachSmartGrey,
                                                                        ),
                                                                      ),
                                                                    ].divide(SizedBox(
                                                                        width:
                                                                            10.0)),
                                                                  ),
                                                                ].divide(SizedBox(
                                                                    height:
                                                                        10.0)),
                                                              ),
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
