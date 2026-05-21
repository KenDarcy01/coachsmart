// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class SearchEventStruct extends FFFirebaseStruct {
  SearchEventStruct({
    int? clubId,
    int? teamId,
    int? eventId,
    String? homeAway,
    String? meetTime,
    String? teamName,
    String? createdBy,
    String? eventCode,
    String? eventLink,
    String? eventType,
    String? opposition,
    String? eventTitle,
    String? locationPin,
    String? eventDetails,
    String? locationName,
    int? acceptedCount,
    int? declinedCount,
    int? noResponseCount,
    bool? notifyAdminsAll,
    bool? requestAttendance,
    String? createdByUserName,
    bool? notifyAdminsChanges,
    int? totalEligibleMembers,
    String? createdByPhoneNumber,
    String? eventDateTimeFormatted,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _clubId = clubId,
        _teamId = teamId,
        _eventId = eventId,
        _homeAway = homeAway,
        _meetTime = meetTime,
        _teamName = teamName,
        _createdBy = createdBy,
        _eventCode = eventCode,
        _eventLink = eventLink,
        _eventType = eventType,
        _opposition = opposition,
        _eventTitle = eventTitle,
        _locationPin = locationPin,
        _eventDetails = eventDetails,
        _locationName = locationName,
        _acceptedCount = acceptedCount,
        _declinedCount = declinedCount,
        _noResponseCount = noResponseCount,
        _notifyAdminsAll = notifyAdminsAll,
        _requestAttendance = requestAttendance,
        _createdByUserName = createdByUserName,
        _notifyAdminsChanges = notifyAdminsChanges,
        _totalEligibleMembers = totalEligibleMembers,
        _createdByPhoneNumber = createdByPhoneNumber,
        _eventDateTimeFormatted = eventDateTimeFormatted,
        super(firestoreUtilData);

  // "club_id" field.
  int? _clubId;
  int get clubId => _clubId ?? 0;
  set clubId(int? val) => _clubId = val;

  void incrementClubId(int amount) => clubId = clubId + amount;

  bool hasClubId() => _clubId != null;

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

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

  // "created_by" field.
  String? _createdBy;
  String get createdBy => _createdBy ?? '';
  set createdBy(String? val) => _createdBy = val;

  bool hasCreatedBy() => _createdBy != null;

  // "event_code" field.
  String? _eventCode;
  String get eventCode => _eventCode ?? '';
  set eventCode(String? val) => _eventCode = val;

  bool hasEventCode() => _eventCode != null;

  // "event_link" field.
  String? _eventLink;
  String get eventLink => _eventLink ?? '';
  set eventLink(String? val) => _eventLink = val;

  bool hasEventLink() => _eventLink != null;

  // "event_type" field.
  String? _eventType;
  String get eventType => _eventType ?? '';
  set eventType(String? val) => _eventType = val;

  bool hasEventType() => _eventType != null;

  // "opposition" field.
  String? _opposition;
  String get opposition => _opposition ?? '';
  set opposition(String? val) => _opposition = val;

  bool hasOpposition() => _opposition != null;

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

  // "event_details" field.
  String? _eventDetails;
  String get eventDetails => _eventDetails ?? '';
  set eventDetails(String? val) => _eventDetails = val;

  bool hasEventDetails() => _eventDetails != null;

  // "location_name" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  set locationName(String? val) => _locationName = val;

  bool hasLocationName() => _locationName != null;

  // "accepted_count" field.
  int? _acceptedCount;
  int get acceptedCount => _acceptedCount ?? 0;
  set acceptedCount(int? val) => _acceptedCount = val;

  void incrementAcceptedCount(int amount) =>
      acceptedCount = acceptedCount + amount;

  bool hasAcceptedCount() => _acceptedCount != null;

  // "declined_count" field.
  int? _declinedCount;
  int get declinedCount => _declinedCount ?? 0;
  set declinedCount(int? val) => _declinedCount = val;

  void incrementDeclinedCount(int amount) =>
      declinedCount = declinedCount + amount;

  bool hasDeclinedCount() => _declinedCount != null;

  // "no_response_count" field.
  int? _noResponseCount;
  int get noResponseCount => _noResponseCount ?? 0;
  set noResponseCount(int? val) => _noResponseCount = val;

  void incrementNoResponseCount(int amount) =>
      noResponseCount = noResponseCount + amount;

  bool hasNoResponseCount() => _noResponseCount != null;

  // "notify_admins_all" field.
  bool? _notifyAdminsAll;
  bool get notifyAdminsAll => _notifyAdminsAll ?? false;
  set notifyAdminsAll(bool? val) => _notifyAdminsAll = val;

  bool hasNotifyAdminsAll() => _notifyAdminsAll != null;

  // "request_attendance" field.
  bool? _requestAttendance;
  bool get requestAttendance => _requestAttendance ?? false;
  set requestAttendance(bool? val) => _requestAttendance = val;

  bool hasRequestAttendance() => _requestAttendance != null;

  // "created_by_user_name" field.
  String? _createdByUserName;
  String get createdByUserName => _createdByUserName ?? '';
  set createdByUserName(String? val) => _createdByUserName = val;

  bool hasCreatedByUserName() => _createdByUserName != null;

  // "notify_admins_changes" field.
  bool? _notifyAdminsChanges;
  bool get notifyAdminsChanges => _notifyAdminsChanges ?? false;
  set notifyAdminsChanges(bool? val) => _notifyAdminsChanges = val;

  bool hasNotifyAdminsChanges() => _notifyAdminsChanges != null;

  // "total_eligible_members" field.
  int? _totalEligibleMembers;
  int get totalEligibleMembers => _totalEligibleMembers ?? 0;
  set totalEligibleMembers(int? val) => _totalEligibleMembers = val;

  void incrementTotalEligibleMembers(int amount) =>
      totalEligibleMembers = totalEligibleMembers + amount;

  bool hasTotalEligibleMembers() => _totalEligibleMembers != null;

  // "created_by_phone_number" field.
  String? _createdByPhoneNumber;
  String get createdByPhoneNumber => _createdByPhoneNumber ?? '';
  set createdByPhoneNumber(String? val) => _createdByPhoneNumber = val;

  bool hasCreatedByPhoneNumber() => _createdByPhoneNumber != null;

  // "event_date_time_formatted" field.
  String? _eventDateTimeFormatted;
  String get eventDateTimeFormatted => _eventDateTimeFormatted ?? '';
  set eventDateTimeFormatted(String? val) => _eventDateTimeFormatted = val;

  bool hasEventDateTimeFormatted() => _eventDateTimeFormatted != null;

  static SearchEventStruct fromMap(Map<String, dynamic> data) =>
      SearchEventStruct(
        clubId: castToType<int>(data['club_id']),
        teamId: castToType<int>(data['team_id']),
        eventId: castToType<int>(data['event_id']),
        homeAway: data['home_away'] as String?,
        meetTime: data['meet_time'] as String?,
        teamName: data['team_name'] as String?,
        createdBy: data['created_by'] as String?,
        eventCode: data['event_code'] as String?,
        eventLink: data['event_link'] as String?,
        eventType: data['event_type'] as String?,
        opposition: data['opposition'] as String?,
        eventTitle: data['event_title'] as String?,
        locationPin: data['location_pin'] as String?,
        eventDetails: data['event_details'] as String?,
        locationName: data['location_name'] as String?,
        acceptedCount: castToType<int>(data['accepted_count']),
        declinedCount: castToType<int>(data['declined_count']),
        noResponseCount: castToType<int>(data['no_response_count']),
        notifyAdminsAll: data['notify_admins_all'] as bool?,
        requestAttendance: data['request_attendance'] as bool?,
        createdByUserName: data['created_by_user_name'] as String?,
        notifyAdminsChanges: data['notify_admins_changes'] as bool?,
        totalEligibleMembers: castToType<int>(data['total_eligible_members']),
        createdByPhoneNumber: data['created_by_phone_number'] as String?,
        eventDateTimeFormatted: data['event_date_time_formatted'] as String?,
      );

  static SearchEventStruct? maybeFromMap(dynamic data) => data is Map
      ? SearchEventStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'club_id': _clubId,
        'team_id': _teamId,
        'event_id': _eventId,
        'home_away': _homeAway,
        'meet_time': _meetTime,
        'team_name': _teamName,
        'created_by': _createdBy,
        'event_code': _eventCode,
        'event_link': _eventLink,
        'event_type': _eventType,
        'opposition': _opposition,
        'event_title': _eventTitle,
        'location_pin': _locationPin,
        'event_details': _eventDetails,
        'location_name': _locationName,
        'accepted_count': _acceptedCount,
        'declined_count': _declinedCount,
        'no_response_count': _noResponseCount,
        'notify_admins_all': _notifyAdminsAll,
        'request_attendance': _requestAttendance,
        'created_by_user_name': _createdByUserName,
        'notify_admins_changes': _notifyAdminsChanges,
        'total_eligible_members': _totalEligibleMembers,
        'created_by_phone_number': _createdByPhoneNumber,
        'event_date_time_formatted': _eventDateTimeFormatted,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'club_id': serializeParam(
          _clubId,
          ParamType.int,
        ),
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
        'home_away': serializeParam(
          _homeAway,
          ParamType.String,
        ),
        'meet_time': serializeParam(
          _meetTime,
          ParamType.String,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'created_by': serializeParam(
          _createdBy,
          ParamType.String,
        ),
        'event_code': serializeParam(
          _eventCode,
          ParamType.String,
        ),
        'event_link': serializeParam(
          _eventLink,
          ParamType.String,
        ),
        'event_type': serializeParam(
          _eventType,
          ParamType.String,
        ),
        'opposition': serializeParam(
          _opposition,
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
        'event_details': serializeParam(
          _eventDetails,
          ParamType.String,
        ),
        'location_name': serializeParam(
          _locationName,
          ParamType.String,
        ),
        'accepted_count': serializeParam(
          _acceptedCount,
          ParamType.int,
        ),
        'declined_count': serializeParam(
          _declinedCount,
          ParamType.int,
        ),
        'no_response_count': serializeParam(
          _noResponseCount,
          ParamType.int,
        ),
        'notify_admins_all': serializeParam(
          _notifyAdminsAll,
          ParamType.bool,
        ),
        'request_attendance': serializeParam(
          _requestAttendance,
          ParamType.bool,
        ),
        'created_by_user_name': serializeParam(
          _createdByUserName,
          ParamType.String,
        ),
        'notify_admins_changes': serializeParam(
          _notifyAdminsChanges,
          ParamType.bool,
        ),
        'total_eligible_members': serializeParam(
          _totalEligibleMembers,
          ParamType.int,
        ),
        'created_by_phone_number': serializeParam(
          _createdByPhoneNumber,
          ParamType.String,
        ),
        'event_date_time_formatted': serializeParam(
          _eventDateTimeFormatted,
          ParamType.String,
        ),
      }.withoutNulls;

  static SearchEventStruct fromSerializableMap(Map<String, dynamic> data) =>
      SearchEventStruct(
        clubId: deserializeParam(
          data['club_id'],
          ParamType.int,
          false,
        ),
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
        teamName: deserializeParam(
          data['team_name'],
          ParamType.String,
          false,
        ),
        createdBy: deserializeParam(
          data['created_by'],
          ParamType.String,
          false,
        ),
        eventCode: deserializeParam(
          data['event_code'],
          ParamType.String,
          false,
        ),
        eventLink: deserializeParam(
          data['event_link'],
          ParamType.String,
          false,
        ),
        eventType: deserializeParam(
          data['event_type'],
          ParamType.String,
          false,
        ),
        opposition: deserializeParam(
          data['opposition'],
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
        eventDetails: deserializeParam(
          data['event_details'],
          ParamType.String,
          false,
        ),
        locationName: deserializeParam(
          data['location_name'],
          ParamType.String,
          false,
        ),
        acceptedCount: deserializeParam(
          data['accepted_count'],
          ParamType.int,
          false,
        ),
        declinedCount: deserializeParam(
          data['declined_count'],
          ParamType.int,
          false,
        ),
        noResponseCount: deserializeParam(
          data['no_response_count'],
          ParamType.int,
          false,
        ),
        notifyAdminsAll: deserializeParam(
          data['notify_admins_all'],
          ParamType.bool,
          false,
        ),
        requestAttendance: deserializeParam(
          data['request_attendance'],
          ParamType.bool,
          false,
        ),
        createdByUserName: deserializeParam(
          data['created_by_user_name'],
          ParamType.String,
          false,
        ),
        notifyAdminsChanges: deserializeParam(
          data['notify_admins_changes'],
          ParamType.bool,
          false,
        ),
        totalEligibleMembers: deserializeParam(
          data['total_eligible_members'],
          ParamType.int,
          false,
        ),
        createdByPhoneNumber: deserializeParam(
          data['created_by_phone_number'],
          ParamType.String,
          false,
        ),
        eventDateTimeFormatted: deserializeParam(
          data['event_date_time_formatted'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'SearchEventStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is SearchEventStruct &&
        clubId == other.clubId &&
        teamId == other.teamId &&
        eventId == other.eventId &&
        homeAway == other.homeAway &&
        meetTime == other.meetTime &&
        teamName == other.teamName &&
        createdBy == other.createdBy &&
        eventCode == other.eventCode &&
        eventLink == other.eventLink &&
        eventType == other.eventType &&
        opposition == other.opposition &&
        eventTitle == other.eventTitle &&
        locationPin == other.locationPin &&
        eventDetails == other.eventDetails &&
        locationName == other.locationName &&
        acceptedCount == other.acceptedCount &&
        declinedCount == other.declinedCount &&
        noResponseCount == other.noResponseCount &&
        notifyAdminsAll == other.notifyAdminsAll &&
        requestAttendance == other.requestAttendance &&
        createdByUserName == other.createdByUserName &&
        notifyAdminsChanges == other.notifyAdminsChanges &&
        totalEligibleMembers == other.totalEligibleMembers &&
        createdByPhoneNumber == other.createdByPhoneNumber &&
        eventDateTimeFormatted == other.eventDateTimeFormatted;
  }

  @override
  int get hashCode => const ListEquality().hash([
        clubId,
        teamId,
        eventId,
        homeAway,
        meetTime,
        teamName,
        createdBy,
        eventCode,
        eventLink,
        eventType,
        opposition,
        eventTitle,
        locationPin,
        eventDetails,
        locationName,
        acceptedCount,
        declinedCount,
        noResponseCount,
        notifyAdminsAll,
        requestAttendance,
        createdByUserName,
        notifyAdminsChanges,
        totalEligibleMembers,
        createdByPhoneNumber,
        eventDateTimeFormatted
      ]);
}

SearchEventStruct createSearchEventStruct({
  int? clubId,
  int? teamId,
  int? eventId,
  String? homeAway,
  String? meetTime,
  String? teamName,
  String? createdBy,
  String? eventCode,
  String? eventLink,
  String? eventType,
  String? opposition,
  String? eventTitle,
  String? locationPin,
  String? eventDetails,
  String? locationName,
  int? acceptedCount,
  int? declinedCount,
  int? noResponseCount,
  bool? notifyAdminsAll,
  bool? requestAttendance,
  String? createdByUserName,
  bool? notifyAdminsChanges,
  int? totalEligibleMembers,
  String? createdByPhoneNumber,
  String? eventDateTimeFormatted,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    SearchEventStruct(
      clubId: clubId,
      teamId: teamId,
      eventId: eventId,
      homeAway: homeAway,
      meetTime: meetTime,
      teamName: teamName,
      createdBy: createdBy,
      eventCode: eventCode,
      eventLink: eventLink,
      eventType: eventType,
      opposition: opposition,
      eventTitle: eventTitle,
      locationPin: locationPin,
      eventDetails: eventDetails,
      locationName: locationName,
      acceptedCount: acceptedCount,
      declinedCount: declinedCount,
      noResponseCount: noResponseCount,
      notifyAdminsAll: notifyAdminsAll,
      requestAttendance: requestAttendance,
      createdByUserName: createdByUserName,
      notifyAdminsChanges: notifyAdminsChanges,
      totalEligibleMembers: totalEligibleMembers,
      createdByPhoneNumber: createdByPhoneNumber,
      eventDateTimeFormatted: eventDateTimeFormatted,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

SearchEventStruct? updateSearchEventStruct(
  SearchEventStruct? searchEvent, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    searchEvent
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addSearchEventStructData(
  Map<String, dynamic> firestoreData,
  SearchEventStruct? searchEvent,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (searchEvent == null) {
    return;
  }
  if (searchEvent.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && searchEvent.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final searchEventData =
      getSearchEventFirestoreData(searchEvent, forFieldValue);
  final nestedData =
      searchEventData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = searchEvent.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getSearchEventFirestoreData(
  SearchEventStruct? searchEvent, [
  bool forFieldValue = false,
]) {
  if (searchEvent == null) {
    return {};
  }
  final firestoreData = mapToFirestore(searchEvent.toMap());

  // Add any Firestore field values
  mapToFirestore(searchEvent.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getSearchEventListFirestoreData(
  List<SearchEventStruct>? searchEvents,
) =>
    searchEvents?.map((e) => getSearchEventFirestoreData(e, true)).toList() ??
    [];
