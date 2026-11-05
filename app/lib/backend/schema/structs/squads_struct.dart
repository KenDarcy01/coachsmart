// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class SquadsStruct extends FFFirebaseStruct {
  SquadsStruct({
    int? id,
    String? name,
    String? image,
    int? squadListSeq,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _id = id,
        _name = name,
        _image = image,
        _squadListSeq = squadListSeq,
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

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  set image(String? val) => _image = val;

  bool hasImage() => _image != null;

  // "squad_list_seq" field.
  int? _squadListSeq;
  int get squadListSeq => _squadListSeq ?? 0;
  set squadListSeq(int? val) => _squadListSeq = val;

  void incrementSquadListSeq(int amount) =>
      squadListSeq = squadListSeq + amount;

  bool hasSquadListSeq() => _squadListSeq != null;

  static SquadsStruct fromMap(Map<String, dynamic> data) => SquadsStruct(
        id: castToType<int>(data['id']),
        name: data['name'] as String?,
        image: data['image'] as String?,
        squadListSeq: castToType<int>(data['squad_list_seq']),
      );

  static SquadsStruct? maybeFromMap(dynamic data) =>
      data is Map ? SquadsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'name': _name,
        'image': _image,
        'squad_list_seq': _squadListSeq,
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
        'image': serializeParam(
          _image,
          ParamType.String,
        ),
        'squad_list_seq': serializeParam(
          _squadListSeq,
          ParamType.int,
        ),
      }.withoutNulls;

  static SquadsStruct fromSerializableMap(Map<String, dynamic> data) =>
      SquadsStruct(
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
        image: deserializeParam(
          data['image'],
          ParamType.String,
          false,
        ),
        squadListSeq: deserializeParam(
          data['squad_list_seq'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'SquadsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is SquadsStruct &&
        id == other.id &&
        name == other.name &&
        image == other.image &&
        squadListSeq == other.squadListSeq;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([id, name, image, squadListSeq]);
}

SquadsStruct createSquadsStruct({
  int? id,
  String? name,
  String? image,
  int? squadListSeq,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    SquadsStruct(
      id: id,
      name: name,
      image: image,
      squadListSeq: squadListSeq,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

SquadsStruct? updateSquadsStruct(
  SquadsStruct? squads, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    squads
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addSquadsStructData(
  Map<String, dynamic> firestoreData,
  SquadsStruct? squads,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (squads == null) {
    return;
  }
  if (squads.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && squads.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final squadsData = getSquadsFirestoreData(squads, forFieldValue);
  final nestedData = squadsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = squads.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getSquadsFirestoreData(
  SquadsStruct? squads, [
  bool forFieldValue = false,
]) {
  if (squads == null) {
    return {};
  }
  final firestoreData = mapToFirestore(squads.toMap());

  // Add any Firestore field values
  mapToFirestore(squads.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getSquadsListFirestoreData(
  List<SquadsStruct>? squadss,
) =>
    squadss?.map((e) => getSquadsFirestoreData(e, true)).toList() ?? [];
