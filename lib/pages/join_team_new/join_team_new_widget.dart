import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'join_team_new_model.dart';
export 'join_team_new_model.dart';

class JoinTeamNewWidget extends StatefulWidget {
  const JoinTeamNewWidget({super.key});

  static String routeName = 'JoinTeamNew';
  static String routePath = 'joinTeamNew';

  @override
  State<JoinTeamNewWidget> createState() => _JoinTeamNewWidgetState();
}

class _JoinTeamNewWidgetState extends State<JoinTeamNewWidget> {
  late JoinTeamNewModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => JoinTeamNewModel());

    logFirebaseEvent('screen_view', parameters: {'screen_name': 'JoinTeamNew'});
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
              Icons.chevron_left,
              color: Color(0xFF87C232),
              size: 40.0,
            ),
            onPressed: () async {
              logFirebaseEvent('JOIN_TEAM_NEW_chevron_left_ICN_ON_TAP');
              logFirebaseEvent('IconButton_backend_call');
              _model.apiTeamSummary = await GetUserTeamSummaryCall.call(
                supabaseJWTtoken: currentJwtToken,
                pUserId: currentUserUid,
              );

              if ((_model.apiTeamSummary?.succeeded ?? true)) {
                logFirebaseEvent('IconButton_update_app_state');
                FFAppState().userTeamSummary =
                    UserTeamSummaryStruct.maybeFromMap(
                        (_model.apiTeamSummary?.jsonBody ?? ''))!;
                safeSetState(() {});
              }
              logFirebaseEvent('IconButton_navigate_back');
              context.pop();

              safeSetState(() {});
            },
          ),
          title: Text(
            'Join Team',
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
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: custom_widgets.NativeWebView(
              width: double.infinity,
              height: double.infinity,
              url:
                  'https://coach-smart-new-mpqa5l.web.app/webviews/join-team.html?access_token=${currentJwtToken}',
              onPageReady: () async {},
              onComplete: () async {},
              onLogout: () async {},
            ),
          ),
        ),
      ),
    );
  }
}
