// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class AvailableRolesStruct extends FFFirebaseStruct {
  AvailableRolesStruct({
    int? roleId,
    String? roleName,
    int? roleGrade,
    int? roleLevel,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _roleId = roleId,
        _roleName = roleName,
        _roleGrade = roleGrade,
        _roleLevel = roleLevel,
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

  // "role_grade" field.
  int? _roleGrade;
  int get roleGrade => _roleGrade ?? 0;
  set roleGrade(int? val) => _roleGrade = val;

  void incrementRoleGrade(int amount) => roleGrade = roleGrade + amount;

  bool hasRoleGrade() => _roleGrade != null;

  // "role_level" field.
  int? _roleLevel;
  int get roleLevel => _roleLevel ?? 0;
  set roleLevel(int? val) => _roleLevel = val;

  void incrementRoleLevel(int amount) => roleLevel = roleLevel + amount;

  bool hasRoleLevel() => _roleLevel != null;

  static AvailableRolesStruct fromMap(Map<String, dynamic> data) =>
      AvailableRolesStruct(
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
        roleGrade: castToType<int>(data['role_grade']),
        roleLevel: castToType<int>(data['role_level']),
      );

  static AvailableRolesStruct? maybeFromMap(dynamic data) => data is Map
      ? AvailableRolesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'role_id': _roleId,
        'role_name': _roleName,
        'role_grade': _roleGrade,
        'role_level': _roleLevel,
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
        'role_grade': serializeParam(
          _roleGrade,
          ParamType.int,
        ),
        'role_level': serializeParam(
          _roleLevel,
          ParamType.int,
        ),
      }.withoutNulls;

  static AvailableRolesStruct fromSerializableMap(Map<String, dynamic> data) =>
      AvailableRolesStruct(
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
        roleGrade: deserializeParam(
          data['role_grade'],
          ParamType.int,
          false,
        ),
        roleLevel: deserializeParam(
          data['role_level'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'AvailableRolesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is AvailableRolesStruct &&
        roleId == other.roleId &&
        roleName == other.roleName &&
        roleGrade == other.roleGrade &&
        roleLevel == other.roleLevel;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([roleId, roleName, roleGrade, roleLevel]);
}

AvailableRolesStruct createAvailableRolesStruct({
  int? roleId,
  String? roleName,
  int? roleGrade,
  int? roleLevel,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    AvailableRolesStruct(
      roleId: roleId,
      roleName: roleName,
      roleGrade: roleGrade,
      roleLevel: roleLevel,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

AvailableRolesStruct? updateAvailableRolesStruct(
  AvailableRolesStruct? availableRoles, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    availableRoles
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addAvailableRolesStructData(
  Map<String, dynamic> firestoreData,
  AvailableRolesStruct? availableRoles,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (availableRoles == null) {
    return;
  }
  if (availableRoles.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && availableRoles.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final availableRolesData =
      getAvailableRolesFirestoreData(availableRoles, forFieldValue);
  final nestedData =
      availableRolesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = availableRoles.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getAvailableRolesFirestoreData(
  AvailableRolesStruct? availableRoles, [
  bool forFieldValue = false,
]) {
  if (availableRoles == null) {
    return {};
  }
  final firestoreData = mapToFirestore(availableRoles.toMap());

  // Add any Firestore field values
  mapToFirestore(availableRoles.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getAvailableRolesListFirestoreData(
  List<AvailableRolesStruct>? availableRoless,
) =>
    availableRoless
        ?.map((e) => getAvailableRolesFirestoreData(e, true))
        .toList() ??
    [];
