// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class RoleGroupsStruct extends FFFirebaseStruct {
  RoleGroupsStruct({
    List<MembersStruct>? members,
    String? roleName,
    int? roleLevel,
    int? memberCount,
    String? roleNamePlural,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _members = members,
        _roleName = roleName,
        _roleLevel = roleLevel,
        _memberCount = memberCount,
        _roleNamePlural = roleNamePlural,
        super(firestoreUtilData);

  // "members" field.
  List<MembersStruct>? _members;
  List<MembersStruct> get members => _members ?? const [];
  set members(List<MembersStruct>? val) => _members = val;

  void updateMembers(Function(List<MembersStruct>) updateFn) {
    updateFn(_members ??= []);
  }

  bool hasMembers() => _members != null;

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

  static RoleGroupsStruct fromMap(Map<String, dynamic> data) =>
      RoleGroupsStruct(
        members: getStructList(
          data['members'],
          MembersStruct.fromMap,
        ),
        roleName: data['role_name'] as String?,
        roleLevel: castToType<int>(data['role_level']),
        memberCount: castToType<int>(data['member_count']),
        roleNamePlural: data['role_name_plural'] as String?,
      );

  static RoleGroupsStruct? maybeFromMap(dynamic data) => data is Map
      ? RoleGroupsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'members': _members?.map((e) => e.toMap()).toList(),
        'role_name': _roleName,
        'role_level': _roleLevel,
        'member_count': _memberCount,
        'role_name_plural': _roleNamePlural,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'members': serializeParam(
          _members,
          ParamType.DataStruct,
          isList: true,
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

  static RoleGroupsStruct fromSerializableMap(Map<String, dynamic> data) =>
      RoleGroupsStruct(
        members: deserializeStructParam<MembersStruct>(
          data['members'],
          ParamType.DataStruct,
          true,
          structBuilder: MembersStruct.fromSerializableMap,
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
  String toString() => 'RoleGroupsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is RoleGroupsStruct &&
        listEquality.equals(members, other.members) &&
        roleName == other.roleName &&
        roleLevel == other.roleLevel &&
        memberCount == other.memberCount &&
        roleNamePlural == other.roleNamePlural;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([members, roleName, roleLevel, memberCount, roleNamePlural]);
}

RoleGroupsStruct createRoleGroupsStruct({
  String? roleName,
  int? roleLevel,
  int? memberCount,
  String? roleNamePlural,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    RoleGroupsStruct(
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

RoleGroupsStruct? updateRoleGroupsStruct(
  RoleGroupsStruct? roleGroups, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    roleGroups
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addRoleGroupsStructData(
  Map<String, dynamic> firestoreData,
  RoleGroupsStruct? roleGroups,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (roleGroups == null) {
    return;
  }
  if (roleGroups.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && roleGroups.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final roleGroupsData = getRoleGroupsFirestoreData(roleGroups, forFieldValue);
  final nestedData = roleGroupsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = roleGroups.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getRoleGroupsFirestoreData(
  RoleGroupsStruct? roleGroups, [
  bool forFieldValue = false,
]) {
  if (roleGroups == null) {
    return {};
  }
  final firestoreData = mapToFirestore(roleGroups.toMap());

  // Add any Firestore field values
  mapToFirestore(roleGroups.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getRoleGroupsListFirestoreData(
  List<RoleGroupsStruct>? roleGroupss,
) =>
    roleGroupss?.map((e) => getRoleGroupsFirestoreData(e, true)).toList() ?? [];
