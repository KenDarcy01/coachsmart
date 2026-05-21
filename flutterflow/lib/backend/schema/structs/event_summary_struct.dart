// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class EventSummaryStruct extends FFFirebaseStruct {
  EventSummaryStruct({
    int? eventId,
    int? roleId,
    String? roleName,
    int? roleLevel,
    int? roleGrade,
    String? roleNamePlural,
    int? roleListSeq,
    int? acceptedAttendeesCount,
    int? declinedAttendeesCount,
    int? noResponseCount,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _eventId = eventId,
        _roleId = roleId,
        _roleName = roleName,
        _roleLevel = roleLevel,
        _roleGrade = roleGrade,
        _roleNamePlural = roleNamePlural,
        _roleListSeq = roleListSeq,
        _acceptedAttendeesCount = acceptedAttendeesCount,
        _declinedAttendeesCount = declinedAttendeesCount,
        _noResponseCount = noResponseCount,
        super(firestoreUtilData);

  // "event_id" field.
  int? _eventId;
  int get eventId => _eventId ?? 0;
  set eventId(int? val) => _eventId = val;

  void incrementEventId(int amount) => eventId = eventId + amount;

  bool hasEventId() => _eventId != null;

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

  // "accepted_attendees_count" field.
  int? _acceptedAttendeesCount;
  int get acceptedAttendeesCount => _acceptedAttendeesCount ?? 0;
  set acceptedAttendeesCount(int? val) => _acceptedAttendeesCount = val;

  void incrementAcceptedAttendeesCount(int amount) =>
      acceptedAttendeesCount = acceptedAttendeesCount + amount;

  bool hasAcceptedAttendeesCount() => _acceptedAttendeesCount != null;

  // "declined_attendees_count" field.
  int? _declinedAttendeesCount;
  int get declinedAttendeesCount => _declinedAttendeesCount ?? 0;
  set declinedAttendeesCount(int? val) => _declinedAttendeesCount = val;

  void incrementDeclinedAttendeesCount(int amount) =>
      declinedAttendeesCount = declinedAttendeesCount + amount;

  bool hasDeclinedAttendeesCount() => _declinedAttendeesCount != null;

  // "no_response_count" field.
  int? _noResponseCount;
  int get noResponseCount => _noResponseCount ?? 0;
  set noResponseCount(int? val) => _noResponseCount = val;

  void incrementNoResponseCount(int amount) =>
      noResponseCount = noResponseCount + amount;

  bool hasNoResponseCount() => _noResponseCount != null;

  static EventSummaryStruct fromMap(Map<String, dynamic> data) =>
      EventSummaryStruct(
        eventId: castToType<int>(data['event_id']),
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
        roleLevel: castToType<int>(data['role_level']),
        roleGrade: castToType<int>(data['role_grade']),
        roleNamePlural: data['role_name_plural'] as String?,
        roleListSeq: castToType<int>(data['role_list_seq']),
        acceptedAttendeesCount:
            castToType<int>(data['accepted_attendees_count']),
        declinedAttendeesCount:
            castToType<int>(data['declined_attendees_count']),
        noResponseCount: castToType<int>(data['no_response_count']),
      );

  static EventSummaryStruct? maybeFromMap(dynamic data) => data is Map
      ? EventSummaryStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'event_id': _eventId,
        'role_id': _roleId,
        'role_name': _roleName,
        'role_level': _roleLevel,
        'role_grade': _roleGrade,
        'role_name_plural': _roleNamePlural,
        'role_list_seq': _roleListSeq,
        'accepted_attendees_count': _acceptedAttendeesCount,
        'declined_attendees_count': _declinedAttendeesCount,
        'no_response_count': _noResponseCount,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
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
        'role_name_plural': serializeParam(
          _roleNamePlural,
          ParamType.String,
        ),
        'role_list_seq': serializeParam(
          _roleListSeq,
          ParamType.int,
        ),
        'accepted_attendees_count': serializeParam(
          _acceptedAttendeesCount,
          ParamType.int,
        ),
        'declined_attendees_count': serializeParam(
          _declinedAttendeesCount,
          ParamType.int,
        ),
        'no_response_count': serializeParam(
          _noResponseCount,
          ParamType.int,
        ),
      }.withoutNulls;

  static EventSummaryStruct fromSerializableMap(Map<String, dynamic> data) =>
      EventSummaryStruct(
        eventId: deserializeParam(
          data['event_id'],
          ParamType.int,
          false,
        ),
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
        acceptedAttendeesCount: deserializeParam(
          data['accepted_attendees_count'],
          ParamType.int,
          false,
        ),
        declinedAttendeesCount: deserializeParam(
          data['declined_attendees_count'],
          ParamType.int,
          false,
        ),
        noResponseCount: deserializeParam(
          data['no_response_count'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'EventSummaryStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is EventSummaryStruct &&
        eventId == other.eventId &&
        roleId == other.roleId &&
        roleName == other.roleName &&
        roleLevel == other.roleLevel &&
        roleGrade == other.roleGrade &&
        roleNamePlural == other.roleNamePlural &&
        roleListSeq == other.roleListSeq &&
        acceptedAttendeesCount == other.acceptedAttendeesCount &&
        declinedAttendeesCount == other.declinedAttendeesCount &&
        noResponseCount == other.noResponseCount;
  }

  @override
  int get hashCode => const ListEquality().hash([
        eventId,
        roleId,
        roleName,
        roleLevel,
        roleGrade,
        roleNamePlural,
        roleListSeq,
        acceptedAttendeesCount,
        declinedAttendeesCount,
        noResponseCount
      ]);
}

EventSummaryStruct createEventSummaryStruct({
  int? eventId,
  int? roleId,
  String? roleName,
  int? roleLevel,
  int? roleGrade,
  String? roleNamePlural,
  int? roleListSeq,
  int? acceptedAttendeesCount,
  int? declinedAttendeesCount,
  int? noResponseCount,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventSummaryStruct(
      eventId: eventId,
      roleId: roleId,
      roleName: roleName,
      roleLevel: roleLevel,
      roleGrade: roleGrade,
      roleNamePlural: roleNamePlural,
      roleListSeq: roleListSeq,
      acceptedAttendeesCount: acceptedAttendeesCount,
      declinedAttendeesCount: declinedAttendeesCount,
      noResponseCount: noResponseCount,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventSummaryStruct? updateEventSummaryStruct(
  EventSummaryStruct? eventSummary, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventSummary
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventSummaryStructData(
  Map<String, dynamic> firestoreData,
  EventSummaryStruct? eventSummary,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventSummary == null) {
    return;
  }
  if (eventSummary.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventSummary.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventSummaryData =
      getEventSummaryFirestoreData(eventSummary, forFieldValue);
  final nestedData =
      eventSummaryData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = eventSummary.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventSummaryFirestoreData(
  EventSummaryStruct? eventSummary, [
  bool forFieldValue = false,
]) {
  if (eventSummary == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventSummary.toMap());

  // Add any Firestore field values
  mapToFirestore(eventSummary.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventSummaryListFirestoreData(
  List<EventSummaryStruct>? eventSummarys,
) =>
    eventSummarys?.map((e) => getEventSummaryFirestoreData(e, true)).toList() ??
    [];
