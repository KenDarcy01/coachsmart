// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class UserMembersStruct extends FFFirebaseStruct {
  UserMembersStruct({
    int? clubId,
    int? teamId,
    String? clubName,
    String? fullName,
    String? lastName,
    int? memberId,
    String? teamName,
    String? firstName,
    int? memberTeamId,
    String? uniqueMemberCode,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _clubId = clubId,
        _teamId = teamId,
        _clubName = clubName,
        _fullName = fullName,
        _lastName = lastName,
        _memberId = memberId,
        _teamName = teamName,
        _firstName = firstName,
        _memberTeamId = memberTeamId,
        _uniqueMemberCode = uniqueMemberCode,
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

  // "club_name" field.
  String? _clubName;
  String get clubName => _clubName ?? '';
  set clubName(String? val) => _clubName = val;

  bool hasClubName() => _clubName != null;

  // "full_name" field.
  String? _fullName;
  String get fullName => _fullName ?? '';
  set fullName(String? val) => _fullName = val;

  bool hasFullName() => _fullName != null;

  // "last_name" field.
  String? _lastName;
  String get lastName => _lastName ?? '';
  set lastName(String? val) => _lastName = val;

  bool hasLastName() => _lastName != null;

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

  // "first_name" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  set firstName(String? val) => _firstName = val;

  bool hasFirstName() => _firstName != null;

  // "member_team_id" field.
  int? _memberTeamId;
  int get memberTeamId => _memberTeamId ?? 0;
  set memberTeamId(int? val) => _memberTeamId = val;

  void incrementMemberTeamId(int amount) =>
      memberTeamId = memberTeamId + amount;

  bool hasMemberTeamId() => _memberTeamId != null;

  // "unique_member_code" field.
  String? _uniqueMemberCode;
  String get uniqueMemberCode => _uniqueMemberCode ?? '';
  set uniqueMemberCode(String? val) => _uniqueMemberCode = val;

  bool hasUniqueMemberCode() => _uniqueMemberCode != null;

  static UserMembersStruct fromMap(Map<String, dynamic> data) =>
      UserMembersStruct(
        clubId: castToType<int>(data['club_id']),
        teamId: castToType<int>(data['team_id']),
        clubName: data['club_name'] as String?,
        fullName: data['full_name'] as String?,
        lastName: data['last_name'] as String?,
        memberId: castToType<int>(data['member_id']),
        teamName: data['team_name'] as String?,
        firstName: data['first_name'] as String?,
        memberTeamId: castToType<int>(data['member_team_id']),
        uniqueMemberCode: data['unique_member_code'] as String?,
      );

  static UserMembersStruct? maybeFromMap(dynamic data) => data is Map
      ? UserMembersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'club_id': _clubId,
        'team_id': _teamId,
        'club_name': _clubName,
        'full_name': _fullName,
        'last_name': _lastName,
        'member_id': _memberId,
        'team_name': _teamName,
        'first_name': _firstName,
        'member_team_id': _memberTeamId,
        'unique_member_code': _uniqueMemberCode,
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
        'club_name': serializeParam(
          _clubName,
          ParamType.String,
        ),
        'full_name': serializeParam(
          _fullName,
          ParamType.String,
        ),
        'last_name': serializeParam(
          _lastName,
          ParamType.String,
        ),
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'first_name': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'member_team_id': serializeParam(
          _memberTeamId,
          ParamType.int,
        ),
        'unique_member_code': serializeParam(
          _uniqueMemberCode,
          ParamType.String,
        ),
      }.withoutNulls;

  static UserMembersStruct fromSerializableMap(Map<String, dynamic> data) =>
      UserMembersStruct(
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
        clubName: deserializeParam(
          data['club_name'],
          ParamType.String,
          false,
        ),
        fullName: deserializeParam(
          data['full_name'],
          ParamType.String,
          false,
        ),
        lastName: deserializeParam(
          data['last_name'],
          ParamType.String,
          false,
        ),
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        teamName: deserializeParam(
          data['team_name'],
          ParamType.String,
          false,
        ),
        firstName: deserializeParam(
          data['first_name'],
          ParamType.String,
          false,
        ),
        memberTeamId: deserializeParam(
          data['member_team_id'],
          ParamType.int,
          false,
        ),
        uniqueMemberCode: deserializeParam(
          data['unique_member_code'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'UserMembersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is UserMembersStruct &&
        clubId == other.clubId &&
        teamId == other.teamId &&
        clubName == other.clubName &&
        fullName == other.fullName &&
        lastName == other.lastName &&
        memberId == other.memberId &&
        teamName == other.teamName &&
        firstName == other.firstName &&
        memberTeamId == other.memberTeamId &&
        uniqueMemberCode == other.uniqueMemberCode;
  }

  @override
  int get hashCode => const ListEquality().hash([
        clubId,
        teamId,
        clubName,
        fullName,
        lastName,
        memberId,
        teamName,
        firstName,
        memberTeamId,
        uniqueMemberCode
      ]);
}

UserMembersStruct createUserMembersStruct({
  int? clubId,
  int? teamId,
  String? clubName,
  String? fullName,
  String? lastName,
  int? memberId,
  String? teamName,
  String? firstName,
  int? memberTeamId,
  String? uniqueMemberCode,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserMembersStruct(
      clubId: clubId,
      teamId: teamId,
      clubName: clubName,
      fullName: fullName,
      lastName: lastName,
      memberId: memberId,
      teamName: teamName,
      firstName: firstName,
      memberTeamId: memberTeamId,
      uniqueMemberCode: uniqueMemberCode,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserMembersStruct? updateUserMembersStruct(
  UserMembersStruct? userMembers, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userMembers
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserMembersStructData(
  Map<String, dynamic> firestoreData,
  UserMembersStruct? userMembers,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userMembers == null) {
    return;
  }
  if (userMembers.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && userMembers.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userMembersData =
      getUserMembersFirestoreData(userMembers, forFieldValue);
  final nestedData =
      userMembersData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = userMembers.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserMembersFirestoreData(
  UserMembersStruct? userMembers, [
  bool forFieldValue = false,
]) {
  if (userMembers == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userMembers.toMap());

  // Add any Firestore field values
  mapToFirestore(userMembers.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserMembersListFirestoreData(
  List<UserMembersStruct>? userMemberss,
) =>
    userMemberss?.map((e) => getUserMembersFirestoreData(e, true)).toList() ??
    [];
