import '/flutter_flow/flutter_flow_util.dart';
import 'payment_transactions_widget.dart' show PaymentTransactionsWidget;
import 'package:flutter/material.dart';

class PaymentTransactionsModel
    extends FlutterFlowModel<PaymentTransactionsWidget> {
  ///  Local state fields for this page.

  List<String> emailReceipients = [];
  void addToEmailReceipients(String item) => emailReceipients.add(item);
  void removeFromEmailReceipients(String item) => emailReceipients.remove(item);
  void removeAtIndexFromEmailReceipients(int index) =>
      emailReceipients.removeAt(index);
  void insertAtIndexInEmailReceipients(int index, String item) =>
      emailReceipients.insert(index, item);
  void updateEmailReceipientsAtIndex(int index, Function(String) updateFn) =>
      emailReceipients[index] = updateFn(emailReceipients[index]);

  int selectedFilter = 1;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
