import 'dart:async';

import 'package:floor/floor.dart';
import 'package:floor/src/adapter/load_options_compiler/load_options_compiler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';

/// This class knows how to execute database queries.
class QueryAdapter {
  final DatabaseExecutor _database;
  final StreamController<String>? _changeListener;

  QueryAdapter(
    final DatabaseExecutor database, {
    final StreamController<String>? changeListener,
  })  : _database = database,
        _changeListener = changeListener;

  /// Executes a SQLite query that may return a single value.
  Future<T?> query<T>(
    final String sql, {
    final List<Object>? arguments,
    required final T Function(Map<String, Object?>) mapper,
  }) async {
    final rows = await _database.rawQuery(sql, arguments);

    if (rows.isEmpty) {
      return null;
    } else if (rows.length > 1) {
      throw StateError("Query returned more than one row for '$sql'");
    }

    return mapper(rows.first);
  }

  /// Executes a SQLite query that may return multiple values.
  Future<List<T>> queryList<T>(
    final String sql, {
    final List<Object>? arguments,
    required final T Function(Map<String, Object?>) mapper,
    LoadOptionsEntry? loadOptions,
    QueryInfo? queryInfo,
  }) async {
    if (loadOptions == null) {
      final rows = await _database.rawQuery(sql, arguments);
      return rows.map((row) => mapper(row)).toList();
    }
    if (queryInfo == null) {
      throw StateError('queryInfo is required when loadOptions is not null.');
    }
    final argumentsNew = arguments ?? <Object>[];
    final loadOptionsComplete = LoadOptions(
      skip: loadOptions.skip,
      sort: loadOptions.sort,
      expand: loadOptions.expand,
      filter: loadOptions.filter,
      take: loadOptions.take,
    );
    final sqlProcessed = processSqlWithLoadOptions(sql, loadOptionsComplete, queryInfo, argumentsNew);
    final rows = await _database.rawQuery(sqlProcessed, argumentsNew);
    final entities = rows.map((row) => mapper(row)).toList();
    final expands = loadOptions.expand;
    if (expands != null) {
      for(var expand in expands) {
        final expandInfo = queryInfo.expand.firstWhereOrNull((e) => e.nameProperty == expand.selector);
        if (expandInfo == null) {
          throw Exception('O selector `${expand.selector}` não é uma Junction ou uma Relation da entidade `${T.toString()}` para expanção');
        }
        await expandInfo.process(entities, expand, expand.expand ?? []);
      }
    }
    return entities;
  }

  Future<void> queryNoReturn(
    final String sql, {
    final List<Object>? arguments,
  }) async {
    // TODO #94 differentiate between different query kinds (select, update, delete, insert)
    //  this enables to notify the observers
    //  also requires extracting the table name :(
    await _database.rawQuery(sql, arguments);
  }

  Future<T?> querySingleValue<T>(
    final String sql, {
    final List<Object>? arguments,
  }) async {
    final result = await _database.rawQuery(sql, arguments);
    if (result.isEmpty) {
      return null;
    }
    result[0].values.first;
  }

  Future<List<Map<String, Object?>>> queryMap(
    final String sql, {
    final List<Object>? arguments,
  }) async {
    return _database.rawQuery(sql, arguments);
  }

  /// Executes a SQLite query that returns a stream of single query results
  /// or `null`.
  Stream<T?> queryStream<T>(
    final String sql, {
    final List<Object>? arguments,
    required final String queryableName,
    required final bool isView,
    required final T Function(Map<String, Object?>) mapper,
  }) {
    // ignore: close_sinks
    final changeListener = ArgumentError.checkNotNull(_changeListener);
    final controller = StreamController<T?>.broadcast();

    Future<void> executeQueryAndNotifyController() async {
      final result = await query(sql, arguments: arguments, mapper: mapper);
      controller.add(result);
    }

    controller.onListen = () async => executeQueryAndNotifyController();

    // listen on all updates if the stream is on a view, only listen to the
    // name of the table if the stream is on a entity.
    final subscription = changeListener.stream.where((updatedTable) => updatedTable == queryableName || isView).listen(
          (_) async => executeQueryAndNotifyController(),
          onDone: () => controller.close(),
        );

    controller.onCancel = () => subscription.cancel();

    return controller.stream;
  }

  /// Executes a SQLite query that returns a stream of multiple query results.
  Stream<List<T>> queryListStream<T>(
    final String sql, {
    final List<Object>? arguments,
    required final String queryableName,
    required final bool isView,
    required final T Function(Map<String, Object?>) mapper,
  }) {
    // ignore: close_sinks
    final changeListener = ArgumentError.checkNotNull(_changeListener);
    final controller = StreamController<List<T>>.broadcast();

    Future<void> executeQueryAndNotifyController() async {
      final result = await queryList(sql, arguments: arguments, mapper: mapper);
      controller.add(result);
    }

    controller.onListen = () async => executeQueryAndNotifyController();

    // Views listen on all events, Entities only on events that changed the same entity.
    final subscription = changeListener.stream.where((updatedTable) => isView || updatedTable == queryableName).listen(
          (_) async => executeQueryAndNotifyController(),
          onDone: () => controller.close(),
        );

    controller.onCancel = () => subscription.cancel();

    return controller.stream;
  }

  String processSqlWithLoadOptions(String sql, LoadOptions loadOptions, QueryInfo queryInfo, List<Object?> arguments) {
    return LoadOptionsCompiler(
      loadOptions: loadOptions,
      queryInfo: queryInfo,
      sql: sql,
      arguments: arguments,
    ).compile();
  }
}
