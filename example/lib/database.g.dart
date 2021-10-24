// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

// ignore_for_file: cast_nullable_to_non_nullable
// ignore_for_file: avoid_types_on_closure_parameters
// ignore_for_file: invalid_null_aware_operator
// ignore_for_file: prefer_interpolation_to_compose_strings

class $FloorFlutterDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$FlutterDatabaseBuilder databaseBuilder(String name) =>
      _$FlutterDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static _$FlutterDatabaseBuilder inMemoryDatabaseBuilder() =>
      _$FlutterDatabaseBuilder(null);
}

class _$FlutterDatabaseBuilder {
  _$FlutterDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  /// Adds migrations to the builder.
  _$FlutterDatabaseBuilder addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  /// Adds a database [Callback] to the builder.
  _$FlutterDatabaseBuilder addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  /// Creates the database and initializes it.
  Future<FlutterDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$FlutterDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$FlutterDatabase extends FlutterDatabase {
  _$FlutterDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  TaskDao? _taskDaoInstance;

  Future<sqflite.Database> open(String path, List<Migration> migrations,
      [Callback? callback]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `Task` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `message` TEXT NOT NULL, `time_Created_at` TEXT NOT NULL, `time_Updated_at` TEXT NOT NULL)');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  TaskDao get taskDao {
    return _taskDaoInstance ??= _$TaskDao(this, changeListener);
  }
}

class _$TaskDao extends TaskDao {
  _$TaskDao(this.floorDatabase, this.changeListener)
      : _queryAdapter = QueryAdapter(floorDatabase.database,
            changeListener: changeListener),
        _taskInsertionAdapter = InsertionAdapter(
            floorDatabase,
            'Task',
            [],
            (Task item) => <String, Object?>{
                  'id': item.id,
                  'message': item.message,
                  'time_Created_at': item.timestamp?.createdAt,
                  'time_Updated_at': item.timestamp?.updatedAt
                },
            changeListener: changeListener),
        _taskUpdateAdapter = UpdateAdapter(
            floorDatabase,
            'Task',
            ['id'],
            [],
            (Task item) => <String, Object?>{
                  'id': item.id,
                  'message': item.message,
                  'time_Created_at': item.timestamp?.createdAt,
                  'time_Updated_at': item.timestamp?.updatedAt
                },
            changeListener: changeListener),
        _taskDeletionAdapter = DeletionAdapter(
            floorDatabase,
            'Task',
            ['id'],
            [],
            (Task item) => <String, Object?>{
                  'id': item.id,
                  'message': item.message,
                  'time_Created_at': item.timestamp?.createdAt,
                  'time_Updated_at': item.timestamp?.updatedAt
                },
            changeListener: changeListener);

  final _$FlutterDatabase floorDatabase;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<Task> _taskInsertionAdapter;

  final UpdateAdapter<Task> _taskUpdateAdapter;

  final DeletionAdapter<Task> _taskDeletionAdapter;

  @override
  Future<Task?> findTaskById(int id) async {
    return _queryAdapter.query('SELECT * FROM task WHERE id = ?1',
        mapper: (Map<String, Object?> row) => Task(
            row['id'] as int?,
            row['message'] as String,
            Timestamp(
                createdAt: row['time_Created_at'] as String,
                updatedAt: row['time_Updated_at'] as String)),
        arguments: [id]);
  }

  @override
  Future<List<Task>> findAllTasks() async {
    return _queryAdapter.queryList('SELECT * FROM task',
        mapper: (Map<String, Object?> row) => Task(
            row['id'] as int?,
            row['message'] as String,
            Timestamp(
                createdAt: row['time_Created_at'] as String,
                updatedAt: row['time_Updated_at'] as String)));
  }

  @override
  Stream<List<Task>> findAllTasksAsStream() {
    return _queryAdapter.queryListStream('SELECT * FROM task',
        mapper: (Map<String, Object?> row) => Task(
            row['id'] as int?,
            row['message'] as String,
            Timestamp(
                createdAt: row['time_Created_at'] as String,
                updatedAt: row['time_Updated_at'] as String)),
        queryableName: 'Task',
        isView: false);
  }

  @override
  Future<void> insertTask(Task task) async {
    await _taskInsertionAdapter.insert(task, OnConflictStrategy.abort);
  }

  @override
  Future<void> insertTasks(List<Task> tasks) async {
    await _taskInsertionAdapter.insertList(tasks, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateTask(Task task) async {
    await _taskUpdateAdapter.update(task, OnConflictStrategy.abort);
  }

  @override
  Future<void> updateTasks(List<Task> task) async {
    await _taskUpdateAdapter.updateList(task, OnConflictStrategy.abort);
  }

  @override
  Future<void> deleteTask(Task task) async {
    await _taskDeletionAdapter.delete(task);
  }

  @override
  Future<void> deleteTasks(List<Task> tasks) async {
    await _taskDeletionAdapter.deleteList(tasks);
  }
}
