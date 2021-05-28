import 'package:floor/src/diff/diff.dart';

class DiffValue extends Diff {
  DiffValue(String property, this.newValue, this.oldValue) : super(property);

  final Object newValue;
  final Object oldValue;

  @override
  String toString() {
    return "DiffValue Property:'$property'; oldValue:'$oldValue' newValue:'$newValue'";
  }
}
