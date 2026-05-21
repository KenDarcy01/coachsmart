// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventAdminDetailStruct extends FFFirebaseStruct {
  EventAdminDetailStruct({
    int? eventId,
    String? eventTitle,
    int? teamId,
    List<RemindersStruct>? reminders,
    bool? notifyAdminsChanges,
    bool? notifyAdminsAll,
    bool? carPooling,
    bool? carPoolingAllowed,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _eventId = eventId,
        _eventTitle = eventTitle,
        _teamId = teamId,
        _reminders = reminders,
        _notifyAdminsChanges = notifyAdminsChanges,
        _notifyAdminsAll = notifyAdminsAll,
        _carPooling = carPooling,
        _carPoolingAllowed = carPoolingAllowed,
        super(firestoreUtilData);

  // "event_id" field.
  int? _eventId;
  int get eventId => _eventId ?? 0;
  set eventId(int? val) => _eventId = val;

  void incrementEventId(int amount) => eventId = eventId + amount;

  bool hasEventId() => _eventId != null;

  // "event_title" field.
  String? _eventTitle;
  String get eventTitle => _eventTitle ?? '';
  set eventTitle(String? val) => _eventTitle = val;

  bool hasEventTitle() => _eventTitle != null;

  // "team_id" field.
  int? _teamId;
  int get teamId => _teamId ?? 0;
  set teamId(int? val) => _teamId = val;

  void incrementTeamId(int amount) => teamId = teamId + amount;

  bool hasTeamId() => _teamId != null;

  // "reminders" field.
  List<RemindersStruct>? _reminders;
  List<RemindersStruct> get reminders => _reminders ?? const [];
  set reminders(List<RemindersStruct>? val) => _reminders = val;

  void updateReminders(Function(List<RemindersStruct>) updateFn) {
    updateFn(_reminders ??= []);
  }

  bool hasReminders() => _reminders != null;

  // "notify_admins_changes" field.
  bool? _notifyAdminsChanges;
  bool get notifyAdminsChanges => _notifyAdminsChanges ?? false;
  set notifyAdminsChanges(bool? val) => _notifyAdminsChanges = val;

  bool hasNotifyAdminsChanges() => _notifyAdminsChanges != null;

  // "notify_admins_all" field.
  bool? _notifyAdminsAll;
  bool get notifyAdminsAll => _notifyAdminsAll ?? false;
  set notifyAdminsAll(bool? val) => _notifyAdminsAll = val;

  bool hasNotifyAdminsAll() => _notifyAdminsAll != null;

  // "car_pooling" field.
  bool? _carPooling;
  bool get carPooling => _carPooling ?? false;
  set carPooling(bool? val) => _carPooling = val;

  bool hasCarPooling() => _carPooling != null;

  // "car_pooling_allowed" field.
  bool? _carPoolingAllowed;
  bool get carPoolingAllowed => _carPoolingAllowed ?? false;
  set carPoolingAllowed(bool? val) => _carPoolingAllowed = val;

  bool hasCarPoolingAllowed() => _carPoolingAllowed != null;

  static EventAdminDetailStruct fromMap(Map<String, dynamic> data) =>
      EventAdminDetailStruct(
        eventId: castToType<int>(data['event_id']),
        eventTitle: data['event_title'] as String?,
        teamId: castToType<int>(data['team_id']),
        reminders: getStructList(
          data['reminders'],
          RemindersStruct.fromMap,
        ),
        notifyAdminsChanges: data['notify_admins_changes'] as bool?,
        notifyAdminsAll: data['notify_admins_all'] as bool?,
        carPooling: data['car_pooling'] as bool?,
        carPoolingAllowed: data['car_pooling_allowed'] as bool?,
      );

  static EventAdminDetailStruct? maybeFromMap(dynamic data) => data is Map
      ? EventAdminDetailStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'event_id': _eventId,
        'event_title': _eventTitle,
        'team_id': _teamId,
        'reminders': _reminders?.map((e) => e.toMap()).toList(),
        'notify_admins_changes': _notifyAdminsChanges,
        'notify_admins_all': _notifyAdminsAll,
        'car_pooling': _carPooling,
        'car_pooling_allowed': _carPoolingAllowed,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'event_id': serializeParam(
          _eventId,
          ParamType.int,
        ),
        'event_title': serializeParam(
          _eventTitle,
          ParamType.String,
        ),
        'team_id': serializeParam(
          _teamId,
          ParamType.int,
        ),
        'reminders': serializeParam(
          _reminders,
          ParamType.DataStruct,
          isList: true,
        ),
        'notify_admins_changes': serializeParam(
          _notifyAdminsChanges,
          ParamType.bool,
        ),
        'notify_admins_all': serializeParam(
          _notifyAdminsAll,
          ParamType.bool,
        ),
        'car_pooling': serializeParam(
          _carPooling,
          ParamType.bool,
        ),
        'car_pooling_allowed': serializeParam(
          _carPoolingAllowed,
          ParamType.bool,
        ),
      }.withoutNulls;

  static EventAdminDetailStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      EventAdminDetailStruct(
        eventId: deserializeParam(
          data['event_id'],
          ParamType.int,
          false,
        ),
        eventTitle: deserializeParam(
          data['event_title'],
          ParamType.String,
          false,
        ),
        teamId: deserializeParam(
          data['team_id'],
          ParamType.int,
          false,
        ),
        reminders: deserializeStructParam<RemindersStruct>(
          data['reminders'],
          ParamType.DataStruct,
          true,
          structBuilder: RemindersStruct.fromSerializableMap,
        ),
        notifyAdminsChanges: deserializeParam(
          data['notify_admins_changes'],
          ParamType.bool,
          false,
        ),
        notifyAdminsAll: deserializeParam(
          data['notify_admins_all'],
          ParamType.bool,
          false,
        ),
        carPooling: deserializeParam(
          data['car_pooling'],
          ParamType.bool,
          false,
        ),
        carPoolingAllowed: deserializeParam(
          data['car_pooling_allowed'],
          ParamType.bool,
          false,
        ),
      );

  @override
  String toString() => 'EventAdminDetailStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is EventAdminDetailStruct &&
        eventId == other.eventId &&
        eventTitle == other.eventTitle &&
        teamId == other.teamId &&
        listEquality.equals(reminders, other.reminders) &&
        notifyAdminsChanges == other.notifyAdminsChanges &&
        notifyAdminsAll == other.notifyAdminsAll &&
        carPooling == other.carPooling &&
        carPoolingAllowed == other.carPoolingAllowed;
  }

  @override
  int get hashCode => const ListEquality().hash([
        eventId,
        eventTitle,
        teamId,
        reminders,
        notifyAdminsChanges,
        notifyAdminsAll,
        carPooling,
        carPoolingAllowed
      ]);
}

EventAdminDetailStruct createEventAdminDetailStruct({
  int? eventId,
  String? eventTitle,
  int? teamId,
  bool? notifyAdminsChanges,
  bool? notifyAdminsAll,
  bool? carPooling,
  bool? carPoolingAllowed,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventAdminDetailStruct(
      eventId: eventId,
      eventTitle: eventTitle,
      teamId: teamId,
      notifyAdminsChanges: notifyAdminsChanges,
      notifyAdminsAll: notifyAdminsAll,
      carPooling: carPooling,
      carPoolingAllowed: carPoolingAllowed,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventAdminDetailStruct? updateEventAdminDetailStruct(
  EventAdminDetailStruct? eventAdminDetail, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventAdminDetail
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventAdminDetailStructData(
  Map<String, dynamic> firestoreData,
  EventAdminDetailStruct? eventAdminDetail,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventAdminDetail == null) {
    return;
  }
  if (eventAdminDetail.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventAdminDetail.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventAdminDetailData =
      getEventAdminDetailFirestoreData(eventAdminDetail, forFieldValue);
  final nestedData =
      eventAdminDetailData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = eventAdminDetail.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventAdminDetailFirestoreData(
  EventAdminDetailStruct? eventAdminDetail, [
  bool forFieldValue = false,
]) {
  if (eventAdminDetail == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventAdminDetail.toMap());

  // Add any Firestore field values
  mapToFirestore(eventAdminDetail.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventAdminDetailListFirestoreData(
  List<EventAdminDetailStruct>? eventAdminDetails,
) =>
    eventAdminDetails
        ?.map((e) => getEventAdminDetailFirestoreData(e, true))
        .toList() ??
    [];
