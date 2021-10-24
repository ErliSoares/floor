import 'package:floor/src/diff/diff.dart';
import 'package:floor/src/diff/diff_complex_type.dart';

class DiffList extends Diff {
  DiffList(String property, this.changes) : super(property);

  final List<DiffComplexType> changes;

  @override
  String toString() {
    return "DiffList Property:'$property'; Changes.Count:'${changes.length}'";
  }
}
