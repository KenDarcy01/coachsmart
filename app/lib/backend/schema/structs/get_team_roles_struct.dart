// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class GetTeamRolesStruct extends FFFirebaseStruct {
  GetTeamRolesStruct({
    int? roleId,
    String? roleName,
    int? roleGrade,
    int? roleLevel,
    int? roleListSeq,
    String? roleNamePlural,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _roleId = roleId,
        _roleName = roleName,
        _roleGrade = roleGrade,
        _roleLevel = roleLevel,
        _roleListSeq = roleListSeq,
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

  // "role_list_seq" field.
  int? _roleListSeq;
  int get roleListSeq => _roleListSeq ?? 0;
  set roleListSeq(int? val) => _roleListSeq = val;

  void incrementRoleListSeq(int amount) => roleListSeq = roleListSeq + amount;

  bool hasRoleListSeq() => _roleListSeq != null;

  // "role_name_plural" field.
  String? _roleNamePlural;
  String get roleNamePlural => _roleNamePlural ?? '';
  set roleNamePlural(String? val) => _roleNamePlural = val;

  bool hasRoleNamePlural() => _roleNamePlural != null;

  static GetTeamRolesStruct fromMap(Map<String, dynamic> data) =>
      GetTeamRolesStruct(
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
        roleGrade: castToType<int>(data['role_grade']),
        roleLevel: castToType<int>(data['role_level']),
        roleListSeq: castToType<int>(data['role_list_seq']),
        roleNamePlural: data['role_name_plural'] as String?,
      );

  static GetTeamRolesStruct? maybeFromMap(dynamic data) => data is Map
      ? GetTeamRolesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'role_id': _roleId,
        'role_name': _roleName,
        'role_grade': _roleGrade,
        'role_level': _roleLevel,
        'role_list_seq': _roleListSeq,
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
        'role_grade': serializeParam(
          _roleGrade,
          ParamType.int,
        ),
        'role_level': serializeParam(
          _roleLevel,
          ParamType.int,
        ),
        'role_list_seq': serializeParam(
          _roleListSeq,
          ParamType.int,
        ),
        'role_name_plural': serializeParam(
          _roleNamePlural,
          ParamType.String,
        ),
      }.withoutNulls;

  static GetTeamRolesStruct fromSerializableMap(Map<String, dynamic> data) =>
      GetTeamRolesStruct(
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
        roleListSeq: deserializeParam(
          data['role_list_seq'],
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
  String toString() => 'GetTeamRolesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is GetTeamRolesStruct &&
        roleId == other.roleId &&
        roleName == other.roleName &&
        roleGrade == other.roleGrade &&
        roleLevel == other.roleLevel &&
        roleListSeq == other.roleListSeq &&
        roleNamePlural == other.roleNamePlural;
  }

  @override
  int get hashCode => const ListEquality().hash(
      [roleId, roleName, roleGrade, roleLevel, roleListSeq, roleNamePlural]);
}

GetTeamRolesStruct createGetTeamRolesStruct({
  int? roleId,
  String? roleName,
  int? roleGrade,
  int? roleLevel,
  int? roleListSeq,
  String? roleNamePlural,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    GetTeamRolesStruct(
      roleId: roleId,
      roleName: roleName,
      roleGrade: roleGrade,
      roleLevel: roleLevel,
      roleListSeq: roleListSeq,
      roleNamePlural: roleNamePlural,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

GetTeamRolesStruct? updateGetTeamRolesStruct(
  GetTeamRolesStruct? getTeamRoles, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    getTeamRoles
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addGetTeamRolesStructData(
  Map<String, dynamic> firestoreData,
  GetTeamRolesStruct? getTeamRoles,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (getTeamRoles == null) {
    return;
  }
  if (getTeamRoles.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && getTeamRoles.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final getTeamRolesData =
      getGetTeamRolesFirestoreData(getTeamRoles, forFieldValue);
  final nestedData =
      getTeamRolesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = getTeamRoles.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getGetTeamRolesFirestoreData(
  GetTeamRolesStruct? getTeamRoles, [
  bool forFieldValue = false,
]) {
  if (getTeamRoles == null) {
    return {};
  }
  final firestoreData = mapToFirestore(getTeamRoles.toMap());

  // Add any Firestore field values
  mapToFirestore(getTeamRoles.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getGetTeamRolesListFirestoreData(
  List<GetTeamRolesStruct>? getTeamRoless,
) =>
    getTeamRoless?.map((e) => getGetTeamRolesFirestoreData(e, true)).toList() ??
    [];
