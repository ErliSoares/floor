import 'package:code_builder/code_builder.dart';
import 'package:floor_generator/schema_generator.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('Process entity', () async {
    final classElement = await createClassElement('''
      enum PessoaTipo {
        @Description('Física')
        @EnumValue(1)
        fisica,
        @Description('Jurídica')
        @EnumValue(2)
        juridica,
      }
      
      @entity
      class Person extends PersonBase {
        @primaryKey
        final int id;
      
        final String name;
        
        final DateTime dataHora;
      
        Person(this.id, this.name, [this.dataHora = DateTime.now()]);
      }
      
      @TypeConverters([DateTimeConverter, DateTimeNullableConverter])
      abstract class PersonBase {
        
      }
    
      
      class DateTimeConverter extends TypeConverter<DateTime, String> {
        @override
        DateTime decode(String databaseValue) {
          return DateTime.parse(databaseValue);
        }
      
        @override
        String encode(DateTime value) {
          return value.toIso8601String();
        }
      }
      
      class DateTimeNullableConverter extends TypeConverter<DateTime?, String?> {
        @override
        DateTime? decode(String? databaseValue) {
          if (databaseValue == null) {
            return null;
          }
          return DateTime.parse(databaseValue);
        }
      
        @override
        String? encode(DateTime? value) {
          return value?.toIso8601String();
        }
      }
    ''');

    final code = SchemaGenerator().codeForEntity(classElement);

    final library = Library((builder) {
      builder.body.add(Code(code));
    });

    final actual = library.accept(DartEmitter()).toString();


    const expected = """mixin PersonMixin {
  @ignore
  @JsonKey(ignore: true)
  PersonSchema get schema => PersonSchema.instance;
}

class PersonSchema extends Table {
  PersonSchema._()
      : super(
          name: 'Person',
          columns: [
            colId,
            colName,
            colDataHora
          ],
        );

  static final colId = Column.useAll('id', DbType.int, nullable: false);
  static final colName = Column.useAll('name', DbType.text, nullable: false);
  static final colDataHora = Column.useAll('dataHora', DbType.text, nullable: false);

  static final PersonSchema instance = PersonSchema._();
}""";

    expect(actual, equals(expected));
  });

}