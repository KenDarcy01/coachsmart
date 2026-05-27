// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class ReservationsStruct extends FFFirebaseStruct {
  ReservationsStruct({
    int? memberId,
    String? memberName,
    String? profilePic,
    String? reservedAt,
    int? reservationId,
    bool? memberBelongsToUser,
    String? associatedUserEmail,
    String? status,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _memberId = memberId,
        _memberName = memberName,
        _profilePic = profilePic,
        _reservedAt = reservedAt,
        _reservationId = reservationId,
        _memberBelongsToUser = memberBelongsToUser,
        _associatedUserEmail = associatedUserEmail,
        _status = status,
        super(firestoreUtilData);

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "member_name" field.
  String? _memberName;
  String get memberName => _memberName ?? '';
  set memberName(String? val) => _memberName = val;

  bool hasMemberName() => _memberName != null;

  // "profile_pic" field.
  String? _profilePic;
  String get profilePic => _profilePic ?? '';
  set profilePic(String? val) => _profilePic = val;

  bool hasProfilePic() => _profilePic != null;

  // "reserved_at" field.
  String? _reservedAt;
  String get reservedAt => _reservedAt ?? '';
  set reservedAt(String? val) => _reservedAt = val;

  bool hasReservedAt() => _reservedAt != null;

  // "reservation_id" field.
  int? _reservationId;
  int get reservationId => _reservationId ?? 0;
  set reservationId(int? val) => _reservationId = val;

  void incrementReservationId(int amount) =>
      reservationId = reservationId + amount;

  bool hasReservationId() => _reservationId != null;

  // "member_belongs_to_user" field.
  bool? _memberBelongsToUser;
  bool get memberBelongsToUser => _memberBelongsToUser ?? false;
  set memberBelongsToUser(bool? val) => _memberBelongsToUser = val;

  bool hasMemberBelongsToUser() => _memberBelongsToUser != null;

  // "associated_user_email" field.
  String? _associatedUserEmail;
  String get associatedUserEmail => _associatedUserEmail ?? '';
  set associatedUserEmail(String? val) => _associatedUserEmail = val;

  bool hasAssociatedUserEmail() => _associatedUserEmail != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

  bool hasStatus() => _status != null;

  static ReservationsStruct fromMap(Map<String, dynamic> data) =>
      ReservationsStruct(
        memberId: castToType<int>(data['member_id']),
        memberName: data['member_name'] as String?,
        profilePic: data['profile_pic'] as String?,
        reservedAt: data['reserved_at'] as String?,
        reservationId: castToType<int>(data['reservation_id']),
        memberBelongsToUser: data['member_belongs_to_user'] as bool?,
        associatedUserEmail: data['associated_user_email'] as String?,
        status: data['status'] as String?,
      );

  static ReservationsStruct? maybeFromMap(dynamic data) => data is Map
      ? ReservationsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'member_id': _memberId,
        'member_name': _memberName,
        'profile_pic': _profilePic,
        'reserved_at': _reservedAt,
        'reservation_id': _reservationId,
        'member_belongs_to_user': _memberBelongsToUser,
        'associated_user_email': _associatedUserEmail,
        'status': _status,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'member_name': serializeParam(
          _memberName,
          ParamType.String,
        ),
        'profile_pic': serializeParam(
          _profilePic,
          ParamType.String,
        ),
        'reserved_at': serializeParam(
          _reservedAt,
          ParamType.String,
        ),
        'reservation_id': serializeParam(
          _reservationId,
          ParamType.int,
        ),
        'member_belongs_to_user': serializeParam(
          _memberBelongsToUser,
          ParamType.bool,
        ),
        'associated_user_email': serializeParam(
          _associatedUserEmail,
          ParamType.String,
        ),
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
      }.withoutNulls;

  static ReservationsStruct fromSerializableMap(Map<String, dynamic> data) =>
      ReservationsStruct(
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        memberName: deserializeParam(
          data['member_name'],
          ParamType.String,
          false,
        ),
        profilePic: deserializeParam(
          data['profile_pic'],
          ParamType.String,
          false,
        ),
        reservedAt: deserializeParam(
          data['reserved_at'],
          ParamType.String,
          false,
        ),
        reservationId: deserializeParam(
          data['reservation_id'],
          ParamType.int,
          false,
        ),
        memberBelongsToUser: deserializeParam(
          data['member_belongs_to_user'],
          ParamType.bool,
          false,
        ),
        associatedUserEmail: deserializeParam(
          data['associated_user_email'],
          ParamType.String,
          false,
        ),
        status: deserializeParam(
          data['status'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ReservationsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ReservationsStruct &&
        memberId == other.memberId &&
        memberName == other.memberName &&
        profilePic == other.profilePic &&
        reservedAt == other.reservedAt &&
        reservationId == other.reservationId &&
        memberBelongsToUser == other.memberBelongsToUser &&
        associatedUserEmail == other.associatedUserEmail &&
        status == other.status;
  }

  @override
  int get hashCode => const ListEquality().hash([
        memberId,
        memberName,
        profilePic,
        reservedAt,
        reservationId,
        memberBelongsToUser,
        associatedUserEmail,
        status
      ]);
}

ReservationsStruct createReservationsStruct({
  int? memberId,
  String? memberName,
  String? profilePic,
  String? reservedAt,
  int? reservationId,
  bool? memberBelongsToUser,
  String? associatedUserEmail,
  String? status,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ReservationsStruct(
      memberId: memberId,
      memberName: memberName,
      profilePic: profilePic,
      reservedAt: reservedAt,
      reservationId: reservationId,
      memberBelongsToUser: memberBelongsToUser,
      associatedUserEmail: associatedUserEmail,
      status: status,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ReservationsStruct? updateReservationsStruct(
  ReservationsStruct? reservations, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    reservations
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addReservationsStructData(
  Map<String, dynamic> firestoreData,
  ReservationsStruct? reservations,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (reservations == null) {
    return;
  }
  if (reservations.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && reservations.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final reservationsData =
      getReservationsFirestoreData(reservations, forFieldValue);
  final nestedData =
      reservationsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = reservations.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getReservationsFirestoreData(
  ReservationsStruct? reservations, [
  bool forFieldValue = false,
]) {
  if (reservations == null) {
    return {};
  }
  final firestoreData = mapToFirestore(reservations.toMap());

  // Add any Firestore field values
  mapToFirestore(reservations.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getReservationsListFirestoreData(
  List<ReservationsStruct>? reservationss,
) =>
    reservationss?.map((e) => getReservationsFirestoreData(e, true)).toList() ??
    [];
