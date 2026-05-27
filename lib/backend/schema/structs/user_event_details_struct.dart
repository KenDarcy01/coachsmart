// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UserEventDetailsStruct extends FFFirebaseStruct {
  UserEventDetailsStruct({
    int? eventId,
    String? homeAway,
    String? meetTime,
    int? teamId,
    String? teamName,
    String? eventCode,
    String? eventLink,
    String? eventType,
    String? opposition,
    String? eventTitle,
    int? totalCount,
    String? locationPin,
    List<TeamMembersStruct>? teamMembers,
    String? eventDetails,
    String? locationName,
    bool? notifyAdminsAll,
    bool? requestAttendance,
    int? acceptedPlayerCount,
    int? declinedPlayerCount,
    bool? notifyAdminsChanges,
    int? userHighestRoleLevel,
    int? noResponsePlayerCount,
    String? eventDateTimeFormatted,
    List<AcceptedAttendanceSummaryStruct>? acceptedAttendanceSummary,
    List<DeclinedAttendanceSummaryStruct>? declinedAttendanceSummary,
    List<NoResponseAttendanceSummaryStruct>? noResponseAttendanceSummary,
    int? audienceId,
    int? eventRoleLevel,
    String? createdBy,
    String? createdByPhoneNumber,
    bool? teamHasSquads,
    int? eventPaid,
    bool? paymentRequired,
    int? paymentAmount,
    String? eventImage,
    int? totalAmountPaid,
    int? totalPayments,
    int? totalNetAmount,
    int? newGrossAmount,
    int? newNetAmount,
    int? newNumPayments,
    bool? carPoolingEnabled,
    int? codeId,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _eventId = eventId,
        _homeAway = homeAway,
        _meetTime = meetTime,
        _teamId = teamId,
        _teamName = teamName,
        _eventCode = eventCode,
        _eventLink = eventLink,
        _eventType = eventType,
        _opposition = opposition,
        _eventTitle = eventTitle,
        _totalCount = totalCount,
        _locationPin = locationPin,
        _teamMembers = teamMembers,
        _eventDetails = eventDetails,
        _locationName = locationName,
        _notifyAdminsAll = notifyAdminsAll,
        _requestAttendance = requestAttendance,
        _acceptedPlayerCount = acceptedPlayerCount,
        _declinedPlayerCount = declinedPlayerCount,
        _notifyAdminsChanges = notifyAdminsChanges,
        _userHighestRoleLevel = userHighestRoleLevel,
        _noResponsePlayerCount = noResponsePlayerCount,
        _eventDateTimeFormatted = eventDateTimeFormatted,
        _acceptedAttendanceSummary = acceptedAttendanceSummary,
        _declinedAttendanceSummary = declinedAttendanceSummary,
        _noResponseAttendanceSummary = noResponseAttendanceSummary,
        _audienceId = audienceId,
        _eventRoleLevel = eventRoleLevel,
        _createdBy = createdBy,
        _createdByPhoneNumber = createdByPhoneNumber,
        _teamHasSquads = teamHasSquads,
        _eventPaid = eventPaid,
        _paymentRequired = paymentRequired,
        _paymentAmount = paymentAmount,
        _eventImage = eventImage,
        _totalAmountPaid = totalAmountPaid,
        _totalPayments = totalPayments,
        _totalNetAmount = totalNetAmount,
        _newGrossAmount = newGrossAmount,
        _newNetAmount = newNetAmount,
        _newNumPayments = newNumPayments,
        _carPoolingEnabled = carPoolingEnabled,
        _codeId = codeId,
        super(firestoreUtilData);

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

  // "team_id" field.
  int? _teamId;
  int get teamId => _teamId ?? 0;
  set teamId(int? val) => _teamId = val;

  void incrementTeamId(int amount) => teamId = teamId + amount;

  bool hasTeamId() => _teamId != null;

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

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

  // "total_count" field.
  int? _totalCount;
  int get totalCount => _totalCount ?? 0;
  set totalCount(int? val) => _totalCount = val;

  void incrementTotalCount(int amount) => totalCount = totalCount + amount;

  bool hasTotalCount() => _totalCount != null;

  // "location_pin" field.
  String? _locationPin;
  String get locationPin => _locationPin ?? '';
  set locationPin(String? val) => _locationPin = val;

  bool hasLocationPin() => _locationPin != null;

  // "team_members" field.
  List<TeamMembersStruct>? _teamMembers;
  List<TeamMembersStruct> get teamMembers => _teamMembers ?? const [];
  set teamMembers(List<TeamMembersStruct>? val) => _teamMembers = val;

  void updateTeamMembers(Function(List<TeamMembersStruct>) updateFn) {
    updateFn(_teamMembers ??= []);
  }

  bool hasTeamMembers() => _teamMembers != null;

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

  // "accepted_player_count" field.
  int? _acceptedPlayerCount;
  int get acceptedPlayerCount => _acceptedPlayerCount ?? 0;
  set acceptedPlayerCount(int? val) => _acceptedPlayerCount = val;

  void incrementAcceptedPlayerCount(int amount) =>
      acceptedPlayerCount = acceptedPlayerCount + amount;

  bool hasAcceptedPlayerCount() => _acceptedPlayerCount != null;

  // "declined_player_count" field.
  int? _declinedPlayerCount;
  int get declinedPlayerCount => _declinedPlayerCount ?? 0;
  set declinedPlayerCount(int? val) => _declinedPlayerCount = val;

  void incrementDeclinedPlayerCount(int amount) =>
      declinedPlayerCount = declinedPlayerCount + amount;

  bool hasDeclinedPlayerCount() => _declinedPlayerCount != null;

  // "notify_admins_changes" field.
  bool? _notifyAdminsChanges;
  bool get notifyAdminsChanges => _notifyAdminsChanges ?? false;
  set notifyAdminsChanges(bool? val) => _notifyAdminsChanges = val;

  bool hasNotifyAdminsChanges() => _notifyAdminsChanges != null;

  // "user_highest_role_level" field.
  int? _userHighestRoleLevel;
  int get userHighestRoleLevel => _userHighestRoleLevel ?? 0;
  set userHighestRoleLevel(int? val) => _userHighestRoleLevel = val;

  void incrementUserHighestRoleLevel(int amount) =>
      userHighestRoleLevel = userHighestRoleLevel + amount;

  bool hasUserHighestRoleLevel() => _userHighestRoleLevel != null;

  // "no_response_player_count" field.
  int? _noResponsePlayerCount;
  int get noResponsePlayerCount => _noResponsePlayerCount ?? 0;
  set noResponsePlayerCount(int? val) => _noResponsePlayerCount = val;

  void incrementNoResponsePlayerCount(int amount) =>
      noResponsePlayerCount = noResponsePlayerCount + amount;

  bool hasNoResponsePlayerCount() => _noResponsePlayerCount != null;

  // "event_date_time_formatted" field.
  String? _eventDateTimeFormatted;
  String get eventDateTimeFormatted => _eventDateTimeFormatted ?? '';
  set eventDateTimeFormatted(String? val) => _eventDateTimeFormatted = val;

  bool hasEventDateTimeFormatted() => _eventDateTimeFormatted != null;

  // "accepted_attendance_summary" field.
  List<AcceptedAttendanceSummaryStruct>? _acceptedAttendanceSummary;
  List<AcceptedAttendanceSummaryStruct> get acceptedAttendanceSummary =>
      _acceptedAttendanceSummary ?? const [];
  set acceptedAttendanceSummary(List<AcceptedAttendanceSummaryStruct>? val) =>
      _acceptedAttendanceSummary = val;

  void updateAcceptedAttendanceSummary(
      Function(List<AcceptedAttendanceSummaryStruct>) updateFn) {
    updateFn(_acceptedAttendanceSummary ??= []);
  }

  bool hasAcceptedAttendanceSummary() => _acceptedAttendanceSummary != null;

  // "declined_attendance_summary" field.
  List<DeclinedAttendanceSummaryStruct>? _declinedAttendanceSummary;
  List<DeclinedAttendanceSummaryStruct> get declinedAttendanceSummary =>
      _declinedAttendanceSummary ?? const [];
  set declinedAttendanceSummary(List<DeclinedAttendanceSummaryStruct>? val) =>
      _declinedAttendanceSummary = val;

  void updateDeclinedAttendanceSummary(
      Function(List<DeclinedAttendanceSummaryStruct>) updateFn) {
    updateFn(_declinedAttendanceSummary ??= []);
  }

  bool hasDeclinedAttendanceSummary() => _declinedAttendanceSummary != null;

  // "no_response_attendance_summary" field.
  List<NoResponseAttendanceSummaryStruct>? _noResponseAttendanceSummary;
  List<NoResponseAttendanceSummaryStruct> get noResponseAttendanceSummary =>
      _noResponseAttendanceSummary ?? const [];
  set noResponseAttendanceSummary(
          List<NoResponseAttendanceSummaryStruct>? val) =>
      _noResponseAttendanceSummary = val;

  void updateNoResponseAttendanceSummary(
      Function(List<NoResponseAttendanceSummaryStruct>) updateFn) {
    updateFn(_noResponseAttendanceSummary ??= []);
  }

  bool hasNoResponseAttendanceSummary() => _noResponseAttendanceSummary != null;

  // "audience_id" field.
  int? _audienceId;
  int get audienceId => _audienceId ?? 0;
  set audienceId(int? val) => _audienceId = val;

  void incrementAudienceId(int amount) => audienceId = audienceId + amount;

  bool hasAudienceId() => _audienceId != null;

  // "event_role_level" field.
  int? _eventRoleLevel;
  int get eventRoleLevel => _eventRoleLevel ?? 0;
  set eventRoleLevel(int? val) => _eventRoleLevel = val;

  void incrementEventRoleLevel(int amount) =>
      eventRoleLevel = eventRoleLevel + amount;

  bool hasEventRoleLevel() => _eventRoleLevel != null;

  // "created_by" field.
  String? _createdBy;
  String get createdBy => _createdBy ?? '';
  set createdBy(String? val) => _createdBy = val;

  bool hasCreatedBy() => _createdBy != null;

  // "created_by_phone_number" field.
  String? _createdByPhoneNumber;
  String get createdByPhoneNumber => _createdByPhoneNumber ?? '';
  set createdByPhoneNumber(String? val) => _createdByPhoneNumber = val;

  bool hasCreatedByPhoneNumber() => _createdByPhoneNumber != null;

  // "team_has_squads" field.
  bool? _teamHasSquads;
  bool get teamHasSquads => _teamHasSquads ?? false;
  set teamHasSquads(bool? val) => _teamHasSquads = val;

  bool hasTeamHasSquads() => _teamHasSquads != null;

  // "event_paid" field.
  int? _eventPaid;
  int get eventPaid => _eventPaid ?? 0;
  set eventPaid(int? val) => _eventPaid = val;

  void incrementEventPaid(int amount) => eventPaid = eventPaid + amount;

  bool hasEventPaid() => _eventPaid != null;

  // "payment_required" field.
  bool? _paymentRequired;
  bool get paymentRequired => _paymentRequired ?? false;
  set paymentRequired(bool? val) => _paymentRequired = val;

  bool hasPaymentRequired() => _paymentRequired != null;

  // "payment_amount" field.
  int? _paymentAmount;
  int get paymentAmount => _paymentAmount ?? 0;
  set paymentAmount(int? val) => _paymentAmount = val;

  void incrementPaymentAmount(int amount) =>
      paymentAmount = paymentAmount + amount;

  bool hasPaymentAmount() => _paymentAmount != null;

  // "event_image" field.
  String? _eventImage;
  String get eventImage => _eventImage ?? '';
  set eventImage(String? val) => _eventImage = val;

  bool hasEventImage() => _eventImage != null;

  // "total_amount_paid" field.
  int? _totalAmountPaid;
  int get totalAmountPaid => _totalAmountPaid ?? 0;
  set totalAmountPaid(int? val) => _totalAmountPaid = val;

  void incrementTotalAmountPaid(int amount) =>
      totalAmountPaid = totalAmountPaid + amount;

  bool hasTotalAmountPaid() => _totalAmountPaid != null;

  // "total_payments" field.
  int? _totalPayments;
  int get totalPayments => _totalPayments ?? 0;
  set totalPayments(int? val) => _totalPayments = val;

  void incrementTotalPayments(int amount) =>
      totalPayments = totalPayments + amount;

  bool hasTotalPayments() => _totalPayments != null;

  // "total_net_amount" field.
  int? _totalNetAmount;
  int get totalNetAmount => _totalNetAmount ?? 0;
  set totalNetAmount(int? val) => _totalNetAmount = val;

  void incrementTotalNetAmount(int amount) =>
      totalNetAmount = totalNetAmount + amount;

  bool hasTotalNetAmount() => _totalNetAmount != null;

  // "new_gross_amount" field.
  int? _newGrossAmount;
  int get newGrossAmount => _newGrossAmount ?? 0;
  set newGrossAmount(int? val) => _newGrossAmount = val;

  void incrementNewGrossAmount(int amount) =>
      newGrossAmount = newGrossAmount + amount;

  bool hasNewGrossAmount() => _newGrossAmount != null;

  // "new_net_amount" field.
  int? _newNetAmount;
  int get newNetAmount => _newNetAmount ?? 0;
  set newNetAmount(int? val) => _newNetAmount = val;

  void incrementNewNetAmount(int amount) =>
      newNetAmount = newNetAmount + amount;

  bool hasNewNetAmount() => _newNetAmount != null;

  // "new_num_payments" field.
  int? _newNumPayments;
  int get newNumPayments => _newNumPayments ?? 0;
  set newNumPayments(int? val) => _newNumPayments = val;

  void incrementNewNumPayments(int amount) =>
      newNumPayments = newNumPayments + amount;

  bool hasNewNumPayments() => _newNumPayments != null;

  // "car_pooling_enabled" field.
  bool? _carPoolingEnabled;
  bool get carPoolingEnabled => _carPoolingEnabled ?? false;
  set carPoolingEnabled(bool? val) => _carPoolingEnabled = val;

  bool hasCarPoolingEnabled() => _carPoolingEnabled != null;

  // "code_id" field.
  int? _codeId;
  int get codeId => _codeId ?? 0;
  set codeId(int? val) => _codeId = val;

  void incrementCodeId(int amount) => codeId = codeId + amount;

  bool hasCodeId() => _codeId != null;

  static UserEventDetailsStruct fromMap(Map<String, dynamic> data) =>
      UserEventDetailsStruct(
        eventId: castToType<int>(data['event_id']),
        homeAway: data['home_away'] as String?,
        meetTime: data['meet_time'] as String?,
        teamId: castToType<int>(data['team_id']),
        teamName: data['team_name'] as String?,
        eventCode: data['event_code'] as String?,
        eventLink: data['event_link'] as String?,
        eventType: data['event_type'] as String?,
        opposition: data['opposition'] as String?,
        eventTitle: data['event_title'] as String?,
        totalCount: castToType<int>(data['total_count']),
        locationPin: data['location_pin'] as String?,
        teamMembers: getStructList(
          data['team_members'],
          TeamMembersStruct.fromMap,
        ),
        eventDetails: data['event_details'] as String?,
        locationName: data['location_name'] as String?,
        notifyAdminsAll: data['notify_admins_all'] as bool?,
        requestAttendance: data['request_attendance'] as bool?,
        acceptedPlayerCount: castToType<int>(data['accepted_player_count']),
        declinedPlayerCount: castToType<int>(data['declined_player_count']),
        notifyAdminsChanges: data['notify_admins_changes'] as bool?,
        userHighestRoleLevel: castToType<int>(data['user_highest_role_level']),
        noResponsePlayerCount:
            castToType<int>(data['no_response_player_count']),
        eventDateTimeFormatted: data['event_date_time_formatted'] as String?,
        acceptedAttendanceSummary: getStructList(
          data['accepted_attendance_summary'],
          AcceptedAttendanceSummaryStruct.fromMap,
        ),
        declinedAttendanceSummary: getStructList(
          data['declined_attendance_summary'],
          DeclinedAttendanceSummaryStruct.fromMap,
        ),
        noResponseAttendanceSummary: getStructList(
          data['no_response_attendance_summary'],
          NoResponseAttendanceSummaryStruct.fromMap,
        ),
        audienceId: castToType<int>(data['audience_id']),
        eventRoleLevel: castToType<int>(data['event_role_level']),
        createdBy: data['created_by'] as String?,
        createdByPhoneNumber: data['created_by_phone_number'] as String?,
        teamHasSquads: data['team_has_squads'] as bool?,
        eventPaid: castToType<int>(data['event_paid']),
        paymentRequired: data['payment_required'] as bool?,
        paymentAmount: castToType<int>(data['payment_amount']),
        eventImage: data['event_image'] as String?,
        totalAmountPaid: castToType<int>(data['total_amount_paid']),
        totalPayments: castToType<int>(data['total_payments']),
        totalNetAmount: castToType<int>(data['total_net_amount']),
        newGrossAmount: castToType<int>(data['new_gross_amount']),
        newNetAmount: castToType<int>(data['new_net_amount']),
        newNumPayments: castToType<int>(data['new_num_payments']),
        carPoolingEnabled: data['car_pooling_enabled'] as bool?,
        codeId: castToType<int>(data['code_id']),
      );

  static UserEventDetailsStruct? maybeFromMap(dynamic data) => data is Map
      ? UserEventDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'event_id': _eventId,
        'home_away': _homeAway,
        'meet_time': _meetTime,
        'team_id': _teamId,
        'team_name': _teamName,
        'event_code': _eventCode,
        'event_link': _eventLink,
        'event_type': _eventType,
        'opposition': _opposition,
        'event_title': _eventTitle,
        'total_count': _totalCount,
        'location_pin': _locationPin,
        'team_members': _teamMembers?.map((e) => e.toMap()).toList(),
        'event_details': _eventDetails,
        'location_name': _locationName,
        'notify_admins_all': _notifyAdminsAll,
        'request_attendance': _requestAttendance,
        'accepted_player_count': _acceptedPlayerCount,
        'declined_player_count': _declinedPlayerCount,
        'notify_admins_changes': _notifyAdminsChanges,
        'user_highest_role_level': _userHighestRoleLevel,
        'no_response_player_count': _noResponsePlayerCount,
        'event_date_time_formatted': _eventDateTimeFormatted,
        'accepted_attendance_summary':
            _acceptedAttendanceSummary?.map((e) => e.toMap()).toList(),
        'declined_attendance_summary':
            _declinedAttendanceSummary?.map((e) => e.toMap()).toList(),
        'no_response_attendance_summary':
            _noResponseAttendanceSummary?.map((e) => e.toMap()).toList(),
        'audience_id': _audienceId,
        'event_role_level': _eventRoleLevel,
        'created_by': _createdBy,
        'created_by_phone_number': _createdByPhoneNumber,
        'team_has_squads': _teamHasSquads,
        'event_paid': _eventPaid,
        'payment_required': _paymentRequired,
        'payment_amount': _paymentAmount,
        'event_image': _eventImage,
        'total_amount_paid': _totalAmountPaid,
        'total_payments': _totalPayments,
        'total_net_amount': _totalNetAmount,
        'new_gross_amount': _newGrossAmount,
        'new_net_amount': _newNetAmount,
        'new_num_payments': _newNumPayments,
        'car_pooling_enabled': _carPoolingEnabled,
        'code_id': _codeId,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
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
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'team_name': serializeParam(
          _teamName,
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
        'total_count': serializeParam(
          _totalCount,
          ParamType.int,
        ),
        'location_pin': serializeParam(
          _locationPin,
          ParamType.String,
        ),
        'team_members': serializeParam(
          _teamMembers,
          ParamType.DataStruct,
          isList: true,
        ),
        'event_details': serializeParam(
          _eventDetails,
          ParamType.String,
        ),
        'location_name': serializeParam(
          _locationName,
          ParamType.String,
        ),
        'notify_admins_all': serializeParam(
          _notifyAdminsAll,
          ParamType.bool,
        ),
        'request_attendance': serializeParam(
          _requestAttendance,
          ParamType.bool,
        ),
        'accepted_player_count': serializeParam(
          _acceptedPlayerCount,
          ParamType.int,
        ),
        'declined_player_count': serializeParam(
          _declinedPlayerCount,
          ParamType.int,
        ),
        'notify_admins_changes': serializeParam(
          _notifyAdminsChanges,
          ParamType.bool,
        ),
        'user_highest_role_level': serializeParam(
          _userHighestRoleLevel,
          ParamType.int,
        ),
        'no_response_player_count': serializeParam(
          _noResponsePlayerCount,
          ParamType.int,
        ),
        'event_date_time_formatted': serializeParam(
          _eventDateTimeFormatted,
          ParamType.String,
        ),
        'accepted_attendance_summary': serializeParam(
          _acceptedAttendanceSummary,
          ParamType.DataStruct,
          isList: true,
        ),
        'declined_attendance_summary': serializeParam(
          _declinedAttendanceSummary,
          ParamType.DataStruct,
          isList: true,
        ),
        'no_response_attendance_summary': serializeParam(
          _noResponseAttendanceSummary,
          ParamType.DataStruct,
          isList: true,
        ),
        'audience_id': serializeParam(
          _audienceId,
          ParamType.int,
        ),
        'event_role_level': serializeParam(
          _eventRoleLevel,
          ParamType.int,
        ),
        'created_by': serializeParam(
          _createdBy,
          ParamType.String,
        ),
        'created_by_phone_number': serializeParam(
          _createdByPhoneNumber,
          ParamType.String,
        ),
        'team_has_squads': serializeParam(
          _teamHasSquads,
          ParamType.bool,
        ),
        'event_paid': serializeParam(
          _eventPaid,
          ParamType.int,
        ),
        'payment_required': serializeParam(
          _paymentRequired,
          ParamType.bool,
        ),
        'payment_amount': serializeParam(
          _paymentAmount,
          ParamType.int,
        ),
        'event_image': serializeParam(
          _eventImage,
          ParamType.String,
        ),
        'total_amount_paid': serializeParam(
          _totalAmountPaid,
          ParamType.int,
        ),
        'total_payments': serializeParam(
          _totalPayments,
          ParamType.int,
        ),
        'total_net_amount': serializeParam(
          _totalNetAmount,
          ParamType.int,
        ),
        'new_gross_amount': serializeParam(
          _newGrossAmount,
          ParamType.int,
        ),
        'new_net_amount': serializeParam(
          _newNetAmount,
          ParamType.int,
        ),
        'new_num_payments': serializeParam(
          _newNumPayments,
          ParamType.int,
        ),
        'car_pooling_enabled': serializeParam(
          _carPoolingEnabled,
          ParamType.bool,
        ),
        'code_id': serializeParam(
          _codeId,
          ParamType.int,
        ),
      }.withoutNulls;

  static UserEventDetailsStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      UserEventDetailsStruct(
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
        teamId: deserializeParam(
          data['team_id'],
          ParamType.int,
          false,
        ),
        teamName: deserializeParam(
          data['team_name'],
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
        totalCount: deserializeParam(
          data['total_count'],
          ParamType.int,
          false,
        ),
        locationPin: deserializeParam(
          data['location_pin'],
          ParamType.String,
          false,
        ),
        teamMembers: deserializeStructParam<TeamMembersStruct>(
          data['team_members'],
          ParamType.DataStruct,
          true,
          structBuilder: TeamMembersStruct.fromSerializableMap,
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
        acceptedPlayerCount: deserializeParam(
          data['accepted_player_count'],
          ParamType.int,
          false,
        ),
        declinedPlayerCount: deserializeParam(
          data['declined_player_count'],
          ParamType.int,
          false,
        ),
        notifyAdminsChanges: deserializeParam(
          data['notify_admins_changes'],
          ParamType.bool,
          false,
        ),
        userHighestRoleLevel: deserializeParam(
          data['user_highest_role_level'],
          ParamType.int,
          false,
        ),
        noResponsePlayerCount: deserializeParam(
          data['no_response_player_count'],
          ParamType.int,
          false,
        ),
        eventDateTimeFormatted: deserializeParam(
          data['event_date_time_formatted'],
          ParamType.String,
          false,
        ),
        acceptedAttendanceSummary:
            deserializeStructParam<AcceptedAttendanceSummaryStruct>(
          data['accepted_attendance_summary'],
          ParamType.DataStruct,
          true,
          structBuilder: AcceptedAttendanceSummaryStruct.fromSerializableMap,
        ),
        declinedAttendanceSummary:
            deserializeStructParam<DeclinedAttendanceSummaryStruct>(
          data['declined_attendance_summary'],
          ParamType.DataStruct,
          true,
          structBuilder: DeclinedAttendanceSummaryStruct.fromSerializableMap,
        ),
        noResponseAttendanceSummary:
            deserializeStructParam<NoResponseAttendanceSummaryStruct>(
          data['no_response_attendance_summary'],
          ParamType.DataStruct,
          true,
          structBuilder: NoResponseAttendanceSummaryStruct.fromSerializableMap,
        ),
        audienceId: deserializeParam(
          data['audience_id'],
          ParamType.int,
          false,
        ),
        eventRoleLevel: deserializeParam(
          data['event_role_level'],
          ParamType.int,
          false,
        ),
        createdBy: deserializeParam(
          data['created_by'],
          ParamType.String,
          false,
        ),
        createdByPhoneNumber: deserializeParam(
          data['created_by_phone_number'],
          ParamType.String,
          false,
        ),
        teamHasSquads: deserializeParam(
          data['team_has_squads'],
          ParamType.bool,
          false,
        ),
        eventPaid: deserializeParam(
          data['event_paid'],
          ParamType.int,
          false,
        ),
        paymentRequired: deserializeParam(
          data['payment_required'],
          ParamType.bool,
          false,
        ),
        paymentAmount: deserializeParam(
          data['payment_amount'],
          ParamType.int,
          false,
        ),
        eventImage: deserializeParam(
          data['event_image'],
          ParamType.String,
          false,
        ),
        totalAmountPaid: deserializeParam(
          data['total_amount_paid'],
          ParamType.int,
          false,
        ),
        totalPayments: deserializeParam(
          data['total_payments'],
          ParamType.int,
          false,
        ),
        totalNetAmount: deserializeParam(
          data['total_net_amount'],
          ParamType.int,
          false,
        ),
        newGrossAmount: deserializeParam(
          data['new_gross_amount'],
          ParamType.int,
          false,
        ),
        newNetAmount: deserializeParam(
          data['new_net_amount'],
          ParamType.int,
          false,
        ),
        newNumPayments: deserializeParam(
          data['new_num_payments'],
          ParamType.int,
          false,
        ),
        carPoolingEnabled: deserializeParam(
          data['car_pooling_enabled'],
          ParamType.bool,
          false,
        ),
        codeId: deserializeParam(
          data['code_id'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'UserEventDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is UserEventDetailsStruct &&
        eventId == other.eventId &&
        homeAway == other.homeAway &&
        meetTime == other.meetTime &&
        teamId == other.teamId &&
        teamName == other.teamName &&
        eventCode == other.eventCode &&
        eventLink == other.eventLink &&
        eventType == other.eventType &&
        opposition == other.opposition &&
        eventTitle == other.eventTitle &&
        totalCount == other.totalCount &&
        locationPin == other.locationPin &&
        listEquality.equals(teamMembers, other.teamMembers) &&
        eventDetails == other.eventDetails &&
        locationName == other.locationName &&
        notifyAdminsAll == other.notifyAdminsAll &&
        requestAttendance == other.requestAttendance &&
        acceptedPlayerCount == other.acceptedPlayerCount &&
        declinedPlayerCount == other.declinedPlayerCount &&
        notifyAdminsChanges == other.notifyAdminsChanges &&
        userHighestRoleLevel == other.userHighestRoleLevel &&
        noResponsePlayerCount == other.noResponsePlayerCount &&
        eventDateTimeFormatted == other.eventDateTimeFormatted &&
        listEquality.equals(
            acceptedAttendanceSummary, other.acceptedAttendanceSummary) &&
        listEquality.equals(
            declinedAttendanceSummary, other.declinedAttendanceSummary) &&
        listEquality.equals(
            noResponseAttendanceSummary, other.noResponseAttendanceSummary) &&
        audienceId == other.audienceId &&
        eventRoleLevel == other.eventRoleLevel &&
        createdBy == other.createdBy &&
        createdByPhoneNumber == other.createdByPhoneNumber &&
        teamHasSquads == other.teamHasSquads &&
        eventPaid == other.eventPaid &&
        paymentRequired == other.paymentRequired &&
        paymentAmount == other.paymentAmount &&
        eventImage == other.eventImage &&
        totalAmountPaid == other.totalAmountPaid &&
        totalPayments == other.totalPayments &&
        totalNetAmount == other.totalNetAmount &&
        newGrossAmount == other.newGrossAmount &&
        newNetAmount == other.newNetAmount &&
        newNumPayments == other.newNumPayments &&
        carPoolingEnabled == other.carPoolingEnabled &&
        codeId == other.codeId;
  }

  @override
  int get hashCode => const ListEquality().hash([
        eventId,
        homeAway,
        meetTime,
        teamId,
        teamName,
        eventCode,
        eventLink,
        eventType,
        opposition,
        eventTitle,
        totalCount,
        locationPin,
        teamMembers,
        eventDetails,
        locationName,
        notifyAdminsAll,
        requestAttendance,
        acceptedPlayerCount,
        declinedPlayerCount,
        notifyAdminsChanges,
        userHighestRoleLevel,
        noResponsePlayerCount,
        eventDateTimeFormatted,
        acceptedAttendanceSummary,
        declinedAttendanceSummary,
        noResponseAttendanceSummary,
        audienceId,
        eventRoleLevel,
        createdBy,
        createdByPhoneNumber,
        teamHasSquads,
        eventPaid,
        paymentRequired,
        paymentAmount,
        eventImage,
        totalAmountPaid,
        totalPayments,
        totalNetAmount,
        newGrossAmount,
        newNetAmount,
        newNumPayments,
        carPoolingEnabled,
        codeId
      ]);
}

UserEventDetailsStruct createUserEventDetailsStruct({
  int? eventId,
  String? homeAway,
  String? meetTime,
  int? teamId,
  String? teamName,
  String? eventCode,
  String? eventLink,
  String? eventType,
  String? opposition,
  String? eventTitle,
  int? totalCount,
  String? locationPin,
  String? eventDetails,
  String? locationName,
  bool? notifyAdminsAll,
  bool? requestAttendance,
  int? acceptedPlayerCount,
  int? declinedPlayerCount,
  bool? notifyAdminsChanges,
  int? userHighestRoleLevel,
  int? noResponsePlayerCount,
  String? eventDateTimeFormatted,
  int? audienceId,
  int? eventRoleLevel,
  String? createdBy,
  String? createdByPhoneNumber,
  bool? teamHasSquads,
  int? eventPaid,
  bool? paymentRequired,
  int? paymentAmount,
  String? eventImage,
  int? totalAmountPaid,
  int? totalPayments,
  int? totalNetAmount,
  int? newGrossAmount,
  int? newNetAmount,
  int? newNumPayments,
  bool? carPoolingEnabled,
  int? codeId,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserEventDetailsStruct(
      eventId: eventId,
      homeAway: homeAway,
      meetTime: meetTime,
      teamId: teamId,
      teamName: teamName,
      eventCode: eventCode,
      eventLink: eventLink,
      eventType: eventType,
      opposition: opposition,
      eventTitle: eventTitle,
      totalCount: totalCount,
      locationPin: locationPin,
      eventDetails: eventDetails,
      locationName: locationName,
      notifyAdminsAll: notifyAdminsAll,
      requestAttendance: requestAttendance,
      acceptedPlayerCount: acceptedPlayerCount,
      declinedPlayerCount: declinedPlayerCount,
      notifyAdminsChanges: notifyAdminsChanges,
      userHighestRoleLevel: userHighestRoleLevel,
      noResponsePlayerCount: noResponsePlayerCount,
      eventDateTimeFormatted: eventDateTimeFormatted,
      audienceId: audienceId,
      eventRoleLevel: eventRoleLevel,
      createdBy: createdBy,
      createdByPhoneNumber: createdByPhoneNumber,
      teamHasSquads: teamHasSquads,
      eventPaid: eventPaid,
      paymentRequired: paymentRequired,
      paymentAmount: paymentAmount,
      eventImage: eventImage,
      totalAmountPaid: totalAmountPaid,
      totalPayments: totalPayments,
      totalNetAmount: totalNetAmount,
      newGrossAmount: newGrossAmount,
      newNetAmount: newNetAmount,
      newNumPayments: newNumPayments,
      carPoolingEnabled: carPoolingEnabled,
      codeId: codeId,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserEventDetailsStruct? updateUserEventDetailsStruct(
  UserEventDetailsStruct? userEventDetails, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userEventDetails
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserEventDetailsStructData(
  Map<String, dynamic> firestoreData,
  UserEventDetailsStruct? userEventDetails,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userEventDetails == null) {
    return;
  }
  if (userEventDetails.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && userEventDetails.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userEventDetailsData =
      getUserEventDetailsFirestoreData(userEventDetails, forFieldValue);
  final nestedData =
      userEventDetailsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = userEventDetails.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserEventDetailsFirestoreData(
  UserEventDetailsStruct? userEventDetails, [
  bool forFieldValue = false,
]) {
  if (userEventDetails == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userEventDetails.toMap());

  // Add any Firestore field values
  mapToFirestore(userEventDetails.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserEventDetailsListFirestoreData(
  List<UserEventDetailsStruct>? userEventDetailss,
) =>
    userEventDetailss
        ?.map((e) => getUserEventDetailsFirestoreData(e, true))
        .toList() ??
    [];
