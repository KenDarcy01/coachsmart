// Calls the `spend` edge function (thread "Explore coach expenses and gear
// orders", 2026-11-23). Throws SpendError with a message fit to show.
import '/backend/supabase/supabase.dart';

class SpendError implements Exception {
  SpendError(this.message);
  final String message;
  @override
  String toString() => message;
}

class SpendApi {
  static Future<Map<String, dynamic>> call(Map<String, dynamic> body) async {
    try {
      final res = await SupaFlow.client.functions.invoke('spend', body: body);
      final d = res.data;
      if (d is Map && d['success'] == true) {
        return Map<String, dynamic>.from((d['data'] as Map?) ?? const {});
      }
      throw SpendError(d is Map && d['error'] is String
          ? d['error'] as String
          : 'Something went wrong. Please try again.');
    } on FunctionException catch (e) {
      final d = e.details;
      throw SpendError(d is Map && d['error'] is String
          ? d['error'] as String
          : 'Something went wrong. Please try again.');
    } on SpendError {
      rethrow;
    } catch (_) {
      throw SpendError('Could not reach CoachSmart. Please try again.');
    }
  }

  /// Is Spend & gear switched on for this account? (Ken only while it is
  /// tried, table spend_access.) False on any error.
  static Future<bool> hasAccess() async {
    try {
      final r = await SupaFlow.client.rpc('spend_has_access');
      return r == true;
    } catch (_) {
      return false;
    }
  }
}
