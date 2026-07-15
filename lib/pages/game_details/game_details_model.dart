import '/backend/api_requests/api_calls.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'game_details_widget.dart' show GameDetailsWidget;
import 'package:flutter/material.dart';

class GameDetailsModel extends FlutterFlowModel<GameDetailsWidget> {
  ///  Local state fields for this page.

  bool? varFavourite;

  List<int> varFavList = [];
  void addToVarFavList(int item) => varFavList.add(item);
  void removeFromVarFavList(int item) => varFavList.remove(item);
  void removeAtIndexFromVarFavList(int index) => varFavList.removeAt(index);
  void insertAtIndexInVarFavList(int index, int item) =>
      varFavList.insert(index, item);
  void updateVarFavListAtIndex(int index, Function(int) updateFn) =>
      varFavList[index] = updateFn(varFavList[index]);

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - Query Rows] action in GameDetails widget.
  List<UserGameLinkRow>? queryGame;
  // Stores action output result for [Backend Call - API (getUserFavourites)] action in IconButton widget.
  ApiCallResponse? apiUserFavourites;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
