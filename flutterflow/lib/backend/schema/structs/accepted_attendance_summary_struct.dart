// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class AcceptedAttendanceSummaryStruct extends FFFirebaseStruct {
  AcceptedAttendanceSummaryStruct({
    int? roleId,
    String? roleName,
    int? roleLevel,
    int? memberCount,
    String? roleNamePlural,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _roleId = roleId,
        _roleName = roleName,
        _roleLevel = roleLevel,
        _memberCount = memberCount,
        _roleNamePlural = roleNamePlural,
        super(firestoreUtilData);

  // "role_id" field.
  int? _roleId;
  int get roleId => _roleId ?? 0;
  set roleId(int? val) => _roleId = val;

  void incrementRoleId(int amount) => roleId = roleId + amount;

  bool hasRoleId() => _roleId != null;

  // "role_name" field.
  String? _roleName;
  String get roleName => _roleName ?? '';
  set roleName(String? val) => _roleName = val;

  bool hasRoleName() => _roleName != null;

  // "role_level" field.
  int? _roleLevel;
  int get roleLevel => _roleLevel ?? 0;
  set roleLevel(int? val) => _roleLevel = val;

  void incrementRoleLevel(int amount) => roleLevel = roleLevel + amount;

  bool hasRoleLevel() => _roleLevel != null;

  // "member_count" field.
  int? _memberCount;
  int get memberCount => _memberCount ?? 0;
  set memberCount(int? val) => _memberCount = val;

  void incrementMemberCount(int amount) => memberCount = memberCount + amount;

  bool hasMemberCount() => _memberCount != null;

  // "role_name_plural" field.
  String? _roleNamePlural;
  String get roleNamePlural => _roleNamePlural ?? '';
  set roleNamePlural(String? val) => _roleNamePlural = val;

  bool hasRoleNamePlural() => _roleNamePlural != null;

  static AcceptedAttendanceSummaryStruct fromMap(Map<String, dynamic> data) =>
      AcceptedAttendanceSummaryStruct(
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
        roleLevel: castToType<int>(data['role_level']),
        memberCount: castToType<int>(data['member_count']),
        roleNamePlural: data['role_name_plural'] as String?,
      );

  static AcceptedAttendanceSummaryStruct? maybeFromMap(dynamic data) => data
          is Map
      ? AcceptedAttendanceSummaryStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'role_id': _roleId,
        'role_name': _roleName,
        'role_level': _roleLevel,
        'member_count': _memberCount,
        'role_name_plural': _roleNamePlural,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'role_id': serializeParam(
          _roleId,
          ParamType.int,
        ),
        'role_name': serializeParam(
          _roleName,
          ParamType.String,
        ),
        'role_level': serializeParam(
          _roleLevel,
          ParamType.int,
        ),
        'member_count': serializeParam(
          _memberCount,
          ParamType.int,
        ),
        'role_name_plural': serializeParam(
          _roleNamePlural,
          ParamType.String,
        ),
      }.withoutNulls;

  static AcceptedAttendanceSummaryStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      AcceptedAttendanceSummaryStruct(
        roleId: deserializeParam(
          data['role_id'],
          ParamType.int,
          false,
        ),
        roleName: deserializeParam(
          data['role_name'],
          ParamType.String,
          false,
        ),
        roleLevel: deserializeParam(
          data['role_level'],
          ParamType.int,
          false,
        ),
        memberCount: deserializeParam(
          data['member_count'],
          ParamType.int,
          false,
        ),
        roleNamePlural: deserializeParam(
          data['role_name_plural'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'AcceptedAttendanceSummaryStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is AcceptedAttendanceSummaryStruct &&
        roleId == other.roleId &&
        roleName == other.roleName &&
        roleLevel == other.roleLevel &&
        memberCount == other.memberCount &&
        roleNamePlural == other.roleNamePlural;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([roleId, roleName, roleLevel, memberCount, roleNamePlural]);
}

AcceptedAttendanceSummaryStruct createAcceptedAttendanceSummaryStruct({
  int? roleId,
  String? roleName,
  int? roleLevel,
  int? memberCount,
  String? roleNamePlural,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    AcceptedAttendanceSummaryStruct(
      roleId: roleId,
      roleName: roleName,
      roleLevel: roleLevel,
      memberCount: memberCount,
      roleNamePlural: roleNamePlural,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

AcceptedAttendanceSummaryStruct? updateAcceptedAttendanceSummaryStruct(
  AcceptedAttendanceSummaryStruct? acceptedAttendanceSummary, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    acceptedAttendanceSummary
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addAcceptedAttendanceSummaryStructData(
  Map<String, dynamic> firestoreData,
  AcceptedAttendanceSummaryStruct? acceptedAttendanceSummary,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (acceptedAttendanceSummary == null) {
    return;
  }
  if (acceptedAttendanceSummary.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields = !forFieldValue &&
      acceptedAttendanceSummary.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final acceptedAttendanceSummaryData =
      getAcceptedAttendanceSummaryFirestoreData(
          acceptedAttendanceSummary, forFieldValue);
  final nestedData =
      acceptedAttendanceSummaryData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      acceptedAttendanceSummary.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getAcceptedAttendanceSummaryFirestoreData(
  AcceptedAttendanceSummaryStruct? acceptedAttendanceSummary, [
  bool forFieldValue = false,
]) {
  if (acceptedAttendanceSummary == null) {
    return {};
  }
  final firestoreData = mapToFirestore(acceptedAttendanceSummary.toMap());

  // Add any Firestore field values
  mapToFirestore(acceptedAttendanceSummary.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getAcceptedAttendanceSummaryListFirestoreData(
  List<AcceptedAttendanceSummaryStruct>? acceptedAttendanceSummarys,
) =>
    acceptedAttendanceSummarys
        ?.map((e) => getAcceptedAttendanceSummaryFirestoreData(e, true))
        .toList() ??
    [];
