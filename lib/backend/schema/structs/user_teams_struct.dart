// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class UserTeamsStruct extends FFFirebaseStruct {
  UserTeamsStruct({
    int? clubId,
    int? teamId,
    String? teamName,
    String? profilePic,
    bool? teamFemale,
    String? teamUniqueCode,
    int? userHighestRoleOnTeam,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _clubId = clubId,
        _teamId = teamId,
        _teamName = teamName,
        _profilePic = profilePic,
        _teamFemale = teamFemale,
        _teamUniqueCode = teamUniqueCode,
        _userHighestRoleOnTeam = userHighestRoleOnTeam,
        super(firestoreUtilData);

  // "club_id" field.
  int? _clubId;
  int get clubId => _clubId ?? 0;
  set clubId(int? val) => _clubId = val;

  void incrementClubId(int amount) => clubId = clubId + amount;

  bool hasClubId() => _clubId != null;

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

  // "profile_pic" field.
  String? _profilePic;
  String get profilePic => _profilePic ?? '';
  set profilePic(String? val) => _profilePic = val;

  bool hasProfilePic() => _profilePic != null;

  // "team_female" field.
  bool? _teamFemale;
  bool get teamFemale => _teamFemale ?? false;
  set teamFemale(bool? val) => _teamFemale = val;

  bool hasTeamFemale() => _teamFemale != null;

  // "team_unique_code" field.
  String? _teamUniqueCode;
  String get teamUniqueCode => _teamUniqueCode ?? '';
  set teamUniqueCode(String? val) => _teamUniqueCode = val;

  bool hasTeamUniqueCode() => _teamUniqueCode != null;

  // "user_highest_role_on_team" field.
  int? _userHighestRoleOnTeam;
  int get userHighestRoleOnTeam => _userHighestRoleOnTeam ?? 0;
  set userHighestRoleOnTeam(int? val) => _userHighestRoleOnTeam = val;

  void incrementUserHighestRoleOnTeam(int amount) =>
      userHighestRoleOnTeam = userHighestRoleOnTeam + amount;

  bool hasUserHighestRoleOnTeam() => _userHighestRoleOnTeam != null;

  static UserTeamsStruct fromMap(Map<String, dynamic> data) => UserTeamsStruct(
        clubId: castToType<int>(data['club_id']),
        teamId: castToType<int>(data['team_id']),
        teamName: data['team_name'] as String?,
        profilePic: data['profile_pic'] as String?,
        teamFemale: data['team_female'] as bool?,
        teamUniqueCode: data['team_unique_code'] as String?,
        userHighestRoleOnTeam:
            castToType<int>(data['user_highest_role_on_team']),
      );

  static UserTeamsStruct? maybeFromMap(dynamic data) => data is Map
      ? UserTeamsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'club_id': _clubId,
        'team_id': _teamId,
        'team_name': _teamName,
        'profile_pic': _profilePic,
        'team_female': _teamFemale,
        'team_unique_code': _teamUniqueCode,
        'user_highest_role_on_team': _userHighestRoleOnTeam,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'club_id': serializeParam(
          _clubId,
          ParamType.int,
        ),
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'profile_pic': serializeParam(
          _profilePic,
          ParamType.String,
        ),
        'team_female': serializeParam(
          _teamFemale,
          ParamType.bool,
        ),
        'team_unique_code': serializeParam(
          _teamUniqueCode,
          ParamType.String,
        ),
        'user_highest_role_on_team': serializeParam(
          _userHighestRoleOnTeam,
          ParamType.int,
        ),
      }.withoutNulls;

  static UserTeamsStruct fromSerializableMap(Map<String, dynamic> data) =>
      UserTeamsStruct(
        clubId: deserializeParam(
          data['club_id'],
          ParamType.int,
          false,
        ),
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
        profilePic: deserializeParam(
          data['profile_pic'],
          ParamType.String,
          false,
        ),
        teamFemale: deserializeParam(
          data['team_female'],
          ParamType.bool,
          false,
        ),
        teamUniqueCode: deserializeParam(
          data['team_unique_code'],
          ParamType.String,
          false,
        ),
        userHighestRoleOnTeam: deserializeParam(
          data['user_highest_role_on_team'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'UserTeamsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is UserTeamsStruct &&
        clubId == other.clubId &&
        teamId == other.teamId &&
        teamName == other.teamName &&
        profilePic == other.profilePic &&
        teamFemale == other.teamFemale &&
        teamUniqueCode == other.teamUniqueCode &&
        userHighestRoleOnTeam == other.userHighestRoleOnTeam;
  }

  @override
  int get hashCode => const ListEquality().hash([
        clubId,
        teamId,
        teamName,
        profilePic,
        teamFemale,
        teamUniqueCode,
        userHighestRoleOnTeam
      ]);
}

UserTeamsStruct createUserTeamsStruct({
  int? clubId,
  int? teamId,
  String? teamName,
  String? profilePic,
  bool? teamFemale,
  String? teamUniqueCode,
  int? userHighestRoleOnTeam,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserTeamsStruct(
      clubId: clubId,
      teamId: teamId,
      teamName: teamName,
      profilePic: profilePic,
      teamFemale: teamFemale,
      teamUniqueCode: teamUniqueCode,
      userHighestRoleOnTeam: userHighestRoleOnTeam,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserTeamsStruct? updateUserTeamsStruct(
  UserTeamsStruct? userTeams, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userTeams
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserTeamsStructData(
  Map<String, dynamic> firestoreData,
  UserTeamsStruct? userTeams,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userTeams == null) {
    return;
  }
  if (userTeams.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && userTeams.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userTeamsData = getUserTeamsFirestoreData(userTeams, forFieldValue);
  final nestedData = userTeamsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = userTeams.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserTeamsFirestoreData(
  UserTeamsStruct? userTeams, [
  bool forFieldValue = false,
]) {
  if (userTeams == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userTeams.toMap());

  // Add any Firestore field values
  mapToFirestore(userTeams.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserTeamsListFirestoreData(
  List<UserTeamsStruct>? userTeamss,
) =>
    userTeamss?.map((e) => getUserTeamsFirestoreData(e, true)).toList() ?? [];
