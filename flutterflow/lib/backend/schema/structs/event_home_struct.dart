// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class EventHomeStruct extends FFFirebaseStruct {
  EventHomeStruct({
    int? eventId,
    String? eventTitle,
    String? meetTime,
    String? eventDateTimeFormatted,
    String? teamName,
    int? teamId,
    int? memberId,
    String? attendanceStatus,
    String? attendanceIcon,
    int? responseId,
    bool? requestAttendance,
    String? eventType,
    String? eventLink,
    String? memberFirstName,
    String? memberLastName,
    int? memberRoleLevel,
    int? eventRoleLevel,
    int? acceptedCount,
    int? declinedCount,
    int? noResponseCount,
    int? userHighestRoleOnTeam,
    int? userHighestRoleOnAnyTeam,
    String? locationName,
    String? locationPin,
    String? opposition,
    String? eventDetails,
    String? homeAway,
    String? createdBy,
    String? createdByUserName,
    String? createdByPhoneNumber,
    String? eventCode,
    int? clubId,
    bool? notifyAdminsChanges,
    bool? notifyAdminsAll,
    bool? userOnboarded,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _eventId = eventId,
        _eventTitle = eventTitle,
        _meetTime = meetTime,
        _eventDateTimeFormatted = eventDateTimeFormatted,
        _teamName = teamName,
        _teamId = teamId,
        _memberId = memberId,
        _attendanceStatus = attendanceStatus,
        _attendanceIcon = attendanceIcon,
        _responseId = responseId,
        _requestAttendance = requestAttendance,
        _eventType = eventType,
        _eventLink = eventLink,
        _memberFirstName = memberFirstName,
        _memberLastName = memberLastName,
        _memberRoleLevel = memberRoleLevel,
        _eventRoleLevel = eventRoleLevel,
        _acceptedCount = acceptedCount,
        _declinedCount = declinedCount,
        _noResponseCount = noResponseCount,
        _userHighestRoleOnTeam = userHighestRoleOnTeam,
        _userHighestRoleOnAnyTeam = userHighestRoleOnAnyTeam,
        _locationName = locationName,
        _locationPin = locationPin,
        _opposition = opposition,
        _eventDetails = eventDetails,
        _homeAway = homeAway,
        _createdBy = createdBy,
        _createdByUserName = createdByUserName,
        _createdByPhoneNumber = createdByPhoneNumber,
        _eventCode = eventCode,
        _clubId = clubId,
        _notifyAdminsChanges = notifyAdminsChanges,
        _notifyAdminsAll = notifyAdminsAll,
        _userOnboarded = userOnboarded,
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

  // "meet_time" field.
  String? _meetTime;
  String get meetTime => _meetTime ?? '';
  set meetTime(String? val) => _meetTime = val;

  bool hasMeetTime() => _meetTime != null;

  // "event_date_time_formatted" field.
  String? _eventDateTimeFormatted;
  String get eventDateTimeFormatted => _eventDateTimeFormatted ?? '';
  set eventDateTimeFormatted(String? val) => _eventDateTimeFormatted = val;

  bool hasEventDateTimeFormatted() => _eventDateTimeFormatted != null;

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

  // "team_id" field.
  int? _teamId;
  int get teamId => _teamId ?? 0;
  set teamId(int? val) => _teamId = val;

  void incrementTeamId(int amount) => teamId = teamId + amount;

  bool hasTeamId() => _teamId != null;

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "attendance_status" field.
  String? _attendanceStatus;
  String get attendanceStatus => _attendanceStatus ?? '';
  set attendanceStatus(String? val) => _attendanceStatus = val;

  bool hasAttendanceStatus() => _attendanceStatus != null;

  // "attendance_icon" field.
  String? _attendanceIcon;
  String get attendanceIcon => _attendanceIcon ?? '';
  set attendanceIcon(String? val) => _attendanceIcon = val;

  bool hasAttendanceIcon() => _attendanceIcon != null;

  // "response_id" field.
  int? _responseId;
  int get responseId => _responseId ?? 0;
  set responseId(int? val) => _responseId = val;

  void incrementResponseId(int amount) => responseId = responseId + amount;

  bool hasResponseId() => _responseId != null;

  // "request_attendance" field.
  bool? _requestAttendance;
  bool get requestAttendance => _requestAttendance ?? false;
  set requestAttendance(bool? val) => _requestAttendance = val;

  bool hasRequestAttendance() => _requestAttendance != null;

  // "event_type" field.
  String? _eventType;
  String get eventType => _eventType ?? '';
  set eventType(String? val) => _eventType = val;

  bool hasEventType() => _eventType != null;

  // "event_link" field.
  String? _eventLink;
  String get eventLink => _eventLink ?? '';
  set eventLink(String? val) => _eventLink = val;

  bool hasEventLink() => _eventLink != null;

  // "member_first_name" field.
  String? _memberFirstName;
  String get memberFirstName => _memberFirstName ?? '';
  set memberFirstName(String? val) => _memberFirstName = val;

  bool hasMemberFirstName() => _memberFirstName != null;

  // "member_last_name" field.
  String? _memberLastName;
  String get memberLastName => _memberLastName ?? '';
  set memberLastName(String? val) => _memberLastName = val;

  bool hasMemberLastName() => _memberLastName != null;

  // "member_role_level" field.
  int? _memberRoleLevel;
  int get memberRoleLevel => _memberRoleLevel ?? 0;
  set memberRoleLevel(int? val) => _memberRoleLevel = val;

  void incrementMemberRoleLevel(int amount) =>
      memberRoleLevel = memberRoleLevel + amount;

  bool hasMemberRoleLevel() => _memberRoleLevel != null;

  // "event_role_level" field.
  int? _eventRoleLevel;
  int get eventRoleLevel => _eventRoleLevel ?? 0;
  set eventRoleLevel(int? val) => _eventRoleLevel = val;

  void incrementEventRoleLevel(int amount) =>
      eventRoleLevel = eventRoleLevel + amount;

  bool hasEventRoleLevel() => _eventRoleLevel != null;

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

  // "user_highest_role_on_team" field.
  int? _userHighestRoleOnTeam;
  int get userHighestRoleOnTeam => _userHighestRoleOnTeam ?? 0;
  set userHighestRoleOnTeam(int? val) => _userHighestRoleOnTeam = val;

  void incrementUserHighestRoleOnTeam(int amount) =>
      userHighestRoleOnTeam = userHighestRoleOnTeam + amount;

  bool hasUserHighestRoleOnTeam() => _userHighestRoleOnTeam != null;

  // "user_highest_role_on_any_team" field.
  int? _userHighestRoleOnAnyTeam;
  int get userHighestRoleOnAnyTeam => _userHighestRoleOnAnyTeam ?? 0;
  set userHighestRoleOnAnyTeam(int? val) => _userHighestRoleOnAnyTeam = val;

  void incrementUserHighestRoleOnAnyTeam(int amount) =>
      userHighestRoleOnAnyTeam = userHighestRoleOnAnyTeam + amount;

  bool hasUserHighestRoleOnAnyTeam() => _userHighestRoleOnAnyTeam != null;

  // "location_name" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  set locationName(String? val) => _locationName = val;

  bool hasLocationName() => _locationName != null;

  // "location_pin" field.
  String? _locationPin;
  String get locationPin => _locationPin ?? '';
  set locationPin(String? val) => _locationPin = val;

  bool hasLocationPin() => _locationPin != null;

  // "opposition" field.
  String? _opposition;
  String get opposition => _opposition ?? '';
  set opposition(String? val) => _opposition = val;

  bool hasOpposition() => _opposition != null;

  // "event_details" field.
  String? _eventDetails;
  String get eventDetails => _eventDetails ?? '';
  set eventDetails(String? val) => _eventDetails = val;

  bool hasEventDetails() => _eventDetails != null;

  // "home_away" field.
  String? _homeAway;
  String get homeAway => _homeAway ?? '';
  set homeAway(String? val) => _homeAway = val;

  bool hasHomeAway() => _homeAway != null;

  // "created_by" field.
  String? _createdBy;
  String get createdBy => _createdBy ?? '';
  set createdBy(String? val) => _createdBy = val;

  bool hasCreatedBy() => _createdBy != null;

  // "created_by_user_name" field.
  String? _createdByUserName;
  String get createdByUserName => _createdByUserName ?? '';
  set createdByUserName(String? val) => _createdByUserName = val;

  bool hasCreatedByUserName() => _createdByUserName != null;

  // "created_by_phone_number" field.
  String? _createdByPhoneNumber;
  String get createdByPhoneNumber => _createdByPhoneNumber ?? '';
  set createdByPhoneNumber(String? val) => _createdByPhoneNumber = val;

  bool hasCreatedByPhoneNumber() => _createdByPhoneNumber != null;

  // "event_code" field.
  String? _eventCode;
  String get eventCode => _eventCode ?? '';
  set eventCode(String? val) => _eventCode = val;

  bool hasEventCode() => _eventCode != null;

  // "club_id" field.
  int? _clubId;
  int get clubId => _clubId ?? 0;
  set clubId(int? val) => _clubId = val;

  void incrementClubId(int amount) => clubId = clubId + amount;

  bool hasClubId() => _clubId != null;

  // "notify_admins_changes" field.
  bool? _notifyAdminsChanges;
  bool get notifyAdminsChanges => _notifyAdminsChanges ?? false;
  set notifyAdminsChanges(bool? val) => _notifyAdminsChanges = val;

  bool hasNotifyAdminsChanges() => _notifyAdminsChanges != null;

  // "notify_admins_all" field.
  bool? _notifyAdminsAll;
  bool get notifyAdminsAll => _notifyAdminsAll ?? false;
  set notifyAdminsAll(bool? val) => _notifyAdminsAll = val;

  bool hasNotifyAdminsAll() => _notifyAdminsAll != null;

  // "user_onboarded" field.
  bool? _userOnboarded;
  bool get userOnboarded => _userOnboarded ?? false;
  set userOnboarded(bool? val) => _userOnboarded = val;

  bool hasUserOnboarded() => _userOnboarded != null;

  static EventHomeStruct fromMap(Map<String, dynamic> data) => EventHomeStruct(
        eventId: castToType<int>(data['event_id']),
        eventTitle: data['event_title'] as String?,
        meetTime: data['meet_time'] as String?,
        eventDateTimeFormatted: data['event_date_time_formatted'] as String?,
        teamName: data['team_name'] as String?,
        teamId: castToType<int>(data['team_id']),
        memberId: castToType<int>(data['member_id']),
        attendanceStatus: data['attendance_status'] as String?,
        attendanceIcon: data['attendance_icon'] as String?,
        responseId: castToType<int>(data['response_id']),
        requestAttendance: data['request_attendance'] as bool?,
        eventType: data['event_type'] as String?,
        eventLink: data['event_link'] as String?,
        memberFirstName: data['member_first_name'] as String?,
        memberLastName: data['member_last_name'] as String?,
        memberRoleLevel: castToType<int>(data['member_role_level']),
        eventRoleLevel: castToType<int>(data['event_role_level']),
        acceptedCount: castToType<int>(data['accepted_count']),
        declinedCount: castToType<int>(data['declined_count']),
        noResponseCount: castToType<int>(data['no_response_count']),
        userHighestRoleOnTeam:
            castToType<int>(data['user_highest_role_on_team']),
        userHighestRoleOnAnyTeam:
            castToType<int>(data['user_highest_role_on_any_team']),
        locationName: data['location_name'] as String?,
        locationPin: data['location_pin'] as String?,
        opposition: data['opposition'] as String?,
        eventDetails: data['event_details'] as String?,
        homeAway: data['home_away'] as String?,
        createdBy: data['created_by'] as String?,
        createdByUserName: data['created_by_user_name'] as String?,
        createdByPhoneNumber: data['created_by_phone_number'] as String?,
        eventCode: data['event_code'] as String?,
        clubId: castToType<int>(data['club_id']),
        notifyAdminsChanges: data['notify_admins_changes'] as bool?,
        notifyAdminsAll: data['notify_admins_all'] as bool?,
        userOnboarded: data['user_onboarded'] as bool?,
      );

  static EventHomeStruct? maybeFromMap(dynamic data) => data is Map
      ? EventHomeStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'event_id': _eventId,
        'event_title': _eventTitle,
        'meet_time': _meetTime,
        'event_date_time_formatted': _eventDateTimeFormatted,
        'team_name': _teamName,
        'team_id': _teamId,
        'member_id': _memberId,
        'attendance_status': _attendanceStatus,
        'attendance_icon': _attendanceIcon,
        'response_id': _responseId,
        'request_attendance': _requestAttendance,
        'event_type': _eventType,
        'event_link': _eventLink,
        'member_first_name': _memberFirstName,
        'member_last_name': _memberLastName,
        'member_role_level': _memberRoleLevel,
        'event_role_level': _eventRoleLevel,
        'accepted_count': _acceptedCount,
        'declined_count': _declinedCount,
        'no_response_count': _noResponseCount,
        'user_highest_role_on_team': _userHighestRoleOnTeam,
        'user_highest_role_on_any_team': _userHighestRoleOnAnyTeam,
        'location_name': _locationName,
        'location_pin': _locationPin,
        'opposition': _opposition,
        'event_details': _eventDetails,
        'home_away': _homeAway,
        'created_by': _createdBy,
        'created_by_user_name': _createdByUserName,
        'created_by_phone_number': _createdByPhoneNumber,
        'event_code': _eventCode,
        'club_id': _clubId,
        'notify_admins_changes': _notifyAdminsChanges,
        'notify_admins_all': _notifyAdminsAll,
        'user_onboarded': _userOnboarded,
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
        'meet_time': serializeParam(
          _meetTime,
          ParamType.String,
        ),
        'event_date_time_formatted': serializeParam(
          _eventDateTimeFormatted,
          ParamType.String,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'attendance_status': serializeParam(
          _attendanceStatus,
          ParamType.String,
        ),
        'attendance_icon': serializeParam(
          _attendanceIcon,
          ParamType.String,
        ),
        'response_id': serializeParam(
          _responseId,
          ParamType.int,
        ),
        'request_attendance': serializeParam(
          _requestAttendance,
          ParamType.bool,
        ),
        'event_type': serializeParam(
          _eventType,
          ParamType.String,
        ),
        'event_link': serializeParam(
          _eventLink,
          ParamType.String,
        ),
        'member_first_name': serializeParam(
          _memberFirstName,
          ParamType.String,
        ),
        'member_last_name': serializeParam(
          _memberLastName,
          ParamType.String,
        ),
        'member_role_level': serializeParam(
          _memberRoleLevel,
          ParamType.int,
        ),
        'event_role_level': serializeParam(
          _eventRoleLevel,
          ParamType.int,
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
        'user_highest_role_on_team': serializeParam(
          _userHighestRoleOnTeam,
          ParamType.int,
        ),
        'user_highest_role_on_any_team': serializeParam(
          _userHighestRoleOnAnyTeam,
          ParamType.int,
        ),
        'location_name': serializeParam(
          _locationName,
          ParamType.String,
        ),
        'location_pin': serializeParam(
          _locationPin,
          ParamType.String,
        ),
        'opposition': serializeParam(
          _opposition,
          ParamType.String,
        ),
        'event_details': serializeParam(
          _eventDetails,
          ParamType.String,
        ),
        'home_away': serializeParam(
          _homeAway,
          ParamType.String,
        ),
        'created_by': serializeParam(
          _createdBy,
          ParamType.String,
        ),
        'created_by_user_name': serializeParam(
          _createdByUserName,
          ParamType.String,
        ),
        'created_by_phone_number': serializeParam(
          _createdByPhoneNumber,
          ParamType.String,
        ),
        'event_code': serializeParam(
          _eventCode,
          ParamType.String,
        ),
        'club_id': serializeParam(
          _clubId,
          ParamType.int,
        ),
        'notify_admins_changes': serializeParam(
          _notifyAdminsChanges,
          ParamType.bool,
        ),
        'notify_admins_all': serializeParam(
          _notifyAdminsAll,
          ParamType.bool,
        ),
        'user_onboarded': serializeParam(
          _userOnboarded,
          ParamType.bool,
        ),
      }.withoutNulls;

  static EventHomeStruct fromSerializableMap(Map<String, dynamic> data) =>
      EventHomeStruct(
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
        meetTime: deserializeParam(
          data['meet_time'],
          ParamType.String,
          false,
        ),
        eventDateTimeFormatted: deserializeParam(
          data['event_date_time_formatted'],
          ParamType.String,
          false,
        ),
        teamName: deserializeParam(
          data['team_name'],
          ParamType.String,
          false,
        ),
        teamId: deserializeParam(
          data['team_id'],
          ParamType.int,
          false,
        ),
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        attendanceStatus: deserializeParam(
          data['attendance_status'],
          ParamType.String,
          false,
        ),
        attendanceIcon: deserializeParam(
          data['attendance_icon'],
          ParamType.String,
          false,
        ),
        responseId: deserializeParam(
          data['response_id'],
          ParamType.int,
          false,
        ),
        requestAttendance: deserializeParam(
          data['request_attendance'],
          ParamType.bool,
          false,
        ),
        eventType: deserializeParam(
          data['event_type'],
          ParamType.String,
          false,
        ),
        eventLink: deserializeParam(
          data['event_link'],
          ParamType.String,
          false,
        ),
        memberFirstName: deserializeParam(
          data['member_first_name'],
          ParamType.String,
          false,
        ),
        memberLastName: deserializeParam(
          data['member_last_name'],
          ParamType.String,
          false,
        ),
        memberRoleLevel: deserializeParam(
          data['member_role_level'],
          ParamType.int,
          false,
        ),
        eventRoleLevel: deserializeParam(
          data['event_role_level'],
          ParamType.int,
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
        userHighestRoleOnTeam: deserializeParam(
          data['user_highest_role_on_team'],
          ParamType.int,
          false,
        ),
        userHighestRoleOnAnyTeam: deserializeParam(
          data['user_highest_role_on_any_team'],
          ParamType.int,
          false,
        ),
        locationName: deserializeParam(
          data['location_name'],
          ParamType.String,
          false,
        ),
        locationPin: deserializeParam(
          data['location_pin'],
          ParamType.String,
          false,
        ),
        opposition: deserializeParam(
          data['opposition'],
          ParamType.String,
          false,
        ),
        eventDetails: deserializeParam(
          data['event_details'],
          ParamType.String,
          false,
        ),
        homeAway: deserializeParam(
          data['home_away'],
          ParamType.String,
          false,
        ),
        createdBy: deserializeParam(
          data['created_by'],
          ParamType.String,
          false,
        ),
        createdByUserName: deserializeParam(
          data['created_by_user_name'],
          ParamType.String,
          false,
        ),
        createdByPhoneNumber: deserializeParam(
          data['created_by_phone_number'],
          ParamType.String,
          false,
        ),
        eventCode: deserializeParam(
          data['event_code'],
          ParamType.String,
          false,
        ),
        clubId: deserializeParam(
          data['club_id'],
          ParamType.int,
          false,
        ),
        notifyAdminsChanges: deserializeParam(
          data['notify_admins_changes'],
          ParamType.bool,
          false,
        ),
        notifyAdminsAll: deserializeParam(
          data['notify_admins_all'],
          ParamType.bool,
          false,
        ),
        userOnboarded: deserializeParam(
          data['user_onboarded'],
          ParamType.bool,
          false,
        ),
      );

  @override
  String toString() => 'EventHomeStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is EventHomeStruct &&
        eventId == other.eventId &&
        eventTitle == other.eventTitle &&
        meetTime == other.meetTime &&
        eventDateTimeFormatted == other.eventDateTimeFormatted &&
        teamName == other.teamName &&
        teamId == other.teamId &&
        memberId == other.memberId &&
        attendanceStatus == other.attendanceStatus &&
        attendanceIcon == other.attendanceIcon &&
        responseId == other.responseId &&
        requestAttendance == other.requestAttendance &&
        eventType == other.eventType &&
        eventLink == other.eventLink &&
        memberFirstName == other.memberFirstName &&
        memberLastName == other.memberLastName &&
        memberRoleLevel == other.memberRoleLevel &&
        eventRoleLevel == other.eventRoleLevel &&
        acceptedCount == other.acceptedCount &&
        declinedCount == other.declinedCount &&
        noResponseCount == other.noResponseCount &&
        userHighestRoleOnTeam == other.userHighestRoleOnTeam &&
        userHighestRoleOnAnyTeam == other.userHighestRoleOnAnyTeam &&
        locationName == other.locationName &&
        locationPin == other.locationPin &&
        opposition == other.opposition &&
        eventDetails == other.eventDetails &&
        homeAway == other.homeAway &&
        createdBy == other.createdBy &&
        createdByUserName == other.createdByUserName &&
        createdByPhoneNumber == other.createdByPhoneNumber &&
        eventCode == other.eventCode &&
        clubId == other.clubId &&
        notifyAdminsChanges == other.notifyAdminsChanges &&
        notifyAdminsAll == other.notifyAdminsAll &&
        userOnboarded == other.userOnboarded;
  }

  @override
  int get hashCode => const ListEquality().hash([
        eventId,
        eventTitle,
        meetTime,
        eventDateTimeFormatted,
        teamName,
        teamId,
        memberId,
        attendanceStatus,
        attendanceIcon,
        responseId,
        requestAttendance,
        eventType,
        eventLink,
        memberFirstName,
        memberLastName,
        memberRoleLevel,
        eventRoleLevel,
        acceptedCount,
        declinedCount,
        noResponseCount,
        userHighestRoleOnTeam,
        userHighestRoleOnAnyTeam,
        locationName,
        locationPin,
        opposition,
        eventDetails,
        homeAway,
        createdBy,
        createdByUserName,
        createdByPhoneNumber,
        eventCode,
        clubId,
        notifyAdminsChanges,
        notifyAdminsAll,
        userOnboarded
      ]);
}

EventHomeStruct createEventHomeStruct({
  int? eventId,
  String? eventTitle,
  String? meetTime,
  String? eventDateTimeFormatted,
  String? teamName,
  int? teamId,
  int? memberId,
  String? attendanceStatus,
  String? attendanceIcon,
  int? responseId,
  bool? requestAttendance,
  String? eventType,
  String? eventLink,
  String? memberFirstName,
  String? memberLastName,
  int? memberRoleLevel,
  int? eventRoleLevel,
  int? acceptedCount,
  int? declinedCount,
  int? noResponseCount,
  int? userHighestRoleOnTeam,
  int? userHighestRoleOnAnyTeam,
  String? locationName,
  String? locationPin,
  String? opposition,
  String? eventDetails,
  String? homeAway,
  String? createdBy,
  String? createdByUserName,
  String? createdByPhoneNumber,
  String? eventCode,
  int? clubId,
  bool? notifyAdminsChanges,
  bool? notifyAdminsAll,
  bool? userOnboarded,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventHomeStruct(
      eventId: eventId,
      eventTitle: eventTitle,
      meetTime: meetTime,
      eventDateTimeFormatted: eventDateTimeFormatted,
      teamName: teamName,
      teamId: teamId,
      memberId: memberId,
      attendanceStatus: attendanceStatus,
      attendanceIcon: attendanceIcon,
      responseId: responseId,
      requestAttendance: requestAttendance,
      eventType: eventType,
      eventLink: eventLink,
      memberFirstName: memberFirstName,
      memberLastName: memberLastName,
      memberRoleLevel: memberRoleLevel,
      eventRoleLevel: eventRoleLevel,
      acceptedCount: acceptedCount,
      declinedCount: declinedCount,
      noResponseCount: noResponseCount,
      userHighestRoleOnTeam: userHighestRoleOnTeam,
      userHighestRoleOnAnyTeam: userHighestRoleOnAnyTeam,
      locationName: locationName,
      locationPin: locationPin,
      opposition: opposition,
      eventDetails: eventDetails,
      homeAway: homeAway,
      createdBy: createdBy,
      createdByUserName: createdByUserName,
      createdByPhoneNumber: createdByPhoneNumber,
      eventCode: eventCode,
      clubId: clubId,
      notifyAdminsChanges: notifyAdminsChanges,
      notifyAdminsAll: notifyAdminsAll,
      userOnboarded: userOnboarded,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventHomeStruct? updateEventHomeStruct(
  EventHomeStruct? eventHome, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventHome
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventHomeStructData(
  Map<String, dynamic> firestoreData,
  EventHomeStruct? eventHome,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventHome == null) {
    return;
  }
  if (eventHome.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventHome.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventHomeData = getEventHomeFirestoreData(eventHome, forFieldValue);
  final nestedData = eventHomeData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = eventHome.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventHomeFirestoreData(
  EventHomeStruct? eventHome, [
  bool forFieldValue = false,
]) {
  if (eventHome == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventHome.toMap());

  // Add any Firestore field values
  mapToFirestore(eventHome.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventHomeListFirestoreData(
  List<EventHomeStruct>? eventHomes,
) =>
    eventHomes?.map((e) => getEventHomeFirestoreData(e, true)).toList() ?? [];
