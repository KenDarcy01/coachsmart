// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class ClubCodesStruct extends FFFirebaseStruct {
  ClubCodesStruct({
    int? codeId,
    String? eventCode,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _codeId = codeId,
        _eventCode = eventCode,
        super(firestoreUtilData);

  // "code_id" field.
  int? _codeId;
  int get codeId => _codeId ?? 0;
  set codeId(int? val) => _codeId = val;

  void incrementCodeId(int amount) => codeId = codeId + amount;

  bool hasCodeId() => _codeId != null;

  // "event_code" field.
  String? _eventCode;
  String get eventCode => _eventCode ?? '';
  set eventCode(String? val) => _eventCode = val;

  bool hasEventCode() => _eventCode != null;

  static ClubCodesStruct fromMap(Map<String, dynamic> data) => ClubCodesStruct(
        codeId: castToType<int>(data['code_id']),
        eventCode: data['event_code'] as String?,
      );

  static ClubCodesStruct? maybeFromMap(dynamic data) => data is Map
      ? ClubCodesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'code_id': _codeId,
        'event_code': _eventCode,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'code_id': serializeParam(
          _codeId,
          ParamType.int,
        ),
        'event_code': serializeParam(
          _eventCode,
          ParamType.String,
        ),
      }.withoutNulls;

  static ClubCodesStruct fromSerializableMap(Map<String, dynamic> data) =>
      ClubCodesStruct(
        codeId: deserializeParam(
          data['code_id'],
          ParamType.int,
          false,
        ),
        eventCode: deserializeParam(
          data['event_code'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ClubCodesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ClubCodesStruct &&
        codeId == other.codeId &&
        eventCode == other.eventCode;
  }

  @override
  int get hashCode => const ListEquality().hash([codeId, eventCode]);
}

ClubCodesStruct createClubCodesStruct({
  int? codeId,
  String? eventCode,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ClubCodesStruct(
      codeId: codeId,
      eventCode: eventCode,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ClubCodesStruct? updateClubCodesStruct(
  ClubCodesStruct? clubCodes, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    clubCodes
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addClubCodesStructData(
  Map<String, dynamic> firestoreData,
  ClubCodesStruct? clubCodes,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (clubCodes == null) {
    return;
  }
  if (clubCodes.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && clubCodes.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final clubCodesData = getClubCodesFirestoreData(clubCodes, forFieldValue);
  final nestedData = clubCodesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = clubCodes.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getClubCodesFirestoreData(
  ClubCodesStruct? clubCodes, [
  bool forFieldValue = false,
]) {
  if (clubCodes == null) {
    return {};
  }
  final firestoreData = mapToFirestore(clubCodes.toMap());

  // Add any Firestore field values
  mapToFirestore(clubCodes.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getClubCodesListFirestoreData(
  List<ClubCodesStruct>? clubCodess,
) =>
    clubCodess?.map((e) => getClubCodesFirestoreData(e, true)).toList() ?? [];
