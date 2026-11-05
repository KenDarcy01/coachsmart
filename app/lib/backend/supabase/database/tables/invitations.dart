import '../database.dart';

class InvitationsTable extends SupabaseTable<InvitationsRow> {
  @override
  String get tableName => 'invitations';

  @override
  InvitationsRow createRow(Map<String, dynamic> data) => InvitationsRow(data);
}

class InvitationsRow extends SupabaseDataRow {
  InvitationsRow(Map<String, dynamic> data) : super(data);

  @override
  SupabaseTable get table => InvitationsTable();

  int get id => getField<int>('id')!;
  set id(int value) => setField<int>('id', value);

  DateTime get createdAt => getField<DateTime>('created_at')!;
  set createdAt(DateTime value) => setField<DateTime>('created_at', value);

  String? get userId => getField<String>('user_id');
  set userId(String? value) => setField<String>('user_id', value);

  String? get emailAddressSent => getField<String>('email_address_sent');
  set emailAddressSent(String? value) =>
      setField<String>('email_address_sent', value);
}
