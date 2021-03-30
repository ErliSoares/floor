import 'package:floor/src/schema/table.dart';
import 'package:floor_annotation/floor_annotation.dart';

/// A column that is part of a table.
class Column {
  Column(
    this.name,
    this.type, {
    this.relationship,
    this.isPrimaryKey = false,
    required this.nullable,
    required this.useInQuery,
    required this.useInInsert,
    required this.useInIUpdate,
    required this.useInIDelete,
  });

  factory Column.useAll(
    String name,
    DbType type, {
    required bool nullable,
    ForeignKey? relationship,
    bool isPrimaryKey = false,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: true,
        useInIDelete: true,
        useInInsert: true,
        useInIUpdate: true,
        relationship: relationship,
        isPrimaryKey: isPrimaryKey,
      );

  factory Column.onlyQuery(
    String name,
    DbType type, {
    required bool nullable,
    ForeignKey? relationship,
    bool isPrimaryKey = false,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: true,
        useInIDelete: false,
        useInInsert: false,
        useInIUpdate: false,
        relationship: relationship,
        isPrimaryKey: isPrimaryKey,
      );

  factory Column.onlyInsert(
    String name,
    DbType type, {
    required bool nullable,
    ForeignKey? relationship,
    bool isPrimaryKey = false,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: false,
        useInIDelete: false,
        useInInsert: true,
        useInIUpdate: false,
        relationship: relationship,
        isPrimaryKey: isPrimaryKey,
      );

  factory Column.onlyDelete(
    String name,
    DbType type, {
    required bool nullable,
    ForeignKey? relationship,
    bool isPrimaryKey = false,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: false,
        useInIDelete: true,
        useInInsert: false,
        useInIUpdate: false,
        relationship: relationship,
        isPrimaryKey: isPrimaryKey,
      );

  factory Column.onlyUpdate(
    String name,
    DbType type, {
    required bool nullable,
    ForeignKey? relationship,
    bool isPrimaryKey = false,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: false,
        useInIDelete: false,
        useInInsert: false,
        useInIUpdate: true,
        relationship: relationship,
        isPrimaryKey: isPrimaryKey,
      );

  final bool useInQuery;
  final bool useInInsert;
  final bool useInIUpdate;
  final bool useInIDelete;

  TypeConverterBase? converter;

  ForeignKey? relationship;

  bool get isSub => relationship != null;

  final bool isPrimaryKey;

  final DbType type;

  final bool nullable;

  /// The table this column belongs to.
  late final Table table;

  /// The raw name of this column
  final String name;
}

/// A type that sql expressions can have at runtime.
enum DbType {
  nullType,
  int,
  real,
  text,
  blob,
}
