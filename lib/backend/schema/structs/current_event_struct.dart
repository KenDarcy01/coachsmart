// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class CurrentEventStruct extends FFFirebaseStruct {
  CurrentEventStruct({
    int? teamId,
    int? eventId,
    String? eventLink,
    int? audienceId,
    String? eventImage,
    String? eventTitle,
    String? locationPin,
    int? eventCodeId,
    String? eventDetails,
    int? eventTypeId,
    String? locationName,
    String? eventDateTime,
    bool? requestAttendance,
    String? opposition,
    String? homeAway,
    String? meetTime,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _teamId = teamId,
        _eventId = eventId,
        _eventLink = eventLink,
        _audienceId = audienceId,
        _eventImage = eventImage,
        _eventTitle = eventTitle,
        _locationPin = locationPin,
        _eventCodeId = eventCodeId,
        _eventDetails = eventDetails,
        _eventTypeId = eventTypeId,
        _locationName = locationName,
        _eventDateTime = eventDateTime,
        _requestAttendance = requestAttendance,
        _opposition = opposition,
        _homeAway = homeAway,
        _meetTime = meetTime,
        super(firestoreUtilData);

  // "team_id" field.
  int? _teamId;
  int get teamId => _teamId ?? 0;
  set teamId(int? val) => _teamId = val;

  void incrementTeamId(int amount) => teamId = teamId + amount;

  bool hasTeamId() => _teamId != null;

  // "event_id" field.
  int? _eventId;
  int get eventId => _eventId ?? 0;
  set eventId(int? val) => _eventId = val;

  void incrementEventId(int amount) => eventId = eventId + amount;

  bool hasEventId() => _eventId != null;

  // "event_link" field.
  String? _eventLink;
  String get eventLink => _eventLink ?? '';
  set eventLink(String? val) => _eventLink = val;

  bool hasEventLink() => _eventLink != null;

  // "audience_id" field.
  int? _audienceId;
  int get audienceId => _audienceId ?? 0;
  set audienceId(int? val) => _audienceId = val;

  void incrementAudienceId(int amount) => audienceId = audienceId + amount;

  bool hasAudienceId() => _audienceId != null;

  // "event_image" field.
  String? _eventImage;
  String get eventImage => _eventImage ?? '';
  set eventImage(String? val) => _eventImage = val;

  bool hasEventImage() => _eventImage != null;

  // "event_title" field.
  String? _eventTitle;
  String get eventTitle => _eventTitle ?? '';
  set eventTitle(String? val) => _eventTitle = val;

  bool hasEventTitle() => _eventTitle != null;

  // "location_pin" field.
  String? _locationPin;
  String get locationPin => _locationPin ?? '';
  set locationPin(String? val) => _locationPin = val;

  bool hasLocationPin() => _locationPin != null;

  // "event_code_id" field.
  int? _eventCodeId;
  int get eventCodeId => _eventCodeId ?? 0;
  set eventCodeId(int? val) => _eventCodeId = val;

  void incrementEventCodeId(int amount) => eventCodeId = eventCodeId + amount;

  bool hasEventCodeId() => _eventCodeId != null;

  // "event_details" field.
  String? _eventDetails;
  String get eventDetails => _eventDetails ?? '';
  set eventDetails(String? val) => _eventDetails = val;

  bool hasEventDetails() => _eventDetails != null;

  // "event_type_id" field.
  int? _eventTypeId;
  int get eventTypeId => _eventTypeId ?? 0;
  set eventTypeId(int? val) => _eventTypeId = val;

  void incrementEventTypeId(int amount) => eventTypeId = eventTypeId + amount;

  bool hasEventTypeId() => _eventTypeId != null;

  // "location_name" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  set locationName(String? val) => _locationName = val;

  bool hasLocationName() => _locationName != null;

  // "event_date_time" field.
  String? _eventDateTime;
  String get eventDateTime => _eventDateTime ?? '';
  set eventDateTime(String? val) => _eventDateTime = val;

  bool hasEventDateTime() => _eventDateTime != null;

  // "request_attendance" field.
  bool? _requestAttendance;
  bool get requestAttendance => _requestAttendance ?? false;
  set requestAttendance(bool? val) => _requestAttendance = val;

  bool hasRequestAttendance() => _requestAttendance != null;

  // "opposition" field.
  String? _opposition;
  String get opposition => _opposition ?? '';
  set opposition(String? val) => _opposition = val;

  bool hasOpposition() => _opposition != null;

  // "home_away" field.
  String? _homeAway;
  String get homeAway => _homeAway ?? '';
  set homeAway(String? val) => _homeAway = val;

  bool hasHomeAway() => _homeAway != null;

  // "meet_time" field.
  String? _meetTime;
  String get meetTime => _meetTime ?? '';
  set meetTime(String? val) => _meetTime = val;

  bool hasMeetTime() => _meetTime != null;

  static CurrentEventStruct fromMap(Map<String, dynamic> data) =>
      CurrentEventStruct(
        teamId: castToType<int>(data['team_id']),
        eventId: castToType<int>(data['event_id']),
        eventLink: data['event_link'] as String?,
        audienceId: castToType<int>(data['audience_id']),
        eventImage: data['event_image'] as String?,
        eventTitle: data['event_title'] as String?,
        locationPin: data['location_pin'] as String?,
        eventCodeId: castToType<int>(data['event_code_id']),
        eventDetails: data['event_details'] as String?,
        eventTypeId: castToType<int>(data['event_type_id']),
        locationName: data['location_name'] as String?,
        eventDateTime: data['event_date_time'] as String?,
        requestAttendance: data['request_attendance'] as bool?,
        opposition: data['opposition'] as String?,
        homeAway: data['home_away'] as String?,
        meetTime: data['meet_time'] as String?,
      );

  static CurrentEventStruct? maybeFromMap(dynamic data) => data is Map
      ? CurrentEventStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'team_id': _teamId,
        'event_id': _eventId,
        'event_link': _eventLink,
        'audience_id': _audienceId,
        'event_image': _eventImage,
        'event_title': _eventTitle,
        'location_pin': _locationPin,
        'event_code_id': _eventCodeId,
        'event_details': _eventDetails,
        'event_type_id': _eventTypeId,
        'location_name': _locationName,
        'event_date_time': _eventDateTime,
        'request_attendance': _requestAttendance,
        'opposition': _opposition,
        'home_away': _homeAway,
        'meet_time': _meetTime,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
        'event_link': serializeParam(
          _eventLink,
          ParamType.String,
        ),
        'audience_id': serializeParam(
          _audienceId,
          ParamType.int,
        ),
        'event_image': serializeParam(
          _eventImage,
          ParamType.String,
        ),
        'event_title': serializeParam(
          _eventTitle,
          ParamType.String,
        ),
        'location_pin': serializeParam(
          _locationPin,
          ParamType.String,
        ),
        'event_code_id': serializeParam(
          _eventCodeId,
          ParamType.int,
        ),
        'event_details': serializeParam(
          _eventDetails,
          ParamType.String,
        ),
        'event_type_id': serializeParam(
          _eventTypeId,
          ParamType.int,
        ),
        'location_name': serializeParam(
          _locationName,
          ParamType.String,
        ),
        'event_date_time': serializeParam(
          _eventDateTime,
          ParamType.String,
        ),
        'request_attendance': serializeParam(
          _requestAttendance,
          ParamType.bool,
        ),
        'opposition': serializeParam(
          _opposition,
          ParamType.String,
        ),
        'home_away': serializeParam(
          _homeAway,
          ParamType.String,
        ),
        'meet_time': serializeParam(
          _meetTime,
          ParamType.String,
        ),
      }.withoutNulls;

  static CurrentEventStruct fromSerializableMap(Map<String, dynamic> data) =>
      CurrentEventStruct(
        teamId: deserializeParam(
          data['team_id'],
          ParamType.int,
          false,
        ),
        eventId: deserializeParam(
          data['event_id'],
          ParamType.int,
          false,
        ),
        eventLink: deserializeParam(
          data['event_link'],
          ParamType.String,
          false,
        ),
        audienceId: deserializeParam(
          data['audience_id'],
          ParamType.int,
          false,
        ),
        eventImage: deserializeParam(
          data['event_image'],
          ParamType.String,
          false,
        ),
        eventTitle: deserializeParam(
          data['event_title'],
          ParamType.String,
          false,
        ),
        locationPin: deserializeParam(
          data['location_pin'],
          ParamType.String,
          false,
        ),
        eventCodeId: deserializeParam(
          data['event_code_id'],
          ParamType.int,
          false,
        ),
        eventDetails: deserializeParam(
          data['event_details'],
          ParamType.String,
          false,
        ),
        eventTypeId: deserializeParam(
          data['event_type_id'],
          ParamType.int,
          false,
        ),
        locationName: deserializeParam(
          data['location_name'],
          ParamType.String,
          false,
        ),
        eventDateTime: deserializeParam(
          data['event_date_time'],
          ParamType.String,
          false,
        ),
        requestAttendance: deserializeParam(
          data['request_attendance'],
          ParamType.bool,
          false,
        ),
        opposition: deserializeParam(
          data['opposition'],
          ParamType.String,
          false,
        ),
        homeAway: deserializeParam(
          data['home_away'],
          ParamType.String,
          false,
        ),
        meetTime: deserializeParam(
          data['meet_time'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CurrentEventStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is CurrentEventStruct &&
        teamId == other.teamId &&
        eventId == other.eventId &&
        eventLink == other.eventLink &&
        audienceId == other.audienceId &&
        eventImage == other.eventImage &&
        eventTitle == other.eventTitle &&
        locationPin == other.locationPin &&
        eventCodeId == other.eventCodeId &&
        eventDetails == other.eventDetails &&
        eventTypeId == other.eventTypeId &&
        locationName == other.locationName &&
        eventDateTime == other.eventDateTime &&
        requestAttendance == other.requestAttendance &&
        opposition == other.opposition &&
        homeAway == other.homeAway &&
        meetTime == other.meetTime;
  }

  @override
  int get hashCode => const ListEquality().hash([
        teamId,
        eventId,
        eventLink,
        audienceId,
        eventImage,
        eventTitle,
        locationPin,
        eventCodeId,
        eventDetails,
        eventTypeId,
        locationName,
        eventDateTime,
        requestAttendance,
        opposition,
        homeAway,
        meetTime
      ]);
}

CurrentEventStruct createCurrentEventStruct({
  int? teamId,
  int? eventId,
  String? eventLink,
  int? audienceId,
  String? eventImage,
  String? eventTitle,
  String? locationPin,
  int? eventCodeId,
  String? eventDetails,
  int? eventTypeId,
  String? locationName,
  String? eventDateTime,
  bool? requestAttendance,
  String? opposition,
  String? homeAway,
  String? meetTime,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CurrentEventStruct(
      teamId: teamId,
      eventId: eventId,
      eventLink: eventLink,
      audienceId: audienceId,
      eventImage: eventImage,
      eventTitle: eventTitle,
      locationPin: locationPin,
      eventCodeId: eventCodeId,
      eventDetails: eventDetails,
      eventTypeId: eventTypeId,
      locationName: locationName,
      eventDateTime: eventDateTime,
      requestAttendance: requestAttendance,
      opposition: opposition,
      homeAway: homeAway,
      meetTime: meetTime,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CurrentEventStruct? updateCurrentEventStruct(
  CurrentEventStruct? currentEvent, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    currentEvent
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCurrentEventStructData(
  Map<String, dynamic> firestoreData,
  CurrentEventStruct? currentEvent,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (currentEvent == null) {
    return;
  }
  if (currentEvent.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && currentEvent.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final currentEventData =
      getCurrentEventFirestoreData(currentEvent, forFieldValue);
  final nestedData =
      currentEventData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = currentEvent.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCurrentEventFirestoreData(
  CurrentEventStruct? currentEvent, [
  bool forFieldValue = false,
]) {
  if (currentEvent == null) {
    return {};
  }
  final firestoreData = mapToFirestore(currentEvent.toMap());

  // Add any Firestore field values
  mapToFirestore(currentEvent.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCurrentEventListFirestoreData(
  List<CurrentEventStruct>? currentEvents,
) =>
    currentEvents?.map((e) => getCurrentEventFirestoreData(e, true)).toList() ??
    [];
