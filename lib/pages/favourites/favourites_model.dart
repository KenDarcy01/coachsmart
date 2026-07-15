import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'favourites_widget.dart' show FavouritesWidget;
import 'package:flutter/material.dart';

class FavouritesModel extends FlutterFlowModel<FavouritesWidget> {
  ///  Local state fields for this page.

  List<int> varGameList = [];
  void addToVarGameList(int item) => varGameList.add(item);
  void removeFromVarGameList(int item) => varGameList.remove(item);
  void removeAtIndexFromVarGameList(int index) => varGameList.removeAt(index);
  void insertAtIndexInVarGameList(int index, int item) =>
      varGameList.insert(index, item);
  void updateVarGameListAtIndex(int index, Function(int) updateFn) =>
      varGameList[index] = updateFn(varGameList[index]);

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (getUserFavourites)] action in Favourites widget.
  ApiCallResponse? apiUserFavourites;
  // Stores action output result for [Backend Call - Query Rows] action in Container widget.
  List<GamesRow>? queryGame;
  // State field(s) for Checkbox widget.
  Map<UserFavouritesStruct, bool> checkboxValueMap = {};
  List<UserFavouritesStruct> get checkboxCheckedItems =>
      checkboxValueMap.entries.where((e) => e.value).map((e) => e.key).toList();

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
