// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CreateTeamsStruct extends FFFirebaseStruct {
  CreateTeamsStruct({
    int? clubId,
    int? roleId,
    int? teamId,
    String? clubName,
    int? memberId,
    String? teamName,
    String? adminRole,
    List<TeamRolesStruct>? teamRoles,
    int? adminLevel,
    List<EventCodesStruct>? eventCodes,
    List<EventTypesStruct>? eventTypes,
    String? authorizedMemberName,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _clubId = clubId,
        _roleId = roleId,
        _teamId = teamId,
        _clubName = clubName,
        _memberId = memberId,
        _teamName = teamName,
        _adminRole = adminRole,
        _teamRoles = teamRoles,
        _adminLevel = adminLevel,
        _eventCodes = eventCodes,
        _eventTypes = eventTypes,
        _authorizedMemberName = authorizedMemberName,
        super(firestoreUtilData);

  // "club_id" field.
  int? _clubId;
  int get clubId => _clubId ?? 0;
  set clubId(int? val) => _clubId = val;

  void incrementClubId(int amount) => clubId = clubId + amount;

  bool hasClubId() => _clubId != null;

  // "role_id" field.
  int? _roleId;
  int get roleId => _roleId ?? 0;
  set roleId(int? val) => _roleId = val;

  void incrementRoleId(int amount) => roleId = roleId + amount;

  bool hasRoleId() => _roleId != null;

  // "team_id" field.
  int? _teamId;
  int get teamId => _teamId ?? 0;
  set teamId(int? val) => _teamId = val;

  void incrementTeamId(int amount) => teamId = teamId + amount;

  bool hasTeamId() => _teamId != null;

  // "club_name" field.
  String? _clubName;
  String get clubName => _clubName ?? '';
  set clubName(String? val) => _clubName = val;

  bool hasClubName() => _clubName != null;

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

  // "admin_role" field.
  String? _adminRole;
  String get adminRole => _adminRole ?? '';
  set adminRole(String? val) => _adminRole = val;

  bool hasAdminRole() => _adminRole != null;

  // "team_roles" field.
  List<TeamRolesStruct>? _teamRoles;
  List<TeamRolesStruct> get teamRoles => _teamRoles ?? const [];
  set teamRoles(List<TeamRolesStruct>? val) => _teamRoles = val;

  void updateTeamRoles(Function(List<TeamRolesStruct>) updateFn) {
    updateFn(_teamRoles ??= []);
  }

  bool hasTeamRoles() => _teamRoles != null;

  // "admin_level" field.
  int? _adminLevel;
  int get adminLevel => _adminLevel ?? 0;
  set adminLevel(int? val) => _adminLevel = val;

  void incrementAdminLevel(int amount) => adminLevel = adminLevel + amount;

  bool hasAdminLevel() => _adminLevel != null;

  // "event_codes" field.
  List<EventCodesStruct>? _eventCodes;
  List<EventCodesStruct> get eventCodes => _eventCodes ?? const [];
  set eventCodes(List<EventCodesStruct>? val) => _eventCodes = val;

  void updateEventCodes(Function(List<EventCodesStruct>) updateFn) {
    updateFn(_eventCodes ??= []);
  }

  bool hasEventCodes() => _eventCodes != null;

  // "event_types" field.
  List<EventTypesStruct>? _eventTypes;
  List<EventTypesStruct> get eventTypes => _eventTypes ?? const [];
  set eventTypes(List<EventTypesStruct>? val) => _eventTypes = val;

  void updateEventTypes(Function(List<EventTypesStruct>) updateFn) {
    updateFn(_eventTypes ??= []);
  }

  bool hasEventTypes() => _eventTypes != null;

  // "authorized_member_name" field.
  String? _authorizedMemberName;
  String get authorizedMemberName => _authorizedMemberName ?? '';
  set authorizedMemberName(String? val) => _authorizedMemberName = val;

  bool hasAuthorizedMemberName() => _authorizedMemberName != null;

  static CreateTeamsStruct fromMap(Map<String, dynamic> data) =>
      CreateTeamsStruct(
        clubId: castToType<int>(data['club_id']),
        roleId: castToType<int>(data['role_id']),
        teamId: castToType<int>(data['team_id']),
        clubName: data['club_name'] as String?,
        memberId: castToType<int>(data['member_id']),
        teamName: data['team_name'] as String?,
        adminRole: data['admin_role'] as String?,
        teamRoles: getStructList(
          data['team_roles'],
          TeamRolesStruct.fromMap,
        ),
        adminLevel: castToType<int>(data['admin_level']),
        eventCodes: getStructList(
          data['event_codes'],
          EventCodesStruct.fromMap,
        ),
        eventTypes: getStructList(
          data['event_types'],
          EventTypesStruct.fromMap,
        ),
        authorizedMemberName: data['authorized_member_name'] as String?,
      );

  static CreateTeamsStruct? maybeFromMap(dynamic data) => data is Map
      ? CreateTeamsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'club_id': _clubId,
        'role_id': _roleId,
        'team_id': _teamId,
        'club_name': _clubName,
        'member_id': _memberId,
        'team_name': _teamName,
        'admin_role': _adminRole,
        'team_roles': _teamRoles?.map((e) => e.toMap()).toList(),
        'admin_level': _adminLevel,
        'event_codes': _eventCodes?.map((e) => e.toMap()).toList(),
        'event_types': _eventTypes?.map((e) => e.toMap()).toList(),
        'authorized_member_name': _authorizedMemberName,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'club_id': serializeParam(
          _clubId,
          ParamType.int,
        ),
        'role_id': serializeParam(
          _roleId,
          ParamType.int,
        ),
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'club_name': serializeParam(
          _clubName,
          ParamType.String,
        ),
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'admin_role': serializeParam(
          _adminRole,
          ParamType.String,
        ),
        'team_roles': serializeParam(
          _teamRoles,
          ParamType.DataStruct,
          isList: true,
        ),
        'admin_level': serializeParam(
          _adminLevel,
          ParamType.int,
        ),
        'event_codes': serializeParam(
          _eventCodes,
          ParamType.DataStruct,
          isList: true,
        ),
        'event_types': serializeParam(
          _eventTypes,
          ParamType.DataStruct,
          isList: true,
        ),
        'authorized_member_name': serializeParam(
          _authorizedMemberName,
          ParamType.String,
        ),
      }.withoutNulls;

  static CreateTeamsStruct fromSerializableMap(Map<String, dynamic> data) =>
      CreateTeamsStruct(
        clubId: deserializeParam(
          data['club_id'],
          ParamType.int,
          false,
        ),
        roleId: deserializeParam(
          data['role_id'],
          ParamType.int,
          false,
        ),
        teamId: deserializeParam(
          data['team_id'],
          ParamType.int,
          false,
        ),
        clubName: deserializeParam(
          data['club_name'],
          ParamType.String,
          false,
        ),
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        teamName: deserializeParam(
          data['team_name'],
          ParamType.String,
          false,
        ),
        adminRole: deserializeParam(
          data['admin_role'],
          ParamType.String,
          false,
        ),
        teamRoles: deserializeStructParam<TeamRolesStruct>(
          data['team_roles'],
          ParamType.DataStruct,
          true,
          structBuilder: TeamRolesStruct.fromSerializableMap,
        ),
        adminLevel: deserializeParam(
          data['admin_level'],
          ParamType.int,
          false,
        ),
        eventCodes: deserializeStructParam<EventCodesStruct>(
          data['event_codes'],
          ParamType.DataStruct,
          true,
          structBuilder: EventCodesStruct.fromSerializableMap,
        ),
        eventTypes: deserializeStructParam<EventTypesStruct>(
          data['event_types'],
          ParamType.DataStruct,
          true,
          structBuilder: EventTypesStruct.fromSerializableMap,
        ),
        authorizedMemberName: deserializeParam(
          data['authorized_member_name'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CreateTeamsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is CreateTeamsStruct &&
        clubId == other.clubId &&
        roleId == other.roleId &&
        teamId == other.teamId &&
        clubName == other.clubName &&
        memberId == other.memberId &&
        teamName == other.teamName &&
        adminRole == other.adminRole &&
        listEquality.equals(teamRoles, other.teamRoles) &&
        adminLevel == other.adminLevel &&
        listEquality.equals(eventCodes, other.eventCodes) &&
        listEquality.equals(eventTypes, other.eventTypes) &&
        authorizedMemberName == other.authorizedMemberName;
  }

  @override
  int get hashCode => const ListEquality().hash([
        clubId,
        roleId,
        teamId,
        clubName,
        memberId,
        teamName,
        adminRole,
        teamRoles,
        adminLevel,
        eventCodes,
        eventTypes,
        authorizedMemberName
      ]);
}

CreateTeamsStruct createCreateTeamsStruct({
  int? clubId,
  int? roleId,
  int? teamId,
  String? clubName,
  int? memberId,
  String? teamName,
  String? adminRole,
  int? adminLevel,
  String? authorizedMemberName,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CreateTeamsStruct(
      clubId: clubId,
      roleId: roleId,
      teamId: teamId,
      clubName: clubName,
      memberId: memberId,
      teamName: teamName,
      adminRole: adminRole,
      adminLevel: adminLevel,
      authorizedMemberName: authorizedMemberName,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CreateTeamsStruct? updateCreateTeamsStruct(
  CreateTeamsStruct? createTeams, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    createTeams
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCreateTeamsStructData(
  Map<String, dynamic> firestoreData,
  CreateTeamsStruct? createTeams,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (createTeams == null) {
    return;
  }
  if (createTeams.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && createTeams.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final createTeamsData =
      getCreateTeamsFirestoreData(createTeams, forFieldValue);
  final nestedData =
      createTeamsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = createTeams.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCreateTeamsFirestoreData(
  CreateTeamsStruct? createTeams, [
  bool forFieldValue = false,
]) {
  if (createTeams == null) {
    return {};
  }
  final firestoreData = mapToFirestore(createTeams.toMap());

  // Add any Firestore field values
  mapToFirestore(createTeams.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCreateTeamsListFirestoreData(
  List<CreateTeamsStruct>? createTeamss,
) =>
    createTeamss?.map((e) => getCreateTeamsFirestoreData(e, true)).toList() ??
    [];
