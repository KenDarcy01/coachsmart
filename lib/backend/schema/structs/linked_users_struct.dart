// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class LinkedUsersStruct extends FFFirebaseStruct {
  LinkedUsersStruct({
    String? userId,
    String? email,
    String? firstName,
    String? lastName,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _userId = userId,
        _email = email,
        _firstName = firstName,
        _lastName = lastName,
        super(firestoreUtilData);

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  set userId(String? val) => _userId = val;

  bool hasUserId() => _userId != null;

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  set email(String? val) => _email = val;

  bool hasEmail() => _email != null;

  // "first_name" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  set firstName(String? val) => _firstName = val;

  bool hasFirstName() => _firstName != null;

  // "last_name" field.
  String? _lastName;
  String get lastName => _lastName ?? '';
  set lastName(String? val) => _lastName = val;

  bool hasLastName() => _lastName != null;

  static LinkedUsersStruct fromMap(Map<String, dynamic> data) =>
      LinkedUsersStruct(
        userId: data['user_id'] as String?,
        email: data['email'] as String?,
        firstName: data['first_name'] as String?,
        lastName: data['last_name'] as String?,
      );

  static LinkedUsersStruct? maybeFromMap(dynamic data) => data is Map
      ? LinkedUsersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'user_id': _userId,
        'email': _email,
        'first_name': _firstName,
        'last_name': _lastName,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user_id': serializeParam(
          _userId,
          ParamType.String,
        ),
        'email': serializeParam(
          _email,
          ParamType.String,
        ),
        'first_name': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'last_name': serializeParam(
          _lastName,
          ParamType.String,
        ),
      }.withoutNulls;

  static LinkedUsersStruct fromSerializableMap(Map<String, dynamic> data) =>
      LinkedUsersStruct(
        userId: deserializeParam(
          data['user_id'],
          ParamType.String,
          false,
        ),
        email: deserializeParam(
          data['email'],
          ParamType.String,
          false,
        ),
        firstName: deserializeParam(
          data['first_name'],
          ParamType.String,
          false,
        ),
        lastName: deserializeParam(
          data['last_name'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'LinkedUsersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is LinkedUsersStruct &&
        userId == other.userId &&
        email == other.email &&
        firstName == other.firstName &&
        lastName == other.lastName;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([userId, email, firstName, lastName]);
}

LinkedUsersStruct createLinkedUsersStruct({
  String? userId,
  String? email,
  String? firstName,
  String? lastName,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    LinkedUsersStruct(
      userId: userId,
      email: email,
      firstName: firstName,
      lastName: lastName,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

LinkedUsersStruct? updateLinkedUsersStruct(
  LinkedUsersStruct? linkedUsers, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    linkedUsers
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addLinkedUsersStructData(
  Map<String, dynamic> firestoreData,
  LinkedUsersStruct? linkedUsers,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (linkedUsers == null) {
    return;
  }
  if (linkedUsers.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && linkedUsers.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final linkedUsersData =
      getLinkedUsersFirestoreData(linkedUsers, forFieldValue);
  final nestedData =
      linkedUsersData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = linkedUsers.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getLinkedUsersFirestoreData(
  LinkedUsersStruct? linkedUsers, [
  bool forFieldValue = false,
]) {
  if (linkedUsers == null) {
    return {};
  }
  final firestoreData = mapToFirestore(linkedUsers.toMap());

  // Add any Firestore field values
  mapToFirestore(linkedUsers.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getLinkedUsersListFirestoreData(
  List<LinkedUsersStruct>? linkedUserss,
) =>
    linkedUserss?.map((e) => getLinkedUsersFirestoreData(e, true)).toList() ??
    [];
