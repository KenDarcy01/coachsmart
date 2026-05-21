// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class EventSquadsRolesStruct extends FFFirebaseStruct {
  EventSquadsRolesStruct({
    int? roleId,
    String? roleName,
    String? roleNamePlural,
    int? roleListSeq,
    int? roleGrade,
    int? roleLevel,
    int? memberCount,
    int? memberRoleCount,
    int? squadCodeCount,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _roleId = roleId,
        _roleName = roleName,
        _roleNamePlural = roleNamePlural,
        _roleListSeq = roleListSeq,
        _roleGrade = roleGrade,
        _roleLevel = roleLevel,
        _memberCount = memberCount,
        _memberRoleCount = memberRoleCount,
        _squadCodeCount = squadCodeCount,
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

  // "role_name_plural" field.
  String? _roleNamePlural;
  String get roleNamePlural => _roleNamePlural ?? '';
  set roleNamePlural(String? val) => _roleNamePlural = val;

  bool hasRoleNamePlural() => _roleNamePlural != null;

  // "role_list_seq" field.
  int? _roleListSeq;
  int get roleListSeq => _roleListSeq ?? 0;
  set roleListSeq(int? val) => _roleListSeq = val;

  void incrementRoleListSeq(int amount) => roleListSeq = roleListSeq + amount;

  bool hasRoleListSeq() => _roleListSeq != null;

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

  // "member_count" field.
  int? _memberCount;
  int get memberCount => _memberCount ?? 0;
  set memberCount(int? val) => _memberCount = val;

  void incrementMemberCount(int amount) => memberCount = memberCount + amount;

  bool hasMemberCount() => _memberCount != null;

  // "member_role_count" field.
  int? _memberRoleCount;
  int get memberRoleCount => _memberRoleCount ?? 0;
  set memberRoleCount(int? val) => _memberRoleCount = val;

  void incrementMemberRoleCount(int amount) =>
      memberRoleCount = memberRoleCount + amount;

  bool hasMemberRoleCount() => _memberRoleCount != null;

  // "squad_code_count" field.
  int? _squadCodeCount;
  int get squadCodeCount => _squadCodeCount ?? 0;
  set squadCodeCount(int? val) => _squadCodeCount = val;

  void incrementSquadCodeCount(int amount) =>
      squadCodeCount = squadCodeCount + amount;

  bool hasSquadCodeCount() => _squadCodeCount != null;

  static EventSquadsRolesStruct fromMap(Map<String, dynamic> data) =>
      EventSquadsRolesStruct(
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
        roleNamePlural: data['role_name_plural'] as String?,
        roleListSeq: castToType<int>(data['role_list_seq']),
        roleGrade: castToType<int>(data['role_grade']),
        roleLevel: castToType<int>(data['role_level']),
        memberCount: castToType<int>(data['member_count']),
        memberRoleCount: castToType<int>(data['member_role_count']),
        squadCodeCount: castToType<int>(data['squad_code_count']),
      );

  static EventSquadsRolesStruct? maybeFromMap(dynamic data) => data is Map
      ? EventSquadsRolesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'role_id': _roleId,
        'role_name': _roleName,
        'role_name_plural': _roleNamePlural,
        'role_list_seq': _roleListSeq,
        'role_grade': _roleGrade,
        'role_level': _roleLevel,
        'member_count': _memberCount,
        'member_role_count': _memberRoleCount,
        'squad_code_count': _squadCodeCount,
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
        'role_name_plural': serializeParam(
          _roleNamePlural,
          ParamType.String,
        ),
        'role_list_seq': serializeParam(
          _roleListSeq,
          ParamType.int,
        ),
        'role_grade': serializeParam(
          _roleGrade,
          ParamType.int,
        ),
        'role_level': serializeParam(
          _roleLevel,
          ParamType.int,
        ),
        'member_count': serializeParam(
          _memberCount,
          ParamType.int,
        ),
        'member_role_count': serializeParam(
          _memberRoleCount,
          ParamType.int,
        ),
        'squad_code_count': serializeParam(
          _squadCodeCount,
          ParamType.int,
        ),
      }.withoutNulls;

  static EventSquadsRolesStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      EventSquadsRolesStruct(
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
        roleNamePlural: deserializeParam(
          data['role_name_plural'],
          ParamType.String,
          false,
        ),
        roleListSeq: deserializeParam(
          data['role_list_seq'],
          ParamType.int,
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
        memberCount: deserializeParam(
          data['member_count'],
          ParamType.int,
          false,
        ),
        memberRoleCount: deserializeParam(
          data['member_role_count'],
          ParamType.int,
          false,
        ),
        squadCodeCount: deserializeParam(
          data['squad_code_count'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'EventSquadsRolesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is EventSquadsRolesStruct &&
        roleId == other.roleId &&
        roleName == other.roleName &&
        roleNamePlural == other.roleNamePlural &&
        roleListSeq == other.roleListSeq &&
        roleGrade == other.roleGrade &&
        roleLevel == other.roleLevel &&
        memberCount == other.memberCount &&
        memberRoleCount == other.memberRoleCount &&
        squadCodeCount == other.squadCodeCount;
  }

  @override
  int get hashCode => const ListEquality().hash([
        roleId,
        roleName,
        roleNamePlural,
        roleListSeq,
        roleGrade,
        roleLevel,
        memberCount,
        memberRoleCount,
        squadCodeCount
      ]);
}

EventSquadsRolesStruct createEventSquadsRolesStruct({
  int? roleId,
  String? roleName,
  String? roleNamePlural,
  int? roleListSeq,
  int? roleGrade,
  int? roleLevel,
  int? memberCount,
  int? memberRoleCount,
  int? squadCodeCount,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventSquadsRolesStruct(
      roleId: roleId,
      roleName: roleName,
      roleNamePlural: roleNamePlural,
      roleListSeq: roleListSeq,
      roleGrade: roleGrade,
      roleLevel: roleLevel,
      memberCount: memberCount,
      memberRoleCount: memberRoleCount,
      squadCodeCount: squadCodeCount,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventSquadsRolesStruct? updateEventSquadsRolesStruct(
  EventSquadsRolesStruct? eventSquadsRoles, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventSquadsRoles
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventSquadsRolesStructData(
  Map<String, dynamic> firestoreData,
  EventSquadsRolesStruct? eventSquadsRoles,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventSquadsRoles == null) {
    return;
  }
  if (eventSquadsRoles.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventSquadsRoles.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventSquadsRolesData =
      getEventSquadsRolesFirestoreData(eventSquadsRoles, forFieldValue);
  final nestedData =
      eventSquadsRolesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = eventSquadsRoles.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventSquadsRolesFirestoreData(
  EventSquadsRolesStruct? eventSquadsRoles, [
  bool forFieldValue = false,
]) {
  if (eventSquadsRoles == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventSquadsRoles.toMap());

  // Add any Firestore field values
  mapToFirestore(eventSquadsRoles.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventSquadsRolesListFirestoreData(
  List<EventSquadsRolesStruct>? eventSquadsRoless,
) =>
    eventSquadsRoless
        ?.map((e) => getEventSquadsRolesFirestoreData(e, true))
        .toList() ??
    [];
