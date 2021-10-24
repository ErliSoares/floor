import 'package:floor/floor.dart';

class EnumConverter extends TypeConverter<Object?, int?> {
  final Map<Object, int> enumMap;

  const EnumConverter(this.enumMap);

  @override
  Object? decode(int? databaseValue) {
    if (databaseValue == null) {
      return null;
    }
    for (final entry in enumMap.entries) {
      if (entry.value == databaseValue) {
        return entry.key;
      }
    }
    throw Exception('Value $databaseValue not converted valid enum');
  }

  @override
  int? encode(Object? value) {
    if (value == null) {
      return null;
    }
    final valueResult = enumMap[value];
    if (valueResult == null) {
      throw Exception('Value $value not converted valid enum');
    }
    return valueResult;
  }
}
