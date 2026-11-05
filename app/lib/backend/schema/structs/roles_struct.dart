// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class RolesStruct extends FFFirebaseStruct {
  RolesStruct({
    int? roleId,
    String? roleName,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _roleId = roleId,
        _roleName = roleName,
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

  static RolesStruct fromMap(Map<String, dynamic> data) => RolesStruct(
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
      );

  static RolesStruct? maybeFromMap(dynamic data) =>
      data is Map ? RolesStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'role_id': _roleId,
        'role_name': _roleName,
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
      }.withoutNulls;

  static RolesStruct fromSerializableMap(Map<String, dynamic> data) =>
      RolesStruct(
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
      );

  @override
  String toString() => 'RolesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is RolesStruct &&
        roleId == other.roleId &&
        roleName == other.roleName;
  }

  @override
  int get hashCode => const ListEquality().hash([roleId, roleName]);
}

RolesStruct createRolesStruct({
  int? roleId,
  String? roleName,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    RolesStruct(
      roleId: roleId,
      roleName: roleName,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

RolesStruct? updateRolesStruct(
  RolesStruct? roles, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    roles
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addRolesStructData(
  Map<String, dynamic> firestoreData,
  RolesStruct? roles,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (roles == null) {
    return;
  }
  if (roles.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && roles.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final rolesData = getRolesFirestoreData(roles, forFieldValue);
  final nestedData = rolesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = roles.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getRolesFirestoreData(
  RolesStruct? roles, [
  bool forFieldValue = false,
]) {
  if (roles == null) {
    return {};
  }
  final firestoreData = mapToFirestore(roles.toMap());

  // Add any Firestore field values
  mapToFirestore(roles.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getRolesListFirestoreData(
  List<RolesStruct>? roless,
) =>
    roless?.map((e) => getRolesFirestoreData(e, true)).toList() ?? [];
