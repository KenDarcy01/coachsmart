// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UserEventsHomeStruct extends FFFirebaseStruct {
  UserEventsHomeStruct({
    List<ClubsStruct>? clubs,
    List<EventsStruct>? events,
    String? userId,
    String? lastName,
    String? firstName,
    String? phoneNumber,
    String? emailAddress,
    int? highestRoleLevel,
    bool? userOnboarded,
    int? unreadNotifications,
    List<UserTeamsStruct>? userTeams,
    int? userTeamCount,
    bool? showAdvert,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _clubs = clubs,
        _events = events,
        _userId = userId,
        _lastName = lastName,
        _firstName = firstName,
        _phoneNumber = phoneNumber,
        _emailAddress = emailAddress,
        _highestRoleLevel = highestRoleLevel,
        _userOnboarded = userOnboarded,
        _unreadNotifications = unreadNotifications,
        _userTeams = userTeams,
        _userTeamCount = userTeamCount,
        _showAdvert = showAdvert,
        super(firestoreUtilData);

  // "clubs" field.
  List<ClubsStruct>? _clubs;
  List<ClubsStruct> get clubs => _clubs ?? const [];
  set clubs(List<ClubsStruct>? val) => _clubs = val;

  void updateClubs(Function(List<ClubsStruct>) updateFn) {
    updateFn(_clubs ??= []);
  }

  bool hasClubs() => _clubs != null;

  // "events" field.
  List<EventsStruct>? _events;
  List<EventsStruct> get events => _events ?? const [];
  set events(List<EventsStruct>? val) => _events = val;

  void updateEvents(Function(List<EventsStruct>) updateFn) {
    updateFn(_events ??= []);
  }

  bool hasEvents() => _events != null;

  // "user_id" field.
  String? _userId;
  String get userId => _userId ?? '';
  set userId(String? val) => _userId = val;

  bool hasUserId() => _userId != null;

  // "last_name" field.
  String? _lastName;
  String get lastName => _lastName ?? '';
  set lastName(String? val) => _lastName = val;

  bool hasLastName() => _lastName != null;

  // "first_name" field.
  String? _firstName;
  String get firstName => _firstName ?? '';
  set firstName(String? val) => _firstName = val;

  bool hasFirstName() => _firstName != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  set phoneNumber(String? val) => _phoneNumber = val;

  bool hasPhoneNumber() => _phoneNumber != null;

  // "email_address" field.
  String? _emailAddress;
  String get emailAddress => _emailAddress ?? '';
  set emailAddress(String? val) => _emailAddress = val;

  bool hasEmailAddress() => _emailAddress != null;

  // "highest_role_level" field.
  int? _highestRoleLevel;
  int get highestRoleLevel => _highestRoleLevel ?? 0;
  set highestRoleLevel(int? val) => _highestRoleLevel = val;

  void incrementHighestRoleLevel(int amount) =>
      highestRoleLevel = highestRoleLevel + amount;

  bool hasHighestRoleLevel() => _highestRoleLevel != null;

  // "user_onboarded" field.
  bool? _userOnboarded;
  bool get userOnboarded => _userOnboarded ?? false;
  set userOnboarded(bool? val) => _userOnboarded = val;

  bool hasUserOnboarded() => _userOnboarded != null;

  // "unread_notifications" field.
  int? _unreadNotifications;
  int get unreadNotifications => _unreadNotifications ?? 0;
  set unreadNotifications(int? val) => _unreadNotifications = val;

  void incrementUnreadNotifications(int amount) =>
      unreadNotifications = unreadNotifications + amount;

  bool hasUnreadNotifications() => _unreadNotifications != null;

  // "user_teams" field.
  List<UserTeamsStruct>? _userTeams;
  List<UserTeamsStruct> get userTeams => _userTeams ?? const [];
  set userTeams(List<UserTeamsStruct>? val) => _userTeams = val;

  void updateUserTeams(Function(List<UserTeamsStruct>) updateFn) {
    updateFn(_userTeams ??= []);
  }

  bool hasUserTeams() => _userTeams != null;

  // "user_team_count" field.
  int? _userTeamCount;
  int get userTeamCount => _userTeamCount ?? 0;
  set userTeamCount(int? val) => _userTeamCount = val;

  void incrementUserTeamCount(int amount) =>
      userTeamCount = userTeamCount + amount;

  bool hasUserTeamCount() => _userTeamCount != null;

  // "show_advert" field.
  bool? _showAdvert;
  bool get showAdvert => _showAdvert ?? false;
  set showAdvert(bool? val) => _showAdvert = val;

  bool hasShowAdvert() => _showAdvert != null;

  static UserEventsHomeStruct fromMap(Map<String, dynamic> data) =>
      UserEventsHomeStruct(
        clubs: getStructList(
          data['clubs'],
          ClubsStruct.fromMap,
        ),
        events: getStructList(
          data['events'],
          EventsStruct.fromMap,
        ),
        userId: data['user_id'] as String?,
        lastName: data['last_name'] as String?,
        firstName: data['first_name'] as String?,
        phoneNumber: data['phone_number'] as String?,
        emailAddress: data['email_address'] as String?,
        highestRoleLevel: castToType<int>(data['highest_role_level']),
        userOnboarded: data['user_onboarded'] as bool?,
        unreadNotifications: castToType<int>(data['unread_notifications']),
        userTeams: getStructList(
          data['user_teams'],
          UserTeamsStruct.fromMap,
        ),
        userTeamCount: castToType<int>(data['user_team_count']),
        showAdvert: data['show_advert'] as bool?,
      );

  static UserEventsHomeStruct? maybeFromMap(dynamic data) => data is Map
      ? UserEventsHomeStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'clubs': _clubs?.map((e) => e.toMap()).toList(),
        'events': _events?.map((e) => e.toMap()).toList(),
        'user_id': _userId,
        'last_name': _lastName,
        'first_name': _firstName,
        'phone_number': _phoneNumber,
        'email_address': _emailAddress,
        'highest_role_level': _highestRoleLevel,
        'user_onboarded': _userOnboarded,
        'unread_notifications': _unreadNotifications,
        'user_teams': _userTeams?.map((e) => e.toMap()).toList(),
        'user_team_count': _userTeamCount,
        'show_advert': _showAdvert,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'clubs': serializeParam(
          _clubs,
          ParamType.DataStruct,
          isList: true,
        ),
        'events': serializeParam(
          _events,
          ParamType.DataStruct,
          isList: true,
        ),
        'user_id': serializeParam(
          _userId,
          ParamType.String,
        ),
        'last_name': serializeParam(
          _lastName,
          ParamType.String,
        ),
        'first_name': serializeParam(
          _firstName,
          ParamType.String,
        ),
        'phone_number': serializeParam(
          _phoneNumber,
          ParamType.String,
        ),
        'email_address': serializeParam(
          _emailAddress,
          ParamType.String,
        ),
        'highest_role_level': serializeParam(
          _highestRoleLevel,
          ParamType.int,
        ),
        'user_onboarded': serializeParam(
          _userOnboarded,
          ParamType.bool,
        ),
        'unread_notifications': serializeParam(
          _unreadNotifications,
          ParamType.int,
        ),
        'user_teams': serializeParam(
          _userTeams,
          ParamType.DataStruct,
          isList: true,
        ),
        'user_team_count': serializeParam(
          _userTeamCount,
          ParamType.int,
        ),
        'show_advert': serializeParam(
          _showAdvert,
          ParamType.bool,
        ),
      }.withoutNulls;

  static UserEventsHomeStruct fromSerializableMap(Map<String, dynamic> data) =>
      UserEventsHomeStruct(
        clubs: deserializeStructParam<ClubsStruct>(
          data['clubs'],
          ParamType.DataStruct,
          true,
          structBuilder: ClubsStruct.fromSerializableMap,
        ),
        events: deserializeStructParam<EventsStruct>(
          data['events'],
          ParamType.DataStruct,
          true,
          structBuilder: EventsStruct.fromSerializableMap,
        ),
        userId: deserializeParam(
          data['user_id'],
          ParamType.String,
          false,
        ),
        lastName: deserializeParam(
          data['last_name'],
          ParamType.String,
          false,
        ),
        firstName: deserializeParam(
          data['first_name'],
          ParamType.String,
          false,
        ),
        phoneNumber: deserializeParam(
          data['phone_number'],
          ParamType.String,
          false,
        ),
        emailAddress: deserializeParam(
          data['email_address'],
          ParamType.String,
          false,
        ),
        highestRoleLevel: deserializeParam(
          data['highest_role_level'],
          ParamType.int,
          false,
        ),
        userOnboarded: deserializeParam(
          data['user_onboarded'],
          ParamType.bool,
          false,
        ),
        unreadNotifications: deserializeParam(
          data['unread_notifications'],
          ParamType.int,
          false,
        ),
        userTeams: deserializeStructParam<UserTeamsStruct>(
          data['user_teams'],
          ParamType.DataStruct,
          true,
          structBuilder: UserTeamsStruct.fromSerializableMap,
        ),
        userTeamCount: deserializeParam(
          data['user_team_count'],
          ParamType.int,
          false,
        ),
        showAdvert: deserializeParam(
          data['show_advert'],
          ParamType.bool,
          false,
        ),
      );

  @override
  String toString() => 'UserEventsHomeStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is UserEventsHomeStruct &&
        listEquality.equals(clubs, other.clubs) &&
        listEquality.equals(events, other.events) &&
        userId == other.userId &&
        lastName == other.lastName &&
        firstName == other.firstName &&
        phoneNumber == other.phoneNumber &&
        emailAddress == other.emailAddress &&
        highestRoleLevel == other.highestRoleLevel &&
        userOnboarded == other.userOnboarded &&
        unreadNotifications == other.unreadNotifications &&
        listEquality.equals(userTeams, other.userTeams) &&
        userTeamCount == other.userTeamCount &&
        showAdvert == other.showAdvert;
  }

  @override
  int get hashCode => const ListEquality().hash([
        clubs,
        events,
        userId,
        lastName,
        firstName,
        phoneNumber,
        emailAddress,
        highestRoleLevel,
        userOnboarded,
        unreadNotifications,
        userTeams,
        userTeamCount,
        showAdvert
      ]);
}

UserEventsHomeStruct createUserEventsHomeStruct({
  String? userId,
  String? lastName,
  String? firstName,
  String? phoneNumber,
  String? emailAddress,
  int? highestRoleLevel,
  bool? userOnboarded,
  int? unreadNotifications,
  int? userTeamCount,
  bool? showAdvert,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    UserEventsHomeStruct(
      userId: userId,
      lastName: lastName,
      firstName: firstName,
      phoneNumber: phoneNumber,
      emailAddress: emailAddress,
      highestRoleLevel: highestRoleLevel,
      userOnboarded: userOnboarded,
      unreadNotifications: unreadNotifications,
      userTeamCount: userTeamCount,
      showAdvert: showAdvert,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

UserEventsHomeStruct? updateUserEventsHomeStruct(
  UserEventsHomeStruct? userEventsHome, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    userEventsHome
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addUserEventsHomeStructData(
  Map<String, dynamic> firestoreData,
  UserEventsHomeStruct? userEventsHome,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (userEventsHome == null) {
    return;
  }
  if (userEventsHome.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && userEventsHome.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final userEventsHomeData =
      getUserEventsHomeFirestoreData(userEventsHome, forFieldValue);
  final nestedData =
      userEventsHomeData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = userEventsHome.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getUserEventsHomeFirestoreData(
  UserEventsHomeStruct? userEventsHome, [
  bool forFieldValue = false,
]) {
  if (userEventsHome == null) {
    return {};
  }
  final firestoreData = mapToFirestore(userEventsHome.toMap());

  // Add any Firestore field values
  mapToFirestore(userEventsHome.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getUserEventsHomeListFirestoreData(
  List<UserEventsHomeStruct>? userEventsHomes,
) =>
    userEventsHomes
        ?.map((e) => getUserEventsHomeFirestoreData(e, true))
        .toList() ??
    [];
