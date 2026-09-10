import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'team_selector_model.dart';
export 'team_selector_model.dart';

class TeamSelectorWidget extends StatefulWidget {
  const TeamSelectorWidget({
    super.key,
    required this.eventId,
    required this.teamId,
    required this.squadId,
    required this.currentAuthToken,
  });

  final int? eventId;
  final int? teamId;
  final int? squadId;
  final String? currentAuthToken;

  static String routeName = 'TeamSelector';
  static String routePath = 'teamSelector';

  @override
  State<TeamSelectorWidget> createState() => _TeamSelectorWidgetState();
}

class _TeamSelectorWidgetState extends State<TeamSelectorWidget> {
  late TeamSelectorModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TeamSelectorModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'TeamSelector'});
    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      logFirebaseEvent('TEAM_SELECTOR_TeamSelector_ON_INIT_STATE');
      logFirebaseEvent('TeamSelector_wait__delay');
      await Future.delayed(
        Duration(
          milliseconds: 4000,
        ),
      );
      logFirebaseEvent('TeamSelector_update_page_state');
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
              logFirebaseEvent('TEAM_SELECTOR_chevron_left_ICN_ON_TAP');
              logFirebaseEvent('IconButton_navigate_back');
              context.safePop();
            },
          ),
          title: Text(
            'Team Selector',
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
                  'https://coach-smart-new-mpqa5l.web.app/webviews/team_selector.html?teamId=${widget.teamId?.toString()}&eventId=${widget.eventId?.toString()}&squadId=${widget.squadId?.toString()}&token=${widget.currentAuthToken}',
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
