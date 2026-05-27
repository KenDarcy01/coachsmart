// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class CreateMemberStruct extends FFFirebaseStruct {
  CreateMemberStruct({
    String? status,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _status = status,
        super(firestoreUtilData);

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

  bool hasStatus() => _status != null;

  static CreateMemberStruct fromMap(Map<String, dynamic> data) =>
      CreateMemberStruct(
        status: data['status'] as String?,
      );

  static CreateMemberStruct? maybeFromMap(dynamic data) => data is Map
      ? CreateMemberStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'status': _status,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
      }.withoutNulls;

  static CreateMemberStruct fromSerializableMap(Map<String, dynamic> data) =>
      CreateMemberStruct(
        status: deserializeParam(
          data['status'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'CreateMemberStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is CreateMemberStruct && status == other.status;
  }

  @override
  int get hashCode => const ListEquality().hash([status]);
}

CreateMemberStruct createCreateMemberStruct({
  String? status,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CreateMemberStruct(
      status: status,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CreateMemberStruct? updateCreateMemberStruct(
  CreateMemberStruct? createMember, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    createMember
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCreateMemberStructData(
  Map<String, dynamic> firestoreData,
  CreateMemberStruct? createMember,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (createMember == null) {
    return;
  }
  if (createMember.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && createMember.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final createMemberData =
      getCreateMemberFirestoreData(createMember, forFieldValue);
  final nestedData =
      createMemberData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = createMember.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCreateMemberFirestoreData(
  CreateMemberStruct? createMember, [
  bool forFieldValue = false,
]) {
  if (createMember == null) {
    return {};
  }
  final firestoreData = mapToFirestore(createMember.toMap());

  // Add any Firestore field values
  mapToFirestore(createMember.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCreateMemberListFirestoreData(
  List<CreateMemberStruct>? createMembers,
) =>
    createMembers?.map((e) => getCreateMemberFirestoreData(e, true)).toList() ??
    [];
