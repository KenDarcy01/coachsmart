// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class EventCodesStruct extends FFFirebaseStruct {
  EventCodesStruct({
    int? id,
    String? name,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _id = id,
        _name = name,
        super(firestoreUtilData);

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  set id(int? val) => _id = val;

  void incrementId(int amount) => id = id + amount;

  bool hasId() => _id != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  set name(String? val) => _name = val;

  bool hasName() => _name != null;

  static EventCodesStruct fromMap(Map<String, dynamic> data) =>
      EventCodesStruct(
        id: castToType<int>(data['id']),
        name: data['name'] as String?,
      );

  static EventCodesStruct? maybeFromMap(dynamic data) => data is Map
      ? EventCodesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'name': _name,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.int,
        ),
        'name': serializeParam(
          _name,
          ParamType.String,
        ),
      }.withoutNulls;

  static EventCodesStruct fromSerializableMap(Map<String, dynamic> data) =>
      EventCodesStruct(
        id: deserializeParam(
          data['id'],
          ParamType.int,
          false,
        ),
        name: deserializeParam(
          data['name'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'EventCodesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is EventCodesStruct && id == other.id && name == other.name;
  }

  @override
  int get hashCode => const ListEquality().hash([id, name]);
}

EventCodesStruct createEventCodesStruct({
  int? id,
  String? name,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventCodesStruct(
      id: id,
      name: name,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventCodesStruct? updateEventCodesStruct(
  EventCodesStruct? eventCodes, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventCodes
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventCodesStructData(
  Map<String, dynamic> firestoreData,
  EventCodesStruct? eventCodes,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventCodes == null) {
    return;
  }
  if (eventCodes.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventCodes.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventCodesData = getEventCodesFirestoreData(eventCodes, forFieldValue);
  final nestedData = eventCodesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = eventCodes.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventCodesFirestoreData(
  EventCodesStruct? eventCodes, [
  bool forFieldValue = false,
]) {
  if (eventCodes == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventCodes.toMap());

  // Add any Firestore field values
  mapToFirestore(eventCodes.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventCodesListFirestoreData(
  List<EventCodesStruct>? eventCodess,
) =>
    eventCodess?.map((e) => getEventCodesFirestoreData(e, true)).toList() ?? [];
