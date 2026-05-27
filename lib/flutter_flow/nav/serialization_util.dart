import 'dart:convert';

import 'package:flutter/material.dart';

import '/backend/backend.dart';

import '/backend/supabase/supabase.dart';

import '../../flutter_flow/place.dart';
import '../../flutter_flow/uploaded_file.dart';

/// SERIALIZATION HELPERS

String dateTimeToString(DateTime dateTime) =>
    '${dateTime.isUtc ? 'u' : 'l'}${dateTime.millisecondsSinceEpoch}';

String dateTimeRangeToString(DateTimeRange dateTimeRange) {
  final start = dateTimeRange.start;
  final end = dateTimeRange.end;
  final startStr = '${start.isUtc ? 'u' : 'l'}${start.millisecondsSinceEpoch}';
  final endStr = '${end.isUtc ? 'u' : 'l'}${end.millisecondsSinceEpoch}';
  return '$startStr|$endStr';
}

String placeToString(FFPlace place) => jsonEncode({
      'latLng': place.latLng.serialize(),
      'name': place.name,
      'address': place.address,
      'city': place.city,
      'state': place.state,
      'country': place.country,
      'zipCode': place.zipCode,
    });

String uploadedFileToString(FFUploadedFile uploadedFile) =>
    uploadedFile.serialize();

const _kDocIdDelimeter = '|';
String _serializeDocumentReference(DocumentReference ref) {
  final docIds = <String>[];
  DocumentReference? currentRef = ref;
  while (currentRef != null) {
    docIds.add(currentRef.id);
    // Get the parent document (catching any errors that arise).
    currentRef = safeGet<DocumentReference?>(() => currentRef?.parent.parent);
  }
  // Reverse the list to get the correct ordering.
  return docIds.reversed.join(_kDocIdDelimeter);
}

String? serializeParam(
  dynamic param,
  ParamType paramType, {
  bool isList = false,
}) {
  try {
    if (param == null) {
      return null;
    }
    if (isList) {
      final serializedValues = (param as Iterable)
          .map((p) => serializeParam(p, paramType, isList: false))
          .where((p) => p != null)
          .map((p) => p!)
          .toList();
      return json.encode(serializedValues);
    }
    String? data;
    switch (paramType) {
      case ParamType.int:
        data = param.toString();
      case ParamType.double:
        data = param.toString();
      case ParamType.String:
        data = param;
      case ParamType.bool:
        data = param ? 'true' : 'false';
      case ParamType.DateTime:
        data = dateTimeToString(param as DateTime);
      case ParamType.DateTimeRange:
        data = dateTimeRangeToString(param as DateTimeRange);
      case ParamType.LatLng:
        data = (param as LatLng).serialize();
      case ParamType.Color:
        data = (param as Color).toCssString();
      case ParamType.FFPlace:
        data = placeToString(param as FFPlace);
      case ParamType.FFUploadedFile:
        data = uploadedFileToString(param as FFUploadedFile);
      case ParamType.JSON:
        data = json.encode(param);
      case ParamType.DocumentReference:
        data = _serializeDocumentReference(param as DocumentReference);
      case ParamType.Document:
        final reference = (param as FirestoreRecord).reference;
        data = _serializeDocumentReference(reference);

      case ParamType.DataStruct:
        data = param is BaseStruct ? param.serialize() : null;

      case ParamType.SupabaseRow:
        return json.encode((param as SupabaseDataRow).data);

      default:
        data = null;
    }
    return data;
  } catch (e) {
    print('Error serializing parameter: $e');
    return null;
  }
}

/// END SERIALIZATION HELPERS

/// DESERIALIZATION HELPERS

DateTime? dateTimeFromString(String? dateTimeStr) {
  if (dateTimeStr == null || dateTimeStr.isEmpty) {
    return null;
  }
  final hasPrefix = dateTimeStr.startsWith('u') || dateTimeStr.startsWith('l');
  final milliseconds = int.tryParse(
    hasPrefix ? dateTimeStr.substring(1) : dateTimeStr,
  );
  return milliseconds != null
      ? DateTime.fromMillisecondsSinceEpoch(
          milliseconds,
          isUtc: hasPrefix ? dateTimeStr.startsWith('u') : false,
        )
      : null;
}

DateTimeRange? dateTimeRangeFromString(String dateTimeRangeStr) {
  final pieces = dateTimeRangeStr.split('|');
  if (pieces.length != 2) {
    return null;
  }
  DateTime? parseDateTime(String value) {
    final hasPrefix = value.startsWith('u') || value.startsWith('l');
    final milliseconds = int.tryParse(hasPrefix ? value.substring(1) : value);
    return milliseconds != null
        ? DateTime.fromMillisecondsSinceEpoch(
            milliseconds,
            isUtc: hasPrefix ? value.startsWith('u') : false,
          )
        : null;
  }

  final start = parseDateTime(pieces.first);
  final end = parseDateTime(pieces.last);
  if (start == null || end == null) {
    return null;
  }
  return DateTimeRange(
    start: start,
    end: end,
  );
}

LatLng? latLngFromString(String? latLngStr) {
  final pieces = latLngStr?.split(',');
  if (pieces == null || pieces.length != 2) {
    return null;
  }
  return LatLng(
    double.parse(pieces.first.trim()),
    double.parse(pieces.last.trim()),
  );
}

FFPlace placeFromString(String placeStr) {
  final serializedData = jsonDecode(placeStr) as Map<String, dynamic>;
  final data = {
    'latLng': serializedData.containsKey('latLng')
        ? latLngFromString(serializedData['latLng'] as String)
        : const LatLng(0.0, 0.0),
    'name': serializedData['name'] ?? '',
    'address': serializedData['address'] ?? '',
    'city': serializedData['city'] ?? '',
    'state': serializedData['state'] ?? '',
    'country': serializedData['country'] ?? '',
    'zipCode': serializedData['zipCode'] ?? '',
  };
  return FFPlace(
    latLng: data['latLng'] as LatLng,
    name: data['name'] as String,
    address: data['address'] as String,
    city: data['city'] as String,
    state: data['state'] as String,
    country: data['country'] as String,
    zipCode: data['zipCode'] as String,
  );
}

FFUploadedFile uploadedFileFromString(String uploadedFileStr) =>
    FFUploadedFile.deserialize(uploadedFileStr);

DocumentReference _deserializeDocumentReference(
  String refStr,
  List<String> collectionNamePath,
) {
  var path = '';
  final docIds = refStr.split(_kDocIdDelimeter);
  for (int i = 0; i < docIds.length && i < collectionNamePath.length; i++) {
    path += '/${collectionNamePath[i]}/${docIds[i]}';
  }
  return FirebaseFirestore.instance.doc(path);
}

enum ParamType {
  int,
  double,
  String,
  bool,
  DateTime,
  DateTimeRange,
  LatLng,
  Color,
  FFPlace,
  FFUploadedFile,
  JSON,

  Document,
  DocumentReference,
  DataStruct,
  SupabaseRow,
}

dynamic deserializeParam<T>(
  String? param,
  ParamType paramType,
  bool isList, {
  List<String>? collectionNamePath,
  StructBuilder<T>? structBuilder,
}) {
  try {
    if (param == null) {
      return null;
    }
    if (isList) {
      final paramValues = json.decode(param);
      if (paramValues is! Iterable || paramValues.isEmpty) {
        return null;
      }
      return paramValues
          .where((p) => p is String)
          .map((p) => p as String)
          .map((p) => deserializeParam<T>(
                p,
                paramType,
                false,
                collectionNamePath: collectionNamePath,
                structBuilder: structBuilder,
              ))
          .where((p) => p != null)
          .map((p) => p! as T)
          .toList();
    }
    switch (paramType) {
      case ParamType.int:
        return int.tryParse(param);
      case ParamType.double:
        return double.tryParse(param);
      case ParamType.String:
        return param;
      case ParamType.bool:
        return param == 'true';
      case ParamType.DateTime:
        return dateTimeFromString(param);
      case ParamType.DateTimeRange:
        return dateTimeRangeFromString(param);
      case ParamType.LatLng:
        return latLngFromString(param);
      case ParamType.Color:
        return fromCssColor(param);
      case ParamType.FFPlace:
        return placeFromString(param);
      case ParamType.FFUploadedFile:
        return uploadedFileFromString(param);
      case ParamType.JSON:
        return json.decode(param);
      case ParamType.DocumentReference:
        return _deserializeDocumentReference(param, collectionNamePath ?? []);

      case ParamType.SupabaseRow:
        final data = json.decode(param) as Map<String, dynamic>;
        switch (T) {
          case LegacyUsersRow:
            return LegacyUsersRow(data);
          case ViewUserClubsRow:
            return ViewUserClubsRow(data);
          case EventResponseTypeRow:
            return EventResponseTypeRow(data);
          case SportRow:
            return SportRow(data);
          case MemberSquadLinkRow:
            return MemberSquadLinkRow(data);
          case ViewMemberEventCountRow:
            return ViewMemberEventCountRow(data);
          case ClubCodeLinkRow:
            return ClubCodeLinkRow(data);
          case ViewUserUniqueMemberTeamEventsRow:
            return ViewUserUniqueMemberTeamEventsRow(data);
          case MatchScoreTypesRow:
            return MatchScoreTypesRow(data);
          case EventCodesRow:
            return EventCodesRow(data);
          case ViewMembersNoResponseRow:
            return ViewMembersNoResponseRow(data);
          case ViewEventAttendanceDetailsRow:
            return ViewEventAttendanceDetailsRow(data);
          case CarPoolDetailRow:
            return CarPoolDetailRow(data);
          case MatchScoresDetailsRow:
            return MatchScoresDetailsRow(data);
          case ViewTeamDetailsRow:
            return ViewTeamDetailsRow(data);
          case MemberTeamLinkRow:
            return MemberTeamLinkRow(data);
          case EventAttendanceRow:
            return EventAttendanceRow(data);
          case ViewMemberResponseListRow:
            return ViewMemberResponseListRow(data);
          case ViewUniqueUserTeamMembersRow:
            return ViewUniqueUserTeamMembersRow(data);
          case MatchSquadDetailsRow:
            return MatchSquadDetailsRow(data);
          case SquadsRow:
            return SquadsRow(data);
          case ViewUserTeamMembersRow:
            return ViewUserTeamMembersRow(data);
          case ViewUserTeamsGradeRow:
            return ViewUserTeamsGradeRow(data);
          case ViewUserTeamMemberSquadRow:
            return ViewUserTeamMemberSquadRow(data);
          case ViewAttendeeDetailsRow:
            return ViewAttendeeDetailsRow(data);
          case ViewLatestMemberEventAttendanceRow:
            return ViewLatestMemberEventAttendanceRow(data);
          case InvitationsRow:
            return InvitationsRow(data);
          case CarPoolRow:
            return CarPoolRow(data);
          case UserMemberLinkRow:
            return UserMemberLinkRow(data);
          case TeamsRow:
            return TeamsRow(data);
          case GameAgesRow:
            return GameAgesRow(data);
          case ViewTeamRolesRow:
            return ViewTeamRolesRow(data);
          case ViewEventAttendanceSummaryRow:
            return ViewEventAttendanceSummaryRow(data);
          case ViewEventRemindersRow:
            return ViewEventRemindersRow(data);
          case ViewTestDataRow:
            return ViewTestDataRow(data);
          case ViewUserHighestRoleRow:
            return ViewUserHighestRoleRow(data);
          case MatchScoresRow:
            return MatchScoresRow(data);
          case RemindersRow:
            return RemindersRow(data);
          case ViewMatchReportsRow:
            return ViewMatchReportsRow(data);
          case ClubsRow:
            return ClubsRow(data);
          case ViewHomepageListviewRow:
            return ViewHomepageListviewRow(data);
          case ViewUserMemberTeamEventsRow:
            return ViewUserMemberTeamEventsRow(data);
          case EventsRow:
            return EventsRow(data);
          case ViewUserTeamsRow:
            return ViewUserTeamsRow(data);
          case GamesRow:
            return GamesRow(data);
          case ViewTeamMembersRow:
            return ViewTeamMembersRow(data);
          case ViewMatchSquadsRow:
            return ViewMatchSquadsRow(data);
          case EventTypesRow:
            return EventTypesRow(data);
          case ViewUserMembersNewRow:
            return ViewUserMembersNewRow(data);
          case UsersRow:
            return UsersRow(data);
          case EventUserPaymentRow:
            return EventUserPaymentRow(data);
          case RolesRow:
            return RolesRow(data);
          case ViewEventSquadSummaryRow:
            return ViewEventSquadSummaryRow(data);
          case ViewUserMembersRow:
            return ViewUserMembersRow(data);
          case MembersRow:
            return MembersRow(data);
          case MatchReportsRow:
            return MatchReportsRow(data);
          case TeamRolesLinkRow:
            return TeamRolesLinkRow(data);
          case ViewUniqueUserTeamsRow:
            return ViewUniqueUserTeamsRow(data);
          case ViewUserTeamHighestRoleRow:
            return ViewUserTeamHighestRoleRow(data);
          case MemberTeamRoleLinkRow:
            return MemberTeamRoleLinkRow(data);
          case NotificationsRow:
            return NotificationsRow(data);
          case ViewGameAgeExpansionRow:
            return ViewGameAgeExpansionRow(data);
          case MatchSquadsRow:
            return MatchSquadsRow(data);
          case EventUserMemberPaymentRow:
            return EventUserMemberPaymentRow(data);
          default:
            return null;
        }

      case ParamType.DataStruct:
        final data = json.decode(param) as Map<String, dynamic>? ?? {};
        return structBuilder != null ? structBuilder(data) : null;

      default:
        return null;
    }
  } catch (e) {
    print('Error deserializing parameter: $e');
    return null;
  }
}

Future<dynamic> Function(String) getDoc(
  List<String> collectionNamePath,
  RecordBuilder recordBuilder,
) {
  return (String ids) => _deserializeDocumentReference(ids, collectionNamePath)
      .get()
      .then((s) => recordBuilder(s));
}

Future<List<T>> Function(String) getDocList<T>(
  List<String> collectionNamePath,
  RecordBuilder<T> recordBuilder,
) {
  return (String idsList) {
    List<String> docIds = [];
    try {
      final ids = json.decode(idsList) as Iterable;
      docIds = ids.where((d) => d is String).map((d) => d as String).toList();
    } catch (_) {}
    return Future.wait(
      docIds.map(
        (ids) => _deserializeDocumentReference(ids, collectionNamePath)
            .get()
            .then((s) => recordBuilder(s)),
      ),
    ).then((docs) => docs.where((d) => d != null).map((d) => d!).toList());
  };
}
