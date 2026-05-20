// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class ClubsStruct extends FFFirebaseStruct {
  ClubsStruct({
    String? crest,
    String? banner,
    String? county,
    int? clubId,
    String? clubName,
    int? sortOrder,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _crest = crest,
        _banner = banner,
        _county = county,
        _clubId = clubId,
        _clubName = clubName,
        _sortOrder = sortOrder,
        super(firestoreUtilData);

  // "crest" field.
  String? _crest;
  String get crest => _crest ?? '';
  set crest(String? val) => _crest = val;

  bool hasCrest() => _crest != null;

  // "banner" field.
  String? _banner;
  String get banner => _banner ?? '';
  set banner(String? val) => _banner = val;

  bool hasBanner() => _banner != null;

  // "county" field.
  String? _county;
  String get county => _county ?? '';
  set county(String? val) => _county = val;

  bool hasCounty() => _county != null;

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

  // "sort_order" field.
  int? _sortOrder;
  int get sortOrder => _sortOrder ?? 0;
  set sortOrder(int? val) => _sortOrder = val;

  void incrementSortOrder(int amount) => sortOrder = sortOrder + amount;

  bool hasSortOrder() => _sortOrder != null;

  static ClubsStruct fromMap(Map<String, dynamic> data) => ClubsStruct(
        crest: data['crest'] as String?,
        banner: data['banner'] as String?,
        county: data['county'] as String?,
        clubId: castToType<int>(data['club_id']),
        clubName: data['club_name'] as String?,
        sortOrder: castToType<int>(data['sort_order']),
      );

  static ClubsStruct? maybeFromMap(dynamic data) =>
      data is Map ? ClubsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'crest': _crest,
        'banner': _banner,
        'county': _county,
        'club_id': _clubId,
        'club_name': _clubName,
        'sort_order': _sortOrder,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'crest': serializeParam(
          _crest,
          ParamType.String,
        ),
        'banner': serializeParam(
          _banner,
          ParamType.String,
        ),
        'county': serializeParam(
          _county,
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
        'sort_order': serializeParam(
          _sortOrder,
          ParamType.int,
        ),
      }.withoutNulls;

  static ClubsStruct fromSerializableMap(Map<String, dynamic> data) =>
      ClubsStruct(
        crest: deserializeParam(
          data['crest'],
          ParamType.String,
          false,
        ),
        banner: deserializeParam(
          data['banner'],
          ParamType.String,
          false,
        ),
        county: deserializeParam(
          data['county'],
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
        sortOrder: deserializeParam(
          data['sort_order'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'ClubsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ClubsStruct &&
        crest == other.crest &&
        banner == other.banner &&
        county == other.county &&
        clubId == other.clubId &&
        clubName == other.clubName &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([crest, banner, county, clubId, clubName, sortOrder]);
}

ClubsStruct createClubsStruct({
  String? crest,
  String? banner,
  String? county,
  int? clubId,
  String? clubName,
  int? sortOrder,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ClubsStruct(
      crest: crest,
      banner: banner,
      county: county,
      clubId: clubId,
      clubName: clubName,
      sortOrder: sortOrder,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ClubsStruct? updateClubsStruct(
  ClubsStruct? clubs, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    clubs
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addClubsStructData(
  Map<String, dynamic> firestoreData,
  ClubsStruct? clubs,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (clubs == null) {
    return;
  }
  if (clubs.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && clubs.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final clubsData = getClubsFirestoreData(clubs, forFieldValue);
  final nestedData = clubsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = clubs.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getClubsFirestoreData(
  ClubsStruct? clubs, [
  bool forFieldValue = false,
]) {
  if (clubs == null) {
    return {};
  }
  final firestoreData = mapToFirestore(clubs.toMap());

  // Add any Firestore field values
  mapToFirestore(clubs.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getClubsListFirestoreData(
  List<ClubsStruct>? clubss,
) =>
    clubss?.map((e) => getClubsFirestoreData(e, true)).toList() ?? [];
