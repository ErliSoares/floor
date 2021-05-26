import 'dart:async';

import 'package:floor/src/util/primary_key_helper.dart';
import 'package:sqflite/sqflite.dart';

class DeletionAdapter<T> {
  final DatabaseExecutor _database;
  final String _entityName;
  final List<String> _primaryKeyColumnNames;
  final Map<String, Object?> Function(T) _valueMapper;
  final StreamController<String>? _changeListener;
  final Future<void> Function(T entity)? _deleted;
  FutureOr<void> Function(T entity)? afterDelete;

  DeletionAdapter(
    final DatabaseExecutor database,
    final String entityName,
    final List<String> primaryKeyColumnName,
    final Map<String, Object?> Function(T) valueMapper,
      {
        final StreamController<String>? changeListener,
        Future<void> Function(T entity)? deleted,
        this.afterDelete,
      }
    )  : assert(entityName.isNotEmpty),
        assert(primaryKeyColumnName.isNotEmpty),
        _database = database,
        _entityName = entityName,
        _primaryKeyColumnNames = primaryKeyColumnName,
        _valueMapper = valueMapper,
        _changeListener = changeListener,
        _deleted = deleted;

  Future<void> delete(final T item) async {
    await _delete(item);
  }

  Future<void> deleteList(final List<T> items) async {
    if (items.isEmpty) return;
    await _deleteList(items);
  }

  Future<int> deleteAndReturnChangedRows(final T item) {
    return _delete(item);
  }

  Future<int> deleteListAndReturnChangedRows(final List<T> items) async {
    if (items.isEmpty) return 0;
    return _deleteList(items);
  }

  Future<int> _delete(final T item) async {
    if (afterDelete != null) {
      await afterDelete!(item);
    }
    final result = await _database.delete(
      _entityName,
      where: PrimaryKeyHelper.getWhereClause(_primaryKeyColumnNames),
      whereArgs: PrimaryKeyHelper.getPrimaryKeyValues(
        _primaryKeyColumnNames,
        _valueMapper(item),
      ),
    );
    if (_deleted != null) {
      await _deleted!(item);
    }
    if (result != 0) {
      _changeListener?.add(_entityName);
    }
    return result;
  }

  Future<int> _deleteList(final List<T> items) async {
    if (afterDelete != null) {
      for(var item in items){
        await afterDelete!(item);
      }
    }
    final batch = _database.batch();
    for (final item in items) {
      batch.delete(
        _entityName,
        where: PrimaryKeyHelper.getWhereClause(_primaryKeyColumnNames),
        whereArgs: PrimaryKeyHelper.getPrimaryKeyValues(
          _primaryKeyColumnNames,
          _valueMapper(item),
        ),
      );
    }
    final result = (await batch.commit(noResult: false)).cast<int>();
    if (_deleted != null) {
      for (final entity in items) {
        await _deleted!(entity);
      }
    }
    _changeListener?.add(_entityName);
    return result.isNotEmpty
        ? result.reduce((sum, element) => sum + element)
        : 0;
  }
}
