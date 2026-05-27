// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ListRolesStruct extends FFFirebaseStruct {
  ListRolesStruct({
    int? roleId,
    String? roleName,
    int? roleGrade,
    int? roleLevel,
    String? roleNamePlural,
    int? memberCount,
    List<ListMembersStruct>? members,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _roleId = roleId,
        _roleName = roleName,
        _roleGrade = roleGrade,
        _roleLevel = roleLevel,
        _roleNamePlural = roleNamePlural,
        _memberCount = memberCount,
        _members = members,
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

  // "role_name_plural" field.
  String? _roleNamePlural;
  String get roleNamePlural => _roleNamePlural ?? '';
  set roleNamePlural(String? val) => _roleNamePlural = val;

  bool hasRoleNamePlural() => _roleNamePlural != null;

  // "member_count" field.
  int? _memberCount;
  int get memberCount => _memberCount ?? 0;
  set memberCount(int? val) => _memberCount = val;

  void incrementMemberCount(int amount) => memberCount = memberCount + amount;

  bool hasMemberCount() => _memberCount != null;

  // "members" field.
  List<ListMembersStruct>? _members;
  List<ListMembersStruct> get members => _members ?? const [];
  set members(List<ListMembersStruct>? val) => _members = val;

  void updateMembers(Function(List<ListMembersStruct>) updateFn) {
    updateFn(_members ??= []);
  }

  bool hasMembers() => _members != null;

  static ListRolesStruct fromMap(Map<String, dynamic> data) => ListRolesStruct(
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
        roleGrade: castToType<int>(data['role_grade']),
        roleLevel: castToType<int>(data['role_level']),
        roleNamePlural: data['role_name_plural'] as String?,
        memberCount: castToType<int>(data['member_count']),
        members: getStructList(
          data['members'],
          ListMembersStruct.fromMap,
        ),
      );

  static ListRolesStruct? maybeFromMap(dynamic data) => data is Map
      ? ListRolesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'role_id': _roleId,
        'role_name': _roleName,
        'role_grade': _roleGrade,
        'role_level': _roleLevel,
        'role_name_plural': _roleNamePlural,
        'member_count': _memberCount,
        'members': _members?.map((e) => e.toMap()).toList(),
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
        'role_name_plural': serializeParam(
          _roleNamePlural,
          ParamType.String,
        ),
        'member_count': serializeParam(
          _memberCount,
          ParamType.int,
        ),
        'members': serializeParam(
          _members,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static ListRolesStruct fromSerializableMap(Map<String, dynamic> data) =>
      ListRolesStruct(
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
        roleNamePlural: deserializeParam(
          data['role_name_plural'],
          ParamType.String,
          false,
        ),
        memberCount: deserializeParam(
          data['member_count'],
          ParamType.int,
          false,
        ),
        members: deserializeStructParam<ListMembersStruct>(
          data['members'],
          ParamType.DataStruct,
          true,
          structBuilder: ListMembersStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'ListRolesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is ListRolesStruct &&
        roleId == other.roleId &&
        roleName == other.roleName &&
        roleGrade == other.roleGrade &&
        roleLevel == other.roleLevel &&
        roleNamePlural == other.roleNamePlural &&
        memberCount == other.memberCount &&
        listEquality.equals(members, other.members);
  }

  @override
  int get hashCode => const ListEquality().hash([
        roleId,
        roleName,
        roleGrade,
        roleLevel,
        roleNamePlural,
        memberCount,
        members
      ]);
}

ListRolesStruct createListRolesStruct({
  int? roleId,
  String? roleName,
  int? roleGrade,
  int? roleLevel,
  String? roleNamePlural,
  int? memberCount,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ListRolesStruct(
      roleId: roleId,
      roleName: roleName,
      roleGrade: roleGrade,
      roleLevel: roleLevel,
      roleNamePlural: roleNamePlural,
      memberCount: memberCount,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ListRolesStruct? updateListRolesStruct(
  ListRolesStruct? listRoles, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    listRoles
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addListRolesStructData(
  Map<String, dynamic> firestoreData,
  ListRolesStruct? listRoles,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (listRoles == null) {
    return;
  }
  if (listRoles.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && listRoles.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final listRolesData = getListRolesFirestoreData(listRoles, forFieldValue);
  final nestedData = listRolesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = listRoles.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getListRolesFirestoreData(
  ListRolesStruct? listRoles, [
  bool forFieldValue = false,
]) {
  if (listRoles == null) {
    return {};
  }
  final firestoreData = mapToFirestore(listRoles.toMap());

  // Add any Firestore field values
  mapToFirestore(listRoles.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getListRolesListFirestoreData(
  List<ListRolesStruct>? listRoless,
) =>
    listRoless?.map((e) => getListRolesFirestoreData(e, true)).toList() ?? [];
