// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class CarPoolsStruct extends FFFirebaseStruct {
  CarPoolsStruct({
    int? carPoolId,
    String? driverUserId,
    String? driverName,
    int? totalSeats,
    int? reservedSeats,
    int? freeSeats,
    String? createdAt,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _carPoolId = carPoolId,
        _driverUserId = driverUserId,
        _driverName = driverName,
        _totalSeats = totalSeats,
        _reservedSeats = reservedSeats,
        _freeSeats = freeSeats,
        _createdAt = createdAt,
        super(firestoreUtilData);

  // "car_pool_id" field.
  int? _carPoolId;
  int get carPoolId => _carPoolId ?? 0;
  set carPoolId(int? val) => _carPoolId = val;

  void incrementCarPoolId(int amount) => carPoolId = carPoolId + amount;

  bool hasCarPoolId() => _carPoolId != null;

  // "driver_user_id" field.
  String? _driverUserId;
  String get driverUserId => _driverUserId ?? '';
  set driverUserId(String? val) => _driverUserId = val;

  bool hasDriverUserId() => _driverUserId != null;

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

  // "reserved_seats" field.
  int? _reservedSeats;
  int get reservedSeats => _reservedSeats ?? 0;
  set reservedSeats(int? val) => _reservedSeats = val;

  void incrementReservedSeats(int amount) =>
      reservedSeats = reservedSeats + amount;

  bool hasReservedSeats() => _reservedSeats != null;

  // "free_seats" field.
  int? _freeSeats;
  int get freeSeats => _freeSeats ?? 0;
  set freeSeats(int? val) => _freeSeats = val;

  void incrementFreeSeats(int amount) => freeSeats = freeSeats + amount;

  bool hasFreeSeats() => _freeSeats != null;

  // "created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  static CarPoolsStruct fromMap(Map<String, dynamic> data) => CarPoolsStruct(
        carPoolId: castToType<int>(data['car_pool_id']),
        driverUserId: data['driver_user_id'] as String?,
        driverName: data['driver_name'] as String?,
        totalSeats: castToType<int>(data['total_seats']),
        reservedSeats: castToType<int>(data['reserved_seats']),
        freeSeats: castToType<int>(data['free_seats']),
        createdAt: data['created_at'] as String?,
      );

  static CarPoolsStruct? maybeFromMap(dynamic data) =>
      data is Map ? CarPoolsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'car_pool_id': _carPoolId,
        'driver_user_id': _driverUserId,
        'driver_name': _driverName,
        'total_seats': _totalSeats,
        'reserved_seats': _reservedSeats,
        'free_seats': _freeSeats,
        'created_at': _createdAt,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'car_pool_id': serializeParam(
          _carPoolId,
          ParamType.int,
        ),
        'driver_user_id': serializeParam(
          _driverUserId,
          ParamType.String,
        ),
        'driver_name': serializeParam(
          _driverName,
          ParamType.String,
        ),
        'total_seats': serializeParam(
          _totalSeats,
          ParamType.int,
        ),
        'reserved_seats': serializeParam(
          _reservedSeats,
          ParamType.int,
        ),
        'free_seats': serializeParam(
          _freeSeats,
          ParamType.int,
        ),
        'created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
      }.withoutNulls;

  static CarPoolsStruct fromSerializableMap(Map<String, dynamic> data) =>
      CarPoolsStruct(
        carPoolId: deserializeParam(
          data['car_pool_id'],
          ParamType.int,
          false,
        ),
        driverUserId: deserializeParam(
          data['driver_user_id'],
          ParamType.String,
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
        reservedSeats: deserializeParam(
          data['reserved_seats'],
          ParamType.int,
          false,
        ),
        freeSeats: deserializeParam(
          data['free_seats'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['created_at'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CarPoolsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is CarPoolsStruct &&
        carPoolId == other.carPoolId &&
        driverUserId == other.driverUserId &&
        driverName == other.driverName &&
        totalSeats == other.totalSeats &&
        reservedSeats == other.reservedSeats &&
        freeSeats == other.freeSeats &&
        createdAt == other.createdAt;
  }

  @override
  int get hashCode => const ListEquality().hash([
        carPoolId,
        driverUserId,
        driverName,
        totalSeats,
        reservedSeats,
        freeSeats,
        createdAt
      ]);
}

CarPoolsStruct createCarPoolsStruct({
  int? carPoolId,
  String? driverUserId,
  String? driverName,
  int? totalSeats,
  int? reservedSeats,
  int? freeSeats,
  String? createdAt,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CarPoolsStruct(
      carPoolId: carPoolId,
      driverUserId: driverUserId,
      driverName: driverName,
      totalSeats: totalSeats,
      reservedSeats: reservedSeats,
      freeSeats: freeSeats,
      createdAt: createdAt,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CarPoolsStruct? updateCarPoolsStruct(
  CarPoolsStruct? carPools, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    carPools
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCarPoolsStructData(
  Map<String, dynamic> firestoreData,
  CarPoolsStruct? carPools,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (carPools == null) {
    return;
  }
  if (carPools.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && carPools.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final carPoolsData = getCarPoolsFirestoreData(carPools, forFieldValue);
  final nestedData = carPoolsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = carPools.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCarPoolsFirestoreData(
  CarPoolsStruct? carPools, [
  bool forFieldValue = false,
]) {
  if (carPools == null) {
    return {};
  }
  final firestoreData = mapToFirestore(carPools.toMap());

  // Add any Firestore field values
  mapToFirestore(carPools.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCarPoolsListFirestoreData(
  List<CarPoolsStruct>? carPoolss,
) =>
    carPoolss?.map((e) => getCarPoolsFirestoreData(e, true)).toList() ?? [];
