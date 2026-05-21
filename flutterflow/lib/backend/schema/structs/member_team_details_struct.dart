// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MemberTeamDetailsStruct extends FFFirebaseStruct {
  MemberTeamDetailsStruct({
    int? memberId,
    String? firstName,
    String? lastName,
    String? profilePic,
    int? teamId,
    String? teamName,
    String? profilePicTeam,
    List<RolesStruct>? roles,
    List<LinkedUsersStruct>? linkedUsers,
    String? memberCode,
    String? teamCode,
    List<ValidTeamRolesStruct>? validTeamRoles,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _memberId = memberId,
        _firstName = firstName,
        _lastName = lastName,
        _profilePic = profilePic,
        _teamId = teamId,
        _teamName = teamName,
        _profilePicTeam = profilePicTeam,
        _roles = roles,
        _linkedUsers = linkedUsers,
        _memberCode = memberCode,
        _teamCode = teamCode,
        _validTeamRoles = validTeamRoles,
        super(firestoreUtilData);

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "first_name" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  set firstName(String? val) => _firstName = val;

  bool hasFirstName() => _firstName != null;

  // "last_name" field.
  String? _lastName;
  String get lastName => _lastName ?? '';
  set lastName(String? val) => _lastName = val;

  bool hasLastName() => _lastName != null;

  // "profile_pic" field.
  String? _profilePic;
  String get profilePic => _profilePic ?? '';
  set profilePic(String? val) => _profilePic = val;

  bool hasProfilePic() => _profilePic != null;

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

  // "profile_pic_team" field.
  String? _profilePicTeam;
  String get profilePicTeam => _profilePicTeam ?? '';
  set profilePicTeam(String? val) => _profilePicTeam = val;

  bool hasProfilePicTeam() => _profilePicTeam != null;

  // "roles" field.
  List<RolesStruct>? _roles;
  List<RolesStruct> get roles => _roles ?? const [];
  set roles(List<RolesStruct>? val) => _roles = val;

  void updateRoles(Function(List<RolesStruct>) updateFn) {
    updateFn(_roles ??= []);
  }

  bool hasRoles() => _roles != null;

  // "linked_users" field.
  List<LinkedUsersStruct>? _linkedUsers;
  List<LinkedUsersStruct> get linkedUsers => _linkedUsers ?? const [];
  set linkedUsers(List<LinkedUsersStruct>? val) => _linkedUsers = val;

  void updateLinkedUsers(Function(List<LinkedUsersStruct>) updateFn) {
    updateFn(_linkedUsers ??= []);
  }

  bool hasLinkedUsers() => _linkedUsers != null;

  // "member_code" field.
  String? _memberCode;
  String get memberCode => _memberCode ?? '';
  set memberCode(String? val) => _memberCode = val;

  bool hasMemberCode() => _memberCode != null;

  // "team_code" field.
  String? _teamCode;
  String get teamCode => _teamCode ?? '';
  set teamCode(String? val) => _teamCode = val;

  bool hasTeamCode() => _teamCode != null;

  // "valid_team_roles" field.
  List<ValidTeamRolesStruct>? _validTeamRoles;
  List<ValidTeamRolesStruct> get validTeamRoles => _validTeamRoles ?? const [];
  set validTeamRoles(List<ValidTeamRolesStruct>? val) => _validTeamRoles = val;

  void updateValidTeamRoles(Function(List<ValidTeamRolesStruct>) updateFn) {
    updateFn(_validTeamRoles ??= []);
  }

  bool hasValidTeamRoles() => _validTeamRoles != null;

  static MemberTeamDetailsStruct fromMap(Map<String, dynamic> data) =>
      MemberTeamDetailsStruct(
        memberId: castToType<int>(data['member_id']),
        firstName: data['first_name'] as String?,
        lastName: data['last_name'] as String?,
        profilePic: data['profile_pic'] as String?,
        teamId: castToType<int>(data['team_id']),
        teamName: data['team_name'] as String?,
        profilePicTeam: data['profile_pic_team'] as String?,
        roles: getStructList(
          data['roles'],
          RolesStruct.fromMap,
        ),
        linkedUsers: getStructList(
          data['linked_users'],
          LinkedUsersStruct.fromMap,
        ),
        memberCode: data['member_code'] as String?,
        teamCode: data['team_code'] as String?,
        validTeamRoles: getStructList(
          data['valid_team_roles'],
          ValidTeamRolesStruct.fromMap,
        ),
      );

  static MemberTeamDetailsStruct? maybeFromMap(dynamic data) => data is Map
      ? MemberTeamDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'member_id': _memberId,
        'first_name': _firstName,
        'last_name': _lastName,
        'profile_pic': _profilePic,
        'team_id': _teamId,
        'team_name': _teamName,
        'profile_pic_team': _profilePicTeam,
        'roles': _roles?.map((e) => e.toMap()).toList(),
        'linked_users': _linkedUsers?.map((e) => e.toMap()).toList(),
        'member_code': _memberCode,
        'team_code': _teamCode,
        'valid_team_roles': _validTeamRoles?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'first_name': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'last_name': serializeParam(
          _lastName,
          ParamType.String,
        ),
        'profile_pic': serializeParam(
          _profilePic,
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
        'profile_pic_team': serializeParam(
          _profilePicTeam,
          ParamType.String,
        ),
        'roles': serializeParam(
          _roles,
          ParamType.DataStruct,
          isList: true,
        ),
        'linked_users': serializeParam(
          _linkedUsers,
          ParamType.DataStruct,
          isList: true,
        ),
        'member_code': serializeParam(
          _memberCode,
          ParamType.String,
        ),
        'team_code': serializeParam(
          _teamCode,
          ParamType.String,
        ),
        'valid_team_roles': serializeParam(
          _validTeamRoles,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static MemberTeamDetailsStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      MemberTeamDetailsStruct(
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        firstName: deserializeParam(
          data['first_name'],
          ParamType.String,
          false,
        ),
        lastName: deserializeParam(
          data['last_name'],
          ParamType.String,
          false,
        ),
        profilePic: deserializeParam(
          data['profile_pic'],
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
        profilePicTeam: deserializeParam(
          data['profile_pic_team'],
          ParamType.String,
          false,
        ),
        roles: deserializeStructParam<RolesStruct>(
          data['roles'],
          ParamType.DataStruct,
          true,
          structBuilder: RolesStruct.fromSerializableMap,
        ),
        linkedUsers: deserializeStructParam<LinkedUsersStruct>(
          data['linked_users'],
          ParamType.DataStruct,
          true,
          structBuilder: LinkedUsersStruct.fromSerializableMap,
        ),
        memberCode: deserializeParam(
          data['member_code'],
          ParamType.String,
          false,
        ),
        teamCode: deserializeParam(
          data['team_code'],
          ParamType.String,
          false,
        ),
        validTeamRoles: deserializeStructParam<ValidTeamRolesStruct>(
          data['valid_team_roles'],
          ParamType.DataStruct,
          true,
          structBuilder: ValidTeamRolesStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'MemberTeamDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is MemberTeamDetailsStruct &&
        memberId == other.memberId &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        profilePic == other.profilePic &&
        teamId == other.teamId &&
        teamName == other.teamName &&
        profilePicTeam == other.profilePicTeam &&
        listEquality.equals(roles, other.roles) &&
        listEquality.equals(linkedUsers, other.linkedUsers) &&
        memberCode == other.memberCode &&
        teamCode == other.teamCode &&
        listEquality.equals(validTeamRoles, other.validTeamRoles);
  }

  @override
  int get hashCode => const ListEquality().hash([
        memberId,
        firstName,
        lastName,
        profilePic,
        teamId,
        teamName,
        profilePicTeam,
        roles,
        linkedUsers,
        memberCode,
        teamCode,
        validTeamRoles
      ]);
}

MemberTeamDetailsStruct createMemberTeamDetailsStruct({
  int? memberId,
  String? firstName,
  String? lastName,
  String? profilePic,
  int? teamId,
  String? teamName,
  String? profilePicTeam,
  String? memberCode,
  String? teamCode,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    MemberTeamDetailsStruct(
      memberId: memberId,
      firstName: firstName,
      lastName: lastName,
      profilePic: profilePic,
      teamId: teamId,
      teamName: teamName,
      profilePicTeam: profilePicTeam,
      memberCode: memberCode,
      teamCode: teamCode,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

MemberTeamDetailsStruct? updateMemberTeamDetailsStruct(
  MemberTeamDetailsStruct? memberTeamDetails, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    memberTeamDetails
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addMemberTeamDetailsStructData(
  Map<String, dynamic> firestoreData,
  MemberTeamDetailsStruct? memberTeamDetails,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (memberTeamDetails == null) {
    return;
  }
  if (memberTeamDetails.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && memberTeamDetails.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final memberTeamDetailsData =
      getMemberTeamDetailsFirestoreData(memberTeamDetails, forFieldValue);
  final nestedData =
      memberTeamDetailsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = memberTeamDetails.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getMemberTeamDetailsFirestoreData(
  MemberTeamDetailsStruct? memberTeamDetails, [
  bool forFieldValue = false,
]) {
  if (memberTeamDetails == null) {
    return {};
  }
  final firestoreData = mapToFirestore(memberTeamDetails.toMap());

  // Add any Firestore field values
  mapToFirestore(memberTeamDetails.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getMemberTeamDetailsListFirestoreData(
  List<MemberTeamDetailsStruct>? memberTeamDetailss,
) =>
    memberTeamDetailss
        ?.map((e) => getMemberTeamDetailsFirestoreData(e, true))
        .toList() ??
    [];
