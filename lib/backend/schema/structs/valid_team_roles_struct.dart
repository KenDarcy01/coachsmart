// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class ValidTeamRolesStruct extends FFFirebaseStruct {
  ValidTeamRolesStruct({
    int? roleId,
    String? roleName,
    int? roleLevel,
    int? roleGrade,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _roleId = roleId,
        _roleName = roleName,
        _roleLevel = roleLevel,
        _roleGrade = roleGrade,
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

  // "role_grade" field.
  int? _roleGrade;
  int get roleGrade => _roleGrade ?? 0;
  set roleGrade(int? val) => _roleGrade = val;

  void incrementRoleGrade(int amount) => roleGrade = roleGrade + amount;

  bool hasRoleGrade() => _roleGrade != null;

  static ValidTeamRolesStruct fromMap(Map<String, dynamic> data) =>
      ValidTeamRolesStruct(
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
        roleLevel: castToType<int>(data['role_level']),
        roleGrade: castToType<int>(data['role_grade']),
      );

  static ValidTeamRolesStruct? maybeFromMap(dynamic data) => data is Map
      ? ValidTeamRolesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'role_id': _roleId,
        'role_name': _roleName,
        'role_level': _roleLevel,
        'role_grade': _roleGrade,
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
        'role_grade': serializeParam(
          _roleGrade,
          ParamType.int,
        ),
      }.withoutNulls;

  static ValidTeamRolesStruct fromSerializableMap(Map<String, dynamic> data) =>
      ValidTeamRolesStruct(
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
        roleGrade: deserializeParam(
          data['role_grade'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'ValidTeamRolesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ValidTeamRolesStruct &&
        roleId == other.roleId &&
        roleName == other.roleName &&
        roleLevel == other.roleLevel &&
        roleGrade == other.roleGrade;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([roleId, roleName, roleLevel, roleGrade]);
}

ValidTeamRolesStruct createValidTeamRolesStruct({
  int? roleId,
  String? roleName,
  int? roleLevel,
  int? roleGrade,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ValidTeamRolesStruct(
      roleId: roleId,
      roleName: roleName,
      roleLevel: roleLevel,
      roleGrade: roleGrade,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ValidTeamRolesStruct? updateValidTeamRolesStruct(
  ValidTeamRolesStruct? validTeamRoles, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    validTeamRoles
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addValidTeamRolesStructData(
  Map<String, dynamic> firestoreData,
  ValidTeamRolesStruct? validTeamRoles,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (validTeamRoles == null) {
    return;
  }
  if (validTeamRoles.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && validTeamRoles.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final validTeamRolesData =
      getValidTeamRolesFirestoreData(validTeamRoles, forFieldValue);
  final nestedData =
      validTeamRolesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = validTeamRoles.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getValidTeamRolesFirestoreData(
  ValidTeamRolesStruct? validTeamRoles, [
  bool forFieldValue = false,
]) {
  if (validTeamRoles == null) {
    return {};
  }
  final firestoreData = mapToFirestore(validTeamRoles.toMap());

  // Add any Firestore field values
  mapToFirestore(validTeamRoles.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getValidTeamRolesListFirestoreData(
  List<ValidTeamRolesStruct>? validTeamRoless,
) =>
    validTeamRoless
        ?.map((e) => getValidTeamRolesFirestoreData(e, true))
        .toList() ??
    [];
