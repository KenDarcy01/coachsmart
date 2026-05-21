// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MembersStruct extends FFFirebaseStruct {
  MembersStruct({
    String? lastName,
    int? memberId,
    String? firstName,
    String? squadImage,
    int? squadId,
    String? squadName,
    List<SquadCodesStruct>? squadCodes,
    int? squadCodeId,
    String? squadCodeName,
    String? squadCodeImage,
    String? fullName,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _lastName = lastName,
        _memberId = memberId,
        _firstName = firstName,
        _squadImage = squadImage,
        _squadId = squadId,
        _squadName = squadName,
        _squadCodes = squadCodes,
        _squadCodeId = squadCodeId,
        _squadCodeName = squadCodeName,
        _squadCodeImage = squadCodeImage,
        _fullName = fullName,
        super(firestoreUtilData);

  // "last_name" field.
  String? _lastName;
  String get lastName => _lastName ?? '';
  set lastName(String? val) => _lastName = val;

  bool hasLastName() => _lastName != null;

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "first_name" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  set firstName(String? val) => _firstName = val;

  bool hasFirstName() => _firstName != null;

  // "squad_image" field.
  String? _squadImage;
  String get squadImage => _squadImage ?? '';
  set squadImage(String? val) => _squadImage = val;

  bool hasSquadImage() => _squadImage != null;

  // "squad_id" field.
  int? _squadId;
  int get squadId => _squadId ?? 0;
  set squadId(int? val) => _squadId = val;

  void incrementSquadId(int amount) => squadId = squadId + amount;

  bool hasSquadId() => _squadId != null;

  // "squad_name" field.
  String? _squadName;
  String get squadName => _squadName ?? '';
  set squadName(String? val) => _squadName = val;

  bool hasSquadName() => _squadName != null;

  // "squad_codes" field.
  List<SquadCodesStruct>? _squadCodes;
  List<SquadCodesStruct> get squadCodes => _squadCodes ?? const [];
  set squadCodes(List<SquadCodesStruct>? val) => _squadCodes = val;

  void updateSquadCodes(Function(List<SquadCodesStruct>) updateFn) {
    updateFn(_squadCodes ??= []);
  }

  bool hasSquadCodes() => _squadCodes != null;

  // "squad_code_id" field.
  int? _squadCodeId;
  int get squadCodeId => _squadCodeId ?? 0;
  set squadCodeId(int? val) => _squadCodeId = val;

  void incrementSquadCodeId(int amount) => squadCodeId = squadCodeId + amount;

  bool hasSquadCodeId() => _squadCodeId != null;

  // "squad_code_name" field.
  String? _squadCodeName;
  String get squadCodeName => _squadCodeName ?? '';
  set squadCodeName(String? val) => _squadCodeName = val;

  bool hasSquadCodeName() => _squadCodeName != null;

  // "squad_code_image" field.
  String? _squadCodeImage;
  String get squadCodeImage => _squadCodeImage ?? '';
  set squadCodeImage(String? val) => _squadCodeImage = val;

  bool hasSquadCodeImage() => _squadCodeImage != null;

  // "full_name" field.
  String? _fullName;
  String get fullName => _fullName ?? '';
  set fullName(String? val) => _fullName = val;

  bool hasFullName() => _fullName != null;

  static MembersStruct fromMap(Map<String, dynamic> data) => MembersStruct(
        lastName: data['last_name'] as String?,
        memberId: castToType<int>(data['member_id']),
        firstName: data['first_name'] as String?,
        squadImage: data['squad_image'] as String?,
        squadId: castToType<int>(data['squad_id']),
        squadName: data['squad_name'] as String?,
        squadCodes: getStructList(
          data['squad_codes'],
          SquadCodesStruct.fromMap,
        ),
        squadCodeId: castToType<int>(data['squad_code_id']),
        squadCodeName: data['squad_code_name'] as String?,
        squadCodeImage: data['squad_code_image'] as String?,
        fullName: data['full_name'] as String?,
      );

  static MembersStruct? maybeFromMap(dynamic data) =>
      data is Map ? MembersStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'last_name': _lastName,
        'member_id': _memberId,
        'first_name': _firstName,
        'squad_image': _squadImage,
        'squad_id': _squadId,
        'squad_name': _squadName,
        'squad_codes': _squadCodes?.map((e) => e.toMap()).toList(),
        'squad_code_id': _squadCodeId,
        'squad_code_name': _squadCodeName,
        'squad_code_image': _squadCodeImage,
        'full_name': _fullName,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'last_name': serializeParam(
          _lastName,
          ParamType.String,
        ),
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'first_name': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'squad_image': serializeParam(
          _squadImage,
          ParamType.String,
        ),
        'squad_id': serializeParam(
          _squadId,
          ParamType.int,
        ),
        'squad_name': serializeParam(
          _squadName,
          ParamType.String,
        ),
        'squad_codes': serializeParam(
          _squadCodes,
          ParamType.DataStruct,
          isList: true,
        ),
        'squad_code_id': serializeParam(
          _squadCodeId,
          ParamType.int,
        ),
        'squad_code_name': serializeParam(
          _squadCodeName,
          ParamType.String,
        ),
        'squad_code_image': serializeParam(
          _squadCodeImage,
          ParamType.String,
        ),
        'full_name': serializeParam(
          _fullName,
          ParamType.String,
        ),
      }.withoutNulls;

  static MembersStruct fromSerializableMap(Map<String, dynamic> data) =>
      MembersStruct(
        lastName: deserializeParam(
          data['last_name'],
          ParamType.String,
          false,
        ),
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        firstName: deserializeParam(
          data['first_name'],
          ParamType.String,
          false,
        ),
        squadImage: deserializeParam(
          data['squad_image'],
          ParamType.String,
          false,
        ),
        squadId: deserializeParam(
          data['squad_id'],
          ParamType.int,
          false,
        ),
        squadName: deserializeParam(
          data['squad_name'],
          ParamType.String,
          false,
        ),
        squadCodes: deserializeStructParam<SquadCodesStruct>(
          data['squad_codes'],
          ParamType.DataStruct,
          true,
          structBuilder: SquadCodesStruct.fromSerializableMap,
        ),
        squadCodeId: deserializeParam(
          data['squad_code_id'],
          ParamType.int,
          false,
        ),
        squadCodeName: deserializeParam(
          data['squad_code_name'],
          ParamType.String,
          false,
        ),
        squadCodeImage: deserializeParam(
          data['squad_code_image'],
          ParamType.String,
          false,
        ),
        fullName: deserializeParam(
          data['full_name'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'MembersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is MembersStruct &&
        lastName == other.lastName &&
        memberId == other.memberId &&
        firstName == other.firstName &&
        squadImage == other.squadImage &&
        squadId == other.squadId &&
        squadName == other.squadName &&
        listEquality.equals(squadCodes, other.squadCodes) &&
        squadCodeId == other.squadCodeId &&
        squadCodeName == other.squadCodeName &&
        squadCodeImage == other.squadCodeImage &&
        fullName == other.fullName;
  }

  @override
  int get hashCode => const ListEquality().hash([
        lastName,
        memberId,
        firstName,
        squadImage,
        squadId,
        squadName,
        squadCodes,
        squadCodeId,
        squadCodeName,
        squadCodeImage,
        fullName
      ]);
}

MembersStruct createMembersStruct({
  String? lastName,
  int? memberId,
  String? firstName,
  String? squadImage,
  int? squadId,
  String? squadName,
  int? squadCodeId,
  String? squadCodeName,
  String? squadCodeImage,
  String? fullName,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    MembersStruct(
      lastName: lastName,
      memberId: memberId,
      firstName: firstName,
      squadImage: squadImage,
      squadId: squadId,
      squadName: squadName,
      squadCodeId: squadCodeId,
      squadCodeName: squadCodeName,
      squadCodeImage: squadCodeImage,
      fullName: fullName,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

MembersStruct? updateMembersStruct(
  MembersStruct? members, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    members
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addMembersStructData(
  Map<String, dynamic> firestoreData,
  MembersStruct? members,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (members == null) {
    return;
  }
  if (members.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && members.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final membersData = getMembersFirestoreData(members, forFieldValue);
  final nestedData = membersData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = members.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getMembersFirestoreData(
  MembersStruct? members, [
  bool forFieldValue = false,
]) {
  if (members == null) {
    return {};
  }
  final firestoreData = mapToFirestore(members.toMap());

  // Add any Firestore field values
  mapToFirestore(members.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getMembersListFirestoreData(
  List<MembersStruct>? memberss,
) =>
    memberss?.map((e) => getMembersFirestoreData(e, true)).toList() ?? [];
