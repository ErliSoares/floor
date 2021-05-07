import 'package:floor/floor.dart';
import 'package:floor/src/adapter/load_options_compiler/column_compiler.dart';
import 'package:floor/src/adapter/load_options_compiler/filter_compiler.dart';
import 'package:floor/src/adapter/load_options_compiler/sort_compiler.dart';

class LoadOptionsCompiler {
  final String sql;
  final LoadOptions loadOptions;
  final QueryInfo queryInfo;
  final List<Object?> arguments;

  LoadOptionsCompiler({
    required this.sql,
    required this.loadOptions,
    required this.queryInfo,
    required this.arguments,
  });

  String compile() {
    String? filter;
    String? sort;
    String? columns;
    String? limit;

    if (loadOptions.filter != null) {
      filter = FilterCompiler(
        sql: sql,
        arguments: arguments,
        loadOptions: loadOptions,
        queryInfo: queryInfo,
      ).compile(loadOptions.filter!);
    }
    if (loadOptions.select != null || loadOptions.notSelect != null) {
      columns = ColumnCompiler(
        sql: sql,
        arguments: arguments,
        loadOptions: loadOptions,
        queryInfo: queryInfo,
      ).compile(loadOptions.select, loadOptions.notSelect);
    }
    if (loadOptions.sort != null) {
      sort = SortCompiler(
        sql: sql,
        arguments: arguments,
        loadOptions: loadOptions,
        queryInfo: queryInfo,
      ).compile(loadOptions.sort!);
    }
    if (loadOptions.take != null && loadOptions.skip != null) {
      limit = ' LIMIT ${loadOptions.take} OFFSET ${loadOptions.skip}';
    } else if (loadOptions.take != null) {
      limit = ' LIMIT ${loadOptions.take}';
    } else if (loadOptions.skip != null) {
      limit = ' LIMIT 99999999999999999 OFFSET ${loadOptions.skip}';
    }

    return changeSql(filter: filter, sort: sort, columns: columns, limit: limit);
  }

  String changeSql({String? filter, String? sort, String? columns, String? limit}) {
    if ((filter?.isEmpty ?? true) &&
        (sort?.isEmpty ?? true) &&
        (columns?.isEmpty ?? true) &&
        (limit?.isEmpty ?? true)) {
      return this.sql;
    }
    var sql = this.sql.trimRight();
    if (sql.endsWith(';')) {
      sql = sql.substring(0, sql.length - 1);
    }
    final partsSql = <String>[];
    var lastIndex = 0;

    if (columns?.isNotEmpty ?? false) {
      lastIndex = queryInfo.columnsIndex.end;
      partsSql.add(sql.substring(0, queryInfo.columnsIndex.start));
      partsSql.add(columns!);
    }

    if (filter?.isNotEmpty ?? false) {
      if (queryInfo.whereExpressionIndex != null) {
        partsSql.add('(${sql.substring(lastIndex, queryInfo.whereExpressionIndex!.end - lastIndex)})');
        lastIndex = queryInfo.whereExpressionIndex!.end;
        partsSql.add(' AND ($filter)');
      } else {
        final nextClause = queryInfo.groupByClauseIndex ?? queryInfo.orderByClauseIndex ?? queryInfo.limitClauseIndex;
        final lastIndexClause = nextClause?.start ?? sql.length;
        if (lastIndexClause > lastIndex) {
          partsSql.add(sql.substring(lastIndex, lastIndexClause - lastIndex));
        }
        lastIndex = lastIndexClause;
        partsSql.add(' WHERE $filter');
      }
    }

    if (sort?.isNotEmpty ?? false) {
      if (queryInfo.orderByClauseIndex != null) {
        if (queryInfo.orderByClauseIndex!.start > lastIndex) {
          partsSql.add(sql.substring(lastIndex, queryInfo.orderByClauseIndex!.start - lastIndex));
          lastIndex = queryInfo.orderByClauseIndex!.start;
        }
      } else {
        final nextClause = queryInfo.limitClauseIndex;
        final lastIndexClause = nextClause?.start ?? sql.length;
        if (lastIndexClause > lastIndex) {
          partsSql.add(sql.substring(lastIndex, lastIndexClause - lastIndex));
        }
        lastIndex = lastIndexClause;
      }
      partsSql.add(' ORDER BY $sort');
    }

    if (limit?.isNotEmpty ?? false) {
      if (queryInfo.limitClauseIndex != null) {
        if (queryInfo.limitClauseIndex!.start > lastIndex) {
          partsSql.add(sql.substring(lastIndex, queryInfo.limitClauseIndex!.start - lastIndex));
          lastIndex = queryInfo.limitClauseIndex!.start;
        }
      } else {
        if (sql.length > lastIndex) {
          partsSql.add(sql.substring(lastIndex, sql.length - lastIndex));
        }
        lastIndex = sql.length;
      }
      partsSql.add(limit!);
    }

    if (sql.length > lastIndex) {
      partsSql.add(sql.substring(lastIndex, sql.length - lastIndex));
    }
    return partsSql.map((e) => e.trim()).join(' ');
  }
}
