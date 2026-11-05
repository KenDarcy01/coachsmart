import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'session_planner_model.dart';
export 'session_planner_model.dart';

class SessionPlannerWidget extends StatefulWidget {
  const SessionPlannerWidget({
    super.key,
    required this.pEventId,
  });

  final int? pEventId;

  static String routeName = 'SessionPlanner';
  static String routePath = 'sessionPlanner';

  @override
  State<SessionPlannerWidget> createState() => _SessionPlannerWidgetState();
}

class _SessionPlannerWidgetState extends State<SessionPlannerWidget> {
  late SessionPlannerModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SessionPlannerModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'SessionPlanner'});
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
            'Session Planner',
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
                  'https://coach-smart-new-mpqa5l.web.app/webviews/session-plan.html?event_id=${widget.pEventId?.toString()}&user_id=${currentUserUid}&token=${currentJwtToken}',
              onPageReady: () async {},
              onComplete: () async {},
              onLogout: () async {
                logFirebaseEvent('SESSION_PLANNER_Container_wqdh16p3_CALLB');
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
