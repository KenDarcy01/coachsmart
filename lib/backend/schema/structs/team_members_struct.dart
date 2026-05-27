// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class TeamMembersStruct extends FFFirebaseStruct {
  TeamMembersStruct({
    String? lastName,
    int? memberId,
    String? roleName,
    String? firstName,
    int? roleLevel,
    String? profilePic,
    int? responseId,
    String? attendanceIcon,
    String? attendanceStatus,
    int? memberPaid,
    int? memberPaymentId,
    String? memberPaymentStatus,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _lastName = lastName,
        _memberId = memberId,
        _roleName = roleName,
        _firstName = firstName,
        _roleLevel = roleLevel,
        _profilePic = profilePic,
        _responseId = responseId,
        _attendanceIcon = attendanceIcon,
        _attendanceStatus = attendanceStatus,
        _memberPaid = memberPaid,
        _memberPaymentId = memberPaymentId,
        _memberPaymentStatus = memberPaymentStatus,
        super(firestoreUtilData);

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

  // "role_name" field.
  String? _roleName;
  String get roleName => _roleName ?? '';
  set roleName(String? val) => _roleName = val;

  bool hasRoleName() => _roleName != null;

  // "first_name" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  set firstName(String? val) => _firstName = val;

  bool hasFirstName() => _firstName != null;

  // "role_level" field.
  int? _roleLevel;
  int get roleLevel => _roleLevel ?? 0;
  set roleLevel(int? val) => _roleLevel = val;

  void incrementRoleLevel(int amount) => roleLevel = roleLevel + amount;

  bool hasRoleLevel() => _roleLevel != null;

  // "profile_pic" field.
  String? _profilePic;
  String get profilePic => _profilePic ?? '';
  set profilePic(String? val) => _profilePic = val;

  bool hasProfilePic() => _profilePic != null;

  // "response_id" field.
  int? _responseId;
  int get responseId => _responseId ?? 0;
  set responseId(int? val) => _responseId = val;

  void incrementResponseId(int amount) => responseId = responseId + amount;

  bool hasResponseId() => _responseId != null;

  // "attendance_icon" field.
  String? _attendanceIcon;
  String get attendanceIcon => _attendanceIcon ?? '';
  set attendanceIcon(String? val) => _attendanceIcon = val;

  bool hasAttendanceIcon() => _attendanceIcon != null;

  // "attendance_status" field.
  String? _attendanceStatus;
  String get attendanceStatus => _attendanceStatus ?? '';
  set attendanceStatus(String? val) => _attendanceStatus = val;

  bool hasAttendanceStatus() => _attendanceStatus != null;

  // "member_paid" field.
  int? _memberPaid;
  int get memberPaid => _memberPaid ?? 0;
  set memberPaid(int? val) => _memberPaid = val;

  void incrementMemberPaid(int amount) => memberPaid = memberPaid + amount;

  bool hasMemberPaid() => _memberPaid != null;

  // "member_payment_id" field.
  int? _memberPaymentId;
  int get memberPaymentId => _memberPaymentId ?? 0;
  set memberPaymentId(int? val) => _memberPaymentId = val;

  void incrementMemberPaymentId(int amount) =>
      memberPaymentId = memberPaymentId + amount;

  bool hasMemberPaymentId() => _memberPaymentId != null;

  // "member_payment_status" field.
  String? _memberPaymentStatus;
  String get memberPaymentStatus => _memberPaymentStatus ?? '';
  set memberPaymentStatus(String? val) => _memberPaymentStatus = val;

  bool hasMemberPaymentStatus() => _memberPaymentStatus != null;

  static TeamMembersStruct fromMap(Map<String, dynamic> data) =>
      TeamMembersStruct(
        lastName: data['last_name'] as String?,
        memberId: castToType<int>(data['member_id']),
        roleName: data['role_name'] as String?,
        firstName: data['first_name'] as String?,
        roleLevel: castToType<int>(data['role_level']),
        profilePic: data['profile_pic'] as String?,
        responseId: castToType<int>(data['response_id']),
        attendanceIcon: data['attendance_icon'] as String?,
        attendanceStatus: data['attendance_status'] as String?,
        memberPaid: castToType<int>(data['member_paid']),
        memberPaymentId: castToType<int>(data['member_payment_id']),
        memberPaymentStatus: data['member_payment_status'] as String?,
      );

  static TeamMembersStruct? maybeFromMap(dynamic data) => data is Map
      ? TeamMembersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'last_name': _lastName,
        'member_id': _memberId,
        'role_name': _roleName,
        'first_name': _firstName,
        'role_level': _roleLevel,
        'profile_pic': _profilePic,
        'response_id': _responseId,
        'attendance_icon': _attendanceIcon,
        'attendance_status': _attendanceStatus,
        'member_paid': _memberPaid,
        'member_payment_id': _memberPaymentId,
        'member_payment_status': _memberPaymentStatus,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'last_name': serializeParam(
          _lastName,
          ParamType.String,
        ),
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'role_name': serializeParam(
          _roleName,
          ParamType.String,
        ),
        'first_name': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'role_level': serializeParam(
          _roleLevel,
          ParamType.int,
        ),
        'profile_pic': serializeParam(
          _profilePic,
          ParamType.String,
        ),
        'response_id': serializeParam(
          _responseId,
          ParamType.int,
        ),
        'attendance_icon': serializeParam(
          _attendanceIcon,
          ParamType.String,
        ),
        'attendance_status': serializeParam(
          _attendanceStatus,
          ParamType.String,
        ),
        'member_paid': serializeParam(
          _memberPaid,
          ParamType.int,
        ),
        'member_payment_id': serializeParam(
          _memberPaymentId,
          ParamType.int,
        ),
        'member_payment_status': serializeParam(
          _memberPaymentStatus,
          ParamType.String,
        ),
      }.withoutNulls;

  static TeamMembersStruct fromSerializableMap(Map<String, dynamic> data) =>
      TeamMembersStruct(
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
        roleName: deserializeParam(
          data['role_name'],
          ParamType.String,
          false,
        ),
        firstName: deserializeParam(
          data['first_name'],
          ParamType.String,
          false,
        ),
        roleLevel: deserializeParam(
          data['role_level'],
          ParamType.int,
          false,
        ),
        profilePic: deserializeParam(
          data['profile_pic'],
          ParamType.String,
          false,
        ),
        responseId: deserializeParam(
          data['response_id'],
          ParamType.int,
          false,
        ),
        attendanceIcon: deserializeParam(
          data['attendance_icon'],
          ParamType.String,
          false,
        ),
        attendanceStatus: deserializeParam(
          data['attendance_status'],
          ParamType.String,
          false,
        ),
        memberPaid: deserializeParam(
          data['member_paid'],
          ParamType.int,
          false,
        ),
        memberPaymentId: deserializeParam(
          data['member_payment_id'],
          ParamType.int,
          false,
        ),
        memberPaymentStatus: deserializeParam(
          data['member_payment_status'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'TeamMembersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is TeamMembersStruct &&
        lastName == other.lastName &&
        memberId == other.memberId &&
        roleName == other.roleName &&
        firstName == other.firstName &&
        roleLevel == other.roleLevel &&
        profilePic == other.profilePic &&
        responseId == other.responseId &&
        attendanceIcon == other.attendanceIcon &&
        attendanceStatus == other.attendanceStatus &&
        memberPaid == other.memberPaid &&
        memberPaymentId == other.memberPaymentId &&
        memberPaymentStatus == other.memberPaymentStatus;
  }

  @override
  int get hashCode => const ListEquality().hash([
        lastName,
        memberId,
        roleName,
        firstName,
        roleLevel,
        profilePic,
        responseId,
        attendanceIcon,
        attendanceStatus,
        memberPaid,
        memberPaymentId,
        memberPaymentStatus
      ]);
}

TeamMembersStruct createTeamMembersStruct({
  String? lastName,
  int? memberId,
  String? roleName,
  String? firstName,
  int? roleLevel,
  String? profilePic,
  int? responseId,
  String? attendanceIcon,
  String? attendanceStatus,
  int? memberPaid,
  int? memberPaymentId,
  String? memberPaymentStatus,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    TeamMembersStruct(
      lastName: lastName,
      memberId: memberId,
      roleName: roleName,
      firstName: firstName,
      roleLevel: roleLevel,
      profilePic: profilePic,
      responseId: responseId,
      attendanceIcon: attendanceIcon,
      attendanceStatus: attendanceStatus,
      memberPaid: memberPaid,
      memberPaymentId: memberPaymentId,
      memberPaymentStatus: memberPaymentStatus,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

TeamMembersStruct? updateTeamMembersStruct(
  TeamMembersStruct? teamMembers, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    teamMembers
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addTeamMembersStructData(
  Map<String, dynamic> firestoreData,
  TeamMembersStruct? teamMembers,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (teamMembers == null) {
    return;
  }
  if (teamMembers.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && teamMembers.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final teamMembersData =
      getTeamMembersFirestoreData(teamMembers, forFieldValue);
  final nestedData =
      teamMembersData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = teamMembers.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getTeamMembersFirestoreData(
  TeamMembersStruct? teamMembers, [
  bool forFieldValue = false,
]) {
  if (teamMembers == null) {
    return {};
  }
  final firestoreData = mapToFirestore(teamMembers.toMap());

  // Add any Firestore field values
  mapToFirestore(teamMembers.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getTeamMembersListFirestoreData(
  List<TeamMembersStruct>? teamMemberss,
) =>
    teamMemberss?.map((e) => getTeamMembersFirestoreData(e, true)).toList() ??
    [];
