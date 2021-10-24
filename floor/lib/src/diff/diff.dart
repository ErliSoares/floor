abstract class Diff {
  Diff(this.property);

  final String? property;

  @override
  String toString() {
    return "Property:'$property'";
  }
}
