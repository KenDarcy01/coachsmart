// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class UserFavouritesStruct extends FFFirebaseStruct {
  UserFavouritesStruct({
    int? linkId,
    int? gameId,
    String? gameName,
    String? gameImage,
    String? gameSkill,
    int? sortOrder,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _linkId = linkId,
        _gameId = gameId,
        _gameName = gameName,
        _gameImage = gameImage,
        _gameSkill = gameSkill,
        _sortOrder = sortOrder,
        super(firestoreUtilData);

  // "link_id" field.
  int? _linkId;
  int get linkId => _linkId ?? 0;
  set linkId(int? val) => _linkId = val;

  void incrementLinkId(int amount) => linkId = linkId + amount;

  bool hasLinkId() => _linkId != null;

  // "game_id" field.
  int? _gameId;
  int get gameId => _gameId ?? 0;
  set gameId(int? val) => _gameId = val;

  void incrementGameId(int amount) => gameId = gameId + amount;

  bool hasGameId() => _gameId != null;

  // "game_name" field.
  String? _gameName;
  String get gameName => _gameName ?? '';
  set gameName(String? val) => _gameName = val;

  bool hasGameName() => _gameName != null;

  // "game_image" field.
  String? _gameImage;
  String get gameImage => _gameImage ?? '';
  set gameImage(String? val) => _gameImage = val;

  bool hasGameImage() => _gameImage != null;

  // "game_skill" field.
  String? _gameSkill;
  String get gameSkill => _gameSkill ?? '';
  set gameSkill(String? val) => _gameSkill = val;

  bool hasGameSkill() => _gameSkill != null;

  // "sort_order" field.
  int? _sortOrder;
  int get sortOrder => _sortOrder ?? 0;
  set sortOrder(int? val) => _sortOrder = val;

  void incrementSortOrder(int amount) => sortOrder = sortOrder + amount;

  bool hasSortOrder() => _sortOrder != null;

  static UserFavouritesStruct fromMap(Map<String, dynamic> data) =>
      UserFavouritesStruct(
        linkId: castToType<int>(data['link_id']),
        gameId: castToType<int>(data['game_id']),
        gameName: data['game_name'] as String?,
        gameImage: data['game_image'] as String?,
        gameSkill: data['game_skill'] as String?,
        sortOrder: castToType<int>(data['sort_order']),
      );

  static UserFavouritesStruct? maybeFromMap(dynamic data) => data is Map
      ? UserFavouritesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'link_id': _linkId,
        'game_id': _gameId,
        'game_name': _gameName,
        'game_image': _gameImage,
        'game_skill': _gameSkill,
        'sort_order': _sortOrder,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'link_id': serializeParam(
          _linkId,
          ParamType.int,
        ),
        'game_id': serializeParam(
          _gameId,
          ParamType.int,
        ),
        'game_name': serializeParam(
          _gameName,
          ParamType.String,
        ),
        'game_image': serializeParam(
          _gameImage,
          ParamType.String,
        ),
        'game_skill': serializeParam(
          _gameSkill,
          ParamType.String,
        ),
        'sort_order': serializeParam(
          _sortOrder,
          ParamType.int,
        ),
      }.withoutNulls;

  static UserFavouritesStruct fromSerializableMap(Map<String, dynamic> data) =>
      UserFavouritesStruct(
        linkId: deserializeParam(
          data['link_id'],
          ParamType.int,
          false,
        ),
        gameId: deserializeParam(
          data['game_id'],
          ParamType.int,
          false,
        ),
        gameName: deserializeParam(
          data['game_name'],
          ParamType.String,
          false,
        ),
        gameImage: deserializeParam(
          data['game_image'],
          ParamType.String,
          false,
        ),
        gameSkill: deserializeParam(
          data['game_skill'],
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
  String toString() => 'UserFavouritesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is UserFavouritesStruct &&
        linkId == other.linkId &&
        gameId == other.gameId &&
        gameName == other.gameName &&
        gameImage == other.gameImage &&
        gameSkill == other.gameSkill &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([linkId, gameId, gameName, gameImage, gameSkill, sortOrder]);
}

UserFavouritesStruct createUserFavouritesStruct({
  int? linkId,
  int? gameId,
  String? gameName,
  String? gameImage,
  String? gameSkill,
  int? sortOrder,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserFavouritesStruct(
      linkId: linkId,
      gameId: gameId,
      gameName: gameName,
      gameImage: gameImage,
      gameSkill: gameSkill,
      sortOrder: sortOrder,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserFavouritesStruct? updateUserFavouritesStruct(
  UserFavouritesStruct? userFavourites, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userFavourites
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserFavouritesStructData(
  Map<String, dynamic> firestoreData,
  UserFavouritesStruct? userFavourites,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userFavourites == null) {
    return;
  }
  if (userFavourites.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && userFavourites.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userFavouritesData =
      getUserFavouritesFirestoreData(userFavourites, forFieldValue);
  final nestedData =
      userFavouritesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = userFavourites.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserFavouritesFirestoreData(
  UserFavouritesStruct? userFavourites, [
  bool forFieldValue = false,
]) {
  if (userFavourites == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userFavourites.toMap());

  // Add any Firestore field values
  mapToFirestore(userFavourites.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserFavouritesListFirestoreData(
  List<UserFavouritesStruct>? userFavouritess,
) =>
    userFavouritess
        ?.map((e) => getUserFavouritesFirestoreData(e, true))
        .toList() ??
    [];
