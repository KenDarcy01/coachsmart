import '/auth/supabase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'resources_model.dart';
export 'resources_model.dart';

class ResourcesWidget extends StatefulWidget {
  const ResourcesWidget({
    super.key,
    required this.currentAuthToken,
  });

  final String? currentAuthToken;

  static String routeName = 'Resources';
  static String routePath = 'resources';

  @override
  State<ResourcesWidget> createState() => _ResourcesWidgetState();
}

class _ResourcesWidgetState extends State<ResourcesWidget> {
  late ResourcesModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ResourcesModel());

    logFirebaseEvent('screen_view', parameters: {'screen_name': 'Resources'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('RESOURCES_PAGE_Resources_ON_INIT_STATE');
      logFirebaseEvent('Resources_wait__delay');
      await Future.delayed(
        Duration(
          milliseconds: 4000,
        ),
      );
      logFirebaseEvent('Resources_update_page_state');
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
            'Resources',
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
                  'https://coach-smart-new-mpqa5l.web.app/webviews/games-resource.html?token=${currentJwtToken}',
              onPageReady: () async {},
              onComplete: () async {},
              onLogout: () async {
                logFirebaseEvent('RESOURCES_Container_865w2281_CALLBACK');
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
