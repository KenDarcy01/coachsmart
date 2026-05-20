// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventAttedanceDetailsStruct extends FFFirebaseStruct {
  EventAttedanceDetailsStruct({
    int? eventId,
    String? eventTitle,
    String? teamName,
    List<AttendeesStruct>? attendees,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _eventId = eventId,
        _eventTitle = eventTitle,
        _teamName = teamName,
        _attendees = attendees,
        super(firestoreUtilData);

  // "event_id" field.
  int? _eventId;
  int get eventId => _eventId ?? 0;
  set eventId(int? val) => _eventId = val;

  void incrementEventId(int amount) => eventId = eventId + amount;

  bool hasEventId() => _eventId != null;

  // "event_title" field.
  String? _eventTitle;
  String get eventTitle => _eventTitle ?? '';
  set eventTitle(String? val) => _eventTitle = val;

  bool hasEventTitle() => _eventTitle != null;

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

  // "attendees" field.
  List<AttendeesStruct>? _attendees;
  List<AttendeesStruct> get attendees => _attendees ?? const [];
  set attendees(List<AttendeesStruct>? val) => _attendees = val;

  void updateAttendees(Function(List<AttendeesStruct>) updateFn) {
    updateFn(_attendees ??= []);
  }

  bool hasAttendees() => _attendees != null;

  static EventAttedanceDetailsStruct fromMap(Map<String, dynamic> data) =>
      EventAttedanceDetailsStruct(
        eventId: castToType<int>(data['event_id']),
        eventTitle: data['event_title'] as String?,
        teamName: data['team_name'] as String?,
        attendees: getStructList(
          data['attendees'],
          AttendeesStruct.fromMap,
        ),
      );

  static EventAttedanceDetailsStruct? maybeFromMap(dynamic data) => data is Map
      ? EventAttedanceDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'event_id': _eventId,
        'event_title': _eventTitle,
        'team_name': _teamName,
        'attendees': _attendees?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
        'event_title': serializeParam(
          _eventTitle,
          ParamType.String,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'attendees': serializeParam(
          _attendees,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static EventAttedanceDetailsStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      EventAttedanceDetailsStruct(
        eventId: deserializeParam(
          data['event_id'],
          ParamType.int,
          false,
        ),
        eventTitle: deserializeParam(
          data['event_title'],
          ParamType.String,
          false,
        ),
        teamName: deserializeParam(
          data['team_name'],
          ParamType.String,
          false,
        ),
        attendees: deserializeStructParam<AttendeesStruct>(
          data['attendees'],
          ParamType.DataStruct,
          true,
          structBuilder: AttendeesStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'EventAttedanceDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is EventAttedanceDetailsStruct &&
        eventId == other.eventId &&
        eventTitle == other.eventTitle &&
        teamName == other.teamName &&
        listEquality.equals(attendees, other.attendees);
  }

  @override
  int get hashCode =>
      const ListEquality().hash([eventId, eventTitle, teamName, attendees]);
}

EventAttedanceDetailsStruct createEventAttedanceDetailsStruct({
  int? eventId,
  String? eventTitle,
  String? teamName,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventAttedanceDetailsStruct(
      eventId: eventId,
      eventTitle: eventTitle,
      teamName: teamName,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventAttedanceDetailsStruct? updateEventAttedanceDetailsStruct(
  EventAttedanceDetailsStruct? eventAttedanceDetails, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventAttedanceDetails
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventAttedanceDetailsStructData(
  Map<String, dynamic> firestoreData,
  EventAttedanceDetailsStruct? eventAttedanceDetails,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventAttedanceDetails == null) {
    return;
  }
  if (eventAttedanceDetails.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields = !forFieldValue &&
      eventAttedanceDetails.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventAttedanceDetailsData = getEventAttedanceDetailsFirestoreData(
      eventAttedanceDetails, forFieldValue);
  final nestedData =
      eventAttedanceDetailsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      eventAttedanceDetails.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventAttedanceDetailsFirestoreData(
  EventAttedanceDetailsStruct? eventAttedanceDetails, [
  bool forFieldValue = false,
]) {
  if (eventAttedanceDetails == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventAttedanceDetails.toMap());

  // Add any Firestore field values
  mapToFirestore(eventAttedanceDetails.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventAttedanceDetailsListFirestoreData(
  List<EventAttedanceDetailsStruct>? eventAttedanceDetailss,
) =>
    eventAttedanceDetailss
        ?.map((e) => getEventAttedanceDetailsFirestoreData(e, true))
        .toList() ??
    [];
