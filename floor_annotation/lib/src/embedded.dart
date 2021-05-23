class Embedded {
  /// Used for the fields of the embedded object.
  final String prefix;

  final bool saveToSeparateEntity;

  /// By default, prefix is empty.
  const Embedded({this.prefix = '', this.saveToSeparateEntity = false});
}

const embedded = Embedded();
