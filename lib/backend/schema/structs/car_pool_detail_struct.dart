// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CarPoolDetailStruct extends FFFirebaseStruct {
  CarPoolDetailStruct({
    String? status,
    int? eventId,
    String? createdAt,
    int? freeSeats,
    int? carPoolId,
    String? driverName,
    int? totalSeats,
    List<ReservationsStruct>? reservations,
    String? driverUserId,
    int? reservedSeats,
    List<UserAssociatedMembersStruct>? userAssociatedMembers,
    int? associatedPlayersCount,
    String? driverEmail,
    String? driverPhone,
    String? eventTitle,
    String? teamName,
    String? eventDateFormatted,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _status = status,
        _eventId = eventId,
        _createdAt = createdAt,
        _freeSeats = freeSeats,
        _carPoolId = carPoolId,
        _driverName = driverName,
        _totalSeats = totalSeats,
        _reservations = reservations,
        _driverUserId = driverUserId,
        _reservedSeats = reservedSeats,
        _userAssociatedMembers = userAssociatedMembers,
        _associatedPlayersCount = associatedPlayersCount,
        _driverEmail = driverEmail,
        _driverPhone = driverPhone,
        _eventTitle = eventTitle,
        _teamName = teamName,
        _eventDateFormatted = eventDateFormatted,
        super(firestoreUtilData);

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

  bool hasStatus() => _status != null;

  // "event_id" field.
  int? _eventId;
  int get eventId => _eventId ?? 0;
  set eventId(int? val) => _eventId = val;

  void incrementEventId(int amount) => eventId = eventId + amount;

  bool hasEventId() => _eventId != null;

  // "created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "free_seats" field.
  int? _freeSeats;
  int get freeSeats => _freeSeats ?? 0;
  set freeSeats(int? val) => _freeSeats = val;

  void incrementFreeSeats(int amount) => freeSeats = freeSeats + amount;

  bool hasFreeSeats() => _freeSeats != null;

  // "car_pool_id" field.
  int? _carPoolId;
  int get carPoolId => _carPoolId ?? 0;
  set carPoolId(int? val) => _carPoolId = val;

  void incrementCarPoolId(int amount) => carPoolId = carPoolId + amount;

  bool hasCarPoolId() => _carPoolId != null;

  // "driver_name" field.
  String? _driverName;
  String get driverName => _driverName ?? '';
  set driverName(String? val) => _driverName = val;

  bool hasDriverName() => _driverName != null;

  // "total_seats" field.
  int? _totalSeats;
  int get totalSeats => _totalSeats ?? 0;
  set totalSeats(int? val) => _totalSeats = val;

  void incrementTotalSeats(int amount) => totalSeats = totalSeats + amount;

  bool hasTotalSeats() => _totalSeats != null;

  // "reservations" field.
  List<ReservationsStruct>? _reservations;
  List<ReservationsStruct> get reservations => _reservations ?? const [];
  set reservations(List<ReservationsStruct>? val) => _reservations = val;

  void updateReservations(Function(List<ReservationsStruct>) updateFn) {
    updateFn(_reservations ??= []);
  }

  bool hasReservations() => _reservations != null;

  // "driver_user_id" field.
  String? _driverUserId;
  String get driverUserId => _driverUserId ?? '';
  set driverUserId(String? val) => _driverUserId = val;

  bool hasDriverUserId() => _driverUserId != null;

  // "reserved_seats" field.
  int? _reservedSeats;
  int get reservedSeats => _reservedSeats ?? 0;
  set reservedSeats(int? val) => _reservedSeats = val;

  void incrementReservedSeats(int amount) =>
      reservedSeats = reservedSeats + amount;

  bool hasReservedSeats() => _reservedSeats != null;

  // "user_associated_members" field.
  List<UserAssociatedMembersStruct>? _userAssociatedMembers;
  List<UserAssociatedMembersStruct> get userAssociatedMembers =>
      _userAssociatedMembers ?? const [];
  set userAssociatedMembers(List<UserAssociatedMembersStruct>? val) =>
      _userAssociatedMembers = val;

  void updateUserAssociatedMembers(
      Function(List<UserAssociatedMembersStruct>) updateFn) {
    updateFn(_userAssociatedMembers ??= []);
  }

  bool hasUserAssociatedMembers() => _userAssociatedMembers != null;

  // "associated_players_count" field.
  int? _associatedPlayersCount;
  int get associatedPlayersCount => _associatedPlayersCount ?? 0;
  set associatedPlayersCount(int? val) => _associatedPlayersCount = val;

  void incrementAssociatedPlayersCount(int amount) =>
      associatedPlayersCount = associatedPlayersCount + amount;

  bool hasAssociatedPlayersCount() => _associatedPlayersCount != null;

  // "driver_email" field.
  String? _driverEmail;
  String get driverEmail => _driverEmail ?? '';
  set driverEmail(String? val) => _driverEmail = val;

  bool hasDriverEmail() => _driverEmail != null;

  // "driver_phone" field.
  String? _driverPhone;
  String get driverPhone => _driverPhone ?? '';
  set driverPhone(String? val) => _driverPhone = val;

  bool hasDriverPhone() => _driverPhone != null;

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

  // "event_date_formatted" field.
  String? _eventDateFormatted;
  String get eventDateFormatted => _eventDateFormatted ?? '';
  set eventDateFormatted(String? val) => _eventDateFormatted = val;

  bool hasEventDateFormatted() => _eventDateFormatted != null;

  static CarPoolDetailStruct fromMap(Map<String, dynamic> data) =>
      CarPoolDetailStruct(
        status: data['status'] as String?,
        eventId: castToType<int>(data['event_id']),
        createdAt: data['created_at'] as String?,
        freeSeats: castToType<int>(data['free_seats']),
        carPoolId: castToType<int>(data['car_pool_id']),
        driverName: data['driver_name'] as String?,
        totalSeats: castToType<int>(data['total_seats']),
        reservations: getStructList(
          data['reservations'],
          ReservationsStruct.fromMap,
        ),
        driverUserId: data['driver_user_id'] as String?,
        reservedSeats: castToType<int>(data['reserved_seats']),
        userAssociatedMembers: getStructList(
          data['user_associated_members'],
          UserAssociatedMembersStruct.fromMap,
        ),
        associatedPlayersCount:
            castToType<int>(data['associated_players_count']),
        driverEmail: data['driver_email'] as String?,
        driverPhone: data['driver_phone'] as String?,
        eventTitle: data['event_title'] as String?,
        teamName: data['team_name'] as String?,
        eventDateFormatted: data['event_date_formatted'] as String?,
      );

  static CarPoolDetailStruct? maybeFromMap(dynamic data) => data is Map
      ? CarPoolDetailStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'status': _status,
        'event_id': _eventId,
        'created_at': _createdAt,
        'free_seats': _freeSeats,
        'car_pool_id': _carPoolId,
        'driver_name': _driverName,
        'total_seats': _totalSeats,
        'reservations': _reservations?.map((e) => e.toMap()).toList(),
        'driver_user_id': _driverUserId,
        'reserved_seats': _reservedSeats,
        'user_associated_members':
            _userAssociatedMembers?.map((e) => e.toMap()).toList(),
        'associated_players_count': _associatedPlayersCount,
        'driver_email': _driverEmail,
        'driver_phone': _driverPhone,
        'event_title': _eventTitle,
        'team_name': _teamName,
        'event_date_formatted': _eventDateFormatted,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
        'created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'free_seats': serializeParam(
          _freeSeats,
          ParamType.int,
        ),
        'car_pool_id': serializeParam(
          _carPoolId,
          ParamType.int,
        ),
        'driver_name': serializeParam(
          _driverName,
          ParamType.String,
        ),
        'total_seats': serializeParam(
          _totalSeats,
          ParamType.int,
        ),
        'reservations': serializeParam(
          _reservations,
          ParamType.DataStruct,
          isList: true,
        ),
        'driver_user_id': serializeParam(
          _driverUserId,
          ParamType.String,
        ),
        'reserved_seats': serializeParam(
          _reservedSeats,
          ParamType.int,
        ),
        'user_associated_members': serializeParam(
          _userAssociatedMembers,
          ParamType.DataStruct,
          isList: true,
        ),
        'associated_players_count': serializeParam(
          _associatedPlayersCount,
          ParamType.int,
        ),
        'driver_email': serializeParam(
          _driverEmail,
          ParamType.String,
        ),
        'driver_phone': serializeParam(
          _driverPhone,
          ParamType.String,
        ),
        'event_title': serializeParam(
          _eventTitle,
          ParamType.String,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'event_date_formatted': serializeParam(
          _eventDateFormatted,
          ParamType.String,
        ),
      }.withoutNulls;

  static CarPoolDetailStruct fromSerializableMap(Map<String, dynamic> data) =>
      CarPoolDetailStruct(
        status: deserializeParam(
          data['status'],
          ParamType.String,
          false,
        ),
        eventId: deserializeParam(
          data['event_id'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['created_at'],
          ParamType.String,
          false,
        ),
        freeSeats: deserializeParam(
          data['free_seats'],
          ParamType.int,
          false,
        ),
        carPoolId: deserializeParam(
          data['car_pool_id'],
          ParamType.int,
          false,
        ),
        driverName: deserializeParam(
          data['driver_name'],
          ParamType.String,
          false,
        ),
        totalSeats: deserializeParam(
          data['total_seats'],
          ParamType.int,
          false,
        ),
        reservations: deserializeStructParam<ReservationsStruct>(
          data['reservations'],
          ParamType.DataStruct,
          true,
          structBuilder: ReservationsStruct.fromSerializableMap,
        ),
        driverUserId: deserializeParam(
          data['driver_user_id'],
          ParamType.String,
          false,
        ),
        reservedSeats: deserializeParam(
          data['reserved_seats'],
          ParamType.int,
          false,
        ),
        userAssociatedMembers:
            deserializeStructParam<UserAssociatedMembersStruct>(
          data['user_associated_members'],
          ParamType.DataStruct,
          true,
          structBuilder: UserAssociatedMembersStruct.fromSerializableMap,
        ),
        associatedPlayersCount: deserializeParam(
          data['associated_players_count'],
          ParamType.int,
          false,
        ),
        driverEmail: deserializeParam(
          data['driver_email'],
          ParamType.String,
          false,
        ),
        driverPhone: deserializeParam(
          data['driver_phone'],
          ParamType.String,
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
        eventDateFormatted: deserializeParam(
          data['event_date_formatted'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CarPoolDetailStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is CarPoolDetailStruct &&
        status == other.status &&
        eventId == other.eventId &&
        createdAt == other.createdAt &&
        freeSeats == other.freeSeats &&
        carPoolId == other.carPoolId &&
        driverName == other.driverName &&
        totalSeats == other.totalSeats &&
        listEquality.equals(reservations, other.reservations) &&
        driverUserId == other.driverUserId &&
        reservedSeats == other.reservedSeats &&
        listEquality.equals(
            userAssociatedMembers, other.userAssociatedMembers) &&
        associatedPlayersCount == other.associatedPlayersCount &&
        driverEmail == other.driverEmail &&
        driverPhone == other.driverPhone &&
        eventTitle == other.eventTitle &&
        teamName == other.teamName &&
        eventDateFormatted == other.eventDateFormatted;
  }

  @override
  int get hashCode => const ListEquality().hash([
        status,
        eventId,
        createdAt,
        freeSeats,
        carPoolId,
        driverName,
        totalSeats,
        reservations,
        driverUserId,
        reservedSeats,
        userAssociatedMembers,
        associatedPlayersCount,
        driverEmail,
        driverPhone,
        eventTitle,
        teamName,
        eventDateFormatted
      ]);
}

CarPoolDetailStruct createCarPoolDetailStruct({
  String? status,
  int? eventId,
  String? createdAt,
  int? freeSeats,
  int? carPoolId,
  String? driverName,
  int? totalSeats,
  String? driverUserId,
  int? reservedSeats,
  int? associatedPlayersCount,
  String? driverEmail,
  String? driverPhone,
  String? eventTitle,
  String? teamName,
  String? eventDateFormatted,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CarPoolDetailStruct(
      status: status,
      eventId: eventId,
      createdAt: createdAt,
      freeSeats: freeSeats,
      carPoolId: carPoolId,
      driverName: driverName,
      totalSeats: totalSeats,
      driverUserId: driverUserId,
      reservedSeats: reservedSeats,
      associatedPlayersCount: associatedPlayersCount,
      driverEmail: driverEmail,
      driverPhone: driverPhone,
      eventTitle: eventTitle,
      teamName: teamName,
      eventDateFormatted: eventDateFormatted,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CarPoolDetailStruct? updateCarPoolDetailStruct(
  CarPoolDetailStruct? carPoolDetail, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    carPoolDetail
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCarPoolDetailStructData(
  Map<String, dynamic> firestoreData,
  CarPoolDetailStruct? carPoolDetail,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (carPoolDetail == null) {
    return;
  }
  if (carPoolDetail.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && carPoolDetail.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final carPoolDetailData =
      getCarPoolDetailFirestoreData(carPoolDetail, forFieldValue);
  final nestedData =
      carPoolDetailData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = carPoolDetail.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCarPoolDetailFirestoreData(
  CarPoolDetailStruct? carPoolDetail, [
  bool forFieldValue = false,
]) {
  if (carPoolDetail == null) {
    return {};
  }
  final firestoreData = mapToFirestore(carPoolDetail.toMap());

  // Add any Firestore field values
  mapToFirestore(carPoolDetail.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCarPoolDetailListFirestoreData(
  List<CarPoolDetailStruct>? carPoolDetails,
) =>
    carPoolDetails
        ?.map((e) => getCarPoolDetailFirestoreData(e, true))
        .toList() ??
    [];
