// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventSquadsStruct extends FFFirebaseStruct {
  EventSquadsStruct({
    int? squadId,
    String? squadName,
    int? roleLevelCount,
    String? squadImage,
    List<EventSquadsRolesStruct>? roles,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _squadId = squadId,
        _squadName = squadName,
        _roleLevelCount = roleLevelCount,
        _squadImage = squadImage,
        _roles = roles,
        super(firestoreUtilData);

  // "squad_id" field.
  int? _squadId;
  int get squadId => _squadId ?? 0;
  set squadId(int? val) => _squadId = val;

  void incrementSquadId(int amount) => squadId = squadId + amount;

  bool hasSquadId() => _squadId != null;

  // "squad_name" field.
  String? _squadName;
  String get squadName => _squadName ?? '';
  set squadName(String? val) => _squadName = val;

  bool hasSquadName() => _squadName != null;

  // "role_level_count" field.
  int? _roleLevelCount;
  int get roleLevelCount => _roleLevelCount ?? 0;
  set roleLevelCount(int? val) => _roleLevelCount = val;

  void incrementRoleLevelCount(int amount) =>
      roleLevelCount = roleLevelCount + amount;

  bool hasRoleLevelCount() => _roleLevelCount != null;

  // "squad_image" field.
  String? _squadImage;
  String get squadImage => _squadImage ?? '';
  set squadImage(String? val) => _squadImage = val;

  bool hasSquadImage() => _squadImage != null;

  // "roles" field.
  List<EventSquadsRolesStruct>? _roles;
  List<EventSquadsRolesStruct> get roles => _roles ?? const [];
  set roles(List<EventSquadsRolesStruct>? val) => _roles = val;

  void updateRoles(Function(List<EventSquadsRolesStruct>) updateFn) {
    updateFn(_roles ??= []);
  }

  bool hasRoles() => _roles != null;

  static EventSquadsStruct fromMap(Map<String, dynamic> data) =>
      EventSquadsStruct(
        squadId: castToType<int>(data['squad_id']),
        squadName: data['squad_name'] as String?,
        roleLevelCount: castToType<int>(data['role_level_count']),
        squadImage: data['squad_image'] as String?,
        roles: getStructList(
          data['roles'],
          EventSquadsRolesStruct.fromMap,
        ),
      );

  static EventSquadsStruct? maybeFromMap(dynamic data) => data is Map
      ? EventSquadsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'squad_id': _squadId,
        'squad_name': _squadName,
        'role_level_count': _roleLevelCount,
        'squad_image': _squadImage,
        'roles': _roles?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'squad_id': serializeParam(
          _squadId,
          ParamType.int,
        ),
        'squad_name': serializeParam(
          _squadName,
          ParamType.String,
        ),
        'role_level_count': serializeParam(
          _roleLevelCount,
          ParamType.int,
        ),
        'squad_image': serializeParam(
          _squadImage,
          ParamType.String,
        ),
        'roles': serializeParam(
          _roles,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static EventSquadsStruct fromSerializableMap(Map<String, dynamic> data) =>
      EventSquadsStruct(
        squadId: deserializeParam(
          data['squad_id'],
          ParamType.int,
          false,
        ),
        squadName: deserializeParam(
          data['squad_name'],
          ParamType.String,
          false,
        ),
        roleLevelCount: deserializeParam(
          data['role_level_count'],
          ParamType.int,
          false,
        ),
        squadImage: deserializeParam(
          data['squad_image'],
          ParamType.String,
          false,
        ),
        roles: deserializeStructParam<EventSquadsRolesStruct>(
          data['roles'],
          ParamType.DataStruct,
          true,
          structBuilder: EventSquadsRolesStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'EventSquadsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is EventSquadsStruct &&
        squadId == other.squadId &&
        squadName == other.squadName &&
        roleLevelCount == other.roleLevelCount &&
        squadImage == other.squadImage &&
        listEquality.equals(roles, other.roles);
  }

  @override
  int get hashCode => const ListEquality()
      .hash([squadId, squadName, roleLevelCount, squadImage, roles]);
}

EventSquadsStruct createEventSquadsStruct({
  int? squadId,
  String? squadName,
  int? roleLevelCount,
  String? squadImage,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventSquadsStruct(
      squadId: squadId,
      squadName: squadName,
      roleLevelCount: roleLevelCount,
      squadImage: squadImage,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventSquadsStruct? updateEventSquadsStruct(
  EventSquadsStruct? eventSquads, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventSquads
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventSquadsStructData(
  Map<String, dynamic> firestoreData,
  EventSquadsStruct? eventSquads,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventSquads == null) {
    return;
  }
  if (eventSquads.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventSquads.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventSquadsData =
      getEventSquadsFirestoreData(eventSquads, forFieldValue);
  final nestedData =
      eventSquadsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = eventSquads.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventSquadsFirestoreData(
  EventSquadsStruct? eventSquads, [
  bool forFieldValue = false,
]) {
  if (eventSquads == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventSquads.toMap());

  // Add any Firestore field values
  mapToFirestore(eventSquads.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventSquadsListFirestoreData(
  List<EventSquadsStruct>? eventSquadss,
) =>
    eventSquadss?.map((e) => getEventSquadsFirestoreData(e, true)).toList() ??
    [];
