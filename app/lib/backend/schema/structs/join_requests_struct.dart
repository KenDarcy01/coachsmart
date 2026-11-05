// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class JoinRequestsStruct extends FFFirebaseStruct {
  JoinRequestsStruct({
    bool? success,
    List<AccessRequestsStruct>? accessRequests,
    List<AvailableRolesStruct>? availableRoles,
    List<MemberRequestsStruct>? memberRequests,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _success = success,
        _accessRequests = accessRequests,
        _availableRoles = availableRoles,
        _memberRequests = memberRequests,
        super(firestoreUtilData);

  // "success" field.
  bool? _success;
  bool get success => _success ?? false;
  set success(bool? val) => _success = val;

  bool hasSuccess() => _success != null;

  // "access_requests" field.
  List<AccessRequestsStruct>? _accessRequests;
  List<AccessRequestsStruct> get accessRequests => _accessRequests ?? const [];
  set accessRequests(List<AccessRequestsStruct>? val) => _accessRequests = val;

  void updateAccessRequests(Function(List<AccessRequestsStruct>) updateFn) {
    updateFn(_accessRequests ??= []);
  }

  bool hasAccessRequests() => _accessRequests != null;

  // "available_roles" field.
  List<AvailableRolesStruct>? _availableRoles;
  List<AvailableRolesStruct> get availableRoles => _availableRoles ?? const [];
  set availableRoles(List<AvailableRolesStruct>? val) => _availableRoles = val;

  void updateAvailableRoles(Function(List<AvailableRolesStruct>) updateFn) {
    updateFn(_availableRoles ??= []);
  }

  bool hasAvailableRoles() => _availableRoles != null;

  // "member_requests" field.
  List<MemberRequestsStruct>? _memberRequests;
  List<MemberRequestsStruct> get memberRequests => _memberRequests ?? const [];
  set memberRequests(List<MemberRequestsStruct>? val) => _memberRequests = val;

  void updateMemberRequests(Function(List<MemberRequestsStruct>) updateFn) {
    updateFn(_memberRequests ??= []);
  }

  bool hasMemberRequests() => _memberRequests != null;

  static JoinRequestsStruct fromMap(Map<String, dynamic> data) =>
      JoinRequestsStruct(
        success: data['success'] as bool?,
        accessRequests: getStructList(
          data['access_requests'],
          AccessRequestsStruct.fromMap,
        ),
        availableRoles: getStructList(
          data['available_roles'],
          AvailableRolesStruct.fromMap,
        ),
        memberRequests: getStructList(
          data['member_requests'],
          MemberRequestsStruct.fromMap,
        ),
      );

  static JoinRequestsStruct? maybeFromMap(dynamic data) => data is Map
      ? JoinRequestsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'success': _success,
        'access_requests': _accessRequests?.map((e) => e.toMap()).toList(),
        'available_roles': _availableRoles?.map((e) => e.toMap()).toList(),
        'member_requests': _memberRequests?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'success': serializeParam(
          _success,
          ParamType.bool,
        ),
        'access_requests': serializeParam(
          _accessRequests,
          ParamType.DataStruct,
          isList: true,
        ),
        'available_roles': serializeParam(
          _availableRoles,
          ParamType.DataStruct,
          isList: true,
        ),
        'member_requests': serializeParam(
          _memberRequests,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static JoinRequestsStruct fromSerializableMap(Map<String, dynamic> data) =>
      JoinRequestsStruct(
        success: deserializeParam(
          data['success'],
          ParamType.bool,
          false,
        ),
        accessRequests: deserializeStructParam<AccessRequestsStruct>(
          data['access_requests'],
          ParamType.DataStruct,
          true,
          structBuilder: AccessRequestsStruct.fromSerializableMap,
        ),
        availableRoles: deserializeStructParam<AvailableRolesStruct>(
          data['available_roles'],
          ParamType.DataStruct,
          true,
          structBuilder: AvailableRolesStruct.fromSerializableMap,
        ),
        memberRequests: deserializeStructParam<MemberRequestsStruct>(
          data['member_requests'],
          ParamType.DataStruct,
          true,
          structBuilder: MemberRequestsStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'JoinRequestsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is JoinRequestsStruct &&
        success == other.success &&
        listEquality.equals(accessRequests, other.accessRequests) &&
        listEquality.equals(availableRoles, other.availableRoles) &&
        listEquality.equals(memberRequests, other.memberRequests);
  }

  @override
  int get hashCode => const ListEquality()
      .hash([success, accessRequests, availableRoles, memberRequests]);
}

JoinRequestsStruct createJoinRequestsStruct({
  bool? success,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    JoinRequestsStruct(
      success: success,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

JoinRequestsStruct? updateJoinRequestsStruct(
  JoinRequestsStruct? joinRequests, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    joinRequests
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addJoinRequestsStructData(
  Map<String, dynamic> firestoreData,
  JoinRequestsStruct? joinRequests,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (joinRequests == null) {
    return;
  }
  if (joinRequests.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && joinRequests.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final joinRequestsData =
      getJoinRequestsFirestoreData(joinRequests, forFieldValue);
  final nestedData =
      joinRequestsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = joinRequests.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getJoinRequestsFirestoreData(
  JoinRequestsStruct? joinRequests, [
  bool forFieldValue = false,
]) {
  if (joinRequests == null) {
    return {};
  }
  final firestoreData = mapToFirestore(joinRequests.toMap());

  // Add any Firestore field values
  mapToFirestore(joinRequests.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getJoinRequestsListFirestoreData(
  List<JoinRequestsStruct>? joinRequestss,
) =>
    joinRequestss?.map((e) => getJoinRequestsFirestoreData(e, true)).toList() ??
    [];
