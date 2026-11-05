// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class StripeCheckoutStruct extends FFFirebaseStruct {
  StripeCheckoutStruct({
    String? checkoutUrl,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _checkoutUrl = checkoutUrl,
        super(firestoreUtilData);

  // "checkoutUrl" field.
  String? _checkoutUrl;
  String get checkoutUrl => _checkoutUrl ?? '';
  set checkoutUrl(String? val) => _checkoutUrl = val;

  bool hasCheckoutUrl() => _checkoutUrl != null;

  static StripeCheckoutStruct fromMap(Map<String, dynamic> data) =>
      StripeCheckoutStruct(
        checkoutUrl: data['checkoutUrl'] as String?,
      );

  static StripeCheckoutStruct? maybeFromMap(dynamic data) => data is Map
      ? StripeCheckoutStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'checkoutUrl': _checkoutUrl,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'checkoutUrl': serializeParam(
          _checkoutUrl,
          ParamType.String,
        ),
      }.withoutNulls;

  static StripeCheckoutStruct fromSerializableMap(Map<String, dynamic> data) =>
      StripeCheckoutStruct(
        checkoutUrl: deserializeParam(
          data['checkoutUrl'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'StripeCheckoutStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is StripeCheckoutStruct && checkoutUrl == other.checkoutUrl;
  }

  @override
  int get hashCode => const ListEquality().hash([checkoutUrl]);
}

StripeCheckoutStruct createStripeCheckoutStruct({
  String? checkoutUrl,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    StripeCheckoutStruct(
      checkoutUrl: checkoutUrl,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

StripeCheckoutStruct? updateStripeCheckoutStruct(
  StripeCheckoutStruct? stripeCheckout, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    stripeCheckout
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addStripeCheckoutStructData(
  Map<String, dynamic> firestoreData,
  StripeCheckoutStruct? stripeCheckout,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (stripeCheckout == null) {
    return;
  }
  if (stripeCheckout.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && stripeCheckout.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final stripeCheckoutData =
      getStripeCheckoutFirestoreData(stripeCheckout, forFieldValue);
  final nestedData =
      stripeCheckoutData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = stripeCheckout.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getStripeCheckoutFirestoreData(
  StripeCheckoutStruct? stripeCheckout, [
  bool forFieldValue = false,
]) {
  if (stripeCheckout == null) {
    return {};
  }
  final firestoreData = mapToFirestore(stripeCheckout.toMap());

  // Add any Firestore field values
  mapToFirestore(stripeCheckout.firestoreUtilData.fieldValues)
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getStripeCheckoutListFirestoreData(
  List<StripeCheckoutStruct>? stripeCheckouts,
) =>
    stripeCheckouts
        ?.map((e) => getStripeCheckoutFirestoreData(e, true))
        .toList() ??
    [];
