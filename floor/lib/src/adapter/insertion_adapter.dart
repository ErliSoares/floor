import 'dart:async';

import 'package:floor/src/extension/on_conflict_strategy_extensions.dart';
import 'package:floor_annotation/floor_annotation.dart';
import 'package:sqflite/sqlite_api.dart';

class InsertionAdapter<T> {
  final DatabaseExecutor _database;
  final String _entityName;
  final Map<String, Object?> Function(T) _valueMapper;
  final StreamController<String>? _changeListener;
  final Future<void> Function(int id, T entity)? _inserted;
  FutureOr<void> Function(T entity)? beforeInsert;

  InsertionAdapter(
    final DatabaseExecutor database,
    final String entityName,
    final Map<String, Object?> Function(T) valueMapper,
      {
        final Future<void> Function(int id, T entity)? inserted,
        final StreamController<String>? changeListener,
        this.beforeInsert,
      })  : assert(entityName.isNotEmpty),
        _database = database,
        _entityName = entityName,
        _valueMapper = valueMapper,
        _changeListener = changeListener,
        _inserted = inserted;

  Future<void> insert(
    final T item,
    final OnConflictStrategy onConflictStrategy,
  ) async {
    await _insert(item, onConflictStrategy);
  }

  Future<void> insertList(
    final List<T> items,
    final OnConflictStrategy onConflictStrategy,
  ) async {
    if (items.isEmpty) return;
    if (beforeInsert != null) {
      for(var item in items){
        await beforeInsert!(item);
      }
    }
    final batch = _database.batch();
    for (final item in items) {
      batch.insert(
        _entityName,
        _valueMapper(item),
        conflictAlgorithm: onConflictStrategy.asSqfliteConflictAlgorithm(),
      );
    }
    final result = (await batch.commit(noResult: false)).cast<int>();
    if (_inserted != null) {
      for (var i = 0; i < result.length; i++) {
        await _inserted!(result[i], items[i]);
      }
    }
    _changeListener?.add(_entityName);
  }

  Future<int> insertAndReturnId(
    final T item,
    final OnConflictStrategy onConflictStrategy,
  ) {
    return _insert(item, onConflictStrategy);
  }

  Future<List<int>> insertListAndReturnIds(
    final List<T> items,
    final OnConflictStrategy onConflictStrategy,
  ) async {
    if (items.isEmpty) return [];
    if (beforeInsert != null) {
      for(var item in items){
        await beforeInsert!(item);
      }
    }
    final batch = _database.batch();
    for (final item in items) {
      batch.insert(
        _entityName,
        _valueMapper(item),
        conflictAlgorithm: onConflictStrategy.asSqfliteConflictAlgorithm(),
      );
    }
    final result = (await batch.commit(noResult: false)).cast<int>();
    if (_inserted != null) {
      for (var i = 0; i < result.length; i++) {
        await _inserted!(result[i], items[i]);
      }
    }
    if (result.isNotEmpty) {
      _changeListener?.add(_entityName);
    }
    return result;
  }

  Future<int> _insert(
    final T item,
    final OnConflictStrategy onConflictStrategy,
  ) async {
    if (beforeInsert != null) {
      await beforeInsert!(item);
    }
    final result = await _database.insert(
      _entityName,
      _valueMapper(item),
      conflictAlgorithm: onConflictStrategy.asSqfliteConflictAlgorithm(),
    );
    if (_inserted != null) {
      await _inserted!(result, item);
    }
    if (result != 0) {
      _changeListener?.add(_entityName);
    }
    return result;
  }
}
