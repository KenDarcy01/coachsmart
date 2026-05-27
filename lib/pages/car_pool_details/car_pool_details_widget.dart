import '/auth/supabase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'car_pool_details_model.dart';
export 'car_pool_details_model.dart';

class CarPoolDetailsWidget extends StatefulWidget {
  const CarPoolDetailsWidget({
    super.key,
    required this.eventID,
    required this.carPoolId,
    required this.roleLevel,
  });

  final int? eventID;
  final int? carPoolId;
  final int? roleLevel;

  static String routeName = 'CarPoolDetails';
  static String routePath = 'carPoolDetails';

  @override
  State<CarPoolDetailsWidget> createState() => _CarPoolDetailsWidgetState();
}

class _CarPoolDetailsWidgetState extends State<CarPoolDetailsWidget> {
  late CarPoolDetailsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CarPoolDetailsModel());

    logFirebaseEvent('screen_view',
        parameters: {'screen_name': 'CarPoolDetails'});
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ApiCallResponse>(
      future: (_model.apiRequestCompleter ??= Completer<ApiCallResponse>()
            ..complete(GetCarPoolsDetailsCall.call(
              pCarPoolId: widget.carPoolId,
              supabaseJWTtoken: currentJwtToken,
              pUserId: currentUserUid,
            )))
          .future,
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).coachSmartMidBlack,
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    FlutterFlowTheme.of(context).coachSmartGreen,
                  ),
                ),
              ),
            ),
          );
        }
        final carPoolDetailsGetCarPoolsDetailsResponse = snapshot.data!;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).coachSmartMidBlack,
            appBar: AppBar(
              backgroundColor: FlutterFlowTheme.of(context).primaryText,
              automaticallyImplyLeading: false,
              leading: FlutterFlowIconButton(
                borderColor: Colors.transparent,
                borderRadius: 30.0,
                borderWidth: 1.0,
                buttonSize: 60.0,
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF87C232),
                  size: 30.0,
                ),
                onPressed: () async {
                  logFirebaseEvent('CAR_POOL_DETAILS_arrow_back_rounded_ICN_');
                  logFirebaseEvent('IconButton_navigate_back');
                  context.safePop();
                },
              ),
              title: Text(
                valueOrDefault<String>(
                  CarPoolDetailStruct.maybeFromMap(
                          carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)
                      ?.driverName,
                  'driver_name',
                ),
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      fontSize: 18.0,
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
              ),
              actions: [],
              centerTitle: true,
              elevation: 2.0,
            ),
            body: SafeArea(
              top: true,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(15.0, 15.0, 15.0, 0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 15.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF447104),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                alignment: AlignmentDirectional(0.0, -1.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 7.0, 0.0, 0.0),
                                      child: Text(
                                        'Remaining',
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 5.0, 0.0, 5.0),
                                      child: Text(
                                        valueOrDefault<String>(
                                          CarPoolDetailStruct.maybeFromMap(
                                                  carPoolDetailsGetCarPoolsDetailsResponse
                                                      .jsonBody)
                                              ?.freeSeats
                                              .toString(),
                                          '?',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              fontSize: 26.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Color(0xFF7A0202),
                                  borderRadius: BorderRadius.circular(10.0),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 7.0, 0.0, 0.0),
                                      child: Text(
                                        'Reserved',
                                        textAlign: TextAlign.center,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 5.0, 0.0, 5.0),
                                      child: Text(
                                        valueOrDefault<String>(
                                          CarPoolDetailStruct.maybeFromMap(
                                                  carPoolDetailsGetCarPoolsDetailsResponse
                                                      .jsonBody)
                                              ?.reservedSeats
                                              .toString(),
                                          '?',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              fontSize: 26.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ].divide(SizedBox(width: 10.0)),
                        ),
                      ),
                      if ((CarPoolDetailStruct.maybeFromMap(
                                      carPoolDetailsGetCarPoolsDetailsResponse
                                          .jsonBody)!
                                  .freeSeats >
                              0) &&
                          (CarPoolDetailStruct.maybeFromMap(
                                      carPoolDetailsGetCarPoolsDetailsResponse
                                          .jsonBody)
                                  ?.driverUserId !=
                              currentUserUid))
                        Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            if (CarPoolDetailStruct.maybeFromMap(
                                        carPoolDetailsGetCarPoolsDetailsResponse
                                            .jsonBody)!
                                    .associatedPlayersCount >
                                1)
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 15.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Expanded(
                                      child: FlutterFlowDropDown<int>(
                                        controller:
                                            _model.dropDownValueController ??=
                                                FormFieldController<int>(
                                          _model.dropDownValue ??=
                                              CarPoolDetailStruct.maybeFromMap(
                                                      carPoolDetailsGetCarPoolsDetailsResponse
                                                          .jsonBody)
                                                  ?.userAssociatedMembers
                                                  .firstOrNull
                                                  ?.memberId,
                                        ),
                                        options: List<int>.from(
                                            CarPoolDetailStruct.maybeFromMap(
                                                    carPoolDetailsGetCarPoolsDetailsResponse
                                                        .jsonBody)!
                                                .userAssociatedMembers
                                                .map((e) => e.memberId)
                                                .toList()),
                                        optionLabels:
                                            CarPoolDetailStruct.maybeFromMap(
                                                    carPoolDetailsGetCarPoolsDetailsResponse
                                                        .jsonBody)!
                                                .userAssociatedMembers
                                                .map((e) => e.memberName)
                                                .toList(),
                                        onChanged: (val) => safeSetState(
                                            () => _model.dropDownValue = val),
                                        width: 200.0,
                                        height: 40.0,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        hintText: 'Select...',
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          size: 24.0,
                                        ),
                                        fillColor: FlutterFlowTheme.of(context)
                                            .coachSmartLightBlack,
                                        elevation: 2.0,
                                        borderColor: Colors.transparent,
                                        borderWidth: 0.0,
                                        borderRadius: 8.0,
                                        margin: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        hidesUnderline: true,
                                        isOverButton: false,
                                        isSearchable: false,
                                        isMultiSelect: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 15.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: FFButtonWidget(
                                      onPressed: () async {
                                        logFirebaseEvent(
                                            'CAR_POOL_DETAILS_RESERVE_SEAT_BTN_ON_TAP');
                                        logFirebaseEvent(
                                            'Button_update_page_state');
                                        _model.varMemberID = null;
                                        if (CarPoolDetailStruct.maybeFromMap(
                                                    carPoolDetailsGetCarPoolsDetailsResponse
                                                        .jsonBody)!
                                                .associatedPlayersCount <=
                                            1) {
                                          logFirebaseEvent(
                                              'Button_update_page_state');
                                          _model.varMemberID =
                                              CarPoolDetailStruct.maybeFromMap(
                                                      carPoolDetailsGetCarPoolsDetailsResponse
                                                          .jsonBody)
                                                  ?.userAssociatedMembers
                                                  .firstOrNull
                                                  ?.memberId;
                                        } else {
                                          logFirebaseEvent(
                                              'Button_update_page_state');
                                          _model.varMemberID =
                                              _model.dropDownValue;
                                        }

                                        logFirebaseEvent('Button_backend_call');
                                        _model.outputExistingCarPool =
                                            await CarPoolDetailTable()
                                                .queryRows(
                                          queryFn: (q) => q
                                              .eqOrNull(
                                                'car_pool_id',
                                                widget.carPoolId,
                                              )
                                              .eqOrNull(
                                                'member_id',
                                                _model.varMemberID,
                                              ),
                                        );
                                        if (_model.outputExistingCarPool !=
                                                null &&
                                            (_model.outputExistingCarPool)!
                                                .isNotEmpty) {
                                          logFirebaseEvent(
                                              'Button_show_snack_bar');
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Member already reserved in this car pool',
                                                style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              duration:
                                                  Duration(milliseconds: 4000),
                                              backgroundColor:
                                                  FlutterFlowTheme.of(context)
                                                      .error,
                                            ),
                                          );
                                        } else {
                                          logFirebaseEvent(
                                              'Button_backend_call');
                                          await CarPoolDetailTable().insert({
                                            'created_at':
                                                supaSerialize<DateTime>(
                                                    getCurrentTimestamp),
                                            'car_pool_id': widget.carPoolId,
                                            'member_id': _model.varMemberID,
                                            'status': 'reserved',
                                          });
                                          logFirebaseEvent(
                                              'Button_refresh_database_request');
                                          safeSetState(() => _model
                                              .apiRequestCompleter = null);
                                          await _model
                                              .waitForApiRequestCompleted();
                                          logFirebaseEvent(
                                              'Button_backend_call');
                                          _model.outputMemberReservation =
                                              await MembersTable().queryRows(
                                            queryFn: (q) => q.eqOrNull(
                                              'member_id',
                                              _model.varMemberID,
                                            ),
                                          );
                                          logFirebaseEvent(
                                              'Button_backend_call');
                                          _model.apiResult28 =
                                              await SendEmailCall.call(
                                            recipient: CarPoolDetailStruct
                                                    .maybeFromMap(
                                                        carPoolDetailsGetCarPoolsDetailsResponse
                                                            .jsonBody)
                                                ?.driverEmail,
                                            subject: 'Car Pool Reservation',
                                            body:
                                                '${_model.outputMemberReservation?.firstOrNull?.firstName} ${_model.outputMemberReservation?.firstOrNull?.lastName} has reserved a seat in your car pool for the event on ${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.eventDateFormatted} (${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.teamName})',
                                          );

                                          logFirebaseEvent(
                                              'Button_backend_call');
                                          _model.apiResult29 =
                                              await SendEmailCall.call(
                                            recipient: currentUserEmail,
                                            subject: 'Car Pool Reservation',
                                            body:
                                                'Confirmation that a car pool seat has been reserved with ${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.driverName} for ${_model.outputMemberReservation?.firstOrNull?.firstName}. Please make contact on ${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.driverPhone} to finalise plans for the event on ${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.eventDateFormatted} (${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.teamName})',
                                          );
                                        }

                                        safeSetState(() {});
                                      },
                                      text: 'Reserve Seat',
                                      icon: Icon(
                                        Icons
                                            .airline_seat_recline_normal_outlined,
                                        size: 25.0,
                                      ),
                                      options: FFButtonOptions(
                                        height: 40.0,
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        iconPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                0.0, 0.0, 0.0, 0.0),
                                        color: FlutterFlowTheme.of(context)
                                            .coachSmartLightBlack,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .override(
                                              font: GoogleFonts.interTight(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .coachSmartGreen,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontStyle,
                                            ),
                                        elevation: 0.0,
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .coachSmartGreen,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                      showLoadingIndicator: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 10.0, 0.0, 10.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  () {
                                    if (CarPoolDetailStruct.maybeFromMap(
                                                carPoolDetailsGetCarPoolsDetailsResponse
                                                    .jsonBody)
                                            ?.freeSeats ==
                                        0) {
                                      return 'Car Pool is Full';
                                    } else if (CarPoolDetailStruct.maybeFromMap(
                                                carPoolDetailsGetCarPoolsDetailsResponse
                                                    .jsonBody)
                                            ?.reservedSeats ==
                                        0) {
                                      return 'No Seats Reserved';
                                    } else {
                                      return 'Currently in this car pool';
                                    }
                                  }(),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          if (CarPoolDetailStruct.maybeFromMap(
                                          carPoolDetailsGetCarPoolsDetailsResponse
                                              .jsonBody)
                                      ?.reservations !=
                                  null &&
                              (CarPoolDetailStruct.maybeFromMap(
                                          carPoolDetailsGetCarPoolsDetailsResponse
                                              .jsonBody)
                                      ?.reservations)!
                                  .isNotEmpty)
                            Builder(
                              builder: (context) {
                                final childrenCarPoolDetails =
                                    CarPoolDetailStruct.maybeFromMap(
                                                carPoolDetailsGetCarPoolsDetailsResponse
                                                    .jsonBody)
                                            ?.reservations
                                            .where(
                                                (e) => e.status == 'reserved')
                                            .toList()
                                            .toList() ??
                                        [];

                                return ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  itemCount: childrenCarPoolDetails.length,
                                  itemBuilder:
                                      (context, childrenCarPoolDetailsIndex) {
                                    final childrenCarPoolDetailsItem =
                                        childrenCarPoolDetails[
                                            childrenCarPoolDetailsIndex];
                                    return Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 5.0, 0.0, 5.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .coachSmartLightBlack,
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(10.0, 10.0,
                                                          10.0, 10.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Container(
                                                            width: 5.0,
                                                            height: 40.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .coachSmartGreen,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10.0),
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        10.0,
                                                                        0.0,
                                                                        0.0,
                                                                        0.0),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .max,
                                                                  children: [
                                                                    Text(
                                                                      valueOrDefault<
                                                                          String>(
                                                                        childrenCarPoolDetailsItem
                                                                            .memberName,
                                                                        'member_name',
                                                                      ),
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                            fontSize:
                                                                                16.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ].divide(SizedBox(
                                                                  height: 5.0)),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (childrenCarPoolDetailsItem
                                                        .memberBelongsToUser ==
                                                    true)
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                15.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        FFButtonWidget(
                                                          onPressed: () async {
                                                            logFirebaseEvent(
                                                                'CAR_POOL_DETAILS_PAGE_CANCEL_BTN_ON_TAP');
                                                            logFirebaseEvent(
                                                                'Button_backend_call');
                                                            await CarPoolDetailTable()
                                                                .delete(
                                                              matchingRows:
                                                                  (rows) => rows
                                                                      .eqOrNull(
                                                                'id',
                                                                childrenCarPoolDetailsItem
                                                                    .reservationId,
                                                              ),
                                                            );
                                                            logFirebaseEvent(
                                                                'Button_show_snack_bar');
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  'Car Pool Reservation Cancelled',
                                                                  style:
                                                                      TextStyle(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                ),
                                                                duration: Duration(
                                                                    milliseconds:
                                                                        4000),
                                                                backgroundColor:
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .coachSmartGreen,
                                                              ),
                                                            );
                                                            logFirebaseEvent(
                                                                'Button_refresh_database_request');
                                                            safeSetState(() =>
                                                                _model.apiRequestCompleter =
                                                                    null);
                                                            await _model
                                                                .waitForApiRequestCompleted();
                                                            logFirebaseEvent(
                                                                'Button_backend_call');
                                                            _model.apiResult26 =
                                                                await SendEmailCall
                                                                    .call(
                                                              recipient: CarPoolDetailStruct
                                                                      .maybeFromMap(
                                                                          carPoolDetailsGetCarPoolsDetailsResponse
                                                                              .jsonBody)
                                                                  ?.driverEmail,
                                                              subject:
                                                                  'Car Pool Cancellation',
                                                              body:
                                                                  '${childrenCarPoolDetailsItem.memberName} has cancelled the car pool reservation with you for the event on: ${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.eventDateFormatted} (${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.teamName})',
                                                            );

                                                            logFirebaseEvent(
                                                                'Button_backend_call');
                                                            _model.apiResult27 =
                                                                await SendEmailCall
                                                                    .call(
                                                              recipient:
                                                                  childrenCarPoolDetailsItem
                                                                      .associatedUserEmail,
                                                              subject:
                                                                  'Car Pool Cancellation',
                                                              body:
                                                                  'Confirmation that your car pool reservation with ${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.driverName} has been cancelled for the event on ${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.eventDateFormatted} (${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.teamName})',
                                                            );

                                                            safeSetState(() {});
                                                          },
                                                          text: 'Cancel',
                                                          options:
                                                              FFButtonOptions(
                                                            height: 30.0,
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        16.0,
                                                                        0.0,
                                                                        16.0,
                                                                        0.0),
                                                            iconPadding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        0.0,
                                                                        0.0,
                                                                        0.0),
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .coachSmartGreen,
                                                            textStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .override(
                                                                      font: GoogleFonts
                                                                          .interTight(
                                                                        fontWeight: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontWeight,
                                                                        fontStyle: FlutterFlowTheme.of(context)
                                                                            .titleSmall
                                                                            .fontStyle,
                                                                      ),
                                                                      color: FlutterFlowTheme.of(
                                                                              context)
                                                                          .coachSmartLightBlack,
                                                                      fontSize:
                                                                          14.0,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleSmall
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .titleSmall
                                                                          .fontStyle,
                                                                    ),
                                                            elevation: 0.0,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0),
                                                          ),
                                                          showLoadingIndicator:
                                                              false,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                      if (CarPoolDetailStruct.maybeFromMap(
                                  carPoolDetailsGetCarPoolsDetailsResponse
                                      .jsonBody)
                              ?.driverUserId ==
                          currentUserUid)
                        Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 15.0, 0.0, 15.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: FFButtonWidget(
                                      onPressed: () async {
                                        logFirebaseEvent(
                                            'CAR_POOL_DETAILS_DELETE_CAR_POOL_BTN_ON_');
                                        for (int loop1Index = 0;
                                            loop1Index <
                                                CarPoolDetailStruct.maybeFromMap(
                                                        carPoolDetailsGetCarPoolsDetailsResponse
                                                            .jsonBody)!
                                                    .reservations
                                                    .length;
                                            loop1Index++) {
                                          final currentLoop1Item =
                                              CarPoolDetailStruct.maybeFromMap(
                                                      carPoolDetailsGetCarPoolsDetailsResponse
                                                          .jsonBody)!
                                                  .reservations[loop1Index];
                                          logFirebaseEvent(
                                              'Button_backend_call');
                                          await SendEmailCall.call(
                                            recipient: currentLoop1Item
                                                .associatedUserEmail,
                                            subject: 'Car Pool Cancellation',
                                            body:
                                                'Unfortunately the car pool you reserved for ${currentLoop1Item.memberName} with ${CarPoolDetailStruct.maybeFromMap(carPoolDetailsGetCarPoolsDetailsResponse.jsonBody)?.driverName} has been cancelled. Please look for a different car pool if you still require assistance attending the event. Thanks!',
                                          );

                                          logFirebaseEvent(
                                              'Button_backend_call');
                                          await CarPoolDetailTable().update(
                                            data: {
                                              'status': 'cancelled',
                                            },
                                            matchingRows: (rows) =>
                                                rows.eqOrNull(
                                              'id',
                                              currentLoop1Item.reservationId,
                                            ),
                                          );
                                        }
                                        logFirebaseEvent('Button_backend_call');
                                        await CarPoolTable().update(
                                          data: {
                                            'status': 'cancelled',
                                          },
                                          matchingRows: (rows) => rows.eqOrNull(
                                            'car_pool_id',
                                            widget.carPoolId,
                                          ),
                                        );
                                        logFirebaseEvent('Button_backend_call');
                                        _model.outputCreateCarPoolAPI =
                                            await GetEventCarPoolsCall.call(
                                          supabaseJWTtoken: currentJwtToken,
                                          pEventId: widget.eventID,
                                          pUserId: currentUserUid,
                                        );

                                        logFirebaseEvent(
                                            'Button_update_app_state');
                                        FFAppState().carPoolEventDetails =
                                            CarPoolParentStruct.maybeFromMap(
                                                (_model.outputCreateCarPoolAPI
                                                        ?.jsonBody ??
                                                    ''))!;
                                        logFirebaseEvent(
                                            'Button_navigate_back');
                                        context.safePop();
                                        logFirebaseEvent(
                                            'Button_show_snack_bar');
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Car Pool successfully cancelled',
                                              style: TextStyle(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            duration:
                                                Duration(milliseconds: 4000),
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .coachSmartGreen,
                                          ),
                                        );

                                        safeSetState(() {});
                                      },
                                      text: 'Delete Car Pool',
                                      icon: Icon(
                                        Icons.cancel_presentation,
                                        size: 25.0,
                                      ),
                                      options: FFButtonOptions(
                                        height: 40.0,
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        iconPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                0.0, 0.0, 0.0, 0.0),
                                        color: Color(0xFF7A0202),
                                        textStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .override(
                                              font: GoogleFonts.interTight(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .fontStyle,
                                              ),
                                              color: Color(0xFFCECACA),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleSmall
                                                      .fontStyle,
                                            ),
                                        elevation: 0.0,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
