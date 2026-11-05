import '/auth/supabase_auth/auth_util.dart';
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
              onLogout: () async {
                logFirebaseEvent('JOIN_TEAM_NEW_Container_i7hhstvc_CALLBAC');
                logFirebaseEvent('NativeWebView_navigate_back');
                context.safePop();
              },
            ),
          ),
        ),
      ),
    );
  }
}
