import '/auth/supabase_auth/auth_util.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'drop_down_menu_notifications_model.dart';
export 'drop_down_menu_notifications_model.dart';

class DropDownMenuNotificationsWidget extends StatefulWidget {
  const DropDownMenuNotificationsWidget({
    super.key,
    required this.paramNotificationID,
    required this.passBackRead,
  });

  final int? paramNotificationID;
  final Future Function()? passBackRead;

  @override
  State<DropDownMenuNotificationsWidget> createState() =>
      _DropDownMenuNotificationsWidgetState();
}

class _DropDownMenuNotificationsWidgetState
    extends State<DropDownMenuNotificationsWidget> {
  late DropDownMenuNotificationsModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DropDownMenuNotificationsModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Container(
        width: 200.0,
        height: 62.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).coachSmartMidBlack,
          boxShadow: [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x33000000),
              offset: Offset(
                0.0,
                2.0,
              ),
            )
          ],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(10.0, 10.0, 10.0, 10.0),
              child: InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  logFirebaseEvent('DROP_DOWN_MENU_NOTIFICATIONS_replaceWidg');
                  logFirebaseEvent('replaceWidget_backend_call');
                  await NotificationsTable().update(
                    data: {
                      'is_read': false,
                    },
                    matchingRows: (rows) => rows.eqOrNull(
                      'id',
                      widget.paramNotificationID,
                    ),
                  );
                  logFirebaseEvent('replaceWidget_execute_callback');
                  await widget.passBackRead?.call();
                  logFirebaseEvent('replaceWidget_backend_call');
                  _model.outputUnreadNotifications =
                      await NotificationsTable().queryRows(
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
                  logFirebaseEvent('replaceWidget_custom_action');
                  _model.outputBadgeUpdate = await actions.updateAppBadge(
                    _model.outputUnreadNotifications?.length,
                  );
                  logFirebaseEvent('replaceWidget_close_dialog_drawer_etc');
                  Navigator.pop(context);

                  safeSetState(() {});
                },
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).coachSmartLightBlack,
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              12.0, 0.0, 0.0, 0.0),
                          child: Icon(
                            Icons.mail_outline,
                            color: FlutterFlowTheme.of(context).alternate,
                            size: 25.0,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                12.0, 0.0, 0.0, 0.0),
                            child: Text(
                              'Mark as Unread',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    fontSize: 14.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
