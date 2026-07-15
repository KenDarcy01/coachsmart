import 'dart:convert';

import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

const _kPrivateApiFunctionName = 'ffPrivateApiCall';

/// Start Google Sheets Group Code

class GoogleSheetsGroup {
  static String getBaseUrl() =>
      'https://sheets.googleapis.com/v4/spreadsheets/';
  static Map<String, String> headers = {};
  static InsertRowCall insertRowCall = InsertRowCall();
}

class InsertRowCall {
  Future<ApiCallResponse> call({
    String? sheetID = '',
    String? accessToken = '',
    String? name = '',
  }) async {
    final baseUrl = GoogleSheetsGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "values": [
    [
      "${escapeStringForJson(name)}"
    ]
  ],
  "majorDimension": "ROWS"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'InsertRow',
      apiUrl:
          '${baseUrl}${sheetID}/values/B1:append?valueInputOption=USER_ENTERED&insertDataOption=INSERT_ROWS',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${accessToken}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// End Google Sheets Group Code

class GetGoogleTokenCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
  }) async {
    final ffApiRequestBody = '''
{"name":"Functions"}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getGoogleToken',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/get-google-token',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CopySheetTemplateCall {
  static Future<ApiCallResponse> call({
    String? yourAccessToken = '',
    String? sheetName = '',
    String? destFolderId = '',
  }) async {
    final ffApiRequestBody = '''
{
  "name": "${escapeStringForJson(sheetName)}",
  "parents": [
    "${escapeStringForJson(destFolderId)}"
  ]
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'copySheetTemplate',
      apiUrl:
          'https://www.googleapis.com/drive/v3/files/19ty8u8ywUScjOuh9bGVKP1tY4RLr_nEG6-FKNOqcSNc/copy',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${yourAccessToken}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SendEmailCall {
  static Future<ApiCallResponse> call({
    String? recipient = '',
    String? subject = '',
    String? body = '',
  }) async {
    final ffApiRequestBody = '''
{
  "to": "${escapeStringForJson(recipient)}",
  "subject": "${escapeStringForJson(subject)}",
  "body": "${escapeStringForJson(body)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'sendEmail',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/send-email',
      callType: ApiCallType.POST,
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SendPushNotificationCall {
  static Future<ApiCallResponse> call({
    String? userId = '',
    String? title = '',
    String? body = '',
  }) async {
    final ffApiRequestBody = '''
{
  "userId": "${escapeStringForJson(userId)}",
  "title": "${escapeStringForJson(title)}",
  "body": "${escapeStringForJson(body)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'sendPushNotification',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/send-push-notification',
      callType: ApiCallType.POST,
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SendEventReminderCall {
  static Future<ApiCallResponse> call({
    String? eventID = '',
    String? supabaseAccessToken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "event_id": "${escapeStringForJson(eventID)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'sendEventReminder',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/event_email_reminder',
      callType: ApiCallType.POST,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ExportEdgeFunctionGoogleSheetCall {
  static Future<ApiCallResponse> call({
    int? eventID,
    String? userEmail = '',
    int? matchSquadId,
  }) async {
    final ffApiRequestBody = '''
{
  "event_id": ${eventID},
  "user_email": "${escapeStringForJson(userEmail)}",
  "match_squad_id": ${matchSquadId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'exportEdgeFunctionGoogleSheet',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/create_google_sheet_squads',
      callType: ApiCallType.POST,
      headers: {
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventAttendanceSummaryCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
    int? pRoleLevel,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_role_level": ${pRoleLevel}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventAttendanceSummary',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_attendance_summary',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserEventTeamMembersResponseCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
    String? pUserId = '',
    String? pRoleGrade = '',
    String? pRoleLevel = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_user_id": "${escapeStringForJson(pUserId)}",
  "p_role_grade": "${escapeStringForJson(pRoleGrade)}",
  "p_role_level": "${escapeStringForJson(pRoleLevel)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserEventTeamMembersResponse',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_event_team_members',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SendMatchReportToAdminsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
    int? pReportId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_report_id": ${pReportId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'send MatchReportToAdmins',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/event_match_report_email',
      callType: ApiCallType.POST,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserEventsHomePageCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    String? userIdParam = '',
  }) async {
    final ffApiRequestBody = '''
{
  "user_id_param": "${escapeStringForJson(userIdParam)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserEventsHomePage',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_events',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventAttendanceSummaryByRoleCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
    int? pRoleGradeFilter,
    int? pRoleLevelFilter,
    int? pRoleLevelExclude,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_role_grade_filter": ${pRoleGradeFilter},
  "p_role_level_filter": ${pRoleLevelFilter},
  "p_role_level_exclude": ${pRoleLevelExclude}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventAttendanceSummaryByRole',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_attendance_summary_by_role',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetAttedanceSummaryByRoleAndSquadCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pEventId,
    int? pRoleGradeFilter,
    int? pRoleLevelFilter,
    int? pRoleLevelExclude,
    int? pResponseId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_role_grade_filter": ${pRoleGradeFilter},
  "p_role_level_filter": ${pRoleLevelFilter},
  "p_role_level_exclude": ${pRoleLevelExclude},
  "p_response_id": ${pResponseId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getAttedanceSummaryByRoleAndSquad',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_attendance_summary_by_role_and_squad',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetAttedanceSummaryByRoleAndSquadvTWOCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pEventId,
    int? pRoleGradeFilter,
    int? pRoleLevelFilter,
    int? pRoleLevelExclude,
    int? pResponseId,
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_role_grade_filter": ${pRoleGradeFilter},
  "p_role_level_filter": ${pRoleLevelFilter},
  "p_role_level_exclude": ${pRoleLevelExclude},
  "p_response_id": ${pResponseId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getAttedanceSummaryByRoleAndSquadvTWO',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_attendance_summary_by_role_and_squad_v2',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventAttendanceByRoleCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
    int? pRoleGradeFilter,
    int? pRoleLevelFilter,
    int? pRoleLevelExclude,
    int? pResponseId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_role_grade_filter": ${pRoleGradeFilter},
  "p_role_level_filter": ${pRoleLevelFilter},
  "p_role_level_exclude": ${pRoleLevelExclude},
  "p_response_id": ${pResponseId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventAttendanceByRole',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_attendance_by_role',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventAttendanceByRoleVTWOCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pEventId,
    int? pRoleGradeFilter,
    int? pRoleLevelFilter,
    int? pRoleLevelExclude,
    int? pResponseId,
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_role_grade_filter": ${pRoleGradeFilter},
  "p_role_level_filter": ${pRoleLevelFilter},
  "p_role_level_exclude": ${pRoleLevelExclude},
  "p_response_id": ${pResponseId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventAttendanceByRoleVTWO',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_attendance_by_role_v2',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserClubsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    String? pUserId = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserClubs',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_clubs',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SendChangeOfAttendanceCall {
  static Future<ApiCallResponse> call({
    int? pEventId,
    int? pMemberId,
    String? pSubject = '',
    String? pBody = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_member_id": ${pMemberId},
  "p_subject": "${escapeStringForJson(pSubject)}",
  "p_body": "${escapeStringForJson(pBody)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'sendChangeOfAttendance',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/send-change-of-attendance',
      callType: ApiCallType.POST,
      headers: {
        'Content-Type': 'application/json',
        'Authorization':
            'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventsListCall {
  static Future<ApiCallResponse> call({
    int? pTeamId,
    int? pCodeId,
    int? pTypeId,
    String? pDateFrom = '',
    String? pDateTo = '',
    String? pOpposition = '',
    String? supabaseAccessToken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_team_id": ${pTeamId},
  "p_code_id": ${pCodeId},
  "p_type_id": ${pTypeId},
  "p_date_from": "${escapeStringForJson(pDateFrom)}",
  "p_date_to": "${escapeStringForJson(pDateTo)}",
  "p_opposition": "${escapeStringForJson(pOpposition)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventsList',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_events_list',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserHomeEventsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? pUserId = '',
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserHomeEvents',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_home_events',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserEventDetailsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pEventId,
    String? pUserId = '',
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserEventDetails',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_event_details',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CreateCheckoutSessionCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? appEventID,
    String? appUserID = '',
    String? productName = '',
    int? amount,
    String? appSuccessUrl = '',
    String? appCancelUrl = '',
  }) async {
    final ffApiRequestBody = '''
{
  "appEventId": ${appEventID},
  "appUserId": "${escapeStringForJson(appUserID)}",
  "appSuccessUrl": "${escapeStringForJson(appSuccessUrl)}",
  "appCancelUrl": "${escapeStringForJson(appCancelUrl)}",
  "productName": "${escapeStringForJson(productName)}",
  "amount": ${amount}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'createCheckoutSession',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/create-checkout-session',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUnrespondedDetailsWrapperCall {
  static Future<ApiCallResponse> call({
    String? supabaseKey = '',
    int? eventId,
    int? pRoleGrade,
    int? pRoleLevel,
  }) async {
    final ffApiRequestBody = '''
{
  "event_id": ${eventId},
  "p_role_grade": ${pRoleGrade},
  "p_role_level": ${pRoleLevel}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUnrespondedDetailsWrapper',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/get_unresponded_details_wrapper',
      callType: ApiCallType.POST,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${supabaseKey}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserMembersEventAttendanceCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
    String? pUserId = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserMembersEventAttendance',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_members_event_attendance',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetCheckoutSessionDetailsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    String? sessionId = '',
  }) async {
    final ffApiRequestBody = '''
{
  "sessionId": "${escapeStringForJson(sessionId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getCheckoutSessionDetails',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/get-checkout-session-details',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventPaymentSummaryCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'getEventPaymentSummary',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_payment_summary',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventPaymentsDetailsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventPaymentsDetails',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_payment_details',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CreateCheckoutSessionVersionTwoCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? appEventID,
    String? appUserID = '',
    String? productName = '',
    int? amount,
    String? appSuccessUrl = '',
    String? appCancelUrl = '',
    List<int>? memberIdsList,
    int? unitPrice,
  }) async {
    final memberIds = _serializeList(memberIdsList);

    final ffApiRequestBody = '''
{
  "appEventId": ${appEventID},
  "appUserId": "${escapeStringForJson(appUserID)}",
  "appSuccessUrl": "${escapeStringForJson(appSuccessUrl)}",
  "appCancelUrl": "${escapeStringForJson(appCancelUrl)}",
  "productName": "${escapeStringForJson(productName)}",
  "amount": ${amount},
  "memberIds": ${memberIds},
  "unitPrice": ${unitPrice}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'createCheckoutSessionVersionTwo',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/create-checkout-session-V2',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventPaymentsDetailsVersionTwoCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventPaymentsDetailsVersionTwo',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_payment_details_v2',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetAcceptedUnpaidMembersCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken = '',
    int? pEventId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getAcceptedUnpaidMembers',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_accepted_unpaid_members',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ExportToCSVCall {
  static Future<ApiCallResponse> call({
    String? supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? eventId,
    int? matchSquadId,
    String? userEmail = '',
  }) async {
    final ffApiRequestBody = '''
{
  "event_id": ${eventId},
  "match_squad_id": ${matchSquadId},
  "user_email": "${escapeStringForJson(userEmail)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'exportToCSV',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/export_to_csv',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseKey}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ExportToXLSCall {
  static Future<ApiCallResponse> call({
    String? supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? eventId,
    int? matchSquadId,
    String? userEmail = '',
  }) async {
    final ffApiRequestBody = '''
{
  "event_id": ${eventId},
  "match_squad_id": ${matchSquadId},
  "user_email": "${escapeStringForJson(userEmail)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'exportToXLS',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/export_to_xls',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseKey}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ExportTeamListXLSCall {
  static Future<ApiCallResponse> call({
    String? supabaseKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pTeamId,
    String? userEmail = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_team_id": ${pTeamId},
  "user_email": "${escapeStringForJson(userEmail)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'exportTeamListXLS',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/functions/v1/export_team_list_xls',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseKey}',
        'Content-Type': 'application/json',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetCarPoolsDetailsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pCarPoolId,
    String? supabaseJWTtoken = '',
    String? pUserId = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_car_pool_id": ${pCarPoolId},
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getCarPoolsDetails',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_full_car_pool_details',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventCarPoolsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pEventId,
    String? pUserId = '',
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventCarPools',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_car_pools',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserNotificationsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? pUserId = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserNotifications',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_notifications',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseAccessToken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserTeamSummaryCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? pUserId = '',
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserTeamSummary',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_team_summary',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetTeamMembersByRoleCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? pUserId = '',
    String? supabaseJWTtoken = '',
    int? pTeamId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_user_id": "${escapeStringForJson(pUserId)}",
  "p_team_id": ${pTeamId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getTeamMembersByRole',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_team_members_by_role',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CreateNewMemberByCodeCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? supabaseJWTtoken = '',
    String? pFirstName = '',
    String? pLastName = '',
    String? pJoiningCode = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_first_name": "${escapeStringForJson(pFirstName)}",
  "p_last_name": "${escapeStringForJson(pLastName)}",
  "p_joining_code": "${escapeStringForJson(pJoiningCode)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'createNewMemberByCode',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/create_new_member_by_code',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventAttendanceDetailsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? supabaseJWTtoken = '',
    int? pEventId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventAttendanceDetails',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_attendance_details',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventContextAndNextCodeCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pEventId,
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventContextAndNextCode',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_context_and_next_code',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserEventCreateDetailCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? pUserId = '',
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserEventCreateDetail',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_event_create_detail',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserEventEditDetailCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? pUserId = '',
    String? supabaseJWTtoken = '',
    int? pEventId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_user_id": "${escapeStringForJson(pUserId)}",
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserEventEditDetail',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_event_edit_detail',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetSingleUserEventCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? pUserId = '',
    String? supabaseJWTtoken = '',
    int? pEventId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_user_id": "${escapeStringForJson(pUserId)}",
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getSingleUserEvent',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_single_user_event',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUpdatedEventCodeCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? supabaseJWTtoken = '',
    int? pEventId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUpdatedEventCode',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_updated_event_code',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetEventAdminDetailsCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? supabaseJWTtoken = '',
    int? pEventId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getEventAdminDetails',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_event_admin_detail',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetUserFavouritesCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? supabaseJWTtoken = '',
  }) async {
    final ffApiRequestBody = '''
{
  
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getUserFavourites',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_user_favourites',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CreateMatchDaySquadFromAttendanceCall {
  static Future<ApiCallResponse> call({
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    String? supabaseJWTtoken = '',
    int? pEventId,
    String? pUserId = '',
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id": ${pEventId},
  "p_user_id": "${escapeStringForJson(pUserId)}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'createMatchDaySquadFromAttendance',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/create_match_squad_from_attendance',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PopulateEventNotificationsCall {
  static Future<ApiCallResponse> call({
    String? supabaseJWTtoken = '',
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pEventIdParam,
    int? pRoleLevel,
    int? pRoleGrade,
  }) async {
    final ffApiRequestBody = '''
{
  "p_event_id_param": ${pEventIdParam},
  "p_role_grade": ${pRoleGrade},
  "p_role_level": ${pRoleLevel}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'populateEventNotifications',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/populate_event_notifications',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GetMemberTeamDetailsCall {
  static Future<ApiCallResponse> call({
    String? supabaseJWTtoken = '',
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pMemberId,
    int? pTeamId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_member_id": ${pMemberId},
  "p_team_id": ${pTeamId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'getMemberTeamDetails',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/get_member_team_details',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class RemoveMemberFromTeamCall {
  static Future<ApiCallResponse> call({
    String? supabaseJWTtoken = '',
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pMemberId,
    int? pTeamId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_member_id": ${pMemberId},
  "p_team_id": ${pTeamId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'removeMemberFromTeam',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/remove_member_from_team',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class NotifyAdminsAttendanceChangeCall {
  static Future<ApiCallResponse> call({
    String? supabaseJWTtoken = '',
    String? supabaseAccessToken =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd5ZnBvcnNiZGZ0dnRha2R2dWt0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzMjkxMjAsImV4cCI6MjA0ODkwNTEyMH0.tuWJT4RCp3b7JHi6cdDogqgInetBHdTjSxhJQMBy5n4',
    int? pMemberIdParam,
    int? pEventIdParam,
    int? pResponseId,
    int? pAttendanceId,
  }) async {
    final ffApiRequestBody = '''
{
  "p_member_id_param": ${pMemberIdParam},
  "p_event_id_param": ${pEventIdParam},
  "p_response_id": ${pResponseId},
  "p_attendance_id": ${pAttendanceId}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'notifyAdminsAttendanceChange',
      apiUrl:
          'https://gyfporsbdftvtakdvukt.supabase.co/rest/v1/rpc/notify_admins_attendance_change',
      callType: ApiCallType.POST,
      headers: {
        'Authorization': 'Bearer ${supabaseJWTtoken}',
        'apikey': '${supabaseAccessToken}',
      },
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String _toEncodable(dynamic item) {
  if (item is DocumentReference) {
    return item.path;
  }
  return item;
}

String _serializeList(List? list) {
  list ??= <String>[];
  try {
    return json.encode(list, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("List serialization failed. Returning empty list.");
    }
    return '[]';
  }
}

String _serializeJson(dynamic jsonVar, [bool isList = false]) {
  jsonVar ??= (isList ? [] : {});
  try {
    return json.encode(jsonVar, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("Json serialization failed. Returning empty json.");
    }
    return isList ? '[]' : '{}';
  }
}

String? escapeStringForJson(String? input) {
  if (input == null) {
    return null;
  }
  return input
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\t', '\\t');
}
