import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'live_updates_model.dart';
export 'live_updates_model.dart';

class LiveUpdatesWidget extends StatefulWidget {
  const LiveUpdatesWidget({
    super.key,
    this.paramEventId,
  });

  final int? paramEventId;

  static String routeName = 'LiveUpdates';
  static String routePath = 'liveUpdate';

  @override
  State<LiveUpdatesWidget> createState() => _LiveUpdatesWidgetState();
}

class _LiveUpdatesWidgetState extends State<LiveUpdatesWidget> {
  late LiveUpdatesModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LiveUpdatesModel());

    logFirebaseEvent('screen_view', parameters: {'screen_name': 'LiveUpdates'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('LIVE_UPDATES_LiveUpdates_ON_INIT_STATE');
      logFirebaseEvent('LiveUpdates_wait__delay');
      await Future.delayed(
        Duration(
          milliseconds: 4000,
        ),
      );
      logFirebaseEvent('LiveUpdates_update_page_state');
      _model.varPageLoaded = false;
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryText,
          automaticallyImplyLeading: false,
          title: Text(
            'Live Updates',
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
                  'https://coach-smart-new-mpqa5l.web.app/webviews/match-live.html?token=${currentJwtToken}',
              onPageReady: () async {},
              onComplete: () async {},
              onLogout: () async {
                logFirebaseEvent('LIVE_UPDATES_Container_9mwrx3it_CALLBACK');
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
