// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class EventTypesStruct extends FFFirebaseStruct {
  EventTypesStruct({
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

  static EventTypesStruct fromMap(Map<String, dynamic> data) =>
      EventTypesStruct(
        id: castToType<int>(data['id']),
        name: data['name'] as String?,
      );

  static EventTypesStruct? maybeFromMap(dynamic data) => data is Map
      ? EventTypesStruct.fromMap(data.cast<String, dynamic>())
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

  static EventTypesStruct fromSerializableMap(Map<String, dynamic> data) =>
      EventTypesStruct(
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
  String toString() => 'EventTypesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is EventTypesStruct && id == other.id && name == other.name;
  }

  @override
  int get hashCode => const ListEquality().hash([id, name]);
}

EventTypesStruct createEventTypesStruct({
  int? id,
  String? name,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventTypesStruct(
      id: id,
      name: name,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventTypesStruct? updateEventTypesStruct(
  EventTypesStruct? eventTypes, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventTypes
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventTypesStructData(
  Map<String, dynamic> firestoreData,
  EventTypesStruct? eventTypes,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventTypes == null) {
    return;
  }
  if (eventTypes.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventTypes.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventTypesData = getEventTypesFirestoreData(eventTypes, forFieldValue);
  final nestedData = eventTypesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = eventTypes.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventTypesFirestoreData(
  EventTypesStruct? eventTypes, [
  bool forFieldValue = false,
]) {
  if (eventTypes == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventTypes.toMap());

  // Add any Firestore field values
  mapToFirestore(eventTypes.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventTypesListFirestoreData(
  List<EventTypesStruct>? eventTypess,
) =>
    eventTypess?.map((e) => getEventTypesFirestoreData(e, true)).toList() ?? [];
