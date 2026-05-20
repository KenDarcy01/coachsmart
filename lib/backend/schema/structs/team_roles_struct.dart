// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class TeamRolesStruct extends FFFirebaseStruct {
  TeamRolesStruct({
    int? id,
    String? name,
    String? namePlural,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _id = id,
        _name = name,
        _namePlural = namePlural,
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

  // "name_plural" field.
  String? _namePlural;
  String get namePlural => _namePlural ?? '';
  set namePlural(String? val) => _namePlural = val;

  bool hasNamePlural() => _namePlural != null;

  static TeamRolesStruct fromMap(Map<String, dynamic> data) => TeamRolesStruct(
        id: castToType<int>(data['id']),
        name: data['name'] as String?,
        namePlural: data['name_plural'] as String?,
      );

  static TeamRolesStruct? maybeFromMap(dynamic data) => data is Map
      ? TeamRolesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'name': _name,
        'name_plural': _namePlural,
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
        'name_plural': serializeParam(
          _namePlural,
          ParamType.String,
        ),
      }.withoutNulls;

  static TeamRolesStruct fromSerializableMap(Map<String, dynamic> data) =>
      TeamRolesStruct(
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
        namePlural: deserializeParam(
          data['name_plural'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'TeamRolesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is TeamRolesStruct &&
        id == other.id &&
        name == other.name &&
        namePlural == other.namePlural;
  }

  @override
  int get hashCode => const ListEquality().hash([id, name, namePlural]);
}

TeamRolesStruct createTeamRolesStruct({
  int? id,
  String? name,
  String? namePlural,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    TeamRolesStruct(
      id: id,
      name: name,
      namePlural: namePlural,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

TeamRolesStruct? updateTeamRolesStruct(
  TeamRolesStruct? teamRoles, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    teamRoles
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addTeamRolesStructData(
  Map<String, dynamic> firestoreData,
  TeamRolesStruct? teamRoles,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (teamRoles == null) {
    return;
  }
  if (teamRoles.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && teamRoles.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final teamRolesData = getTeamRolesFirestoreData(teamRoles, forFieldValue);
  final nestedData = teamRolesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = teamRoles.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getTeamRolesFirestoreData(
  TeamRolesStruct? teamRoles, [
  bool forFieldValue = false,
]) {
  if (teamRoles == null) {
    return {};
  }
  final firestoreData = mapToFirestore(teamRoles.toMap());

  // Add any Firestore field values
  mapToFirestore(teamRoles.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getTeamRolesListFirestoreData(
  List<TeamRolesStruct>? teamRoless,
) =>
    teamRoless?.map((e) => getTeamRolesFirestoreData(e, true)).toList() ?? [];
