// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class TeamsStruct extends FFFirebaseStruct {
  TeamsStruct({
    int? teamId,
    String? teamName,
    String? teamRoleName,
    int? teamHighestRoleLevel,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _teamId = teamId,
        _teamName = teamName,
        _teamRoleName = teamRoleName,
        _teamHighestRoleLevel = teamHighestRoleLevel,
        super(firestoreUtilData);

  // "team_id" field.
  int? _teamId;
  int get teamId => _teamId ?? 0;
  set teamId(int? val) => _teamId = val;

  void incrementTeamId(int amount) => teamId = teamId + amount;

  bool hasTeamId() => _teamId != null;

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

  // "team_role_name" field.
  String? _teamRoleName;
  String get teamRoleName => _teamRoleName ?? '';
  set teamRoleName(String? val) => _teamRoleName = val;

  bool hasTeamRoleName() => _teamRoleName != null;

  // "team_highest_role_level" field.
  int? _teamHighestRoleLevel;
  int get teamHighestRoleLevel => _teamHighestRoleLevel ?? 0;
  set teamHighestRoleLevel(int? val) => _teamHighestRoleLevel = val;

  void incrementTeamHighestRoleLevel(int amount) =>
      teamHighestRoleLevel = teamHighestRoleLevel + amount;

  bool hasTeamHighestRoleLevel() => _teamHighestRoleLevel != null;

  static TeamsStruct fromMap(Map<String, dynamic> data) => TeamsStruct(
        teamId: castToType<int>(data['team_id']),
        teamName: data['team_name'] as String?,
        teamRoleName: data['team_role_name'] as String?,
        teamHighestRoleLevel: castToType<int>(data['team_highest_role_level']),
      );

  static TeamsStruct? maybeFromMap(dynamic data) =>
      data is Map ? TeamsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'team_id': _teamId,
        'team_name': _teamName,
        'team_role_name': _teamRoleName,
        'team_highest_role_level': _teamHighestRoleLevel,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'team_role_name': serializeParam(
          _teamRoleName,
          ParamType.String,
        ),
        'team_highest_role_level': serializeParam(
          _teamHighestRoleLevel,
          ParamType.int,
        ),
      }.withoutNulls;

  static TeamsStruct fromSerializableMap(Map<String, dynamic> data) =>
      TeamsStruct(
        teamId: deserializeParam(
          data['team_id'],
          ParamType.int,
          false,
        ),
        teamName: deserializeParam(
          data['team_name'],
          ParamType.String,
          false,
        ),
        teamRoleName: deserializeParam(
          data['team_role_name'],
          ParamType.String,
          false,
        ),
        teamHighestRoleLevel: deserializeParam(
          data['team_highest_role_level'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'TeamsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is TeamsStruct &&
        teamId == other.teamId &&
        teamName == other.teamName &&
        teamRoleName == other.teamRoleName &&
        teamHighestRoleLevel == other.teamHighestRoleLevel;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([teamId, teamName, teamRoleName, teamHighestRoleLevel]);
}

TeamsStruct createTeamsStruct({
  int? teamId,
  String? teamName,
  String? teamRoleName,
  int? teamHighestRoleLevel,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    TeamsStruct(
      teamId: teamId,
      teamName: teamName,
      teamRoleName: teamRoleName,
      teamHighestRoleLevel: teamHighestRoleLevel,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

TeamsStruct? updateTeamsStruct(
  TeamsStruct? teams, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    teams
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addTeamsStructData(
  Map<String, dynamic> firestoreData,
  TeamsStruct? teams,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (teams == null) {
    return;
  }
  if (teams.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && teams.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final teamsData = getTeamsFirestoreData(teams, forFieldValue);
  final nestedData = teamsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = teams.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getTeamsFirestoreData(
  TeamsStruct? teams, [
  bool forFieldValue = false,
]) {
  if (teams == null) {
    return {};
  }
  final firestoreData = mapToFirestore(teams.toMap());

  // Add any Firestore field values
  mapToFirestore(teams.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getTeamsListFirestoreData(
  List<TeamsStruct>? teamss,
) =>
    teamss?.map((e) => getTeamsFirestoreData(e, true)).toList() ?? [];
