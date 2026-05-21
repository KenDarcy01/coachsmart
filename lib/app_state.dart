import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {}

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  String _fcmToken = 'noToken';
  String get fcmToken => _fcmToken;
  set fcmToken(String value) {
    _fcmToken = value;
  }

  String _firebaseInstallationId = 'noInstallId';
  String get firebaseInstallationId => _firebaseInstallationId;
  set firebaseInstallationId(String value) {
    _firebaseInstallationId = value;
  }

  UserEventsHomeStruct _homePageEvents =
      UserEventsHomeStruct.fromSerializableMap(jsonDecode(
          '{\"clubs\":\"[]\",\"events\":\"[]\",\"user_onboarded\":\"false\",\"user_teams\":\"[]\"}'));
  UserEventsHomeStruct get homePageEvents => _homePageEvents;
  set homePageEvents(UserEventsHomeStruct value) {
    _homePageEvents = value;
  }

  void updateHomePageEventsStruct(Function(UserEventsHomeStruct) updateFn) {
    updateFn(_homePageEvents);
  }

  bool _showCarPool = false;
  bool get showCarPool => _showCarPool;
  set showCarPool(bool value) {
    _showCarPool = value;
  }

  CarPoolParentStruct _carPoolEventDetails = CarPoolParentStruct();
  CarPoolParentStruct get carPoolEventDetails => _carPoolEventDetails;
  set carPoolEventDetails(CarPoolParentStruct value) {
    _carPoolEventDetails = value;
  }

  void updateCarPoolEventDetailsStruct(Function(CarPoolParentStruct) updateFn) {
    updateFn(_carPoolEventDetails);
  }

  List<UserNotificationsStruct> _userNotifications = [];
  List<UserNotificationsStruct> get userNotifications => _userNotifications;
  set userNotifications(List<UserNotificationsStruct> value) {
    _userNotifications = value;
  }

  void addToUserNotifications(UserNotificationsStruct value) {
    userNotifications.add(value);
  }

  void removeFromUserNotifications(UserNotificationsStruct value) {
    userNotifications.remove(value);
  }

  void removeAtIndexFromUserNotifications(int index) {
    userNotifications.removeAt(index);
  }

  void updateUserNotificationsAtIndex(
    int index,
    UserNotificationsStruct Function(UserNotificationsStruct) updateFn,
  ) {
    userNotifications[index] = updateFn(_userNotifications[index]);
  }

  void insertAtIndexInUserNotifications(
      int index, UserNotificationsStruct value) {
    userNotifications.insert(index, value);
  }

  EditEventDetailsStruct _editEventDetails = EditEventDetailsStruct();
  EditEventDetailsStruct get editEventDetails => _editEventDetails;
  set editEventDetails(EditEventDetailsStruct value) {
    _editEventDetails = value;
  }

  void updateEditEventDetailsStruct(Function(EditEventDetailsStruct) updateFn) {
    updateFn(_editEventDetails);
  }

  UserEventDetailsStruct _userEventDetails = UserEventDetailsStruct();
  UserEventDetailsStruct get userEventDetails => _userEventDetails;
  set userEventDetails(UserEventDetailsStruct value) {
    _userEventDetails = value;
  }

  void updateUserEventDetailsStruct(Function(UserEventDetailsStruct) updateFn) {
    updateFn(_userEventDetails);
  }

  EventAdminDetailStruct _eventAdminDetail = EventAdminDetailStruct();
  EventAdminDetailStruct get eventAdminDetail => _eventAdminDetail;
  set eventAdminDetail(EventAdminDetailStruct value) {
    _eventAdminDetail = value;
  }

  void updateEventAdminDetailStruct(Function(EventAdminDetailStruct) updateFn) {
    updateFn(_eventAdminDetail);
  }

  ListTeamMembersStruct _listTeamMembers = ListTeamMembersStruct();
  ListTeamMembersStruct get listTeamMembers => _listTeamMembers;
  set listTeamMembers(ListTeamMembersStruct value) {
    _listTeamMembers = value;
  }

  void updateListTeamMembersStruct(Function(ListTeamMembersStruct) updateFn) {
    updateFn(_listTeamMembers);
  }
}
