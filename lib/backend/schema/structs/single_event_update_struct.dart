// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class SingleEventUpdateStruct extends FFFirebaseStruct {
  SingleEventUpdateStruct({
    int? clubId,
    int? teamId,
    int? eventId,
    String? homeAway,
    String? meetTime,
    int? memberId,
    String? teamName,
    String? createdBy,
    String? eventCode,
    String? eventLink,
    bool? eventPaid,
    String? eventType,
    String? opposition,
    String? eventTitle,
    String? responseId,
    String? locationPin,
    String? attendanceId,
    String? eventDetails,
    String? locationName,
    int? acceptedCount,
    int? declinedCount,
    String? attendanceIcon,
    int? eventRoleLevel,
    String? memberLastName,
    String? paymentRequired,
    String? attendanceStatus,
    String? memberFirstName,
    int? memberRoleLevel,
    int? noResponseCount,
    bool? notifyAdminsAll,
    bool? requestAttendance,
    String? createdByUserName,
    bool? notifyAdminsChanges,
    String? createdByPhoneNumber,
    String? eventDateTimeFormatted,
    int? userHighestRoleOnTeam,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _clubId = clubId,
        _teamId = teamId,
        _eventId = eventId,
        _homeAway = homeAway,
        _meetTime = meetTime,
        _memberId = memberId,
        _teamName = teamName,
        _createdBy = createdBy,
        _eventCode = eventCode,
        _eventLink = eventLink,
        _eventPaid = eventPaid,
        _eventType = eventType,
        _opposition = opposition,
        _eventTitle = eventTitle,
        _responseId = responseId,
        _locationPin = locationPin,
        _attendanceId = attendanceId,
        _eventDetails = eventDetails,
        _locationName = locationName,
        _acceptedCount = acceptedCount,
        _declinedCount = declinedCount,
        _attendanceIcon = attendanceIcon,
        _eventRoleLevel = eventRoleLevel,
        _memberLastName = memberLastName,
        _paymentRequired = paymentRequired,
        _attendanceStatus = attendanceStatus,
        _memberFirstName = memberFirstName,
        _memberRoleLevel = memberRoleLevel,
        _noResponseCount = noResponseCount,
        _notifyAdminsAll = notifyAdminsAll,
        _requestAttendance = requestAttendance,
        _createdByUserName = createdByUserName,
        _notifyAdminsChanges = notifyAdminsChanges,
        _createdByPhoneNumber = createdByPhoneNumber,
        _eventDateTimeFormatted = eventDateTimeFormatted,
        _userHighestRoleOnTeam = userHighestRoleOnTeam,
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

  // "event_paid" field.
  bool? _eventPaid;
  bool get eventPaid => _eventPaid ?? false;
  set eventPaid(bool? val) => _eventPaid = val;

  bool hasEventPaid() => _eventPaid != null;

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

  // "response_id" field.
  String? _responseId;
  String get responseId => _responseId ?? '';
  set responseId(String? val) => _responseId = val;

  bool hasResponseId() => _responseId != null;

  // "location_pin" field.
  String? _locationPin;
  String get locationPin => _locationPin ?? '';
  set locationPin(String? val) => _locationPin = val;

  bool hasLocationPin() => _locationPin != null;

  // "attendance_id" field.
  String? _attendanceId;
  String get attendanceId => _attendanceId ?? '';
  set attendanceId(String? val) => _attendanceId = val;

  bool hasAttendanceId() => _attendanceId != null;

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

  // "attendance_icon" field.
  String? _attendanceIcon;
  String get attendanceIcon => _attendanceIcon ?? '';
  set attendanceIcon(String? val) => _attendanceIcon = val;

  bool hasAttendanceIcon() => _attendanceIcon != null;

  // "event_role_level" field.
  int? _eventRoleLevel;
  int get eventRoleLevel => _eventRoleLevel ?? 0;
  set eventRoleLevel(int? val) => _eventRoleLevel = val;

  void incrementEventRoleLevel(int amount) =>
      eventRoleLevel = eventRoleLevel + amount;

  bool hasEventRoleLevel() => _eventRoleLevel != null;

  // "member_last_name" field.
  String? _memberLastName;
  String get memberLastName => _memberLastName ?? '';
  set memberLastName(String? val) => _memberLastName = val;

  bool hasMemberLastName() => _memberLastName != null;

  // "payment_required" field.
  String? _paymentRequired;
  String get paymentRequired => _paymentRequired ?? '';
  set paymentRequired(String? val) => _paymentRequired = val;

  bool hasPaymentRequired() => _paymentRequired != null;

  // "attendance_status" field.
  String? _attendanceStatus;
  String get attendanceStatus => _attendanceStatus ?? '';
  set attendanceStatus(String? val) => _attendanceStatus = val;

  bool hasAttendanceStatus() => _attendanceStatus != null;

  // "member_first_name" field.
  String? _memberFirstName;
  String get memberFirstName => _memberFirstName ?? '';
  set memberFirstName(String? val) => _memberFirstName = val;

  bool hasMemberFirstName() => _memberFirstName != null;

  // "member_role_level" field.
  int? _memberRoleLevel;
  int get memberRoleLevel => _memberRoleLevel ?? 0;
  set memberRoleLevel(int? val) => _memberRoleLevel = val;

  void incrementMemberRoleLevel(int amount) =>
      memberRoleLevel = memberRoleLevel + amount;

  bool hasMemberRoleLevel() => _memberRoleLevel != null;

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

  // "user_highest_role_on_team" field.
  int? _userHighestRoleOnTeam;
  int get userHighestRoleOnTeam => _userHighestRoleOnTeam ?? 0;
  set userHighestRoleOnTeam(int? val) => _userHighestRoleOnTeam = val;

  void incrementUserHighestRoleOnTeam(int amount) =>
      userHighestRoleOnTeam = userHighestRoleOnTeam + amount;

  bool hasUserHighestRoleOnTeam() => _userHighestRoleOnTeam != null;

  static SingleEventUpdateStruct fromMap(Map<String, dynamic> data) =>
      SingleEventUpdateStruct(
        clubId: castToType<int>(data['club_id']),
        teamId: castToType<int>(data['team_id']),
        eventId: castToType<int>(data['event_id']),
        homeAway: data['home_away'] as String?,
        meetTime: data['meet_time'] as String?,
        memberId: castToType<int>(data['member_id']),
        teamName: data['team_name'] as String?,
        createdBy: data['created_by'] as String?,
        eventCode: data['event_code'] as String?,
        eventLink: data['event_link'] as String?,
        eventPaid: data['event_paid'] as bool?,
        eventType: data['event_type'] as String?,
        opposition: data['opposition'] as String?,
        eventTitle: data['event_title'] as String?,
        responseId: data['response_id'] as String?,
        locationPin: data['location_pin'] as String?,
        attendanceId: data['attendance_id'] as String?,
        eventDetails: data['event_details'] as String?,
        locationName: data['location_name'] as String?,
        acceptedCount: castToType<int>(data['accepted_count']),
        declinedCount: castToType<int>(data['declined_count']),
        attendanceIcon: data['attendance_icon'] as String?,
        eventRoleLevel: castToType<int>(data['event_role_level']),
        memberLastName: data['member_last_name'] as String?,
        paymentRequired: data['payment_required'] as String?,
        attendanceStatus: data['attendance_status'] as String?,
        memberFirstName: data['member_first_name'] as String?,
        memberRoleLevel: castToType<int>(data['member_role_level']),
        noResponseCount: castToType<int>(data['no_response_count']),
        notifyAdminsAll: data['notify_admins_all'] as bool?,
        requestAttendance: data['request_attendance'] as bool?,
        createdByUserName: data['created_by_user_name'] as String?,
        notifyAdminsChanges: data['notify_admins_changes'] as bool?,
        createdByPhoneNumber: data['created_by_phone_number'] as String?,
        eventDateTimeFormatted: data['event_date_time_formatted'] as String?,
        userHighestRoleOnTeam:
            castToType<int>(data['user_highest_role_on_team']),
      );

  static SingleEventUpdateStruct? maybeFromMap(dynamic data) => data is Map
      ? SingleEventUpdateStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'club_id': _clubId,
        'team_id': _teamId,
        'event_id': _eventId,
        'home_away': _homeAway,
        'meet_time': _meetTime,
        'member_id': _memberId,
        'team_name': _teamName,
        'created_by': _createdBy,
        'event_code': _eventCode,
        'event_link': _eventLink,
        'event_paid': _eventPaid,
        'event_type': _eventType,
        'opposition': _opposition,
        'event_title': _eventTitle,
        'response_id': _responseId,
        'location_pin': _locationPin,
        'attendance_id': _attendanceId,
        'event_details': _eventDetails,
        'location_name': _locationName,
        'accepted_count': _acceptedCount,
        'declined_count': _declinedCount,
        'attendance_icon': _attendanceIcon,
        'event_role_level': _eventRoleLevel,
        'member_last_name': _memberLastName,
        'payment_required': _paymentRequired,
        'attendance_status': _attendanceStatus,
        'member_first_name': _memberFirstName,
        'member_role_level': _memberRoleLevel,
        'no_response_count': _noResponseCount,
        'notify_admins_all': _notifyAdminsAll,
        'request_attendance': _requestAttendance,
        'created_by_user_name': _createdByUserName,
        'notify_admins_changes': _notifyAdminsChanges,
        'created_by_phone_number': _createdByPhoneNumber,
        'event_date_time_formatted': _eventDateTimeFormatted,
        'user_highest_role_on_team': _userHighestRoleOnTeam,
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
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
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
        'event_paid': serializeParam(
          _eventPaid,
          ParamType.bool,
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
        'response_id': serializeParam(
          _responseId,
          ParamType.String,
        ),
        'location_pin': serializeParam(
          _locationPin,
          ParamType.String,
        ),
        'attendance_id': serializeParam(
          _attendanceId,
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
        'attendance_icon': serializeParam(
          _attendanceIcon,
          ParamType.String,
        ),
        'event_role_level': serializeParam(
          _eventRoleLevel,
          ParamType.int,
        ),
        'member_last_name': serializeParam(
          _memberLastName,
          ParamType.String,
        ),
        'payment_required': serializeParam(
          _paymentRequired,
          ParamType.String,
        ),
        'attendance_status': serializeParam(
          _attendanceStatus,
          ParamType.String,
        ),
        'member_first_name': serializeParam(
          _memberFirstName,
          ParamType.String,
        ),
        'member_role_level': serializeParam(
          _memberRoleLevel,
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
        'created_by_phone_number': serializeParam(
          _createdByPhoneNumber,
          ParamType.String,
        ),
        'event_date_time_formatted': serializeParam(
          _eventDateTimeFormatted,
          ParamType.String,
        ),
        'user_highest_role_on_team': serializeParam(
          _userHighestRoleOnTeam,
          ParamType.int,
        ),
      }.withoutNulls;

  static SingleEventUpdateStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      SingleEventUpdateStruct(
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
        eventPaid: deserializeParam(
          data['event_paid'],
          ParamType.bool,
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
        responseId: deserializeParam(
          data['response_id'],
          ParamType.String,
          false,
        ),
        locationPin: deserializeParam(
          data['location_pin'],
          ParamType.String,
          false,
        ),
        attendanceId: deserializeParam(
          data['attendance_id'],
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
        attendanceIcon: deserializeParam(
          data['attendance_icon'],
          ParamType.String,
          false,
        ),
        eventRoleLevel: deserializeParam(
          data['event_role_level'],
          ParamType.int,
          false,
        ),
        memberLastName: deserializeParam(
          data['member_last_name'],
          ParamType.String,
          false,
        ),
        paymentRequired: deserializeParam(
          data['payment_required'],
          ParamType.String,
          false,
        ),
        attendanceStatus: deserializeParam(
          data['attendance_status'],
          ParamType.String,
          false,
        ),
        memberFirstName: deserializeParam(
          data['member_first_name'],
          ParamType.String,
          false,
        ),
        memberRoleLevel: deserializeParam(
          data['member_role_level'],
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
        userHighestRoleOnTeam: deserializeParam(
          data['user_highest_role_on_team'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'SingleEventUpdateStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is SingleEventUpdateStruct &&
        clubId == other.clubId &&
        teamId == other.teamId &&
        eventId == other.eventId &&
        homeAway == other.homeAway &&
        meetTime == other.meetTime &&
        memberId == other.memberId &&
        teamName == other.teamName &&
        createdBy == other.createdBy &&
        eventCode == other.eventCode &&
        eventLink == other.eventLink &&
        eventPaid == other.eventPaid &&
        eventType == other.eventType &&
        opposition == other.opposition &&
        eventTitle == other.eventTitle &&
        responseId == other.responseId &&
        locationPin == other.locationPin &&
        attendanceId == other.attendanceId &&
        eventDetails == other.eventDetails &&
        locationName == other.locationName &&
        acceptedCount == other.acceptedCount &&
        declinedCount == other.declinedCount &&
        attendanceIcon == other.attendanceIcon &&
        eventRoleLevel == other.eventRoleLevel &&
        memberLastName == other.memberLastName &&
        paymentRequired == other.paymentRequired &&
        attendanceStatus == other.attendanceStatus &&
        memberFirstName == other.memberFirstName &&
        memberRoleLevel == other.memberRoleLevel &&
        noResponseCount == other.noResponseCount &&
        notifyAdminsAll == other.notifyAdminsAll &&
        requestAttendance == other.requestAttendance &&
        createdByUserName == other.createdByUserName &&
        notifyAdminsChanges == other.notifyAdminsChanges &&
        createdByPhoneNumber == other.createdByPhoneNumber &&
        eventDateTimeFormatted == other.eventDateTimeFormatted &&
        userHighestRoleOnTeam == other.userHighestRoleOnTeam;
  }

  @override
  int get hashCode => const ListEquality().hash([
        clubId,
        teamId,
        eventId,
        homeAway,
        meetTime,
        memberId,
        teamName,
        createdBy,
        eventCode,
        eventLink,
        eventPaid,
        eventType,
        opposition,
        eventTitle,
        responseId,
        locationPin,
        attendanceId,
        eventDetails,
        locationName,
        acceptedCount,
        declinedCount,
        attendanceIcon,
        eventRoleLevel,
        memberLastName,
        paymentRequired,
        attendanceStatus,
        memberFirstName,
        memberRoleLevel,
        noResponseCount,
        notifyAdminsAll,
        requestAttendance,
        createdByUserName,
        notifyAdminsChanges,
        createdByPhoneNumber,
        eventDateTimeFormatted,
        userHighestRoleOnTeam
      ]);
}

SingleEventUpdateStruct createSingleEventUpdateStruct({
  int? clubId,
  int? teamId,
  int? eventId,
  String? homeAway,
  String? meetTime,
  int? memberId,
  String? teamName,
  String? createdBy,
  String? eventCode,
  String? eventLink,
  bool? eventPaid,
  String? eventType,
  String? opposition,
  String? eventTitle,
  String? responseId,
  String? locationPin,
  String? attendanceId,
  String? eventDetails,
  String? locationName,
  int? acceptedCount,
  int? declinedCount,
  String? attendanceIcon,
  int? eventRoleLevel,
  String? memberLastName,
  String? paymentRequired,
  String? attendanceStatus,
  String? memberFirstName,
  int? memberRoleLevel,
  int? noResponseCount,
  bool? notifyAdminsAll,
  bool? requestAttendance,
  String? createdByUserName,
  bool? notifyAdminsChanges,
  String? createdByPhoneNumber,
  String? eventDateTimeFormatted,
  int? userHighestRoleOnTeam,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    SingleEventUpdateStruct(
      clubId: clubId,
      teamId: teamId,
      eventId: eventId,
      homeAway: homeAway,
      meetTime: meetTime,
      memberId: memberId,
      teamName: teamName,
      createdBy: createdBy,
      eventCode: eventCode,
      eventLink: eventLink,
      eventPaid: eventPaid,
      eventType: eventType,
      opposition: opposition,
      eventTitle: eventTitle,
      responseId: responseId,
      locationPin: locationPin,
      attendanceId: attendanceId,
      eventDetails: eventDetails,
      locationName: locationName,
      acceptedCount: acceptedCount,
      declinedCount: declinedCount,
      attendanceIcon: attendanceIcon,
      eventRoleLevel: eventRoleLevel,
      memberLastName: memberLastName,
      paymentRequired: paymentRequired,
      attendanceStatus: attendanceStatus,
      memberFirstName: memberFirstName,
      memberRoleLevel: memberRoleLevel,
      noResponseCount: noResponseCount,
      notifyAdminsAll: notifyAdminsAll,
      requestAttendance: requestAttendance,
      createdByUserName: createdByUserName,
      notifyAdminsChanges: notifyAdminsChanges,
      createdByPhoneNumber: createdByPhoneNumber,
      eventDateTimeFormatted: eventDateTimeFormatted,
      userHighestRoleOnTeam: userHighestRoleOnTeam,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

SingleEventUpdateStruct? updateSingleEventUpdateStruct(
  SingleEventUpdateStruct? singleEventUpdate, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    singleEventUpdate
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addSingleEventUpdateStructData(
  Map<String, dynamic> firestoreData,
  SingleEventUpdateStruct? singleEventUpdate,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (singleEventUpdate == null) {
    return;
  }
  if (singleEventUpdate.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && singleEventUpdate.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final singleEventUpdateData =
      getSingleEventUpdateFirestoreData(singleEventUpdate, forFieldValue);
  final nestedData =
      singleEventUpdateData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = singleEventUpdate.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getSingleEventUpdateFirestoreData(
  SingleEventUpdateStruct? singleEventUpdate, [
  bool forFieldValue = false,
]) {
  if (singleEventUpdate == null) {
    return {};
  }
  final firestoreData = mapToFirestore(singleEventUpdate.toMap());

  // Add any Firestore field values
  mapToFirestore(singleEventUpdate.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getSingleEventUpdateListFirestoreData(
  List<SingleEventUpdateStruct>? singleEventUpdates,
) =>
    singleEventUpdates
        ?.map((e) => getSingleEventUpdateFirestoreData(e, true))
        .toList() ??
    [];
