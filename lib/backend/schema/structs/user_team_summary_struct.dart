// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UserTeamSummaryStruct extends FFFirebaseStruct {
  UserTeamSummaryStruct({
    List<TeamsStruct>? teams,
    int? overallHighestRoleLevel,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _teams = teams,
        _overallHighestRoleLevel = overallHighestRoleLevel,
        super(firestoreUtilData);

  // "teams" field.
  List<TeamsStruct>? _teams;
  List<TeamsStruct> get teams => _teams ?? const [];
  set teams(List<TeamsStruct>? val) => _teams = val;

  void updateTeams(Function(List<TeamsStruct>) updateFn) {
    updateFn(_teams ??= []);
  }

  bool hasTeams() => _teams != null;

  // "overall_highest_role_level" field.
  int? _overallHighestRoleLevel;
  int get overallHighestRoleLevel => _overallHighestRoleLevel ?? 0;
  set overallHighestRoleLevel(int? val) => _overallHighestRoleLevel = val;

  void incrementOverallHighestRoleLevel(int amount) =>
      overallHighestRoleLevel = overallHighestRoleLevel + amount;

  bool hasOverallHighestRoleLevel() => _overallHighestRoleLevel != null;

  static UserTeamSummaryStruct fromMap(Map<String, dynamic> data) =>
      UserTeamSummaryStruct(
        teams: getStructList(
          data['teams'],
          TeamsStruct.fromMap,
        ),
        overallHighestRoleLevel:
            castToType<int>(data['overall_highest_role_level']),
      );

  static UserTeamSummaryStruct? maybeFromMap(dynamic data) => data is Map
      ? UserTeamSummaryStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'teams': _teams?.map((e) => e.toMap()).toList(),
        'overall_highest_role_level': _overallHighestRoleLevel,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'teams': serializeParam(
          _teams,
          ParamType.DataStruct,
          isList: true,
        ),
        'overall_highest_role_level': serializeParam(
          _overallHighestRoleLevel,
          ParamType.int,
        ),
      }.withoutNulls;

  static UserTeamSummaryStruct fromSerializableMap(Map<String, dynamic> data) =>
      UserTeamSummaryStruct(
        teams: deserializeStructParam<TeamsStruct>(
          data['teams'],
          ParamType.DataStruct,
          true,
          structBuilder: TeamsStruct.fromSerializableMap,
        ),
        overallHighestRoleLevel: deserializeParam(
          data['overall_highest_role_level'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'UserTeamSummaryStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is UserTeamSummaryStruct &&
        listEquality.equals(teams, other.teams) &&
        overallHighestRoleLevel == other.overallHighestRoleLevel;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([teams, overallHighestRoleLevel]);
}

UserTeamSummaryStruct createUserTeamSummaryStruct({
  int? overallHighestRoleLevel,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserTeamSummaryStruct(
      overallHighestRoleLevel: overallHighestRoleLevel,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserTeamSummaryStruct? updateUserTeamSummaryStruct(
  UserTeamSummaryStruct? userTeamSummary, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userTeamSummary
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserTeamSummaryStructData(
  Map<String, dynamic> firestoreData,
  UserTeamSummaryStruct? userTeamSummary,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userTeamSummary == null) {
    return;
  }
  if (userTeamSummary.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && userTeamSummary.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userTeamSummaryData =
      getUserTeamSummaryFirestoreData(userTeamSummary, forFieldValue);
  final nestedData =
      userTeamSummaryData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = userTeamSummary.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserTeamSummaryFirestoreData(
  UserTeamSummaryStruct? userTeamSummary, [
  bool forFieldValue = false,
]) {
  if (userTeamSummary == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userTeamSummary.toMap());

  // Add any Firestore field values
  mapToFirestore(userTeamSummary.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserTeamSummaryListFirestoreData(
  List<UserTeamSummaryStruct>? userTeamSummarys,
) =>
    userTeamSummarys
        ?.map((e) => getUserTeamSummaryFirestoreData(e, true))
        .toList() ??
    [];
