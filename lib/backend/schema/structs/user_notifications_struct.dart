// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class UserNotificationsStruct extends FFFirebaseStruct {
  UserNotificationsStruct({
    int? id,
    String? createdAt,
    String? appTitle,
    String? appBody,
    bool? isRead,
    String? timeLabel,
    String? teamName,
    int? eventId,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _id = id,
        _createdAt = createdAt,
        _appTitle = appTitle,
        _appBody = appBody,
        _isRead = isRead,
        _timeLabel = timeLabel,
        _teamName = teamName,
        _eventId = eventId,
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

  // "app_title" field.
  String? _appTitle;
  String get appTitle => _appTitle ?? '';
  set appTitle(String? val) => _appTitle = val;

  bool hasAppTitle() => _appTitle != null;

  // "app_body" field.
  String? _appBody;
  String get appBody => _appBody ?? '';
  set appBody(String? val) => _appBody = val;

  bool hasAppBody() => _appBody != null;

  // "is_read" field.
  bool? _isRead;
  bool get isRead => _isRead ?? false;
  set isRead(bool? val) => _isRead = val;

  bool hasIsRead() => _isRead != null;

  // "time_label" field.
  String? _timeLabel;
  String get timeLabel => _timeLabel ?? '';
  set timeLabel(String? val) => _timeLabel = val;

  bool hasTimeLabel() => _timeLabel != null;

  // "team_name" field.
  String? _teamName;
  String get teamName => _teamName ?? '';
  set teamName(String? val) => _teamName = val;

  bool hasTeamName() => _teamName != null;

  // "event_id" field.
  int? _eventId;
  int get eventId => _eventId ?? 0;
  set eventId(int? val) => _eventId = val;

  void incrementEventId(int amount) => eventId = eventId + amount;

  bool hasEventId() => _eventId != null;

  static UserNotificationsStruct fromMap(Map<String, dynamic> data) =>
      UserNotificationsStruct(
        id: castToType<int>(data['id']),
        createdAt: data['created_at'] as String?,
        appTitle: data['app_title'] as String?,
        appBody: data['app_body'] as String?,
        isRead: data['is_read'] as bool?,
        timeLabel: data['time_label'] as String?,
        teamName: data['team_name'] as String?,
        eventId: castToType<int>(data['event_id']),
      );

  static UserNotificationsStruct? maybeFromMap(dynamic data) => data is Map
      ? UserNotificationsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'created_at': _createdAt,
        'app_title': _appTitle,
        'app_body': _appBody,
        'is_read': _isRead,
        'time_label': _timeLabel,
        'team_name': _teamName,
        'event_id': _eventId,
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
        'app_title': serializeParam(
          _appTitle,
          ParamType.String,
        ),
        'app_body': serializeParam(
          _appBody,
          ParamType.String,
        ),
        'is_read': serializeParam(
          _isRead,
          ParamType.bool,
        ),
        'time_label': serializeParam(
          _timeLabel,
          ParamType.String,
        ),
        'team_name': serializeParam(
          _teamName,
          ParamType.String,
        ),
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
      }.withoutNulls;

  static UserNotificationsStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      UserNotificationsStruct(
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
        appTitle: deserializeParam(
          data['app_title'],
          ParamType.String,
          false,
        ),
        appBody: deserializeParam(
          data['app_body'],
          ParamType.String,
          false,
        ),
        isRead: deserializeParam(
          data['is_read'],
          ParamType.bool,
          false,
        ),
        timeLabel: deserializeParam(
          data['time_label'],
          ParamType.String,
          false,
        ),
        teamName: deserializeParam(
          data['team_name'],
          ParamType.String,
          false,
        ),
        eventId: deserializeParam(
          data['event_id'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'UserNotificationsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is UserNotificationsStruct &&
        id == other.id &&
        createdAt == other.createdAt &&
        appTitle == other.appTitle &&
        appBody == other.appBody &&
        isRead == other.isRead &&
        timeLabel == other.timeLabel &&
        teamName == other.teamName &&
        eventId == other.eventId;
  }

  @override
  int get hashCode => const ListEquality().hash(
      [id, createdAt, appTitle, appBody, isRead, timeLabel, teamName, eventId]);
}

UserNotificationsStruct createUserNotificationsStruct({
  int? id,
  String? createdAt,
  String? appTitle,
  String? appBody,
  bool? isRead,
  String? timeLabel,
  String? teamName,
  int? eventId,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserNotificationsStruct(
      id: id,
      createdAt: createdAt,
      appTitle: appTitle,
      appBody: appBody,
      isRead: isRead,
      timeLabel: timeLabel,
      teamName: teamName,
      eventId: eventId,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserNotificationsStruct? updateUserNotificationsStruct(
  UserNotificationsStruct? userNotifications, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userNotifications
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserNotificationsStructData(
  Map<String, dynamic> firestoreData,
  UserNotificationsStruct? userNotifications,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userNotifications == null) {
    return;
  }
  if (userNotifications.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && userNotifications.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userNotificationsData =
      getUserNotificationsFirestoreData(userNotifications, forFieldValue);
  final nestedData =
      userNotificationsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = userNotifications.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserNotificationsFirestoreData(
  UserNotificationsStruct? userNotifications, [
  bool forFieldValue = false,
]) {
  if (userNotifications == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userNotifications.toMap());

  // Add any Firestore field values
  mapToFirestore(userNotifications.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserNotificationsListFirestoreData(
  List<UserNotificationsStruct>? userNotificationss,
) =>
    userNotificationss
        ?.map((e) => getUserNotificationsFirestoreData(e, true))
        .toList() ??
    [];
