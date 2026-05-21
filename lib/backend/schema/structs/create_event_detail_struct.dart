// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CreateEventDetailStruct extends FFFirebaseStruct {
  CreateEventDetailStruct({
    String? userId,
    int? defaultTeamId,
    List<CreateTeamsStruct>? createTeams,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _userId = userId,
        _defaultTeamId = defaultTeamId,
        _createTeams = createTeams,
        super(firestoreUtilData);

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  set userId(String? val) => _userId = val;

  bool hasUserId() => _userId != null;

  // "default_team_id" field.
  int? _defaultTeamId;
  int get defaultTeamId => _defaultTeamId ?? 0;
  set defaultTeamId(int? val) => _defaultTeamId = val;

  void incrementDefaultTeamId(int amount) =>
      defaultTeamId = defaultTeamId + amount;

  bool hasDefaultTeamId() => _defaultTeamId != null;

  // "create_teams" field.
  List<CreateTeamsStruct>? _createTeams;
  List<CreateTeamsStruct> get createTeams => _createTeams ?? const [];
  set createTeams(List<CreateTeamsStruct>? val) => _createTeams = val;

  void updateCreateTeams(Function(List<CreateTeamsStruct>) updateFn) {
    updateFn(_createTeams ??= []);
  }

  bool hasCreateTeams() => _createTeams != null;

  static CreateEventDetailStruct fromMap(Map<String, dynamic> data) =>
      CreateEventDetailStruct(
        userId: data['user_id'] as String?,
        defaultTeamId: castToType<int>(data['default_team_id']),
        createTeams: getStructList(
          data['create_teams'],
          CreateTeamsStruct.fromMap,
        ),
      );

  static CreateEventDetailStruct? maybeFromMap(dynamic data) => data is Map
      ? CreateEventDetailStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'user_id': _userId,
        'default_team_id': _defaultTeamId,
        'create_teams': _createTeams?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user_id': serializeParam(
          _userId,
          ParamType.String,
        ),
        'default_team_id': serializeParam(
          _defaultTeamId,
          ParamType.int,
        ),
        'create_teams': serializeParam(
          _createTeams,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static CreateEventDetailStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      CreateEventDetailStruct(
        userId: deserializeParam(
          data['user_id'],
          ParamType.String,
          false,
        ),
        defaultTeamId: deserializeParam(
          data['default_team_id'],
          ParamType.int,
          false,
        ),
        createTeams: deserializeStructParam<CreateTeamsStruct>(
          data['create_teams'],
          ParamType.DataStruct,
          true,
          structBuilder: CreateTeamsStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'CreateEventDetailStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is CreateEventDetailStruct &&
        userId == other.userId &&
        defaultTeamId == other.defaultTeamId &&
        listEquality.equals(createTeams, other.createTeams);
  }

  @override
  int get hashCode =>
      const ListEquality().hash([userId, defaultTeamId, createTeams]);
}

CreateEventDetailStruct createCreateEventDetailStruct({
  String? userId,
  int? defaultTeamId,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CreateEventDetailStruct(
      userId: userId,
      defaultTeamId: defaultTeamId,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CreateEventDetailStruct? updateCreateEventDetailStruct(
  CreateEventDetailStruct? createEventDetail, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    createEventDetail
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCreateEventDetailStructData(
  Map<String, dynamic> firestoreData,
  CreateEventDetailStruct? createEventDetail,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (createEventDetail == null) {
    return;
  }
  if (createEventDetail.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && createEventDetail.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final createEventDetailData =
      getCreateEventDetailFirestoreData(createEventDetail, forFieldValue);
  final nestedData =
      createEventDetailData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = createEventDetail.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCreateEventDetailFirestoreData(
  CreateEventDetailStruct? createEventDetail, [
  bool forFieldValue = false,
]) {
  if (createEventDetail == null) {
    return {};
  }
  final firestoreData = mapToFirestore(createEventDetail.toMap());

  // Add any Firestore field values
  mapToFirestore(createEventDetail.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCreateEventDetailListFirestoreData(
  List<CreateEventDetailStruct>? createEventDetails,
) =>
    createEventDetails
        ?.map((e) => getCreateEventDetailFirestoreData(e, true))
        .toList() ??
    [];
