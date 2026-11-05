// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class MemberRequestsStruct extends FFFirebaseStruct {
  MemberRequestsStruct({
    String? lastName,
    int? memberId,
    String? firstName,
    String? requestedAt,
    int? memberTeamId,
    String? requestingUserId,
    String? requestingUserName,
    String? requestingUserEmail,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _lastName = lastName,
        _memberId = memberId,
        _firstName = firstName,
        _requestedAt = requestedAt,
        _memberTeamId = memberTeamId,
        _requestingUserId = requestingUserId,
        _requestingUserName = requestingUserName,
        _requestingUserEmail = requestingUserEmail,
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

  // "first_name" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  set firstName(String? val) => _firstName = val;

  bool hasFirstName() => _firstName != null;

  // "requested_at" field.
  String? _requestedAt;
  String get requestedAt => _requestedAt ?? '';
  set requestedAt(String? val) => _requestedAt = val;

  bool hasRequestedAt() => _requestedAt != null;

  // "member_team_id" field.
  int? _memberTeamId;
  int get memberTeamId => _memberTeamId ?? 0;
  set memberTeamId(int? val) => _memberTeamId = val;

  void incrementMemberTeamId(int amount) =>
      memberTeamId = memberTeamId + amount;

  bool hasMemberTeamId() => _memberTeamId != null;

  // "requesting_user_id" field.
  String? _requestingUserId;
  String get requestingUserId => _requestingUserId ?? '';
  set requestingUserId(String? val) => _requestingUserId = val;

  bool hasRequestingUserId() => _requestingUserId != null;

  // "requesting_user_name" field.
  String? _requestingUserName;
  String get requestingUserName => _requestingUserName ?? '';
  set requestingUserName(String? val) => _requestingUserName = val;

  bool hasRequestingUserName() => _requestingUserName != null;

  // "requesting_user_email" field.
  String? _requestingUserEmail;
  String get requestingUserEmail => _requestingUserEmail ?? '';
  set requestingUserEmail(String? val) => _requestingUserEmail = val;

  bool hasRequestingUserEmail() => _requestingUserEmail != null;

  static MemberRequestsStruct fromMap(Map<String, dynamic> data) =>
      MemberRequestsStruct(
        lastName: data['last_name'] as String?,
        memberId: castToType<int>(data['member_id']),
        firstName: data['first_name'] as String?,
        requestedAt: data['requested_at'] as String?,
        memberTeamId: castToType<int>(data['member_team_id']),
        requestingUserId: data['requesting_user_id'] as String?,
        requestingUserName: data['requesting_user_name'] as String?,
        requestingUserEmail: data['requesting_user_email'] as String?,
      );

  static MemberRequestsStruct? maybeFromMap(dynamic data) => data is Map
      ? MemberRequestsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'last_name': _lastName,
        'member_id': _memberId,
        'first_name': _firstName,
        'requested_at': _requestedAt,
        'member_team_id': _memberTeamId,
        'requesting_user_id': _requestingUserId,
        'requesting_user_name': _requestingUserName,
        'requesting_user_email': _requestingUserEmail,
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
        'first_name': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'requested_at': serializeParam(
          _requestedAt,
          ParamType.String,
        ),
        'member_team_id': serializeParam(
          _memberTeamId,
          ParamType.int,
        ),
        'requesting_user_id': serializeParam(
          _requestingUserId,
          ParamType.String,
        ),
        'requesting_user_name': serializeParam(
          _requestingUserName,
          ParamType.String,
        ),
        'requesting_user_email': serializeParam(
          _requestingUserEmail,
          ParamType.String,
        ),
      }.withoutNulls;

  static MemberRequestsStruct fromSerializableMap(Map<String, dynamic> data) =>
      MemberRequestsStruct(
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
        firstName: deserializeParam(
          data['first_name'],
          ParamType.String,
          false,
        ),
        requestedAt: deserializeParam(
          data['requested_at'],
          ParamType.String,
          false,
        ),
        memberTeamId: deserializeParam(
          data['member_team_id'],
          ParamType.int,
          false,
        ),
        requestingUserId: deserializeParam(
          data['requesting_user_id'],
          ParamType.String,
          false,
        ),
        requestingUserName: deserializeParam(
          data['requesting_user_name'],
          ParamType.String,
          false,
        ),
        requestingUserEmail: deserializeParam(
          data['requesting_user_email'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'MemberRequestsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is MemberRequestsStruct &&
        lastName == other.lastName &&
        memberId == other.memberId &&
        firstName == other.firstName &&
        requestedAt == other.requestedAt &&
        memberTeamId == other.memberTeamId &&
        requestingUserId == other.requestingUserId &&
        requestingUserName == other.requestingUserName &&
        requestingUserEmail == other.requestingUserEmail;
  }

  @override
  int get hashCode => const ListEquality().hash([
        lastName,
        memberId,
        firstName,
        requestedAt,
        memberTeamId,
        requestingUserId,
        requestingUserName,
        requestingUserEmail
      ]);
}

MemberRequestsStruct createMemberRequestsStruct({
  String? lastName,
  int? memberId,
  String? firstName,
  String? requestedAt,
  int? memberTeamId,
  String? requestingUserId,
  String? requestingUserName,
  String? requestingUserEmail,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    MemberRequestsStruct(
      lastName: lastName,
      memberId: memberId,
      firstName: firstName,
      requestedAt: requestedAt,
      memberTeamId: memberTeamId,
      requestingUserId: requestingUserId,
      requestingUserName: requestingUserName,
      requestingUserEmail: requestingUserEmail,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

MemberRequestsStruct? updateMemberRequestsStruct(
  MemberRequestsStruct? memberRequests, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    memberRequests
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addMemberRequestsStructData(
  Map<String, dynamic> firestoreData,
  MemberRequestsStruct? memberRequests,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (memberRequests == null) {
    return;
  }
  if (memberRequests.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && memberRequests.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final memberRequestsData =
      getMemberRequestsFirestoreData(memberRequests, forFieldValue);
  final nestedData =
      memberRequestsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = memberRequests.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getMemberRequestsFirestoreData(
  MemberRequestsStruct? memberRequests, [
  bool forFieldValue = false,
]) {
  if (memberRequests == null) {
    return {};
  }
  final firestoreData = mapToFirestore(memberRequests.toMap());

  // Add any Firestore field values
  mapToFirestore(memberRequests.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getMemberRequestsListFirestoreData(
  List<MemberRequestsStruct>? memberRequestss,
) =>
    memberRequestss
        ?.map((e) => getMemberRequestsFirestoreData(e, true))
        .toList() ??
    [];
