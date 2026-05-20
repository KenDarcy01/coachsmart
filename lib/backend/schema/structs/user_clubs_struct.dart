// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class UserClubsStruct extends FFFirebaseStruct {
  UserClubsStruct({
    String? userId,
    String? emailAddress,
    String? userFirstName,
    String? userLastName,
    String? userFullName,
    int? clubId,
    String? clubName,
    String? county,
    String? banner,
    String? crest,
    int? sortOrder,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _userId = userId,
        _emailAddress = emailAddress,
        _userFirstName = userFirstName,
        _userLastName = userLastName,
        _userFullName = userFullName,
        _clubId = clubId,
        _clubName = clubName,
        _county = county,
        _banner = banner,
        _crest = crest,
        _sortOrder = sortOrder,
        super(firestoreUtilData);

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  set userId(String? val) => _userId = val;

  bool hasUserId() => _userId != null;

  // "email_address" field.
  String? _emailAddress;
  String get emailAddress => _emailAddress ?? '';
  set emailAddress(String? val) => _emailAddress = val;

  bool hasEmailAddress() => _emailAddress != null;

  // "user_first_name" field.
  String? _userFirstName;
  String get userFirstName => _userFirstName ?? '';
  set userFirstName(String? val) => _userFirstName = val;

  bool hasUserFirstName() => _userFirstName != null;

  // "user_last_name" field.
  String? _userLastName;
  String get userLastName => _userLastName ?? '';
  set userLastName(String? val) => _userLastName = val;

  bool hasUserLastName() => _userLastName != null;

  // "user_full_name" field.
  String? _userFullName;
  String get userFullName => _userFullName ?? '';
  set userFullName(String? val) => _userFullName = val;

  bool hasUserFullName() => _userFullName != null;

  // "club_id" field.
  int? _clubId;
  int get clubId => _clubId ?? 0;
  set clubId(int? val) => _clubId = val;

  void incrementClubId(int amount) => clubId = clubId + amount;

  bool hasClubId() => _clubId != null;

  // "club_name" field.
  String? _clubName;
  String get clubName => _clubName ?? '';
  set clubName(String? val) => _clubName = val;

  bool hasClubName() => _clubName != null;

  // "county" field.
  String? _county;
  String get county => _county ?? '';
  set county(String? val) => _county = val;

  bool hasCounty() => _county != null;

  // "banner" field.
  String? _banner;
  String get banner => _banner ?? '';
  set banner(String? val) => _banner = val;

  bool hasBanner() => _banner != null;

  // "crest" field.
  String? _crest;
  String get crest => _crest ?? '';
  set crest(String? val) => _crest = val;

  bool hasCrest() => _crest != null;

  // "sort_order" field.
  int? _sortOrder;
  int get sortOrder => _sortOrder ?? 0;
  set sortOrder(int? val) => _sortOrder = val;

  void incrementSortOrder(int amount) => sortOrder = sortOrder + amount;

  bool hasSortOrder() => _sortOrder != null;

  static UserClubsStruct fromMap(Map<String, dynamic> data) => UserClubsStruct(
        userId: data['user_id'] as String?,
        emailAddress: data['email_address'] as String?,
        userFirstName: data['user_first_name'] as String?,
        userLastName: data['user_last_name'] as String?,
        userFullName: data['user_full_name'] as String?,
        clubId: castToType<int>(data['club_id']),
        clubName: data['club_name'] as String?,
        county: data['county'] as String?,
        banner: data['banner'] as String?,
        crest: data['crest'] as String?,
        sortOrder: castToType<int>(data['sort_order']),
      );

  static UserClubsStruct? maybeFromMap(dynamic data) => data is Map
      ? UserClubsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'user_id': _userId,
        'email_address': _emailAddress,
        'user_first_name': _userFirstName,
        'user_last_name': _userLastName,
        'user_full_name': _userFullName,
        'club_id': _clubId,
        'club_name': _clubName,
        'county': _county,
        'banner': _banner,
        'crest': _crest,
        'sort_order': _sortOrder,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user_id': serializeParam(
          _userId,
          ParamType.String,
        ),
        'email_address': serializeParam(
          _emailAddress,
          ParamType.String,
        ),
        'user_first_name': serializeParam(
          _userFirstName,
          ParamType.String,
        ),
        'user_last_name': serializeParam(
          _userLastName,
          ParamType.String,
        ),
        'user_full_name': serializeParam(
          _userFullName,
          ParamType.String,
        ),
        'club_id': serializeParam(
          _clubId,
          ParamType.int,
        ),
        'club_name': serializeParam(
          _clubName,
          ParamType.String,
        ),
        'county': serializeParam(
          _county,
          ParamType.String,
        ),
        'banner': serializeParam(
          _banner,
          ParamType.String,
        ),
        'crest': serializeParam(
          _crest,
          ParamType.String,
        ),
        'sort_order': serializeParam(
          _sortOrder,
          ParamType.int,
        ),
      }.withoutNulls;

  static UserClubsStruct fromSerializableMap(Map<String, dynamic> data) =>
      UserClubsStruct(
        userId: deserializeParam(
          data['user_id'],
          ParamType.String,
          false,
        ),
        emailAddress: deserializeParam(
          data['email_address'],
          ParamType.String,
          false,
        ),
        userFirstName: deserializeParam(
          data['user_first_name'],
          ParamType.String,
          false,
        ),
        userLastName: deserializeParam(
          data['user_last_name'],
          ParamType.String,
          false,
        ),
        userFullName: deserializeParam(
          data['user_full_name'],
          ParamType.String,
          false,
        ),
        clubId: deserializeParam(
          data['club_id'],
          ParamType.int,
          false,
        ),
        clubName: deserializeParam(
          data['club_name'],
          ParamType.String,
          false,
        ),
        county: deserializeParam(
          data['county'],
          ParamType.String,
          false,
        ),
        banner: deserializeParam(
          data['banner'],
          ParamType.String,
          false,
        ),
        crest: deserializeParam(
          data['crest'],
          ParamType.String,
          false,
        ),
        sortOrder: deserializeParam(
          data['sort_order'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'UserClubsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is UserClubsStruct &&
        userId == other.userId &&
        emailAddress == other.emailAddress &&
        userFirstName == other.userFirstName &&
        userLastName == other.userLastName &&
        userFullName == other.userFullName &&
        clubId == other.clubId &&
        clubName == other.clubName &&
        county == other.county &&
        banner == other.banner &&
        crest == other.crest &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => const ListEquality().hash([
        userId,
        emailAddress,
        userFirstName,
        userLastName,
        userFullName,
        clubId,
        clubName,
        county,
        banner,
        crest,
        sortOrder
      ]);
}

UserClubsStruct createUserClubsStruct({
  String? userId,
  String? emailAddress,
  String? userFirstName,
  String? userLastName,
  String? userFullName,
  int? clubId,
  String? clubName,
  String? county,
  String? banner,
  String? crest,
  int? sortOrder,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserClubsStruct(
      userId: userId,
      emailAddress: emailAddress,
      userFirstName: userFirstName,
      userLastName: userLastName,
      userFullName: userFullName,
      clubId: clubId,
      clubName: clubName,
      county: county,
      banner: banner,
      crest: crest,
      sortOrder: sortOrder,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserClubsStruct? updateUserClubsStruct(
  UserClubsStruct? userClubs, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userClubs
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserClubsStructData(
  Map<String, dynamic> firestoreData,
  UserClubsStruct? userClubs,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userClubs == null) {
    return;
  }
  if (userClubs.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && userClubs.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userClubsData = getUserClubsFirestoreData(userClubs, forFieldValue);
  final nestedData = userClubsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = userClubs.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserClubsFirestoreData(
  UserClubsStruct? userClubs, [
  bool forFieldValue = false,
]) {
  if (userClubs == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userClubs.toMap());

  // Add any Firestore field values
  mapToFirestore(userClubs.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserClubsListFirestoreData(
  List<UserClubsStruct>? userClubss,
) =>
    userClubss?.map((e) => getUserClubsFirestoreData(e, true)).toList() ?? [];
