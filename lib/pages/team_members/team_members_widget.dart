import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/components/drop_down_menu_squads_widget.dart';
import '/components/drop_down_menu_team_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'team_members_model.dart';
export 'team_members_model.dart';

class TeamMembersWidget extends StatefulWidget {
  const TeamMembersWidget({
    super.key,
    required this.teamID,
  });

  final int? teamID;

  static String routeName = 'TeamMembers';
  static String routePath = 'teamMembers';

  @override
  State<TeamMembersWidget> createState() => _TeamMembersWidgetState();
}

class _TeamMembersWidgetState extends State<TeamMembersWidget> {
  late TeamMembersModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TeamMembersModel());

    logFirebaseEvent('screen_view', parameters: {'screen_name': 'TeamMembers'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('TEAM_MEMBERS_TeamMembers_ON_INIT_STATE');
      logFirebaseEvent('TeamMembers_update_page_state');
      _model.codeSelected = 1;
      logFirebaseEvent('TeamMembers_backend_call');
      _model.apiGetTeamMembersByRole = await GetTeamMembersByRoleCall.call(
        pUserId: currentUserUid,
        supabaseJWTtoken: currentJwtToken,
        pTeamId: widget.teamID,
      );

      if ((_model.apiGetTeamMembersByRole?.succeeded ?? true)) {
        logFirebaseEvent('TeamMembers_update_app_state');
        FFAppState().listTeamMembers = ListTeamMembersStruct.maybeFromMap(
            (_model.apiGetTeamMembersByRole?.jsonBody ?? ''))!;
        safeSetState(() {});
      }
    });

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

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
              logFirebaseEvent('TEAM_MEMBERS_arrow_back_rounded_ICN_ON_T');
              logFirebaseEvent('IconButton_navigate_back');
              context.safePop();
            },
          ),
          title: Visibility(
            visible: _model.apiGetTeamMembersByRole != null,
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  valueOrDefault<String>(
                    FFAppState().listTeamMembers.teamName,
                    'team_name',
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        fontSize: isWeb == true ? 16.0 : 18.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
                Text(
                  valueOrDefault<String>(
                    FFAppState().listTeamMembers.teamUniqueCode,
                    'team_code',
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.inter(
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).coachSmartGreen,
                        fontSize: isWeb == true ? 14.0 : 16.0,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                ),
              ].divide(SizedBox(height: 3.0)),
            ),
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(
                  builder: (context) => Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 5.0, 0.0),
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
                            'TEAM_MEMBERS_more_vert_sharp_ICN_ON_TAP');
                        logFirebaseEvent('IconButton_alert_dialog');
                        await showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return Dialog(
                              elevation: 0,
                              insetPadding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              alignment: AlignmentDirectional(1.0, -1.0)
                                  .resolve(Directionality.of(context)),
                              child: WebViewAware(
                                child: GestureDetector(
                                  onTap: () {
                                    FocusScope.of(dialogContext).unfocus();
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                  child: DropDownMenuTeamWidget(
                                    paramTeamID: widget.teamID!,
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
              ],
            ),
          ],
          centerTitle: true,
          elevation: 2.0,
        ),
        body: SafeArea(
          top: true,
          child: Visibility(
            visible: _model.apiGetTeamMembersByRole != null,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(15.0, 0.0, 15.0, 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((FFAppState().listTeamMembers.userHighestRoleLevel >=
                              100) &&
                          (FFAppState().listTeamMembers.clubCodes.length > 1))
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 10.0, 0.0, 10.0),
                          child: Builder(
                            builder: (context) {
                              final childrenCodes = FFAppState()
                                  .listTeamMembers
                                  .clubCodes
                                  .toList();

                              return Row(
                                mainAxisSize: MainAxisSize.max,
                                children: List.generate(childrenCodes.length,
                                    (childrenCodesIndex) {
                                  final childrenCodesItem =
                                      childrenCodes[childrenCodesIndex];
                                  return FFButtonWidget(
                                    onPressed: () {
                                      print('Button pressed ...');
                                    },
                                    text: valueOrDefault<String>(
                                      childrenCodesItem.codeId == 1
                                          ? 'All'
                                          : valueOrDefault<String>(
                                              childrenCodesItem.eventCode,
                                              'code',
                                            ),
                                      'Code',
                                    ),
                                    options: FFButtonOptions(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16.0, 15.0, 16.0, 15.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      color: _model.codeSelected ==
                                              childrenCodesItem.codeId
                                          ? FlutterFlowTheme.of(context)
                                              .coachSmartGreen
                                          : FlutterFlowTheme.of(context)
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
                                            color: _model.codeSelected ==
                                                    childrenCodesItem.codeId
                                                ? FlutterFlowTheme.of(context)
                                                    .coachSmartLightBlack
                                                : FlutterFlowTheme.of(context)
                                                    .coachSmartGrey,
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
                                      borderRadius: BorderRadius.circular(24.0),
                                    ),
                                  );
                                }).divide(SizedBox(width: 10.0)),
                              );
                            },
                          ),
                        ),
                      TextFormField(
                        controller: _model.textController,
                        focusNode: _model.textFieldFocusNode,
                        onChanged: (_) => EasyDebounce.debounce(
                          '_model.textController',
                          Duration(milliseconds: 2000),
                          () async {
                            logFirebaseEvent(
                                'TEAM_MEMBERS_TextField_a44k4cmw_ON_TEXTF');
                            logFirebaseEvent('TextField_update_page_state');
                            _model.searchMember = _model.textController.text;
                            safeSetState(() {});
                          },
                        ),
                        autofocus: false,
                        enabled: true,
                        obscureText: false,
                        decoration: InputDecoration(
                          isDense: true,
                          labelStyle:
                              FlutterFlowTheme.of(context).labelMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .labelMedium
                                        .fontStyle,
                                  ),
                          hintText: 'Search members......',
                          hintStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).coachSmartGrey,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .fontStyle,
                              ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0x00000000),
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0x00000000),
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          filled: true,
                          fillColor:
                              FlutterFlowTheme.of(context).coachSmartLightBlack,
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                        cursorColor:
                            FlutterFlowTheme.of(context).coachSmartGrey,
                        enableInteractiveSelection: true,
                        validator:
                            _model.textControllerValidator.asValidator(context),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Builder(
                      builder: (context) {
                        final childrenTeamRoles = FFAppState()
                            .listTeamMembers
                            .roleGroups
                            .sortedList(keyOf: (e) => e.roleLevel, desc: false)
                            .toList();

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          scrollDirection: Axis.vertical,
                          itemCount: childrenTeamRoles.length,
                          itemBuilder: (context, childrenTeamRolesIndex) {
                            final childrenTeamRolesItem =
                                childrenTeamRoles[childrenTeamRolesIndex];
                            return Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 15.0, 0.0, 0.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${childrenTeamRolesItem.roleNamePlural} (${childrenTeamRolesItem.memberCount.toString()})',
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
                                          color: FlutterFlowTheme.of(context)
                                              .coachSmartGreen,
                                          fontSize: isWeb == true ? 16.0 : 18.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                  ),
                                  Divider(
                                    thickness: 0.5,
                                    indent: 0.0,
                                    color: Color(0xFF585757),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 5.0, 0.0, 10.0),
                                    child: Builder(
                                      builder: (context) {
                                        final childrenTeamMembers =
                                            childrenTeamRolesItem.members
                                                .sortedList(
                                                    keyOf: (e) => e.firstName,
                                                    desc: false)
                                                .where((e) => (String fullName,
                                                            String searchMember) {
                                                      return fullName
                                                          .toLowerCase()
                                                          .contains(
                                                              (searchMember ??
                                                                      '')
                                                                  .toLowerCase());
                                                    }(e.fullName,
                                                        _model.searchMember!))
                                                .toList();

                                        return ListView.separated(
                                          padding: EdgeInsets.zero,
                                          primary: false,
                                          shrinkWrap: true,
                                          scrollDirection: Axis.vertical,
                                          itemCount: childrenTeamMembers.length,
                                          separatorBuilder: (_, __) =>
                                              SizedBox(height: 10.0),
                                          itemBuilder: (context,
                                              childrenTeamMembersIndex) {
                                            final childrenTeamMembersItem =
                                                childrenTeamMembers[
                                                    childrenTeamMembersIndex];
                                            return Column(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .coachSmartLightBlack,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12.0),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(15.0, 5.0,
                                                                15.0, 5.0),
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
                                                            'TEAM_MEMBERS_PAGE_Row_unbuw3b1_ON_TAP');
                                                        if (FFAppState()
                                                                .listTeamMembers
                                                                .userHighestRoleLevel >=
                                                            100) {
                                                          logFirebaseEvent(
                                                              'Row_navigate_to');

                                                          context.pushNamed(
                                                            MemberDetailsWidget
                                                                .routeName,
                                                            queryParameters: {
                                                              'memberID':
                                                                  serializeParam(
                                                                childrenTeamMembersItem
                                                                    .memberId,
                                                                ParamType.int,
                                                              ),
                                                              'teamID':
                                                                  serializeParam(
                                                                widget.teamID,
                                                                ParamType.int,
                                                              ),
                                                            }.withoutNulls,
                                                          );
                                                        }
                                                      },
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            children: [
                                                              Padding(
                                                                padding:
                                                                    EdgeInsetsDirectional
                                                                        .fromSTEB(
                                                                            0.0,
                                                                            5.0,
                                                                            0.0,
                                                                            5.0),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      children:
                                                                          [
                                                                        Text(
                                                                          '${childrenTeamMembersItem.firstName} ${childrenTeamMembersItem.lastName}',
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .bodyMedium
                                                                              .override(
                                                                                font: GoogleFonts.inter(
                                                                                  fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                ),
                                                                                fontSize: isWeb == true ? 14.0 : 16.0,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                              ),
                                                                        ),
                                                                      ].divide(SizedBox(
                                                                              width: 10.0)),
                                                                    ),
                                                                    if ((_model.codeSelected !=
                                                                            1) &&
                                                                        (FFAppState().listTeamMembers.userHighestRoleLevel >=
                                                                            100))
                                                                      Builder(
                                                                        builder:
                                                                            (context) =>
                                                                                Builder(
                                                                          builder:
                                                                              (context) {
                                                                            final childrenSquadCodes =
                                                                                childrenTeamMembersItem.squadCodes.where((e) => e.codeId == _model.codeSelected).toList().take(1).toList();

                                                                            return InkWell(
                                                                              splashColor: Colors.transparent,
                                                                              focusColor: Colors.transparent,
                                                                              hoverColor: Colors.transparent,
                                                                              highlightColor: Colors.transparent,
                                                                              onTap: () async {
                                                                                logFirebaseEvent('TEAM_MEMBERS_PAGE_Row_7sjfn727_ON_TAP');
                                                                                if (FFAppState().listTeamMembers.userHighestRoleLevel >= 100) {
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
                                                                                  _model.outputExistingCodeRecord = await MemberSquadLinkTable().queryRows(
                                                                                    queryFn: (q) => q
                                                                                        .eqOrNull(
                                                                                          'member_id',
                                                                                          childrenTeamMembersItem.memberId,
                                                                                        )
                                                                                        .eqOrNull(
                                                                                          'team_id',
                                                                                          widget.teamID,
                                                                                        )
                                                                                        .eqOrNull(
                                                                                          'code_id',
                                                                                          _model.codeSelected,
                                                                                        ),
                                                                                  );
                                                                                  if (_model.outputExistingCodeRecord!.length >= 1) {
                                                                                    logFirebaseEvent('Row_backend_call');
                                                                                    await MemberSquadLinkTable().update(
                                                                                      data: {
                                                                                        'squad_id': _model.squadSelected,
                                                                                      },
                                                                                      matchingRows: (rows) => rows.eqOrNull(
                                                                                        'member_squad_id',
                                                                                        _model.outputExistingCodeRecord?.firstOrNull?.memberSquadId,
                                                                                      ),
                                                                                    );
                                                                                  } else {
                                                                                    logFirebaseEvent('Row_backend_call');
                                                                                    _model.outputInsertSquadLink = await MemberSquadLinkTable().insert({
                                                                                      'member_id': childrenTeamMembersItem.memberId,
                                                                                      'squad_id': _model.squadSelected,
                                                                                      'code_id': _model.codeSelected,
                                                                                      'team_id': widget.teamID,
                                                                                    });
                                                                                  }
                                                                                }

                                                                                safeSetState(() {});
                                                                              },
                                                                              child: Row(
                                                                                mainAxisSize: MainAxisSize.max,
                                                                                children: List.generate(childrenSquadCodes.length, (childrenSquadCodesIndex) {
                                                                                  final childrenSquadCodesItem = childrenSquadCodes[childrenSquadCodesIndex];
                                                                                  return Row(
                                                                                    mainAxisSize: MainAxisSize.max,
                                                                                    children: [
                                                                                      Container(
                                                                                        width: 30.0,
                                                                                        height: 30.0,
                                                                                        decoration: BoxDecoration(
                                                                                          image: DecorationImage(
                                                                                            fit: BoxFit.cover,
                                                                                            image: Image.network(
                                                                                              getJsonField(
                                                                                                childrenSquadCodesItem.toMap(),
                                                                                                r'''$.squad_image''',
                                                                                              ).toString(),
                                                                                            ).image,
                                                                                          ),
                                                                                          shape: BoxShape.circle,
                                                                                        ),
                                                                                      ),
                                                                                      Text(
                                                                                        valueOrDefault<String>(
                                                                                          childrenSquadCodesItem.squadName,
                                                                                          'squad_name',
                                                                                        ),
                                                                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                              font: GoogleFonts.inter(
                                                                                                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                              ),
                                                                                              letterSpacing: 0.0,
                                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                                            ),
                                                                                      ),
                                                                                    ].divide(SizedBox(width: 10.0)),
                                                                                  );
                                                                                }).divide(SizedBox(width: 10.0)),
                                                                              ),
                                                                            );
                                                                          },
                                                                        ),
                                                                      ),
                                                                  ].divide(SizedBox(
                                                                      height:
                                                                          10.0)),
                                                                ),
                                                              ),
                                                            ].divide(SizedBox(
                                                                width: 10.0)),
                                                          ),
                                                          if (FFAppState()
                                                                  .listTeamMembers
                                                                  .userHighestRoleLevel >=
                                                              100)
                                                            Icon(
                                                              Icons
                                                                  .chevron_right,
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .coachSmartWhite,
                                                              size: 30.0,
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
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
            ),
          ),
        ),
      ),
    );
  }
}
