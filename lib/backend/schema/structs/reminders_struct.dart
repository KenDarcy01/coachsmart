// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class RemindersStruct extends FFFirebaseStruct {
  RemindersStruct({
    int? id,
    String? createdAt,
    int? eventId,
    String? userId,
    String? result,
    String? userFullName,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _id = id,
        _createdAt = createdAt,
        _eventId = eventId,
        _userId = userId,
        _result = result,
        _userFullName = userFullName,
        super(firestoreUtilData);

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  set id(int? val) => _id = val;

  void incrementId(int amount) => id = id + amount;

  bool hasId() => _id != null;

  // "created_at" field.
  String? _createdAt;
  String get createdAt => _createdAt ?? '';
  set createdAt(String? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "event_id" field.
  int? _eventId;
  int get eventId => _eventId ?? 0;
  set eventId(int? val) => _eventId = val;

  void incrementEventId(int amount) => eventId = eventId + amount;

  bool hasEventId() => _eventId != null;

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  set userId(String? val) => _userId = val;

  bool hasUserId() => _userId != null;

  // "result" field.
  String? _result;
  String get result => _result ?? '';
  set result(String? val) => _result = val;

  bool hasResult() => _result != null;

  // "user_full_name" field.
  String? _userFullName;
  String get userFullName => _userFullName ?? '';
  set userFullName(String? val) => _userFullName = val;

  bool hasUserFullName() => _userFullName != null;

  static RemindersStruct fromMap(Map<String, dynamic> data) => RemindersStruct(
        id: castToType<int>(data['id']),
        createdAt: data['created_at'] as String?,
        eventId: castToType<int>(data['event_id']),
        userId: data['user_id'] as String?,
        result: data['result'] as String?,
        userFullName: data['user_full_name'] as String?,
      );

  static RemindersStruct? maybeFromMap(dynamic data) => data is Map
      ? RemindersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'created_at': _createdAt,
        'event_id': _eventId,
        'user_id': _userId,
        'result': _result,
        'user_full_name': _userFullName,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.int,
        ),
        'created_at': serializeParam(
          _createdAt,
          ParamType.String,
        ),
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
        'user_id': serializeParam(
          _userId,
          ParamType.String,
        ),
        'result': serializeParam(
          _result,
          ParamType.String,
        ),
        'user_full_name': serializeParam(
          _userFullName,
          ParamType.String,
        ),
      }.withoutNulls;

  static RemindersStruct fromSerializableMap(Map<String, dynamic> data) =>
      RemindersStruct(
        id: deserializeParam(
          data['id'],
          ParamType.int,
          false,
        ),
        createdAt: deserializeParam(
          data['created_at'],
          ParamType.String,
          false,
        ),
        eventId: deserializeParam(
          data['event_id'],
          ParamType.int,
          false,
        ),
        userId: deserializeParam(
          data['user_id'],
          ParamType.String,
          false,
        ),
        result: deserializeParam(
          data['result'],
          ParamType.String,
          false,
        ),
        userFullName: deserializeParam(
          data['user_full_name'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'RemindersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is RemindersStruct &&
        id == other.id &&
        createdAt == other.createdAt &&
        eventId == other.eventId &&
        userId == other.userId &&
        result == other.result &&
        userFullName == other.userFullName;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([id, createdAt, eventId, userId, result, userFullName]);
}

RemindersStruct createRemindersStruct({
  int? id,
  String? createdAt,
  int? eventId,
  String? userId,
  String? result,
  String? userFullName,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    RemindersStruct(
      id: id,
      createdAt: createdAt,
      eventId: eventId,
      userId: userId,
      result: result,
      userFullName: userFullName,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

RemindersStruct? updateRemindersStruct(
  RemindersStruct? reminders, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    reminders
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addRemindersStructData(
  Map<String, dynamic> firestoreData,
  RemindersStruct? reminders,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (reminders == null) {
    return;
  }
  if (reminders.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && reminders.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final remindersData = getRemindersFirestoreData(reminders, forFieldValue);
  final nestedData = remindersData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = reminders.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getRemindersFirestoreData(
  RemindersStruct? reminders, [
  bool forFieldValue = false,
]) {
  if (reminders == null) {
    return {};
  }
  final firestoreData = mapToFirestore(reminders.toMap());

  // Add any Firestore field values
  mapToFirestore(reminders.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getRemindersListFirestoreData(
  List<RemindersStruct>? reminderss,
) =>
    reminderss?.map((e) => getRemindersFirestoreData(e, true)).toList() ?? [];
