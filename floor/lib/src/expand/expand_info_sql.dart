import 'package:floor_annotation/floor_annotation.dart';

class ExpandInfoSql<T> {
  final String nameProperty;
  final Future<void> Function (List<T> entities, List<ExpandInfo> expandChild) process;

  ExpandInfoSql(this.nameProperty, this.process);
}