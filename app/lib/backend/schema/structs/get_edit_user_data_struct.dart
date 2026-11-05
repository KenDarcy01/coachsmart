// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class GetEditUserDataStruct extends FFFirebaseStruct {
  GetEditUserDataStruct({
    UserStruct? user,
    List<ClubsStruct>? clubs,
    List<UserMembersStruct>? userMembers,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _user = user,
        _clubs = clubs,
        _userMembers = userMembers,
        super(firestoreUtilData);

  // "user" field.
  UserStruct? _user;
  UserStruct get user => _user ?? UserStruct();
  set user(UserStruct? val) => _user = val;

  void updateUser(Function(UserStruct) updateFn) {
    updateFn(_user ??= UserStruct());
  }

  bool hasUser() => _user != null;

  // "clubs" field.
  List<ClubsStruct>? _clubs;
  List<ClubsStruct> get clubs => _clubs ?? const [];
  set clubs(List<ClubsStruct>? val) => _clubs = val;

  void updateClubs(Function(List<ClubsStruct>) updateFn) {
    updateFn(_clubs ??= []);
  }

  bool hasClubs() => _clubs != null;

  // "userMembers" field.
  List<UserMembersStruct>? _userMembers;
  List<UserMembersStruct> get userMembers => _userMembers ?? const [];
  set userMembers(List<UserMembersStruct>? val) => _userMembers = val;

  void updateUserMembers(Function(List<UserMembersStruct>) updateFn) {
    updateFn(_userMembers ??= []);
  }

  bool hasUserMembers() => _userMembers != null;

  static GetEditUserDataStruct fromMap(Map<String, dynamic> data) =>
      GetEditUserDataStruct(
        user: data['user'] is UserStruct
            ? data['user']
            : UserStruct.maybeFromMap(data['user']),
        clubs: getStructList(
          data['clubs'],
          ClubsStruct.fromMap,
        ),
        userMembers: getStructList(
          data['userMembers'],
          UserMembersStruct.fromMap,
        ),
      );

  static GetEditUserDataStruct? maybeFromMap(dynamic data) => data is Map
      ? GetEditUserDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'user': _user?.toMap(),
        'clubs': _clubs?.map((e) => e.toMap()).toList(),
        'userMembers': _userMembers?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user': serializeParam(
          _user,
          ParamType.DataStruct,
        ),
        'clubs': serializeParam(
          _clubs,
          ParamType.DataStruct,
          isList: true,
        ),
        'userMembers': serializeParam(
          _userMembers,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static GetEditUserDataStruct fromSerializableMap(Map<String, dynamic> data) =>
      GetEditUserDataStruct(
        user: deserializeStructParam(
          data['user'],
          ParamType.DataStruct,
          false,
          structBuilder: UserStruct.fromSerializableMap,
        ),
        clubs: deserializeStructParam<ClubsStruct>(
          data['clubs'],
          ParamType.DataStruct,
          true,
          structBuilder: ClubsStruct.fromSerializableMap,
        ),
        userMembers: deserializeStructParam<UserMembersStruct>(
          data['userMembers'],
          ParamType.DataStruct,
          true,
          structBuilder: UserMembersStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'GetEditUserDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is GetEditUserDataStruct &&
        user == other.user &&
        listEquality.equals(clubs, other.clubs) &&
        listEquality.equals(userMembers, other.userMembers);
  }

  @override
  int get hashCode => const ListEquality().hash([user, clubs, userMembers]);
}

GetEditUserDataStruct createGetEditUserDataStruct({
  UserStruct? user,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    GetEditUserDataStruct(
      user: user ?? (clearUnsetFields ? UserStruct() : null),
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

GetEditUserDataStruct? updateGetEditUserDataStruct(
  GetEditUserDataStruct? getEditUserData, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    getEditUserData
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addGetEditUserDataStructData(
  Map<String, dynamic> firestoreData,
  GetEditUserDataStruct? getEditUserData,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (getEditUserData == null) {
    return;
  }
  if (getEditUserData.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && getEditUserData.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final getEditUserDataData =
      getGetEditUserDataFirestoreData(getEditUserData, forFieldValue);
  final nestedData =
      getEditUserDataData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = getEditUserData.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getGetEditUserDataFirestoreData(
  GetEditUserDataStruct? getEditUserData, [
  bool forFieldValue = false,
]) {
  if (getEditUserData == null) {
    return {};
  }
  final firestoreData = mapToFirestore(getEditUserData.toMap());

  // Handle nested data for "user" field.
  addUserStructData(
    firestoreData,
    getEditUserData.hasUser() ? getEditUserData.user : null,
    'user',
    forFieldValue,
  );

  // Add any Firestore field values
  mapToFirestore(getEditUserData.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getGetEditUserDataListFirestoreData(
  List<GetEditUserDataStruct>? getEditUserDatas,
) =>
    getEditUserDatas
        ?.map((e) => getGetEditUserDataFirestoreData(e, true))
        .toList() ??
    [];
