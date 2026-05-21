import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_team_model.dart';
export 'create_team_model.dart';

class CreateTeamWidget extends StatefulWidget {
  const CreateTeamWidget({super.key});

  static String routeName = 'CreateTeam';
  static String routePath = 'createTeam';

  @override
  State<CreateTeamWidget> createState() => _CreateTeamWidgetState();
}

class _CreateTeamWidgetState extends State<CreateTeamWidget> {
  late CreateTeamModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CreateTeamModel());

    logFirebaseEvent('screen_view', parameters: {'screen_name': 'CreateTeam'});
    _model.teamNameInputTextController ??= TextEditingController();
    _model.teamNameInputFocusNode ??= FocusNode();

    _model.switchJuvenileValue = true;
    _model.switchFemaleValue = false;
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
              logFirebaseEvent('CREATE_TEAM_arrow_back_rounded_ICN_ON_TA');
              logFirebaseEvent('IconButton_navigate_back');
              context.pop();
            },
          ),
          title: Text(
            'Create Team',
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
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(15.0, 15.0, 15.0, 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: AlignmentDirectional(-1.0, 0.0),
                  child: Text(
                    'Enter Team Name:',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).coachSmartGrey,
                          fontSize: 15.0,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  child: TextFormField(
                    controller: _model.teamNameInputTextController,
                    focusNode: _model.teamNameInputFocusNode,
                    autofocus: false,
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
                      hintStyle:
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
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0x00000000),
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: FlutterFlowTheme.of(context).coachSmartGreen,
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
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                    cursorColor: FlutterFlowTheme.of(context).primaryBackground,
                    validator: _model.teamNameInputTextControllerValidator
                        .asValidator(context),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(-1.0, 0.0),
                  child: Text(
                    'Select Club:',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                          color: FlutterFlowTheme.of(context).coachSmartGrey,
                          fontSize: 15.0,
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                  ),
                ),
                FutureBuilder<List<ClubsRow>>(
                  future: ClubsTable().queryRows(
                    queryFn: (q) => q,
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
                              FlutterFlowTheme.of(context).coachSmartGreen,
                            ),
                          ),
                        ),
                      );
                    }
                    List<ClubsRow> dropDownClubClubsRowList = snapshot.data!;

                    return FlutterFlowDropDown<int>(
                      controller: _model.dropDownClubValueController ??=
                          FormFieldController<int>(
                        _model.dropDownClubValue ??= null,
                      ),
                      options: List<int>.from(dropDownClubClubsRowList
                          .map((e) => e.clubId)
                          .toList()),
                      optionLabels: dropDownClubClubsRowList
                          .map((e) => e.clubName)
                          .withoutNulls
                          .toList(),
                      onChanged: (val) =>
                          safeSetState(() => _model.dropDownClubValue = val),
                      width: 400.1,
                      height: 40.0,
                      searchHintTextStyle:
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
                      searchTextStyle:
                          FlutterFlowTheme.of(context).bodyMedium.override(
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
                      textStyle: FlutterFlowTheme.of(context)
                          .bodyMedium
                          .override(
                            font: GoogleFonts.inter(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                      hintText: 'Select Club...',
                      searchHintText: 'Search...',
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: FlutterFlowTheme.of(context).secondaryText,
                        size: 24.0,
                      ),
                      fillColor:
                          FlutterFlowTheme.of(context).coachSmartLightBlack,
                      elevation: 2.0,
                      borderColor: Colors.transparent,
                      borderWidth: 0.0,
                      borderRadius: 8.0,
                      margin:
                          EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
                      hidesUnderline: true,
                      isOverButton: false,
                      isSearchable: true,
                      isMultiSelect: false,
                    );
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Juvenile Team?',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).coachSmartGrey,
                            fontSize: 15.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                    ),
                    Switch.adaptive(
                      value: _model.switchJuvenileValue!,
                      onChanged: (newValue) async {
                        safeSetState(
                            () => _model.switchJuvenileValue = newValue);
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor:
                          FlutterFlowTheme.of(context).coachSmartGreen,
                      inactiveTrackColor:
                          FlutterFlowTheme.of(context).coachSmartGrey,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).coachSmartWhite,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Female Team?',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.inter(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).coachSmartGrey,
                            fontSize: 15.0,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                          ),
                    ),
                    Switch.adaptive(
                      value: _model.switchFemaleValue!,
                      onChanged: (newValue) async {
                        safeSetState(
                            () => _model.switchFemaleValue = newValue);
                      },
                      activeColor: FlutterFlowTheme.of(context).alternate,
                      activeTrackColor:
                          FlutterFlowTheme.of(context).coachSmartGreen,
                      inactiveTrackColor:
                          FlutterFlowTheme.of(context).coachSmartGrey,
                      inactiveThumbColor:
                          FlutterFlowTheme.of(context).coachSmartWhite,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                        child: FFButtonWidget(
                          onPressed: () async {
                            logFirebaseEvent(
                                'CREATE_TEAM_PAGE_createTeamButton_ON_TAP');
                            if (_model.teamNameInputTextController.text == '') {
                              // Team Name Blank
                              logFirebaseEvent(
                                  'createTeamButton_TeamNameBlank');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Team Name must not be empty',
                                    style: TextStyle(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                    ),
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                  backgroundColor: FlutterFlowTheme.of(context)
                                      .coachSmartGreen,
                                ),
                              );
                            } else {
                              if (_model.dropDownClubValue != null) {
                                // Create New Team
                                logFirebaseEvent(
                                    'createTeamButton_CreateNewTeam');
                                _model.newTeamRow = await TeamsTable().insert({
                                  'created_at': supaSerialize<DateTime>(
                                      dateTimeFromSecondsSinceEpoch(
                                          getCurrentTimestamp
                                              .secondsSinceEpoch)),
                                  'team_name':
                                      _model.teamNameInputTextController.text,
                                  'team_juvenile': _model.switchJuvenileValue,
                                  'team_female': _model.switchFemaleValue,
                                  'club_id': _model.dropDownClubValue,
                                });
                                logFirebaseEvent(
                                    'createTeamButton_backend_call');
                                await SquadsTable().insert({
                                  'created_at': supaSerialize<DateTime>(
                                      getCurrentTimestamp),
                                  'team_id': _model.newTeamRow?.teamId,
                                  'squad_name': 'No Team',
                                  'squad_colour': '',
                                  'squad_image':
                                      'https://gyfporsbdftvtakdvukt.supabase.co/storage/v1/object/sign/coachsmartimages/Grey%20Team.png?token=eyJraWQiOiJzdG9yYWdlLXVybC1zaWduaW5nLWtleV82OTA4NmRkYy01MWQ3LTQ1NzUtYWYwMC1mZjQxYmMyNDU2YWMiLCJhbGciOiJIUzI1NiJ9.eyJ1cmwiOiJjb2FjaHNtYXJ0aW1hZ2VzL0dyZXkgVGVhbS5wbmciLCJpYXQiOjE3NTY0NDg1OTgsImV4cCI6MjYyMDQ0ODU5OH0.LRFMMpY8ifKkQDGxwMhKArQeyz-__9SIWn-1bQG0rA4',
                                });
                                // Find Player Role
                                logFirebaseEvent(
                                    'createTeamButton_FindPlayerRole');
                                _model.outputQueryPlayer =
                                    await RolesTable().queryRows(
                                  queryFn: (q) => q.eqOrNull(
                                    'role_name',
                                    'Player',
                                  ),
                                );
                                // Create Default Player Role
                                logFirebaseEvent(
                                    'createTeamButton_CreateDefaultPlayerRole');
                                await TeamRolesLinkTable().insert({
                                  'created_at': supaSerialize<DateTime>(
                                      getCurrentTimestamp),
                                  'team_id': _model.newTeamRow?.teamId,
                                  'role_id': _model
                                      .outputQueryPlayer?.firstOrNull?.roleId,
                                });
                                // Find Admin Role
                                logFirebaseEvent(
                                    'createTeamButton_FindAdminRole');
                                _model.outputQueryAdmin =
                                    await RolesTable().queryRows(
                                  queryFn: (q) => q.eqOrNull(
                                    'role_name',
                                    'Admin',
                                  ),
                                );
                                // Create Default Admin Role
                                logFirebaseEvent(
                                    'createTeamButton_CreateDefaultAdminRole');
                                await TeamRolesLinkTable().insert({
                                  'created_at': supaSerialize<DateTime>(
                                      getCurrentTimestamp),
                                  'team_id': _model.newTeamRow?.teamId,
                                  'role_id': _model
                                      .outputQueryAdmin?.firstOrNull?.roleId,
                                });
                                // Find Coach Role
                                logFirebaseEvent(
                                    'createTeamButton_FindCoachRole');
                                _model.outputQueryCoach =
                                    await RolesTable().queryRows(
                                  queryFn: (q) => q.eqOrNull(
                                    'role_name',
                                    'Coach',
                                  ),
                                );
                                // Create Default Coach Role
                                logFirebaseEvent(
                                    'createTeamButton_CreateDefaultCoachRole');
                                await TeamRolesLinkTable().insert({
                                  'created_at': supaSerialize<DateTime>(
                                      getCurrentTimestamp),
                                  'team_id': _model.newTeamRow?.teamId,
                                  'role_id': _model
                                      .outputQueryCoach?.firstOrNull?.roleId,
                                });
                                if (_model.switchFemaleValue!) {
                                  // Find FLO Role
                                  logFirebaseEvent(
                                      'createTeamButton_FindFLORole');
                                  _model.outputQueryFLO =
                                      await RolesTable().queryRows(
                                    queryFn: (q) => q.eqOrNull(
                                      'role_name',
                                      'FLO',
                                    ),
                                  );
                                  // Create Default Player Role
                                  logFirebaseEvent(
                                      'createTeamButton_CreateDefaultPlayerRole');
                                  await TeamRolesLinkTable().insert({
                                    'created_at': supaSerialize<DateTime>(
                                        getCurrentTimestamp),
                                    'team_id': _model.newTeamRow?.teamId,
                                    'role_id': _model
                                        .outputQueryFLO?.firstOrNull?.roleId,
                                  });
                                }
                                // Confirm Created
                                logFirebaseEvent(
                                    'createTeamButton_ConfirmCreated');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'New Team Created',
                                      style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    duration: Duration(milliseconds: 4000),
                                    backgroundColor:
                                        FlutterFlowTheme.of(context)
                                            .coachSmartGreen,
                                  ),
                                );
                                logFirebaseEvent(
                                    'createTeamButton_navigate_to');

                                context.pushNamed(
                                  JoinTeamWidget.routeName,
                                  queryParameters: {
                                    'pageParamJoiningCode': serializeParam(
                                      _model.newTeamRow?.teamUniqueCode,
                                      ParamType.String,
                                    ),
                                  }.withoutNulls,
                                );
                              } else {
                                // Confirm Created
                                logFirebaseEvent(
                                    'createTeamButton_ConfirmCreated');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'You must select a club',
                                      style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    duration: Duration(milliseconds: 4000),
                                    backgroundColor:
                                        FlutterFlowTheme.of(context)
                                            .coachSmartGreen,
                                  ),
                                );
                              }
                            }

                            safeSetState(() {});
                          },
                          text: 'Create Team',
                          icon: Icon(
                            Icons.people_alt_sharp,
                            size: 24.0,
                          ),
                          options: FFButtonOptions(
                            width: 170.0,
                            height: 40.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color:
                                FlutterFlowTheme.of(context).coachSmartMidBlack,
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
                              color:
                                  FlutterFlowTheme.of(context).coachSmartGreen,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          showLoadingIndicator: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ].divide(SizedBox(height: 10.0)),
            ),
          ),
        ),
      ),
    );
  }
}
