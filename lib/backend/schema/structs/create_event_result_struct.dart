// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CreateEventResultStruct extends FFFirebaseStruct {
  CreateEventResultStruct({
    bool? success,
    int? eventsCreated,
    List<int>? eventIds,
    String? message,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _success = success,
        _eventsCreated = eventsCreated,
        _eventIds = eventIds,
        _message = message,
        super(firestoreUtilData);

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "events_created" field.
  int? _eventsCreated;
  int get eventsCreated => _eventsCreated ?? 0;
  set eventsCreated(int? val) => _eventsCreated = val;

  void incrementEventsCreated(int amount) =>
      eventsCreated = eventsCreated + amount;

  bool hasEventsCreated() => _eventsCreated != null;

  // "event_ids" field.
  List<int>? _eventIds;
  List<int> get eventIds => _eventIds ?? const [];
  set eventIds(List<int>? val) => _eventIds = val;

  void updateEventIds(Function(List<int>) updateFn) {
    updateFn(_eventIds ??= []);
  }

  bool hasEventIds() => _eventIds != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  set message(String? val) => _message = val;

  bool hasMessage() => _message != null;

  static CreateEventResultStruct fromMap(Map<String, dynamic> data) =>
      CreateEventResultStruct(
        success: data['success'] as bool?,
        eventsCreated: castToType<int>(data['events_created']),
        eventIds: getDataList(data['event_ids']),
        message: data['message'] as String?,
      );

  static CreateEventResultStruct? maybeFromMap(dynamic data) => data is Map
      ? CreateEventResultStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'events_created': _eventsCreated,
        'event_ids': _eventIds,
        'message': _message,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'events_created': serializeParam(
          _eventsCreated,
          ParamType.int,
        ),
        'event_ids': serializeParam(
          _eventIds,
          ParamType.int,
          isList: true,
        ),
        'message': serializeParam(
          _message,
          ParamType.String,
        ),
      }.withoutNulls;

  static CreateEventResultStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      CreateEventResultStruct(
        success: deserializeParam(
          data['success'],
          ParamType.bool,
          false,
        ),
        eventsCreated: deserializeParam(
          data['events_created'],
          ParamType.int,
          false,
        ),
        eventIds: deserializeParam<int>(
          data['event_ids'],
          ParamType.int,
          true,
        ),
        message: deserializeParam(
          data['message'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CreateEventResultStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is CreateEventResultStruct &&
        success == other.success &&
        eventsCreated == other.eventsCreated &&
        listEquality.equals(eventIds, other.eventIds) &&
        message == other.message;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([success, eventsCreated, eventIds, message]);
}

CreateEventResultStruct createCreateEventResultStruct({
  bool? success,
  int? eventsCreated,
  String? message,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CreateEventResultStruct(
      success: success,
      eventsCreated: eventsCreated,
      message: message,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CreateEventResultStruct? updateCreateEventResultStruct(
  CreateEventResultStruct? createEventResult, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    createEventResult
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCreateEventResultStructData(
  Map<String, dynamic> firestoreData,
  CreateEventResultStruct? createEventResult,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (createEventResult == null) {
    return;
  }
  if (createEventResult.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && createEventResult.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final createEventResultData =
      getCreateEventResultFirestoreData(createEventResult, forFieldValue);
  final nestedData =
      createEventResultData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = createEventResult.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCreateEventResultFirestoreData(
  CreateEventResultStruct? createEventResult, [
  bool forFieldValue = false,
]) {
  if (createEventResult == null) {
    return {};
  }
  final firestoreData = mapToFirestore(createEventResult.toMap());

  // Add any Firestore field values
  mapToFirestore(createEventResult.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCreateEventResultListFirestoreData(
  List<CreateEventResultStruct>? createEventResults,
) =>
    createEventResults
        ?.map((e) => getCreateEventResultFirestoreData(e, true))
        .toList() ??
    [];
