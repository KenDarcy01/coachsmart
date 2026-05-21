// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ListMembersStruct extends FFFirebaseStruct {
  ListMembersStruct({
    int? squadId,
    int? memberId,
    String? squadName,
    String? memberName,
    String? squadGrade,
    String? squadImage,
    List<SquadCodesStruct>? squadCodes,
    int? squadCodeId,
    String? squadCodeName,
    String? squadCodeImage,
    int? squadListSeq,
    String? sortKey,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _squadId = squadId,
        _memberId = memberId,
        _squadName = squadName,
        _memberName = memberName,
        _squadGrade = squadGrade,
        _squadImage = squadImage,
        _squadCodes = squadCodes,
        _squadCodeId = squadCodeId,
        _squadCodeName = squadCodeName,
        _squadCodeImage = squadCodeImage,
        _squadListSeq = squadListSeq,
        _sortKey = sortKey,
        super(firestoreUtilData);

  // "squad_id" field.
  int? _squadId;
  int get squadId => _squadId ?? 0;
  set squadId(int? val) => _squadId = val;

  void incrementSquadId(int amount) => squadId = squadId + amount;

  bool hasSquadId() => _squadId != null;

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "squad_name" field.
  String? _squadName;
  String get squadName => _squadName ?? '';
  set squadName(String? val) => _squadName = val;

  bool hasSquadName() => _squadName != null;

  // "member_name" field.
  String? _memberName;
  String get memberName => _memberName ?? '';
  set memberName(String? val) => _memberName = val;

  bool hasMemberName() => _memberName != null;

  // "squad_grade" field.
  String? _squadGrade;
  String get squadGrade => _squadGrade ?? '';
  set squadGrade(String? val) => _squadGrade = val;

  bool hasSquadGrade() => _squadGrade != null;

  // "squad_image" field.
  String? _squadImage;
  String get squadImage => _squadImage ?? '';
  set squadImage(String? val) => _squadImage = val;

  bool hasSquadImage() => _squadImage != null;

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

  // "squad_list_seq" field.
  int? _squadListSeq;
  int get squadListSeq => _squadListSeq ?? 0;
  set squadListSeq(int? val) => _squadListSeq = val;

  void incrementSquadListSeq(int amount) =>
      squadListSeq = squadListSeq + amount;

  bool hasSquadListSeq() => _squadListSeq != null;

  // "sort_key" field.
  String? _sortKey;
  String get sortKey => _sortKey ?? '';
  set sortKey(String? val) => _sortKey = val;

  bool hasSortKey() => _sortKey != null;

  static ListMembersStruct fromMap(Map<String, dynamic> data) =>
      ListMembersStruct(
        squadId: castToType<int>(data['squad_id']),
        memberId: castToType<int>(data['member_id']),
        squadName: data['squad_name'] as String?,
        memberName: data['member_name'] as String?,
        squadGrade: data['squad_grade'] as String?,
        squadImage: data['squad_image'] as String?,
        squadCodes: getStructList(
          data['squad_codes'],
          SquadCodesStruct.fromMap,
        ),
        squadCodeId: castToType<int>(data['squad_code_id']),
        squadCodeName: data['squad_code_name'] as String?,
        squadCodeImage: data['squad_code_image'] as String?,
        squadListSeq: castToType<int>(data['squad_list_seq']),
        sortKey: data['sort_key'] as String?,
      );

  static ListMembersStruct? maybeFromMap(dynamic data) => data is Map
      ? ListMembersStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'squad_id': _squadId,
        'member_id': _memberId,
        'squad_name': _squadName,
        'member_name': _memberName,
        'squad_grade': _squadGrade,
        'squad_image': _squadImage,
        'squad_codes': _squadCodes?.map((e) => e.toMap()).toList(),
        'squad_code_id': _squadCodeId,
        'squad_code_name': _squadCodeName,
        'squad_code_image': _squadCodeImage,
        'squad_list_seq': _squadListSeq,
        'sort_key': _sortKey,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'squad_id': serializeParam(
          _squadId,
          ParamType.int,
        ),
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'squad_name': serializeParam(
          _squadName,
          ParamType.String,
        ),
        'member_name': serializeParam(
          _memberName,
          ParamType.String,
        ),
        'squad_grade': serializeParam(
          _squadGrade,
          ParamType.String,
        ),
        'squad_image': serializeParam(
          _squadImage,
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
        'squad_list_seq': serializeParam(
          _squadListSeq,
          ParamType.int,
        ),
        'sort_key': serializeParam(
          _sortKey,
          ParamType.String,
        ),
      }.withoutNulls;

  static ListMembersStruct fromSerializableMap(Map<String, dynamic> data) =>
      ListMembersStruct(
        squadId: deserializeParam(
          data['squad_id'],
          ParamType.int,
          false,
        ),
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        squadName: deserializeParam(
          data['squad_name'],
          ParamType.String,
          false,
        ),
        memberName: deserializeParam(
          data['member_name'],
          ParamType.String,
          false,
        ),
        squadGrade: deserializeParam(
          data['squad_grade'],
          ParamType.String,
          false,
        ),
        squadImage: deserializeParam(
          data['squad_image'],
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
        squadListSeq: deserializeParam(
          data['squad_list_seq'],
          ParamType.int,
          false,
        ),
        sortKey: deserializeParam(
          data['sort_key'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ListMembersStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is ListMembersStruct &&
        squadId == other.squadId &&
        memberId == other.memberId &&
        squadName == other.squadName &&
        memberName == other.memberName &&
        squadGrade == other.squadGrade &&
        squadImage == other.squadImage &&
        listEquality.equals(squadCodes, other.squadCodes) &&
        squadCodeId == other.squadCodeId &&
        squadCodeName == other.squadCodeName &&
        squadCodeImage == other.squadCodeImage &&
        squadListSeq == other.squadListSeq &&
        sortKey == other.sortKey;
  }

  @override
  int get hashCode => const ListEquality().hash([
        squadId,
        memberId,
        squadName,
        memberName,
        squadGrade,
        squadImage,
        squadCodes,
        squadCodeId,
        squadCodeName,
        squadCodeImage,
        squadListSeq,
        sortKey
      ]);
}

ListMembersStruct createListMembersStruct({
  int? squadId,
  int? memberId,
  String? squadName,
  String? memberName,
  String? squadGrade,
  String? squadImage,
  int? squadCodeId,
  String? squadCodeName,
  String? squadCodeImage,
  int? squadListSeq,
  String? sortKey,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ListMembersStruct(
      squadId: squadId,
      memberId: memberId,
      squadName: squadName,
      memberName: memberName,
      squadGrade: squadGrade,
      squadImage: squadImage,
      squadCodeId: squadCodeId,
      squadCodeName: squadCodeName,
      squadCodeImage: squadCodeImage,
      squadListSeq: squadListSeq,
      sortKey: sortKey,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ListMembersStruct? updateListMembersStruct(
  ListMembersStruct? listMembers, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    listMembers
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addListMembersStructData(
  Map<String, dynamic> firestoreData,
  ListMembersStruct? listMembers,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (listMembers == null) {
    return;
  }
  if (listMembers.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && listMembers.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final listMembersData =
      getListMembersFirestoreData(listMembers, forFieldValue);
  final nestedData =
      listMembersData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = listMembers.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getListMembersFirestoreData(
  ListMembersStruct? listMembers, [
  bool forFieldValue = false,
]) {
  if (listMembers == null) {
    return {};
  }
  final firestoreData = mapToFirestore(listMembers.toMap());

  // Add any Firestore field values
  mapToFirestore(listMembers.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getListMembersListFirestoreData(
  List<ListMembersStruct>? listMemberss,
) =>
    listMemberss?.map((e) => getListMembersFirestoreData(e, true)).toList() ??
    [];
