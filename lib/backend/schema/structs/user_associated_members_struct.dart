// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class UserAssociatedMembersStruct extends FFFirebaseStruct {
  UserAssociatedMembersStruct({
    int? memberId,
    String? memberName,
    String? profilePic,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _memberId = memberId,
        _memberName = memberName,
        _profilePic = profilePic,
        super(firestoreUtilData);

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "member_name" field.
  String? _memberName;
  String get memberName => _memberName ?? '';
  set memberName(String? val) => _memberName = val;

  bool hasMemberName() => _memberName != null;

  // "profile_pic" field.
  String? _profilePic;
  String get profilePic => _profilePic ?? '';
  set profilePic(String? val) => _profilePic = val;

  bool hasProfilePic() => _profilePic != null;

  static UserAssociatedMembersStruct fromMap(Map<String, dynamic> data) =>
      UserAssociatedMembersStruct(
        memberId: castToType<int>(data['member_id']),
        memberName: data['member_name'] as String?,
        profilePic: data['profile_pic'] as String?,
      );

  static UserAssociatedMembersStruct? maybeFromMap(dynamic data) => data is Map
      ? UserAssociatedMembersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'member_id': _memberId,
        'member_name': _memberName,
        'profile_pic': _profilePic,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'member_name': serializeParam(
          _memberName,
          ParamType.String,
        ),
        'profile_pic': serializeParam(
          _profilePic,
          ParamType.String,
        ),
      }.withoutNulls;

  static UserAssociatedMembersStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      UserAssociatedMembersStruct(
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        memberName: deserializeParam(
          data['member_name'],
          ParamType.String,
          false,
        ),
        profilePic: deserializeParam(
          data['profile_pic'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'UserAssociatedMembersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is UserAssociatedMembersStruct &&
        memberId == other.memberId &&
        memberName == other.memberName &&
        profilePic == other.profilePic;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([memberId, memberName, profilePic]);
}

UserAssociatedMembersStruct createUserAssociatedMembersStruct({
  int? memberId,
  String? memberName,
  String? profilePic,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserAssociatedMembersStruct(
      memberId: memberId,
      memberName: memberName,
      profilePic: profilePic,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserAssociatedMembersStruct? updateUserAssociatedMembersStruct(
  UserAssociatedMembersStruct? userAssociatedMembers, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userAssociatedMembers
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserAssociatedMembersStructData(
  Map<String, dynamic> firestoreData,
  UserAssociatedMembersStruct? userAssociatedMembers,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userAssociatedMembers == null) {
    return;
  }
  if (userAssociatedMembers.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields = !forFieldValue &&
      userAssociatedMembers.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userAssociatedMembersData = getUserAssociatedMembersFirestoreData(
      userAssociatedMembers, forFieldValue);
  final nestedData =
      userAssociatedMembersData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      userAssociatedMembers.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserAssociatedMembersFirestoreData(
  UserAssociatedMembersStruct? userAssociatedMembers, [
  bool forFieldValue = false,
]) {
  if (userAssociatedMembers == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userAssociatedMembers.toMap());

  // Add any Firestore field values
  mapToFirestore(userAssociatedMembers.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserAssociatedMembersListFirestoreData(
  List<UserAssociatedMembersStruct>? userAssociatedMemberss,
) =>
    userAssociatedMemberss
        ?.map((e) => getUserAssociatedMembersFirestoreData(e, true))
        .toList() ??
    [];
