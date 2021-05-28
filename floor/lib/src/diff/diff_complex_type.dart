import 'package:floor/src/diff/diff_change_action.dart';
import 'package:floor/src/diff/diff.dart';

class DiffComplexType extends Diff {
  DiffComplexType(this.newEntry, this.oldEntry, {List<Diff>? changes, this.changeAction = DiffChangeAction.changed})
      : changes = changes ?? [],
        super(null);

  final DiffChangeAction changeAction;
  final List<Diff> changes;

  final Object newEntry;
  final Object oldEntry;

  @override
  String toString() {
    return "DiffComplexType Property:'$property'; ChangeAction:'$changeAction' Changes.Count:'${changes.length}'";
  }
}
