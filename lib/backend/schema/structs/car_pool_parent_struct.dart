// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CarPoolParentStruct extends FFFirebaseStruct {
  CarPoolParentStruct({
    List<CarPoolsStruct>? carPools,
    bool? currentUserHasPool,
    int? currentUserRoleLevel,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _carPools = carPools,
        _currentUserHasPool = currentUserHasPool,
        _currentUserRoleLevel = currentUserRoleLevel,
        super(firestoreUtilData);

  // "car_pools" field.
  List<CarPoolsStruct>? _carPools;
  List<CarPoolsStruct> get carPools => _carPools ?? const [];
  set carPools(List<CarPoolsStruct>? val) => _carPools = val;

  void updateCarPools(Function(List<CarPoolsStruct>) updateFn) {
    updateFn(_carPools ??= []);
  }

  bool hasCarPools() => _carPools != null;

  // "current_user_has_pool" field.
  bool? _currentUserHasPool;
  bool get currentUserHasPool => _currentUserHasPool ?? false;
  set currentUserHasPool(bool? val) => _currentUserHasPool = val;

  bool hasCurrentUserHasPool() => _currentUserHasPool != null;

  // "current_user_role_level" field.
  int? _currentUserRoleLevel;
  int get currentUserRoleLevel => _currentUserRoleLevel ?? 0;
  set currentUserRoleLevel(int? val) => _currentUserRoleLevel = val;

  void incrementCurrentUserRoleLevel(int amount) =>
      currentUserRoleLevel = currentUserRoleLevel + amount;

  bool hasCurrentUserRoleLevel() => _currentUserRoleLevel != null;

  static CarPoolParentStruct fromMap(Map<String, dynamic> data) =>
      CarPoolParentStruct(
        carPools: getStructList(
          data['car_pools'],
          CarPoolsStruct.fromMap,
        ),
        currentUserHasPool: data['current_user_has_pool'] as bool?,
        currentUserRoleLevel: castToType<int>(data['current_user_role_level']),
      );

  static CarPoolParentStruct? maybeFromMap(dynamic data) => data is Map
      ? CarPoolParentStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'car_pools': _carPools?.map((e) => e.toMap()).toList(),
        'current_user_has_pool': _currentUserHasPool,
        'current_user_role_level': _currentUserRoleLevel,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'car_pools': serializeParam(
          _carPools,
          ParamType.DataStruct,
          isList: true,
        ),
        'current_user_has_pool': serializeParam(
          _currentUserHasPool,
          ParamType.bool,
        ),
        'current_user_role_level': serializeParam(
          _currentUserRoleLevel,
          ParamType.int,
        ),
      }.withoutNulls;

  static CarPoolParentStruct fromSerializableMap(Map<String, dynamic> data) =>
      CarPoolParentStruct(
        carPools: deserializeStructParam<CarPoolsStruct>(
          data['car_pools'],
          ParamType.DataStruct,
          true,
          structBuilder: CarPoolsStruct.fromSerializableMap,
        ),
        currentUserHasPool: deserializeParam(
          data['current_user_has_pool'],
          ParamType.bool,
          false,
        ),
        currentUserRoleLevel: deserializeParam(
          data['current_user_role_level'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'CarPoolParentStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is CarPoolParentStruct &&
        listEquality.equals(carPools, other.carPools) &&
        currentUserHasPool == other.currentUserHasPool &&
        currentUserRoleLevel == other.currentUserRoleLevel;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([carPools, currentUserHasPool, currentUserRoleLevel]);
}

CarPoolParentStruct createCarPoolParentStruct({
  bool? currentUserHasPool,
  int? currentUserRoleLevel,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CarPoolParentStruct(
      currentUserHasPool: currentUserHasPool,
      currentUserRoleLevel: currentUserRoleLevel,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CarPoolParentStruct? updateCarPoolParentStruct(
  CarPoolParentStruct? carPoolParent, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    carPoolParent
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCarPoolParentStructData(
  Map<String, dynamic> firestoreData,
  CarPoolParentStruct? carPoolParent,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (carPoolParent == null) {
    return;
  }
  if (carPoolParent.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && carPoolParent.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final carPoolParentData =
      getCarPoolParentFirestoreData(carPoolParent, forFieldValue);
  final nestedData =
      carPoolParentData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = carPoolParent.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCarPoolParentFirestoreData(
  CarPoolParentStruct? carPoolParent, [
  bool forFieldValue = false,
]) {
  if (carPoolParent == null) {
    return {};
  }
  final firestoreData = mapToFirestore(carPoolParent.toMap());

  // Add any Firestore field values
  mapToFirestore(carPoolParent.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCarPoolParentListFirestoreData(
  List<CarPoolParentStruct>? carPoolParents,
) =>
    carPoolParents
        ?.map((e) => getCarPoolParentFirestoreData(e, true))
        .toList() ??
    [];
