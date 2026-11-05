// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class SquadCodesStruct extends FFFirebaseStruct {
  SquadCodesStruct({
    int? codeId,
    String? squadName,
    String? squadImage,
    String? codeName,
    int? squadId,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _codeId = codeId,
        _squadName = squadName,
        _squadImage = squadImage,
        _codeName = codeName,
        _squadId = squadId,
        super(firestoreUtilData);

  // "code_id" field.
  int? _codeId;
  int get codeId => _codeId ?? 0;
  set codeId(int? val) => _codeId = val;

  void incrementCodeId(int amount) => codeId = codeId + amount;

  bool hasCodeId() => _codeId != null;

  // "squad_name" field.
  String? _squadName;
  String get squadName => _squadName ?? '';
  set squadName(String? val) => _squadName = val;

  bool hasSquadName() => _squadName != null;

  // "squad_image" field.
  String? _squadImage;
  String get squadImage => _squadImage ?? '';
  set squadImage(String? val) => _squadImage = val;

  bool hasSquadImage() => _squadImage != null;

  // "code_name" field.
  String? _codeName;
  String get codeName => _codeName ?? '';
  set codeName(String? val) => _codeName = val;

  bool hasCodeName() => _codeName != null;

  // "squad_id" field.
  int? _squadId;
  int get squadId => _squadId ?? 0;
  set squadId(int? val) => _squadId = val;

  void incrementSquadId(int amount) => squadId = squadId + amount;

  bool hasSquadId() => _squadId != null;

  static SquadCodesStruct fromMap(Map<String, dynamic> data) =>
      SquadCodesStruct(
        codeId: castToType<int>(data['code_id']),
        squadName: data['squad_name'] as String?,
        squadImage: data['squad_image'] as String?,
        codeName: data['code_name'] as String?,
        squadId: castToType<int>(data['squad_id']),
      );

  static SquadCodesStruct? maybeFromMap(dynamic data) => data is Map
      ? SquadCodesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'code_id': _codeId,
        'squad_name': _squadName,
        'squad_image': _squadImage,
        'code_name': _codeName,
        'squad_id': _squadId,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'code_id': serializeParam(
          _codeId,
          ParamType.int,
        ),
        'squad_name': serializeParam(
          _squadName,
          ParamType.String,
        ),
        'squad_image': serializeParam(
          _squadImage,
          ParamType.String,
        ),
        'code_name': serializeParam(
          _codeName,
          ParamType.String,
        ),
        'squad_id': serializeParam(
          _squadId,
          ParamType.int,
        ),
      }.withoutNulls;

  static SquadCodesStruct fromSerializableMap(Map<String, dynamic> data) =>
      SquadCodesStruct(
        codeId: deserializeParam(
          data['code_id'],
          ParamType.int,
          false,
        ),
        squadName: deserializeParam(
          data['squad_name'],
          ParamType.String,
          false,
        ),
        squadImage: deserializeParam(
          data['squad_image'],
          ParamType.String,
          false,
        ),
        codeName: deserializeParam(
          data['code_name'],
          ParamType.String,
          false,
        ),
        squadId: deserializeParam(
          data['squad_id'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'SquadCodesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is SquadCodesStruct &&
        codeId == other.codeId &&
        squadName == other.squadName &&
        squadImage == other.squadImage &&
        codeName == other.codeName &&
        squadId == other.squadId;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([codeId, squadName, squadImage, codeName, squadId]);
}

SquadCodesStruct createSquadCodesStruct({
  int? codeId,
  String? squadName,
  String? squadImage,
  String? codeName,
  int? squadId,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    SquadCodesStruct(
      codeId: codeId,
      squadName: squadName,
      squadImage: squadImage,
      codeName: codeName,
      squadId: squadId,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

SquadCodesStruct? updateSquadCodesStruct(
  SquadCodesStruct? squadCodes, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    squadCodes
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addSquadCodesStructData(
  Map<String, dynamic> firestoreData,
  SquadCodesStruct? squadCodes,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (squadCodes == null) {
    return;
  }
  if (squadCodes.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && squadCodes.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final squadCodesData = getSquadCodesFirestoreData(squadCodes, forFieldValue);
  final nestedData = squadCodesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = squadCodes.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getSquadCodesFirestoreData(
  SquadCodesStruct? squadCodes, [
  bool forFieldValue = false,
]) {
  if (squadCodes == null) {
    return {};
  }
  final firestoreData = mapToFirestore(squadCodes.toMap());

  // Add any Firestore field values
  mapToFirestore(squadCodes.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getSquadCodesListFirestoreData(
  List<SquadCodesStruct>? squadCodess,
) =>
    squadCodess?.map((e) => getSquadCodesFirestoreData(e, true)).toList() ?? [];
