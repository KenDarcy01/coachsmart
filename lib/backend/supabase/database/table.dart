import 'database.dart';

abstract class SupabaseTable<T extends SupabaseDataRow> {
  String get tableName;
  T createRow(Map<String, dynamic> data);

  PostgrestFilterBuilder _select() => SupaFlow.client.from(tableName).select();

  Future<List<T>> queryRows({
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder) queryFn,
    int? limit,
  }) {
    final select = _select();
    var query = queryFn(select);
    query = limit != null ? query.limit(limit) : query;
    return query.select().then((rows) => rows.map(createRow).toList());
  }

  /// Fetches one page of rows, starting at row [offset] and returning at most
  /// [pageSize] rows. A page shorter than [pageSize] means the query is
  /// exhausted.
  Future<List<T>> queryRowsPage({
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder) queryFn,
    required int offset,
    required int pageSize,
  }) {
    final select = _select();
    return queryFn(select)
        .range(offset, offset + pageSize - 1)
        .select()
        .then((rows) => rows.map(createRow).toList());
  }

  Future<List<T>> querySingleRow({
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder) queryFn,
  }) =>
      queryFn(_select())
          .limit(1)
          .select()
          .maybeSingle()
          .catchError((e) => print('Error querying row: $e'))
          .then((r) => [if (r != null) createRow(r)]);

  Future<T> insert(Map<String, dynamic> data) => SupaFlow.client
      .from(tableName)
      .insert(data)
      .select()
      .limit(1)
      .single()
      .then(createRow);

  Future<T> upsert(Map<String, dynamic> data, {String? onConflict}) =>
      SupaFlow.client
          .from(tableName)
          .upsert(data, onConflict: onConflict)
          .select()
          .limit(1)
          .single()
          .then(createRow);

  Future<List<T>> update({
    required Map<String, dynamic> data,
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder)
        matchingRows,
    bool returnRows = false,
  }) async {
    final update = matchingRows(SupaFlow.client.from(tableName).update(data));
    if (!returnRows) {
      await update;
      return [];
    }
    return update.select().then((rows) => rows.map(createRow).toList());
  }

  Future<List<T>> delete({
    required PostgrestTransformBuilder Function(PostgrestFilterBuilder)
        matchingRows,
    bool returnRows = false,
  }) async {
    final delete = matchingRows(SupaFlow.client.from(tableName).delete());
    if (!returnRows) {
      await delete;
      return [];
    }
    return delete.select().then((rows) => rows.map(createRow).toList());
  }
}

/// Serializes a full-text search value for use inside a raw PostgREST
/// `or=(...)` filter string. The value is double-quoted with quotes and
/// backslashes escaped, so reserved PostgREST characters (commas, dots,
/// parentheses) in user input cannot terminate or extend the filter
/// expression. Null or blank input becomes an empty search, which matches
/// no rows - the OR-identity, mirroring how textSearchOrNull skips the
/// filter in AND chains.
String ftsOrFilterValue(String? query) {
  final escaped =
      (query?.trim() ?? '').replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

extension NullSafePostgrestFilters on PostgrestFilterBuilder {
  PostgrestFilterBuilder eqOrNull(String column, dynamic value) {
    return value != null ? eq(column, value) : this;
  }

  PostgrestFilterBuilder neqOrNull(String column, dynamic value) {
    return value != null ? neq(column, value) : this;
  }

  PostgrestFilterBuilder ltOrNull(String column, dynamic value) {
    return value != null ? lt(column, value) : this;
  }

  PostgrestFilterBuilder lteOrNull(String column, dynamic value) {
    return value != null ? lte(column, value) : this;
  }

  PostgrestFilterBuilder gtOrNull(String column, dynamic value) {
    return value != null ? gt(column, value) : this;
  }

  PostgrestFilterBuilder gteOrNull(String column, dynamic value) {
    return value != null ? gte(column, value) : this;
  }

  PostgrestFilterBuilder containsOrNull(String column, dynamic value) {
    return value != null ? contains(column, value) : this;
  }

  PostgrestFilterBuilder overlapsOrNull(String column, dynamic value) {
    return value != null ? overlaps(column, value) : this;
  }

  PostgrestFilterBuilder inFilterOrNull(String column, List<dynamic>? values) {
    return values != null ? inFilter(column, values) : this;
  }

  PostgrestFilterBuilder textSearchOrNull(
    String column,
    String? query, {
    String? config,
    TextSearchType? type,
  }) {
    return query != null && query.trim().isNotEmpty
        ? textSearch(column, query, config: config, type: type)
        : this;
  }

  /// Full-text search for update/delete matching-rows filters. Unlike
  /// [textSearchOrNull], a null or blank [query] must not remove the
  /// predicate - that would turn "mutate matching rows" into "mutate every
  /// visible row". A blank query is sent as an empty search instead, which
  /// matches no rows, so the mutation affects nothing.
  PostgrestFilterBuilder requiredTextSearch(
    String column,
    String? query, {
    String? config,
    TextSearchType? type,
  }) {
    return textSearch(column, query?.trim() ?? '', config: config, type: type);
  }
}

extension NullSafeSupabaseStreamFilters on SupabaseStreamFilterBuilder {
  SupabaseStreamBuilder eqOrNull(String column, dynamic value) {
    return value != null ? eq(column, value) : this;
  }

  SupabaseStreamBuilder neqOrNull(String column, dynamic value) {
    return value != null ? neq(column, value) : this;
  }

  SupabaseStreamBuilder ltOrNull(String column, dynamic value) {
    return value != null ? lt(column, value) : this;
  }

  SupabaseStreamBuilder lteOrNull(String column, dynamic value) {
    return value != null ? lte(column, value) : this;
  }

  SupabaseStreamBuilder gtOrNull(String column, dynamic value) {
    return value != null ? gt(column, value) : this;
  }

  SupabaseStreamBuilder gteOrNull(String column, dynamic value) {
    return value != null ? gte(column, value) : this;
  }

  SupabaseStreamBuilder inFilterOrNull(String column, List<Object>? values) {
    return values != null ? inFilter(column, values) : this;
  }
}

class PostgresTime {
  PostgresTime(this.time);
  DateTime? time;

  static PostgresTime? tryParse(String formattedString) {
    final datePrefix = DateTime.now().toIso8601String().split('T').first;
    return PostgresTime(
        DateTime.tryParse('${datePrefix}T$formattedString')?.toLocal());
  }

  String? toIso8601String() {
    return time?.toIso8601String().split('T').last;
  }

  @override
  String toString() {
    return toIso8601String() ?? '';
  }
}
