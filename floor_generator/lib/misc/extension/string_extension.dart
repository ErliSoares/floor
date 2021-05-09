extension StringExtension on String {
  String firstCharToUpper() {
    if (isEmpty) {
      return this;
    }
    return '${this[0].toUpperCase()}${substring(1)}';
  }

/// Returns a copy of this string having its first letter lowercased, or the
  /// original string, if it's empty or already starts with a lower case letter.
  ///
  /// ```dart
  /// print('abcd'.decapitalize()) // abcd
  /// print('Abcd'.decapitalize()) // abcd
  /// ```
  String decapitalize() {
    switch (length) {
      case 0:
        return this;
      case 1:
        return toLowerCase();
      default:
        return this[0].toLowerCase() + substring(1);
    }
  }

  /// Returns a copy of this string having its first letter uppercased, or the
  /// original string, if it's empty or already starts with a upper case letter.
  ///
  /// ```dart
  /// print('abcd'.capitalize()) // Abcd
  /// print('Abcd'.capitalize()) // Abcd
  /// ```
  String capitalize() {
    switch (length) {
      case 0:
        return this;
      case 1:
        return toUpperCase();
      default:
        return this[0].toUpperCase() + substring(1);
    }
  }
}

extension NullableStringExtension on String? {
  /// Converts this string to a literal for
  /// embedding it into source code strings.
  ///
  /// ```dart
  /// print(null.toLiteral())   // null
  /// print('Abcd'.toLiteral()) // 'Abcd'
  /// ```
  String toLiteral() {
    if (this == null) {
      return 'null';
    } else {
      //TODO escape correctly
      return "'$this'";
    }
  }

  /// Remove ['] or ["]
  ///
  /// ```dart
  /// print(null.fromLiteral())   // null
  /// print("'Abcd'".fromLiteral()) // Abcd
  /// ```
  String fromLiteral() {
    if (this == null) {
      return 'null';
    } else {
      //TODO unescape correctly
      if (this!.startsWith('"') && this!.endsWith('"')) {
        return this!.substring(1, this!.length -1);
      }
      if (this!.startsWith('\'') && this!.endsWith('\'')) {
        return this!.substring(1, this!.length -1);
      }
      return this!;
    }
  }
}
