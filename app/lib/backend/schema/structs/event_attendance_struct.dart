// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventAttendanceStruct extends FFFirebaseStruct {
  EventAttendanceStruct({
    int? eventId,
    String? teamName,
    int? responseId,
    List<EventSquadsStruct>? squads,
    int? eventCodeId,
    bool? matchSquadAvailable,
    bool? allowLineup,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _eventId = eventId,
        _teamName = teamName,
        _responseId = responseId,
        _squads = squads,
        _eventCodeId = eventCodeId,
        _matchSquadAvailable = matchSquadAvailable,
        _allowLineup = allowLineup,
        super(firestoreUtilData);

  // "event_id" field.
  int? _eventId;
  int get eventId => _eventId ?? 0;
  set eventId(int? val) => _eventId = val;

  void incrementEventId(int amount) => eventId = eventId + amount;

  bool hasEventId() => _eventId != null;

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

  // "response_id" field.
  int? _responseId;
  int get responseId => _responseId ?? 0;
  set responseId(int? val) => _responseId = val;

  void incrementResponseId(int amount) => responseId = responseId + amount;

  bool hasResponseId() => _responseId != null;

  // "squads" field.
  List<EventSquadsStruct>? _squads;
  List<EventSquadsStruct> get squads => _squads ?? const [];
  set squads(List<EventSquadsStruct>? val) => _squads = val;

  void updateSquads(Function(List<EventSquadsStruct>) updateFn) {
    updateFn(_squads ??= []);
  }

  bool hasSquads() => _squads != null;

  // "event_code_id" field.
  int? _eventCodeId;
  int get eventCodeId => _eventCodeId ?? 0;
  set eventCodeId(int? val) => _eventCodeId = val;

  void incrementEventCodeId(int amount) => eventCodeId = eventCodeId + amount;

  bool hasEventCodeId() => _eventCodeId != null;

  // "match_squad_available" field.
  bool? _matchSquadAvailable;
  bool get matchSquadAvailable => _matchSquadAvailable ?? false;
  set matchSquadAvailable(bool? val) => _matchSquadAvailable = val;

  bool hasMatchSquadAvailable() => _matchSquadAvailable != null;

  // "allow_lineup" field.
  bool? _allowLineup;
  bool get allowLineup => _allowLineup ?? false;
  set allowLineup(bool? val) => _allowLineup = val;

  bool hasAllowLineup() => _allowLineup != null;

  static EventAttendanceStruct fromMap(Map<String, dynamic> data) =>
      EventAttendanceStruct(
        eventId: castToType<int>(data['event_id']),
        teamName: data['team_name'] as String?,
        responseId: castToType<int>(data['response_id']),
        squads: getStructList(
          data['squads'],
          EventSquadsStruct.fromMap,
        ),
        eventCodeId: castToType<int>(data['event_code_id']),
        matchSquadAvailable: data['match_squad_available'] as bool?,
        allowLineup: data['allow_lineup'] as bool?,
      );

  static EventAttendanceStruct? maybeFromMap(dynamic data) => data is Map
      ? EventAttendanceStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'event_id': _eventId,
        'team_name': _teamName,
        'response_id': _responseId,
        'squads': _squads?.map((e) => e.toMap()).toList(),
        'event_code_id': _eventCodeId,
        'match_squad_available': _matchSquadAvailable,
        'allow_lineup': _allowLineup,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'response_id': serializeParam(
          _responseId,
          ParamType.int,
        ),
        'squads': serializeParam(
          _squads,
          ParamType.DataStruct,
          isList: true,
        ),
        'event_code_id': serializeParam(
          _eventCodeId,
          ParamType.int,
        ),
        'match_squad_available': serializeParam(
          _matchSquadAvailable,
          ParamType.bool,
        ),
        'allow_lineup': serializeParam(
          _allowLineup,
          ParamType.bool,
        ),
      }.withoutNulls;

  static EventAttendanceStruct fromSerializableMap(Map<String, dynamic> data) =>
      EventAttendanceStruct(
        eventId: deserializeParam(
          data['event_id'],
          ParamType.int,
          false,
        ),
        teamName: deserializeParam(
          data['team_name'],
          ParamType.String,
          false,
        ),
        responseId: deserializeParam(
          data['response_id'],
          ParamType.int,
          false,
        ),
        squads: deserializeStructParam<EventSquadsStruct>(
          data['squads'],
          ParamType.DataStruct,
          true,
          structBuilder: EventSquadsStruct.fromSerializableMap,
        ),
        eventCodeId: deserializeParam(
          data['event_code_id'],
          ParamType.int,
          false,
        ),
        matchSquadAvailable: deserializeParam(
          data['match_squad_available'],
          ParamType.bool,
          false,
        ),
        allowLineup: deserializeParam(
          data['allow_lineup'],
          ParamType.bool,
          false,
        ),
      );

  @override
  String toString() => 'EventAttendanceStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is EventAttendanceStruct &&
        eventId == other.eventId &&
        teamName == other.teamName &&
        responseId == other.responseId &&
        listEquality.equals(squads, other.squads) &&
        eventCodeId == other.eventCodeId &&
        matchSquadAvailable == other.matchSquadAvailable &&
        allowLineup == other.allowLineup;
  }

  @override
  int get hashCode => const ListEquality().hash([
        eventId,
        teamName,
        responseId,
        squads,
        eventCodeId,
        matchSquadAvailable,
        allowLineup
      ]);
}

EventAttendanceStruct createEventAttendanceStruct({
  int? eventId,
  String? teamName,
  int? responseId,
  int? eventCodeId,
  bool? matchSquadAvailable,
  bool? allowLineup,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventAttendanceStruct(
      eventId: eventId,
      teamName: teamName,
      responseId: responseId,
      eventCodeId: eventCodeId,
      matchSquadAvailable: matchSquadAvailable,
      allowLineup: allowLineup,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventAttendanceStruct? updateEventAttendanceStruct(
  EventAttendanceStruct? eventAttendance, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventAttendance
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventAttendanceStructData(
  Map<String, dynamic> firestoreData,
  EventAttendanceStruct? eventAttendance,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventAttendance == null) {
    return;
  }
  if (eventAttendance.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventAttendance.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventAttendanceData =
      getEventAttendanceFirestoreData(eventAttendance, forFieldValue);
  final nestedData =
      eventAttendanceData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = eventAttendance.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventAttendanceFirestoreData(
  EventAttendanceStruct? eventAttendance, [
  bool forFieldValue = false,
]) {
  if (eventAttendance == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventAttendance.toMap());

  // Add any Firestore field values
  mapToFirestore(eventAttendance.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventAttendanceListFirestoreData(
  List<EventAttendanceStruct>? eventAttendances,
) =>
    eventAttendances
        ?.map((e) => getEventAttendanceFirestoreData(e, true))
        .toList() ??
    [];
