import '../database.dart';

class EventUserMemberPaymentTable
    extends SupabaseTable<EventUserMemberPaymentRow> {
  @override
  String get tableName => 'event_user_member_payment';

  @override
  EventUserMemberPaymentRow createRow(Map<String, dynamic> data) =>
      EventUserMemberPaymentRow(data);
}

class EventUserMemberPaymentRow extends SupabaseDataRow {
  EventUserMemberPaymentRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => EventUserMemberPaymentTable();

  int get paymentId => getField<int>('payment_id')!;
  set paymentId(int value) => setField<int>('payment_id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  int? get eventId => getField<int>('event_id');
  set eventId(int? value) => setField<int>('event_id', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get eventTitle => getField<String>('event_title');
  set eventTitle(String? value) => setField<String>('event_title', value);

  String? get stripeSessionId => getField<String>('stripe_session_id');
  set stripeSessionId(String? value) =>
      setField<String>('stripe_session_id', value);

  String get paymentStatus => getField<String>('payment_status')!;
  set paymentStatus(String value) => setField<String>('payment_status', value);

  int? get amountPaid => getField<int>('amount_paid');
  set amountPaid(int? value) => setField<int>('amount_paid', value);

  String? get stripePaymentIntentId =>
      getField<String>('stripe_payment_intent_id');
  set stripePaymentIntentId(String? value) =>
      setField<String>('stripe_payment_intent_id', value);

  String? get stripeCheckoutUrl => getField<String>('stripe_checkout_url');
  set stripeCheckoutUrl(String? value) =>
      setField<String>('stripe_checkout_url', value);

  int? get feeAmount => getField<int>('fee_amount');
  set feeAmount(int? value) => setField<int>('fee_amount', value);

  int? get netAmount => getField<int>('net_amount');
  set netAmount(int? value) => setField<int>('net_amount', value);

  int? get taxAmount => getField<int>('tax_amount');
  set taxAmount(int? value) => setField<int>('tax_amount', value);

  int? get grossAmount => getField<int>('gross_amount');
  set grossAmount(int? value) => setField<int>('gross_amount', value);

  int? get memberId => getField<int>('member_id');
  set memberId(int? value) => setField<int>('member_id', value);
}
