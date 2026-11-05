// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class EventMemberDetailsStruct extends FFFirebaseStruct {
  EventMemberDetailsStruct({
    int? memberId,
    String? firstName,
    String? lastName,
    String? profilePic,
    String? responseValue,
    String? responseIcon,
    String? displayValue,
    String? iconLink,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _memberId = memberId,
        _firstName = firstName,
        _lastName = lastName,
        _profilePic = profilePic,
        _responseValue = responseValue,
        _responseIcon = responseIcon,
        _displayValue = displayValue,
        _iconLink = iconLink,
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

  // "profile_pic" field.
  String? _profilePic;
  String get profilePic => _profilePic ?? '';
  set profilePic(String? val) => _profilePic = val;

  bool hasProfilePic() => _profilePic != null;

  // "response_value" field.
  String? _responseValue;
  String get responseValue => _responseValue ?? '';
  set responseValue(String? val) => _responseValue = val;

  bool hasResponseValue() => _responseValue != null;

  // "response_icon" field.
  String? _responseIcon;
  String get responseIcon => _responseIcon ?? '';
  set responseIcon(String? val) => _responseIcon = val;

  bool hasResponseIcon() => _responseIcon != null;

  // "display_value" field.
  String? _displayValue;
  String get displayValue => _displayValue ?? '';
  set displayValue(String? val) => _displayValue = val;

  bool hasDisplayValue() => _displayValue != null;

  // "icon_link" field.
  String? _iconLink;
  String get iconLink => _iconLink ?? '';
  set iconLink(String? val) => _iconLink = val;

  bool hasIconLink() => _iconLink != null;

  static EventMemberDetailsStruct fromMap(Map<String, dynamic> data) =>
      EventMemberDetailsStruct(
        memberId: castToType<int>(data['member_id']),
        firstName: data['first_name'] as String?,
        lastName: data['last_name'] as String?,
        profilePic: data['profile_pic'] as String?,
        responseValue: data['response_value'] as String?,
        responseIcon: data['response_icon'] as String?,
        displayValue: data['display_value'] as String?,
        iconLink: data['icon_link'] as String?,
      );

  static EventMemberDetailsStruct? maybeFromMap(dynamic data) => data is Map
      ? EventMemberDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'member_id': _memberId,
        'first_name': _firstName,
        'last_name': _lastName,
        'profile_pic': _profilePic,
        'response_value': _responseValue,
        'response_icon': _responseIcon,
        'display_value': _displayValue,
        'icon_link': _iconLink,
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
        'profile_pic': serializeParam(
          _profilePic,
          ParamType.String,
        ),
        'response_value': serializeParam(
          _responseValue,
          ParamType.String,
        ),
        'response_icon': serializeParam(
          _responseIcon,
          ParamType.String,
        ),
        'display_value': serializeParam(
          _displayValue,
          ParamType.String,
        ),
        'icon_link': serializeParam(
          _iconLink,
          ParamType.String,
        ),
      }.withoutNulls;

  static EventMemberDetailsStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      EventMemberDetailsStruct(
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
        profilePic: deserializeParam(
          data['profile_pic'],
          ParamType.String,
          false,
        ),
        responseValue: deserializeParam(
          data['response_value'],
          ParamType.String,
          false,
        ),
        responseIcon: deserializeParam(
          data['response_icon'],
          ParamType.String,
          false,
        ),
        displayValue: deserializeParam(
          data['display_value'],
          ParamType.String,
          false,
        ),
        iconLink: deserializeParam(
          data['icon_link'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'EventMemberDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is EventMemberDetailsStruct &&
        memberId == other.memberId &&
        firstName == other.firstName &&
        lastName == other.lastName &&
        profilePic == other.profilePic &&
        responseValue == other.responseValue &&
        responseIcon == other.responseIcon &&
        displayValue == other.displayValue &&
        iconLink == other.iconLink;
  }

  @override
  int get hashCode => const ListEquality().hash([
        memberId,
        firstName,
        lastName,
        profilePic,
        responseValue,
        responseIcon,
        displayValue,
        iconLink
      ]);
}

EventMemberDetailsStruct createEventMemberDetailsStruct({
  int? memberId,
  String? firstName,
  String? lastName,
  String? profilePic,
  String? responseValue,
  String? responseIcon,
  String? displayValue,
  String? iconLink,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EventMemberDetailsStruct(
      memberId: memberId,
      firstName: firstName,
      lastName: lastName,
      profilePic: profilePic,
      responseValue: responseValue,
      responseIcon: responseIcon,
      displayValue: displayValue,
      iconLink: iconLink,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EventMemberDetailsStruct? updateEventMemberDetailsStruct(
  EventMemberDetailsStruct? eventMemberDetails, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    eventMemberDetails
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEventMemberDetailsStructData(
  Map<String, dynamic> firestoreData,
  EventMemberDetailsStruct? eventMemberDetails,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (eventMemberDetails == null) {
    return;
  }
  if (eventMemberDetails.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && eventMemberDetails.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final eventMemberDetailsData =
      getEventMemberDetailsFirestoreData(eventMemberDetails, forFieldValue);
  final nestedData =
      eventMemberDetailsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields =
      eventMemberDetails.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEventMemberDetailsFirestoreData(
  EventMemberDetailsStruct? eventMemberDetails, [
  bool forFieldValue = false,
]) {
  if (eventMemberDetails == null) {
    return {};
  }
  final firestoreData = mapToFirestore(eventMemberDetails.toMap());

  // Add any Firestore field values
  mapToFirestore(eventMemberDetails.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEventMemberDetailsListFirestoreData(
  List<EventMemberDetailsStruct>? eventMemberDetailss,
) =>
    eventMemberDetailss
        ?.map((e) => getEventMemberDetailsFirestoreData(e, true))
        .toList() ??
    [];
