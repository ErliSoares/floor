import 'package:analyzer/dart/element/element.dart';
import 'package:build_test/build_test.dart';
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/processor/field_processor.dart';
import 'package:floor_generator/value_object/field.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  test('Process field', () async {
    final fieldElement = await _generateFieldElement();

    final actual = FieldProcessor(fieldElement, null).process();

    const name = 'id';
    const columnName = 'id';
    const isNullable = false;
    const sqlType = SqlType.integer;
    final expected = Field(
      fieldElement,
      name,
      columnName,
      isNullable,
      sqlType,
      null,
    );
    expect(actual, equals(expected));
  });
}

Future<FieldElement> _generateFieldElement() async {
  final library = await resolveSource('''
    library test;
  
    import 'package:floor_annotation/floor_annotation.dart';
    
    @Entity(
      tableName: 'pessoa',
    )
    class PessoaEntry {
      PessoaEntry({
        this.id = 0,
        this.name,
        this.enderecos = const [],
      });
    
      @Junction(PessoaEnderecoEntry)
      List<EnderecoEntry> enderecos;
    
      @PrimaryKey(autoGenerate: true)
      int id;
    
      String? name;
    }
    
    @Entity(
      tableName: 'pessoa_endereco',
      primaryKeys: ['pessoaId', 'enderecoId'],
      foreignKeys: [
        ForeignKey(
          childColumns: ['pessoaId'],
          parentColumns: ['id'],
          entity: PessoaEntry,
        ),
        ForeignKey(
          childColumns: ['enderecoId'],
          parentColumns: ['id'],
          entity: EnderecoEntry,
        ),
      ],
    )
    class PessoaEnderecoEntry {
      PessoaEnderecoEntry({
        this.pessoaId = 0,
        this.enderecoId = 0,
      });
    
      int pessoaId;
    
      int enderecoId;
    }
    
    @Entity(
      tableName: 'endereco',
    )
    class EnderecoEntry {
      EnderecoEntry({
        this.id = 0,
        this.name,
      });
    
      @PrimaryKey(autoGenerate: true)
      int id;
    
      String? name;
    }
      ''', (resolver) async {
    return LibraryReader((await resolver.findLibraryByName('test'))!);
  });

  return library.classes.first.fields.first;
}
