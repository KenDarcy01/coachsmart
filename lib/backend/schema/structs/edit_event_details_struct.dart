// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EditEventDetailsStruct extends FFFirebaseStruct {
  EditEventDetailsStruct({
    String? userId,
    List<CreateTeamsStruct>? createTeams,
    CurrentEventStruct? currentEvent,
    String? defaultTeamId,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _userId = userId,
        _createTeams = createTeams,
        _currentEvent = currentEvent,
        _defaultTeamId = defaultTeamId,
        super(firestoreUtilData);

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  set userId(String? val) => _userId = val;

  bool hasUserId() => _userId != null;

  // "create_teams" field.
  List<CreateTeamsStruct>? _createTeams;
  List<CreateTeamsStruct> get createTeams => _createTeams ?? const [];
  set createTeams(List<CreateTeamsStruct>? val) => _createTeams = val;

  void updateCreateTeams(Function(List<CreateTeamsStruct>) updateFn) {
    updateFn(_createTeams ??= []);
  }

  bool hasCreateTeams() => _createTeams != null;

  // "current_event" field.
  CurrentEventStruct? _currentEvent;
  CurrentEventStruct get currentEvent => _currentEvent ?? CurrentEventStruct();
  set currentEvent(CurrentEventStruct? val) => _currentEvent = val;

  void updateCurrentEvent(Function(CurrentEventStruct) updateFn) {
    updateFn(_currentEvent ??= CurrentEventStruct());
  }

  bool hasCurrentEvent() => _currentEvent != null;

  // "default_team_id" field.
  String? _defaultTeamId;
  String get defaultTeamId => _defaultTeamId ?? '';
  set defaultTeamId(String? val) => _defaultTeamId = val;

  bool hasDefaultTeamId() => _defaultTeamId != null;

  static EditEventDetailsStruct fromMap(Map<String, dynamic> data) =>
      EditEventDetailsStruct(
        userId: data['user_id'] as String?,
        createTeams: getStructList(
          data['create_teams'],
          CreateTeamsStruct.fromMap,
        ),
        currentEvent: data['current_event'] is CurrentEventStruct
            ? data['current_event']
            : CurrentEventStruct.maybeFromMap(data['current_event']),
        defaultTeamId: data['default_team_id'] as String?,
      );

  static EditEventDetailsStruct? maybeFromMap(dynamic data) => data is Map
      ? EditEventDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'user_id': _userId,
        'create_teams': _createTeams?.map((e) => e.toMap()).toList(),
        'current_event': _currentEvent?.toMap(),
        'default_team_id': _defaultTeamId,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user_id': serializeParam(
          _userId,
          ParamType.String,
        ),
        'create_teams': serializeParam(
          _createTeams,
          ParamType.DataStruct,
          isList: true,
        ),
        'current_event': serializeParam(
          _currentEvent,
          ParamType.DataStruct,
        ),
        'default_team_id': serializeParam(
          _defaultTeamId,
          ParamType.String,
        ),
      }.withoutNulls;

  static EditEventDetailsStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      EditEventDetailsStruct(
        userId: deserializeParam(
          data['user_id'],
          ParamType.String,
          false,
        ),
        createTeams: deserializeStructParam<CreateTeamsStruct>(
          data['create_teams'],
          ParamType.DataStruct,
          true,
          structBuilder: CreateTeamsStruct.fromSerializableMap,
        ),
        currentEvent: deserializeStructParam(
          data['current_event'],
          ParamType.DataStruct,
          false,
          structBuilder: CurrentEventStruct.fromSerializableMap,
        ),
        defaultTeamId: deserializeParam(
          data['default_team_id'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'EditEventDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is EditEventDetailsStruct &&
        userId == other.userId &&
        listEquality.equals(createTeams, other.createTeams) &&
        currentEvent == other.currentEvent &&
        defaultTeamId == other.defaultTeamId;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([userId, createTeams, currentEvent, defaultTeamId]);
}

EditEventDetailsStruct createEditEventDetailsStruct({
  String? userId,
  CurrentEventStruct? currentEvent,
  String? defaultTeamId,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EditEventDetailsStruct(
      userId: userId,
      currentEvent:
          currentEvent ?? (clearUnsetFields ? CurrentEventStruct() : null),
      defaultTeamId: defaultTeamId,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EditEventDetailsStruct? updateEditEventDetailsStruct(
  EditEventDetailsStruct? editEventDetails, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    editEventDetails
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEditEventDetailsStructData(
  Map<String, dynamic> firestoreData,
  EditEventDetailsStruct? editEventDetails,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (editEventDetails == null) {
    return;
  }
  if (editEventDetails.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && editEventDetails.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final editEventDetailsData =
      getEditEventDetailsFirestoreData(editEventDetails, forFieldValue);
  final nestedData =
      editEventDetailsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = editEventDetails.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEditEventDetailsFirestoreData(
  EditEventDetailsStruct? editEventDetails, [
  bool forFieldValue = false,
]) {
  if (editEventDetails == null) {
    return {};
  }
  final firestoreData = mapToFirestore(editEventDetails.toMap());

  // Handle nested data for "current_event" field.
  addCurrentEventStructData(
    firestoreData,
    editEventDetails.hasCurrentEvent() ? editEventDetails.currentEvent : null,
    'current_event',
    forFieldValue,
  );

  // Add any Firestore field values
  mapToFirestore(editEventDetails.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEditEventDetailsListFirestoreData(
  List<EditEventDetailsStruct>? editEventDetailss,
) =>
    editEventDetailss
        ?.map((e) => getEditEventDetailsFirestoreData(e, true))
        .toList() ??
    [];
