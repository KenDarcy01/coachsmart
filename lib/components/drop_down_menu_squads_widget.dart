import '/backend/supabase/supabase.dart';
import '/components/squad_list_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'drop_down_menu_squads_model.dart';
export 'drop_down_menu_squads_model.dart';

class DropDownMenuSquadsWidget extends StatefulWidget {
  const DropDownMenuSquadsWidget({
    super.key,
    required this.parTeamID,
    required this.passBackSquadID,
  });

  final int? parTeamID;
  final Future Function(int outputSelectedSquadID)? passBackSquadID;

  @override
  State<DropDownMenuSquadsWidget> createState() =>
      _DropDownMenuSquadsWidgetState();
}

class _DropDownMenuSquadsWidgetState extends State<DropDownMenuSquadsWidget> {
  late DropDownMenuSquadsModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DropDownMenuSquadsModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    // On component dispose action.
    () async {
      logFirebaseEvent('DROP_DOWN_MENU_SQUADS_dropDownMenuSquads');
      logFirebaseEvent('dropDownMenuSquads_execute_callback');
      await widget.passBackSquadID?.call(
        _model.callBackSquad!,
      );
    }();

    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.0),
      child: Container(
        width: 220.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).coachSmartLightBlack,
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
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(15.0, 15.0, 15.0, 15.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FutureBuilder<List<SquadsRow>>(
                future: SquadsTable().queryRows(
                  queryFn: (q) => q
                      .eqOrNull(
                        'team_id',
                        widget.parTeamID,
                      )
                      .order('squad_list_seq', ascending: true),
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
                  List<SquadsRow> listViewSquadsRowList = snapshot.data!;

                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    scrollDirection: Axis.vertical,
                    itemCount: listViewSquadsRowList.length,
                    itemBuilder: (context, listViewIndex) {
                      final listViewSquadsRow =
                          listViewSquadsRowList[listViewIndex];
                      return SquadListItemWidget(
                        key: Key(
                            'Key2uy_${listViewIndex}_of_${listViewSquadsRowList.length}'),
                        inputSquadImage: listViewSquadsRow.squadImage,
                        inputSquadName: valueOrDefault<String>(
                          listViewSquadsRow.squadName,
                          'squad_name',
                        ),
                        inputSquadID: listViewSquadsRow.squadId,
                        callBackSquad: (outputSquadID) async {
                          logFirebaseEvent(
                              'DROP_DOWN_MENU_SQUADS_Container_2uya4wlq');
                          logFirebaseEvent('squadListItem_execute_callback');
                          await widget.passBackSquadID?.call(
                            outputSquadID,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
