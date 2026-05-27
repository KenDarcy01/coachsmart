// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class EventUserMemberResponseStruct extends FFFirebaseStruct {
  EventUserMemberResponseStruct({
    int? memberId,
    String? firstName,
    String? lastName,
    String? latestResponseValue,
    String? responseCreatedAt,
    bool? isAccepted,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _memberId = memberId,
        _firstName = firstName,
        _lastName = lastName,
        _latestResponseValue = latestResponseValue,
        _responseCreatedAt = responseCreatedAt,
        _isAccepted = isAccepted,
        super(firestoreUtilData);

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

  // "last_name" field.
  String? _lastName;
  String get lastName => _lastName ?? '';
  set lastName(String? val) => _lastName = val;

  bool hasLastName() => _lastName != null;

  // "latest_response_value" field.
  String? _latestResponseValue;
  String get latestResponseValue => _latestResponseValue ?? '';
  set latestResponseValue(String? val) => _latestResponseValue = val;

  bool hasLatestResponseValue() => _latestResponseValue != null;

  // "response_created_at" field.
  String? _responseCreatedAt;
  String get responseCreatedAt => _responseCreatedAt ?? '';
  set responseCreatedAt(String? val) => _responseCreatedAt = val;

  bool hasResponseCreatedAt() => _responseCreatedAt != null;

  // "is_accepted" field.
  bool? _isAccepted;
  bool get isAccepted => _isAccepted ?? false;
  set isAccepted(bool? val) => _isAccepted = val;

  bool hasIsAccepted() => _isAccepted != null;

  static EventUserMemberResponseStruct fromMap(Map<String, dynamic> data) =>
      EventUserMemberResponseStruct(
        memberId: castToType<int>(data['member_id']),
        firstName: data['first_name'] as String?,
        lastName: data['last_name'] as String?,
        latestResponseValue: data['latest_response_value'] as String?,
        responseCreatedAt: data['response_created_at'] as String?,
        isAccepted: data['is_accepted'] as bool?,
      );

  static EventUserMemberResponseStruct? maybeFromMap(dynamic data) =>
      data is Map
          ? EventUserMemberResponseStruct.fromMap(data.cast<String, dynamic>())
          : null;

  Map<String, dynamic> toMap() => {
        'member_id': _memberId,
        'first_name': _firstName,
        'last_name': _lastName,
        'latest_response_value': _latestResponseValue,
        'response_created_at': _responseCreatedAt,
        'is_accepted': _isAccepted,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'member_id': serializeParam(
          _memberId,
          ParamType.int,
        ),
        'first_name': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'last_name': serializeParam(
          _lastName,
          ParamType.String,
        ),
        'latest_response_value': serializeParam(
          _latestResponseValue,
          ParamType.String,
        ),
        'response_created_at': serializeParam(
          _responseCreatedAt,
          ParamType.String,
        ),
        'is_accepted': serializeParam(
          _isAccepted,
          ParamType.bool,
        ),
      }.withoutNulls;

  static EventUserMemberResponseStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      EventUserMemberResponseStruct(
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
        lastName: deserializeParam(
          data['last_name'],
          ParamType.String,
          false,
        ),
        latestResponseValue: deserializeParam(
          data['latest_response_value'],
          ParamType.String,
          false,
        ),
        responseCreatedAt: deserializeParam(
          data['response_created_at'],
          ParamType.String,
          false,
        ),
        isAccepted: deserializeParam(
          data['is_accepted'],
          ParamType.bool,
          false,
        ),
      );

  @override
  String toString() => 'EventUserMemberResponseStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is EventUserMemberResponseStruct &&
        memberId == other.memberId &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        latestResponseValue == other.latestResponseValue &&
        responseCreatedAt == other.responseCreatedAt &&
        isAccepted == other.isAccepted;
  }

  @override
  int get hashCode => const ListEquality().hash([
        memberId,
        firstName,
        lastName,
        latestResponseValue,
        responseCreatedAt,
        isAccepted
      ]);
}

EventUserMemberResponseStruct createEventUserMemberResponseStruct({
  int? memberId,
  String? firstName,
  String? lastName,
  String? latestResponseValue,
  String? responseCreatedAt,
  bool? isAccepted,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventUserMemberResponseStruct(
      memberId: memberId,
      firstName: firstName,
      lastName: lastName,
      latestResponseValue: latestResponseValue,
      responseCreatedAt: responseCreatedAt,
      isAccepted: isAccepted,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventUserMemberResponseStruct? updateEventUserMemberResponseStruct(
  EventUserMemberResponseStruct? eventUserMemberResponse, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventUserMemberResponse
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventUserMemberResponseStructData(
  Map<String, dynamic> firestoreData,
  EventUserMemberResponseStruct? eventUserMemberResponse,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventUserMemberResponse == null) {
    return;
  }
  if (eventUserMemberResponse.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields = !forFieldValue &&
      eventUserMemberResponse.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventUserMemberResponseData = getEventUserMemberResponseFirestoreData(
      eventUserMemberResponse, forFieldValue);
  final nestedData =
      eventUserMemberResponseData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      eventUserMemberResponse.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventUserMemberResponseFirestoreData(
  EventUserMemberResponseStruct? eventUserMemberResponse, [
  bool forFieldValue = false,
]) {
  if (eventUserMemberResponse == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventUserMemberResponse.toMap());

  // Add any Firestore field values
  mapToFirestore(eventUserMemberResponse.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventUserMemberResponseListFirestoreData(
  List<EventUserMemberResponseStruct>? eventUserMemberResponses,
) =>
    eventUserMemberResponses
        ?.map((e) => getEventUserMemberResponseFirestoreData(e, true))
        .toList() ??
    [];
