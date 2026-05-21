// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class PaymentDetailsStruct extends FFFirebaseStruct {
  PaymentDetailsStruct({
    String? userFullName,
    String? paymentDate,
    int? amountPaid,
    String? memberFullName,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _userFullName = userFullName,
        _paymentDate = paymentDate,
        _amountPaid = amountPaid,
        _memberFullName = memberFullName,
        super(firestoreUtilData);

  // "user_full_name" field.
  String? _userFullName;
  String get userFullName => _userFullName ?? '';
  set userFullName(String? val) => _userFullName = val;

  bool hasUserFullName() => _userFullName != null;

  // "payment_date" field.
  String? _paymentDate;
  String get paymentDate => _paymentDate ?? '';
  set paymentDate(String? val) => _paymentDate = val;

  bool hasPaymentDate() => _paymentDate != null;

  // "amount_paid" field.
  int? _amountPaid;
  int get amountPaid => _amountPaid ?? 0;
  set amountPaid(int? val) => _amountPaid = val;

  void incrementAmountPaid(int amount) => amountPaid = amountPaid + amount;

  bool hasAmountPaid() => _amountPaid != null;

  // "member_full_name" field.
  String? _memberFullName;
  String get memberFullName => _memberFullName ?? '';
  set memberFullName(String? val) => _memberFullName = val;

  bool hasMemberFullName() => _memberFullName != null;

  static PaymentDetailsStruct fromMap(Map<String, dynamic> data) =>
      PaymentDetailsStruct(
        userFullName: data['user_full_name'] as String?,
        paymentDate: data['payment_date'] as String?,
        amountPaid: castToType<int>(data['amount_paid']),
        memberFullName: data['member_full_name'] as String?,
      );

  static PaymentDetailsStruct? maybeFromMap(dynamic data) => data is Map
      ? PaymentDetailsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'user_full_name': _userFullName,
        'payment_date': _paymentDate,
        'amount_paid': _amountPaid,
        'member_full_name': _memberFullName,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user_full_name': serializeParam(
          _userFullName,
          ParamType.String,
        ),
        'payment_date': serializeParam(
          _paymentDate,
          ParamType.String,
        ),
        'amount_paid': serializeParam(
          _amountPaid,
          ParamType.int,
        ),
        'member_full_name': serializeParam(
          _memberFullName,
          ParamType.String,
        ),
      }.withoutNulls;

  static PaymentDetailsStruct fromSerializableMap(Map<String, dynamic> data) =>
      PaymentDetailsStruct(
        userFullName: deserializeParam(
          data['user_full_name'],
          ParamType.String,
          false,
        ),
        paymentDate: deserializeParam(
          data['payment_date'],
          ParamType.String,
          false,
        ),
        amountPaid: deserializeParam(
          data['amount_paid'],
          ParamType.int,
          false,
        ),
        memberFullName: deserializeParam(
          data['member_full_name'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'PaymentDetailsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is PaymentDetailsStruct &&
        userFullName == other.userFullName &&
        paymentDate == other.paymentDate &&
        amountPaid == other.amountPaid &&
        memberFullName == other.memberFullName;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([userFullName, paymentDate, amountPaid, memberFullName]);
}

PaymentDetailsStruct createPaymentDetailsStruct({
  String? userFullName,
  String? paymentDate,
  int? amountPaid,
  String? memberFullName,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    PaymentDetailsStruct(
      userFullName: userFullName,
      paymentDate: paymentDate,
      amountPaid: amountPaid,
      memberFullName: memberFullName,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

PaymentDetailsStruct? updatePaymentDetailsStruct(
  PaymentDetailsStruct? paymentDetails, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    paymentDetails
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addPaymentDetailsStructData(
  Map<String, dynamic> firestoreData,
  PaymentDetailsStruct? paymentDetails,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (paymentDetails == null) {
    return;
  }
  if (paymentDetails.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && paymentDetails.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final paymentDetailsData =
      getPaymentDetailsFirestoreData(paymentDetails, forFieldValue);
  final nestedData =
      paymentDetailsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = paymentDetails.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getPaymentDetailsFirestoreData(
  PaymentDetailsStruct? paymentDetails, [
  bool forFieldValue = false,
]) {
  if (paymentDetails == null) {
    return {};
  }
  final firestoreData = mapToFirestore(paymentDetails.toMap());

  // Add any Firestore field values
  mapToFirestore(paymentDetails.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getPaymentDetailsListFirestoreData(
  List<PaymentDetailsStruct>? paymentDetailss,
) =>
    paymentDetailss
        ?.map((e) => getPaymentDetailsFirestoreData(e, true))
        .toList() ??
    [];
