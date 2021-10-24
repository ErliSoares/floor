import 'dart:async';

import 'package:floor/src/database.dart';
import 'package:floor/src/routine/routine_entry_trigger_base.dart';
import 'package:floor/src/util/primary_key_helper.dart';

class DeletionAdapter<T> {
  final FloorDatabase _database;
  final String _entityName;
  final List<String> _primaryKeyColumnNames;
  final Map<String, Object?> Function(T) _valueMapper;
  final StreamController<String>? _changeListener;
  final Future<void> Function(T entity)? _deleted;
  final List<RoutineEntryTriggerBase<T>> _routines;

  FutureOr<void> Function(T entity)? beforeDelete;

  DeletionAdapter(
    final FloorDatabase database,
    final String entityName,
    final List<String> primaryKeyColumnName,
    final List<RoutineEntryTriggerBase<T>> routines,
      final Map<String, Object?> Function(T) valueMapper,
      {
        final StreamController<String>? changeListener,
        Future<void> Function(T entity)? deleted,
        this.beforeDelete,
      }
    )  : assert(entityName.isNotEmpty),
        assert(primaryKeyColumnName.isNotEmpty),
        _database = database,
        _entityName = entityName,
        _primaryKeyColumnNames = primaryKeyColumnName,
        _valueMapper = valueMapper,
        _changeListener = changeListener,
        _deleted = deleted,
        _routines = routines;

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
    if (beforeDelete != null) {
      await beforeDelete!(item);
    }
    final result = await _database.database.delete(
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
    for(final routine in _routines){
      await routine.run([item], _database);
    }
    if (result != 0) {
      _changeListener?.add(_entityName);
    }
    return result;
  }

  Future<int> _deleteList(final List<T> items) async {
    if (beforeDelete != null) {
      for(var item in items){
        await beforeDelete!(item);
      }
    }
    final batch = _database.database.batch();
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
    for(final routine in _routines){
      await routine.run(items, _database);
    }
    _changeListener?.add(_entityName);
    return result.isNotEmpty
        ? result.reduce((sum, element) => sum + element)
        : 0;
  }
}
