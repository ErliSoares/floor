import 'package:floor_annotation/floor_annotation.dart';

/// A column that is part of a table.
class Column {
  Column(
    this.name,
    this.type, {
    required this.nullable,
    required this.useInQuery,
    required this.useInInsert,
    required this.useInIUpdate,
    required this.useInIDelete,
    this.converter,
    this.junction,
  });

  factory Column.useAll(
    String name,
    DbType type, {
    required bool nullable,
    TypeConverterBase? converter,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: true,
        useInIDelete: true,
        useInInsert: true,
        useInIUpdate: true,
        converter: converter,
      );

  factory Column.onlyQuery(
    String name,
    DbType type, {
    required bool nullable,
    TypeConverterBase? converter,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: true,
        useInIDelete: false,
        useInInsert: false,
        useInIUpdate: false,
        converter: converter,
      );

  factory Column.onlyInsert(
    String name,
    DbType type, {
    required bool nullable,
    TypeConverterBase? converter,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: false,
        useInIDelete: false,
        useInInsert: true,
        useInIUpdate: false,
        converter: converter,
      );

  factory Column.onlyDelete(
    String name,
    DbType type, {
    required bool nullable,
    TypeConverterBase? converter,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: false,
        useInIDelete: true,
        useInInsert: false,
        useInIUpdate: false,
        converter: converter,
      );

  factory Column.onlyUpdate(
    String name,
    DbType type, {
    required bool nullable,
    TypeConverterBase? converter,
  }) =>
      Column(
        name,
        type,
        nullable: nullable,
        useInQuery: false,
        useInIDelete: false,
        useInInsert: false,
        useInIUpdate: true,
        converter: converter,
      );

  factory Column.junction(
    String name,
    JunctionData junction, {
    required bool nullable,
    TypeConverterBase? converter,
  }) =>
      Column(
        name,
        DbType.expand,
        nullable: nullable,
        useInQuery: true,
        useInIDelete: true,
        useInInsert: true,
        useInIUpdate: true,
        converter: converter,
        junction: junction,
      );

  final bool useInQuery;
  final bool useInInsert;
  final bool useInIUpdate;
  final bool useInIDelete;

  TypeConverterBase? converter;

  final DbType type;

  final bool nullable;

  /// The table this column belongs to.
  late final Table table;

  /// The raw name of this column
  final String name;

  final JunctionData? junction;
}

/// A type that sql expressions can have at runtime.
enum DbType {
  int,
  real,
  text,
  blob,
  expand,
}
