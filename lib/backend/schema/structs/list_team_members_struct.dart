// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ListTeamMembersStruct extends FFFirebaseStruct {
  ListTeamMembersStruct({
    List<RoleGroupsStruct>? roleGroups,
    int? userHighestRoleLevel,
    String? teamUniqueCode,
    int? teamId,
    String? teamName,
    List<ClubCodesStruct>? clubCodes,
    int? defaultCode,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _roleGroups = roleGroups,
        _userHighestRoleLevel = userHighestRoleLevel,
        _teamUniqueCode = teamUniqueCode,
        _teamId = teamId,
        _teamName = teamName,
        _clubCodes = clubCodes,
        _defaultCode = defaultCode,
        super(firestoreUtilData);

  // "role_groups" field.
  List<RoleGroupsStruct>? _roleGroups;
  List<RoleGroupsStruct> get roleGroups => _roleGroups ?? const [];
  set roleGroups(List<RoleGroupsStruct>? val) => _roleGroups = val;

  void updateRoleGroups(Function(List<RoleGroupsStruct>) updateFn) {
    updateFn(_roleGroups ??= []);
  }

  bool hasRoleGroups() => _roleGroups != null;

  // "user_highest_role_level" field.
  int? _userHighestRoleLevel;
  int get userHighestRoleLevel => _userHighestRoleLevel ?? 0;
  set userHighestRoleLevel(int? val) => _userHighestRoleLevel = val;

  void incrementUserHighestRoleLevel(int amount) =>
      userHighestRoleLevel = userHighestRoleLevel + amount;

  bool hasUserHighestRoleLevel() => _userHighestRoleLevel != null;

  // "team_unique_code" field.
  String? _teamUniqueCode;
  String get teamUniqueCode => _teamUniqueCode ?? '';
  set teamUniqueCode(String? val) => _teamUniqueCode = val;

  bool hasTeamUniqueCode() => _teamUniqueCode != null;

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

  // "club_codes" field.
  List<ClubCodesStruct>? _clubCodes;
  List<ClubCodesStruct> get clubCodes => _clubCodes ?? const [];
  set clubCodes(List<ClubCodesStruct>? val) => _clubCodes = val;

  void updateClubCodes(Function(List<ClubCodesStruct>) updateFn) {
    updateFn(_clubCodes ??= []);
  }

  bool hasClubCodes() => _clubCodes != null;

  // "default_code" field.
  int? _defaultCode;
  int get defaultCode => _defaultCode ?? 0;
  set defaultCode(int? val) => _defaultCode = val;

  void incrementDefaultCode(int amount) => defaultCode = defaultCode + amount;

  bool hasDefaultCode() => _defaultCode != null;

  static ListTeamMembersStruct fromMap(Map<String, dynamic> data) =>
      ListTeamMembersStruct(
        roleGroups: getStructList(
          data['role_groups'],
          RoleGroupsStruct.fromMap,
        ),
        userHighestRoleLevel: castToType<int>(data['user_highest_role_level']),
        teamUniqueCode: data['team_unique_code'] as String?,
        teamId: castToType<int>(data['team_id']),
        teamName: data['team_name'] as String?,
        clubCodes: getStructList(
          data['club_codes'],
          ClubCodesStruct.fromMap,
        ),
        defaultCode: castToType<int>(data['default_code']),
      );

  static ListTeamMembersStruct? maybeFromMap(dynamic data) => data is Map
      ? ListTeamMembersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'role_groups': _roleGroups?.map((e) => e.toMap()).toList(),
        'user_highest_role_level': _userHighestRoleLevel,
        'team_unique_code': _teamUniqueCode,
        'team_id': _teamId,
        'team_name': _teamName,
        'club_codes': _clubCodes?.map((e) => e.toMap()).toList(),
        'default_code': _defaultCode,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'role_groups': serializeParam(
          _roleGroups,
          ParamType.DataStruct,
          isList: true,
        ),
        'user_highest_role_level': serializeParam(
          _userHighestRoleLevel,
          ParamType.int,
        ),
        'team_unique_code': serializeParam(
          _teamUniqueCode,
          ParamType.String,
        ),
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'club_codes': serializeParam(
          _clubCodes,
          ParamType.DataStruct,
          isList: true,
        ),
        'default_code': serializeParam(
          _defaultCode,
          ParamType.int,
        ),
      }.withoutNulls;

  static ListTeamMembersStruct fromSerializableMap(Map<String, dynamic> data) =>
      ListTeamMembersStruct(
        roleGroups: deserializeStructParam<RoleGroupsStruct>(
          data['role_groups'],
          ParamType.DataStruct,
          true,
          structBuilder: RoleGroupsStruct.fromSerializableMap,
        ),
        userHighestRoleLevel: deserializeParam(
          data['user_highest_role_level'],
          ParamType.int,
          false,
        ),
        teamUniqueCode: deserializeParam(
          data['team_unique_code'],
          ParamType.String,
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
        clubCodes: deserializeStructParam<ClubCodesStruct>(
          data['club_codes'],
          ParamType.DataStruct,
          true,
          structBuilder: ClubCodesStruct.fromSerializableMap,
        ),
        defaultCode: deserializeParam(
          data['default_code'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'ListTeamMembersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is ListTeamMembersStruct &&
        listEquality.equals(roleGroups, other.roleGroups) &&
        userHighestRoleLevel == other.userHighestRoleLevel &&
        teamUniqueCode == other.teamUniqueCode &&
        teamId == other.teamId &&
        teamName == other.teamName &&
        listEquality.equals(clubCodes, other.clubCodes) &&
        defaultCode == other.defaultCode;
  }

  @override
  int get hashCode => const ListEquality().hash([
        roleGroups,
        userHighestRoleLevel,
        teamUniqueCode,
        teamId,
        teamName,
        clubCodes,
        defaultCode
      ]);
}

ListTeamMembersStruct createListTeamMembersStruct({
  int? userHighestRoleLevel,
  String? teamUniqueCode,
  int? teamId,
  String? teamName,
  int? defaultCode,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ListTeamMembersStruct(
      userHighestRoleLevel: userHighestRoleLevel,
      teamUniqueCode: teamUniqueCode,
      teamId: teamId,
      teamName: teamName,
      defaultCode: defaultCode,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ListTeamMembersStruct? updateListTeamMembersStruct(
  ListTeamMembersStruct? listTeamMembers, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    listTeamMembers
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addListTeamMembersStructData(
  Map<String, dynamic> firestoreData,
  ListTeamMembersStruct? listTeamMembers,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (listTeamMembers == null) {
    return;
  }
  if (listTeamMembers.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && listTeamMembers.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final listTeamMembersData =
      getListTeamMembersFirestoreData(listTeamMembers, forFieldValue);
  final nestedData =
      listTeamMembersData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = listTeamMembers.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getListTeamMembersFirestoreData(
  ListTeamMembersStruct? listTeamMembers, [
  bool forFieldValue = false,
]) {
  if (listTeamMembers == null) {
    return {};
  }
  final firestoreData = mapToFirestore(listTeamMembers.toMap());

  // Add any Firestore field values
  mapToFirestore(listTeamMembers.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getListTeamMembersListFirestoreData(
  List<ListTeamMembersStruct>? listTeamMemberss,
) =>
    listTeamMemberss
        ?.map((e) => getListTeamMembersFirestoreData(e, true))
        .toList() ??
    [];
