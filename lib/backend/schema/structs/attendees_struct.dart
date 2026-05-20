// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class AttendeesStruct extends FFFirebaseStruct {
  AttendeesStruct({
    String? userId,
    String? fullUserName,
    int? memberId,
    String? fullMemberName,
    int? squadId,
    String? squadName,
    String? squadImage,
    int? squadCodeId,
    String? squadCodeName,
    String? squadCodeImage,
    int? roleId,
    String? roleName,
    int? roleListSeq,
    String? status,
    String? icon,
    String? attendanceDate,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _userId = userId,
        _fullUserName = fullUserName,
        _memberId = memberId,
        _fullMemberName = fullMemberName,
        _squadId = squadId,
        _squadName = squadName,
        _squadImage = squadImage,
        _squadCodeId = squadCodeId,
        _squadCodeName = squadCodeName,
        _squadCodeImage = squadCodeImage,
        _roleId = roleId,
        _roleName = roleName,
        _roleListSeq = roleListSeq,
        _status = status,
        _icon = icon,
        _attendanceDate = attendanceDate,
        super(firestoreUtilData);

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  set userId(String? val) => _userId = val;

  bool hasUserId() => _userId != null;

  // "full_user_name" field.
  String? _fullUserName;
  String get fullUserName => _fullUserName ?? '';
  set fullUserName(String? val) => _fullUserName = val;

  bool hasFullUserName() => _fullUserName != null;

  // "member_id" field.
  int? _memberId;
  int get memberId => _memberId ?? 0;
  set memberId(int? val) => _memberId = val;

  void incrementMemberId(int amount) => memberId = memberId + amount;

  bool hasMemberId() => _memberId != null;

  // "full_member_name" field.
  String? _fullMemberName;
  String get fullMemberName => _fullMemberName ?? '';
  set fullMemberName(String? val) => _fullMemberName = val;

  bool hasFullMemberName() => _fullMemberName != null;

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

  // "squad_image" field.
  String? _squadImage;
  String get squadImage => _squadImage ?? '';
  set squadImage(String? val) => _squadImage = val;

  bool hasSquadImage() => _squadImage != null;

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

  // "role_id" field.
  int? _roleId;
  int get roleId => _roleId ?? 0;
  set roleId(int? val) => _roleId = val;

  void incrementRoleId(int amount) => roleId = roleId + amount;

  bool hasRoleId() => _roleId != null;

  // "role_name" field.
  String? _roleName;
  String get roleName => _roleName ?? '';
  set roleName(String? val) => _roleName = val;

  bool hasRoleName() => _roleName != null;

  // "role_list_seq" field.
  int? _roleListSeq;
  int get roleListSeq => _roleListSeq ?? 0;
  set roleListSeq(int? val) => _roleListSeq = val;

  void incrementRoleListSeq(int amount) => roleListSeq = roleListSeq + amount;

  bool hasRoleListSeq() => _roleListSeq != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  set status(String? val) => _status = val;

  bool hasStatus() => _status != null;

  // "icon" field.
  String? _icon;
  String get icon => _icon ?? '';
  set icon(String? val) => _icon = val;

  bool hasIcon() => _icon != null;

  // "attendance_date" field.
  String? _attendanceDate;
  String get attendanceDate => _attendanceDate ?? '';
  set attendanceDate(String? val) => _attendanceDate = val;

  bool hasAttendanceDate() => _attendanceDate != null;

  static AttendeesStruct fromMap(Map<String, dynamic> data) => AttendeesStruct(
        userId: data['user_id'] as String?,
        fullUserName: data['full_user_name'] as String?,
        memberId: castToType<int>(data['member_id']),
        fullMemberName: data['full_member_name'] as String?,
        squadId: castToType<int>(data['squad_id']),
        squadName: data['squad_name'] as String?,
        squadImage: data['squad_image'] as String?,
        squadCodeId: castToType<int>(data['squad_code_id']),
        squadCodeName: data['squad_code_name'] as String?,
        squadCodeImage: data['squad_code_image'] as String?,
        roleId: castToType<int>(data['role_id']),
        roleName: data['role_name'] as String?,
        roleListSeq: castToType<int>(data['role_list_seq']),
        status: data['status'] as String?,
        icon: data['icon'] as String?,
        attendanceDate: data['attendance_date'] as String?,
      );

  static AttendeesStruct? maybeFromMap(dynamic data) => data is Map
      ? AttendeesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'user_id': _userId,
        'full_user_name': _fullUserName,
        'member_id': _memberId,
        'full_member_name': _fullMemberName,
        'squad_id': _squadId,
        'squad_name': _squadName,
        'squad_image': _squadImage,
        'squad_code_id': _squadCodeId,
        'squad_code_name': _squadCodeName,
        'squad_code_image': _squadCodeImage,
        'role_id': _roleId,
        'role_name': _roleName,
        'role_list_seq': _roleListSeq,
        'status': _status,
        'icon': _icon,
        'attendance_date': _attendanceDate,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user_id': serializeParam(
          _userId,
          ParamType.String,
        ),
        'full_user_name': serializeParam(
          _fullUserName,
          ParamType.String,
        ),
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'full_member_name': serializeParam(
          _fullMemberName,
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
        'squad_image': serializeParam(
          _squadImage,
          ParamType.String,
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
        'role_id': serializeParam(
          _roleId,
          ParamType.int,
        ),
        'role_name': serializeParam(
          _roleName,
          ParamType.String,
        ),
        'role_list_seq': serializeParam(
          _roleListSeq,
          ParamType.int,
        ),
        'status': serializeParam(
          _status,
          ParamType.String,
        ),
        'icon': serializeParam(
          _icon,
          ParamType.String,
        ),
        'attendance_date': serializeParam(
          _attendanceDate,
          ParamType.String,
        ),
      }.withoutNulls;

  static AttendeesStruct fromSerializableMap(Map<String, dynamic> data) =>
      AttendeesStruct(
        userId: deserializeParam(
          data['user_id'],
          ParamType.String,
          false,
        ),
        fullUserName: deserializeParam(
          data['full_user_name'],
          ParamType.String,
          false,
        ),
        memberId: deserializeParam(
          data['member_id'],
          ParamType.int,
          false,
        ),
        fullMemberName: deserializeParam(
          data['full_member_name'],
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
        squadImage: deserializeParam(
          data['squad_image'],
          ParamType.String,
          false,
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
        roleId: deserializeParam(
          data['role_id'],
          ParamType.int,
          false,
        ),
        roleName: deserializeParam(
          data['role_name'],
          ParamType.String,
          false,
        ),
        roleListSeq: deserializeParam(
          data['role_list_seq'],
          ParamType.int,
          false,
        ),
        status: deserializeParam(
          data['status'],
          ParamType.String,
          false,
        ),
        icon: deserializeParam(
          data['icon'],
          ParamType.String,
          false,
        ),
        attendanceDate: deserializeParam(
          data['attendance_date'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'AttendeesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is AttendeesStruct &&
        userId == other.userId &&
        fullUserName == other.fullUserName &&
        memberId == other.memberId &&
        fullMemberName == other.fullMemberName &&
        squadId == other.squadId &&
        squadName == other.squadName &&
        squadImage == other.squadImage &&
        squadCodeId == other.squadCodeId &&
        squadCodeName == other.squadCodeName &&
        squadCodeImage == other.squadCodeImage &&
        roleId == other.roleId &&
        roleName == other.roleName &&
        roleListSeq == other.roleListSeq &&
        status == other.status &&
        icon == other.icon &&
        attendanceDate == other.attendanceDate;
  }

  @override
  int get hashCode => const ListEquality().hash([
        userId,
        fullUserName,
        memberId,
        fullMemberName,
        squadId,
        squadName,
        squadImage,
        squadCodeId,
        squadCodeName,
        squadCodeImage,
        roleId,
        roleName,
        roleListSeq,
        status,
        icon,
        attendanceDate
      ]);
}

AttendeesStruct createAttendeesStruct({
  String? userId,
  String? fullUserName,
  int? memberId,
  String? fullMemberName,
  int? squadId,
  String? squadName,
  String? squadImage,
  int? squadCodeId,
  String? squadCodeName,
  String? squadCodeImage,
  int? roleId,
  String? roleName,
  int? roleListSeq,
  String? status,
  String? icon,
  String? attendanceDate,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    AttendeesStruct(
      userId: userId,
      fullUserName: fullUserName,
      memberId: memberId,
      fullMemberName: fullMemberName,
      squadId: squadId,
      squadName: squadName,
      squadImage: squadImage,
      squadCodeId: squadCodeId,
      squadCodeName: squadCodeName,
      squadCodeImage: squadCodeImage,
      roleId: roleId,
      roleName: roleName,
      roleListSeq: roleListSeq,
      status: status,
      icon: icon,
      attendanceDate: attendanceDate,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

AttendeesStruct? updateAttendeesStruct(
  AttendeesStruct? attendees, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    attendees
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addAttendeesStructData(
  Map<String, dynamic> firestoreData,
  AttendeesStruct? attendees,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (attendees == null) {
    return;
  }
  if (attendees.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && attendees.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final attendeesData = getAttendeesFirestoreData(attendees, forFieldValue);
  final nestedData = attendeesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = attendees.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getAttendeesFirestoreData(
  AttendeesStruct? attendees, [
  bool forFieldValue = false,
]) {
  if (attendees == null) {
    return {};
  }
  final firestoreData = mapToFirestore(attendees.toMap());

  // Add any Firestore field values
  mapToFirestore(attendees.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getAttendeesListFirestoreData(
  List<AttendeesStruct>? attendeess,
) =>
    attendeess?.map((e) => getAttendeesFirestoreData(e, true)).toList() ?? [];
