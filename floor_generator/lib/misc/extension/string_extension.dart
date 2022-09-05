const int _asciiEnd = 0x7f;

const int _asciiStart = 0x0;

const int _c0End = 0x1f;

const int _c0Start = 0x00;

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
      return "'${escape(this!)}'";
    }
  }

  /// Returns an escaped string.
  ///
  /// Example:
  ///     print(escape("Hello 'world' \n"));
  ///     => Hello \'world\' \n
  String escape(String string) {
    if (string.isEmpty) {
      return string;
    }

    final sb = StringBuffer();

    for (int i = 0; i < string.length; i++) {
      final s = string[i];
      final runes = s.runes;
      if (runes.length == 1) {
        final c = runes.first;
        if (c >= _c0Start && c <= _c0End) {
          switch (c) {
            case 9:
              sb.write('\\t');
              break;
            case 10:
              sb.write('\\n');
              break;
            case 13:
              sb.write('\\r');
              break;
            default:
              sb.write(c);
          }
        } else if (c >= _asciiStart && c <= _asciiEnd) {
          switch (c) {
            case 34:
              sb.write('\\\"');
              break;
            case 36:
              sb.write('\\\$');
              break;
            case 39:
              sb.write("\\\'");
              break;
            case 92:
              sb.write('\\\\');
              break;
            default:
              sb.write(s);
          }
        } else {
          sb.write(s);
        }
      } else {
        // Experimental: Assuming that all clusters does not need to be escaped
        sb.write(s);
      }
    }

    return sb.toString();
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
        return this!.substring(1, this!.length - 1);
      }
      if (this!.startsWith('\'') && this!.endsWith('\'')) {
        return this!.substring(1, this!.length - 1);
      }
      return this!;
    }
  }
}
