import 'dart:core';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:code_builder/code_builder.dart';
import 'package:floor_generator/misc/annotation_expression.dart';
import 'package:floor_generator/misc/extension/string_extension.dart';
import 'package:floor_generator/misc/extension/type_converters_extension.dart';
import 'package:floor_generator/misc/type_utils.dart';
import 'package:floor_generator/processor/database_processor.dart';
import 'package:floor_generator/processor/error/processor_error.dart';
import 'package:floor_generator/processor/sql_column_processor.dart';
import 'package:floor_generator/value_object/after_query_method.dart';
import 'package:floor_generator/value_object/foreign_key_relation.dart';
import 'package:floor_generator/value_object/junction.dart';
import 'package:floor_generator/value_object/query.dart';
import 'package:floor_generator/value_object/query_method.dart';
import 'package:floor_generator/value_object/queryable.dart';
import 'package:floor_generator/value_object/relation.dart';
import 'package:floor_generator/value_object/view.dart';
import 'package:floor_generator/writer/writer.dart';
import 'package:collection/collection.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/extension/dart_type_extension.dart';
import 'package:sqlparser/sqlparser.dart' as sqlparser;

class QueryMethodWriter implements Writer {
  final QueryMethod _queryMethod;
  final SqlColumnProcessor? _sqlColumnProcessor;
  final List<FieldOfDaoWithAllMethods> _allFieldOfDaoWithAllMethods;
  final List<AfterQueryMethod> afterQueryMethods;

  QueryMethodWriter(final QueryMethod queryMethod,
      {final SqlColumnProcessor? sqlColumnProcessor,
      final List<FieldOfDaoWithAllMethods> allFieldOfDaoWithAllMethods = const [],
      this.afterQueryMethods = const []})
      : _queryMethod = queryMethod,
        _sqlColumnProcessor = sqlColumnProcessor,
        _allFieldOfDaoWithAllMethods = allFieldOfDaoWithAllMethods;

  @override
  Method write() {
    final builder = MethodBuilder()
      ..annotations.add(overrideAnnotationExpression)
      ..returns = refer(_queryMethod.rawReturnType.getDisplayString(
        withNullability: true,
      ))
      ..name = _queryMethod.name
      ..optionalParameters.addAll(_generateMethodParametersOptional())
      ..requiredParameters.addAll(_generateMethodParametersRequired())
      ..body = Code(_generateMethodBody());

    if (!_queryMethod.returnsStream || _queryMethod.returnsVoid) {
      builder..modifier = MethodModifier.async;
    }
    return builder.build();
  }

  List<Parameter> _generateMethodParametersRequired() {
    return _queryMethod.parameters.where((e) => e.isPositional).map((parameter) {
      return Parameter((builder) => builder
        ..name = parameter.name
        ..type = refer(parameter.type.getDisplayString(
          // processor disallows nullable method parameters and throws if found,
          // still interested in nullability here to future-proof codebase
          withNullability: true,
        )));
    }).toList();
  }

  List<Parameter> _generateMethodParametersOptional() {
    return _queryMethod.parameters.where((e) => !e.isPositional).map((parameter) {
      return Parameter((builder) => builder
        ..name = parameter.name
        ..named = parameter.isNamed
        ..required = parameter.isRequiredNamed
        ..defaultTo = parameter.defaultValueCode == null ? null : Code(parameter.defaultValueCode!)
        ..type = refer(parameter.type.getDisplayString(
          // processor disallows nullable method parameters and throws if found,
          // still interested in nullability here to future-proof codebase
          withNullability: true,
        )));
    }).toList();
  }

  String _generateMethodBody() {
    final _methodBody = StringBuffer();

    // generate the variable definitions which will store the sqlite argument
    // lists, e.g. '?5,?6,?7,?8'. These have to be generated for each call to
    // the query method to accommodate for different list sizes. This is
    // necessary to guarantee that each single value is inserted at the right
    // place and only via SQLite's escape-mechanism.
    // If no [List] parameters are present, Nothing will be written.
    _methodBody.write(_generateListConvertersForQuery());

    final arguments = _generateArguments();
    final query = _generateQueryString();

    if (_queryMethod.flattenedReturnType.isDartCoreMap) {
      var parameters = '';
      if (arguments != null) parameters = ', arguments: $arguments';
      _methodBody.writeln('return _queryAdapter.queryMap($query$parameters);');
      return _methodBody.toString();
    }

    final queryable = _queryMethod.queryable;

    if (!_queryMethod.returnsVoid && queryable == null && _sqlColumnProcessor != null) {
      final select = _sqlColumnProcessor!.parserQuery(query.fromLiteral(), _queryMethod.methodElement);
      if (select is sqlparser.SelectStatement) {
        var parameters = '';
        if (arguments != null) parameters = ', arguments: $arguments';

        if (_queryMethod.flattenedReturnType.isDefaultSqlType) {
          _methodBody.writeln('return _queryAdapter.querySingleValue($query$parameters);');
          return _methodBody.toString();
        } else {
          final typeConverter = _queryMethod.typeConverters.getClosestOrNull(_queryMethod.flattenedReturnType);
          if (typeConverter != null) {
            _methodBody.writeln(
                'return ${typeConverter.name.decapitalize()}.decode(_queryAdapter.querySingleValue($query$parameters));');
            return _methodBody.toString();
          }
        }
        // TODO Validar se tem mais de um campo para retorno simples
        // TODO Validar caso o valor de retorno não seja null
        // TODO Validar caso não tenha typeConverter
      }
    }

    // null queryable implies void-returning query method
    if (_queryMethod.returnsVoid || queryable == null) {
      _methodBody.write(_generateNoReturnQuery(query, arguments));
    } else {
      _methodBody.write(_generateQuery(query, arguments, queryable));
    }

    return _methodBody.toString();
  }

  String _generateListConvertersForQuery() {
    final code = StringBuffer();
    // because we ultimately want to give a query with numbered variables to sqflite, we have to compute them dynamically when working with lists.
    // We establish the conventions that we provide the fixed parameters first and then append the list parameters one by one.
    // parameters 1,2,... start-1 are already used by fixed (non-list) parameters.
    final start = _queryMethod.parameters
            .where((param) => !param.type.isDartCoreList && !param.type.isLoadOptions && !param.type.isLoadOptionsEntry)
            .length +
        1;

    String? lastParam;
    for (final listParam in _queryMethod.parameters.where((param) => param.type.isDartCoreList)) {
      if (lastParam == null) {
        //make start final if it is only used once, fixes a lint
        final constInt = (start == _queryMethod.parameters.length) ? 'const' : 'int';
        code.writeln('$constInt offset = $start;');
      } else {
        code.writeln('offset += $lastParam.length;');
      }
      final currentParamName = listParam.displayName;
      // dynamically generate strings of the form '?4,?5,?6,?7,?8' which we can
      // later insert into the query at the marked locations.
      code.write('final _sqliteVariablesFor${currentParamName.capitalize()}=');
      code.write('Iterable<String>.generate(');
      code.write("$currentParamName.length, (i)=>'?\${i+offset}'");
      code.writeln(").join(',');");

      lastParam = currentParamName;
    }
    return code.toString();
  }

  List<String> _generateParameters() {
    //first, take fixed parameters, then insert list parameters.
    return [
      ..._queryMethod.parameters
          .where((parameter) =>
              !parameter.type.isDartCoreList && !parameter.type.isLoadOptions && !parameter.type.isLoadOptionsEntry)
          .map((parameter) {
        if (parameter.type.isDefaultSqlType) {
          if (parameter.type.isDartCoreBool) {
            // query method parameters can't be null
            return '${parameter.displayName} ? 1 : 0';
          } else {
            return parameter.displayName;
          }
        } else if (parameter.type.element is EnumElement) {
          return parameter.displayName + '.value';
        } else {
          final typeConverter = _queryMethod.typeConverters.getClosest(parameter.type);
          return '${typeConverter.name.decapitalize()}.encode(${parameter.displayName})';
        }
      }),
      ..._queryMethod.parameters.where((parameter) => parameter.type.isDartCoreList).map((parameter) {
        // TODO #403 what about type converters that map between e.g. string and list?
        final DartType flatType = parameter.type.flatten();
        if (flatType.isDefaultSqlType) {
          return '...${parameter.displayName}';
        } else {
          final typeConverter = _queryMethod.typeConverters.getClosest(flatType);
          return '...${parameter.displayName}.map((element) => ${typeConverter.name.decapitalize()}.encode(element))';
        }
      })
    ];
  }

  String? _generateArguments() {
    final parameters = _generateParameters();
    return parameters.isNotEmpty ? '[${parameters.join(', ')}]' : null;
  }

  String _generateQueryString() {
    final code = StringBuffer();
    int start = 0;
    final originalQuery = _queryMethod.query.sql;

    var tableName = '';
    final flattenedReturnTypeElement = _queryMethod.flattenedReturnType.element;
    if (flattenedReturnTypeElement is ClassElement) {
      tableName = flattenedReturnTypeElement.tableName();
    } else {
      if (originalQuery.contains(r'$table_name_of_return_type')) {
        throw ProcessorError(
          message:
              r'The $table_name_of_return_type variable in the query string cannot be used when the method return is not an entity',
          todo: r'Make the de value return one entity or remove $table_name_of_return_type in query string.',
          element: flattenedReturnTypeElement ?? _queryMethod.rawReturnType.element!,
        );
      }
    }

    for (final listParameter in _queryMethod.query.listParameters) {
      code.write(originalQuery
          .substring(start, listParameter.position)
          .replaceAll(r'$table_name_of_return_type', tableName)
          .toLiteral());
      code.write(' + _sqliteVariablesFor${listParameter.name.capitalize()} + ');
      start = listParameter.position + varlistPlaceholder.length;
    }
    code.write(originalQuery.substring(start).replaceAll(r'$table_name_of_return_type', tableName).toLiteral());

    return code.toString();
  }

  String _generateNoReturnQuery(final String query, final String? arguments) {
    final parameters = StringBuffer(query);
    if (arguments != null) parameters.write(', arguments: $arguments');
    return 'await _queryAdapter.queryNoReturn($parameters);';
  }

  String _generateQuery(
    final String query,
    final String? arguments,
    final Queryable queryable,
  ) {
    final mapper = _generateMapper(queryable);
    final parameters = StringBuffer(query)..write(', mapper: $mapper');
    if (arguments != null) parameters.write(', arguments: $arguments');

    if (afterQueryMethods.isNotEmpty) {
      if (afterQueryMethods.length == 1) {
        parameters.write(', afterQuery: super.${afterQueryMethods[0].name}');
      } else {
        parameters.write(''', afterQuery: (entities, loadOptions) async {
        ${afterQueryMethods.map((e) => 'entities = await super.${e.name}(entities, loadOptions);').join('\n')}
        return entities;
      }''');
      }
    }

    if (_queryMethod.returnsStream) {
      // for streamed queries, we need to provide the queryable to know which
      // entity to monitor. For views, we monitor all entities.
      parameters
        ..write(", queryableName: '${queryable.name}'")
        ..write(', isView: ${queryable is View}');
    }

    final loadOptionsParam =
        _queryMethod.parameters.firstWhereOrNull((param) => param.type.isLoadOptions || param.type.isLoadOptionsEntry);
    if (loadOptionsParam != null) {
      if (_sqlColumnProcessor == null) {
        throw Exception('Não foi informado _sqlColumnProcessor para processar as colunas para o loadOptions');
      }

      parameters.write(', loadOptions: ${loadOptionsParam.name}');

      final select = _sqlColumnProcessor!.parserSelect(query.fromLiteral(), _queryMethod.methodElement);

      final queryInfoParameters = StringBuffer();

      final sqlColumns = StringBuffer();
      final mapColumns = _sqlColumnProcessor!.getColumns(select);
      for (var field in mapColumns.entries) {
        sqlColumns.writeln(
            'ColumnSql(${_queryMethod.flattenedReturnType.getDisplayString(withNullability: false)}Schema.col${field.key.firstCharToUpper()}, sqlField: \'${field.value}\'),');
      }
      final additionalFieldForFilter =
          _queryMethod.queryable?.fieldsAll.where((element) => element.junction != null) ?? [];
      for (var field in additionalFieldForFilter) {
        sqlColumns.writeln(
            'ColumnSql(${_queryMethod.flattenedReturnType.getDisplayString(withNullability: false)}Schema.col${field.name.firstCharToUpper()}, sqlField: \'\'),');
      }
      queryInfoParameters.writeln('columns: [$sqlColumns],');

      final fieldsQuery = _queryMethod.queryable?.fieldsQuery;
      if (fieldsQuery == null) {
        throw ProcessorError(
          message: 'Não foi encontrado os fields para query desse tipo',
          todo: 'Abra uma issue para o concerto do prooblema.',
          element: _queryMethod.methodElement,
        );
      }
      final fieldsEmbeddeds = _queryMethod.queryable!.embeddeds.expand((e) => e.fields);

      for (var field in fieldsQuery) {
        if (mapColumns.containsKey(field.columnName)) {
          continue;
        }
        throw ProcessorError(
          message:
              'O query não contêm o campo para o preenchimento do propriedade ${field.name} da entidade ${_queryMethod.flattenedReturnType.getDisplayString(withNullability: false)}.',
          todo: 'Considere colocar a coluna no query ou ignorar a coluna na entidade.',
          element: _queryMethod.methodElement,
        );
      }
      for (var field in fieldsEmbeddeds) {
        if (mapColumns.containsKey(field.columnName)) {
          continue;
        }
        throw ProcessorError(
          message:
              'O query não contêm o campo para o preenchimento do propriedade embedded ${field.name} da entidade ${_queryMethod.flattenedReturnType.getDisplayString(withNullability: false)}.',
          todo: 'Considere colocar a coluna no query ou ignorar a coluna na entidade.',
          element: _queryMethod.methodElement,
        );
      }

      for (var columnName in mapColumns.keys) {
        if (fieldsQuery.any((e) => e.columnName == columnName) ||
            fieldsEmbeddeds.any((e) => e.columnName == columnName)) {
          continue;
        }
        throw ProcessorError(
          message: 'O query tem como retorno o campo $columnName, mas não está sendo utilizado.',
          todo: 'Retire o campo do query ou adicione na entidade.',
          element: _queryMethod.methodElement,
        );
      }

      var whereClauseStartIndex = 0;
      final columns = select.columns;
      if (columns.isNotEmpty && columns.first.span != null) {
        final offsetStart = columns.first.span!.start.offset;
        // TODO Tem de somar mais um parece que o index da biblioteca está errado
        final offsetEnd = columns.last.span!.end.offset + 1;
        queryInfoParameters.writeln('columnsIndex: const RangeIndex($offsetStart, $offsetEnd),');
        whereClauseStartIndex = offsetEnd;
      }

      if (select.from?.span != null) {
        whereClauseStartIndex = select.from!.span!.end.offset + 1;
      }

      if (select.orderBy?.span != null) {
        final span = select.orderBy!.span!;
        queryInfoParameters
            .writeln('orderByClauseIndex: const RangeIndex(${span.start.offset + 1}, ${span.end.offset + 1}),');
        if (whereClauseStartIndex == 0) {
          whereClauseStartIndex = span.start.offset + 1;
        }
      }

      if (select.limit?.span != null) {
        final span = select.limit!.span!;
        queryInfoParameters
            .writeln('limitClauseIndex: const RangeIndex(${span.start.offset + 1}, ${span.end.offset + 1}),');
        if (whereClauseStartIndex == 0) {
          whereClauseStartIndex = span.start.offset + 1;
        }
      }

      if (select.where?.span != null) {
        final span = select.where!.span!;
        queryInfoParameters
            .writeln('whereClauseIndex: const RangeIndex($whereClauseStartIndex, ${span.end.offset + 1}),');
      }

      if (select.where?.span != null) {
        final span = select.where!.span!;
        queryInfoParameters
            .writeln('whereExpressionIndex: const RangeIndex(${span.start.offset + 1}, ${span.end.offset + 1}),');
      }

      final expands = StringBuffer();
      final relations =
          _queryMethod.queryable?.fieldsAll.where((element) => element.relation != null).map((e) => e.relation!) ?? [];
      if (relations.isNotEmpty) {
        expands.writeln(_writeRelationsExpand(relations));
      }
      final junctions =
          _queryMethod.queryable?.fieldsAll.where((element) => element.junction != null).map((e) => e.junction!) ?? [];
      if (junctions.isNotEmpty) {
        expands.writeln(_writeJunctionsExpand(junctions));
      }
      final foreignKeyRelations = _queryMethod.queryable?.fieldsAll
              .where((element) => element.foreignKeyRelation != null)
              .map((e) => e.foreignKeyRelation!) ??
          [];
      if (foreignKeyRelations.isNotEmpty) {
        expands.writeln(_writeForeignKeyRelationsExpand(foreignKeyRelations));
      }
      if (expands.isNotEmpty) {
        queryInfoParameters.writeln('expand: [$expands],');
      }

      parameters
        ..write(
            ', queryInfo: QueryInfo<${_queryMethod.flattenedReturnType.getDisplayString(withNullability: false)}>($queryInfoParameters),');
    }

    final list = _queryMethod.returnsList ? 'List' : '';
    final stream = _queryMethod.returnsStream ? 'Stream' : '';

    return 'return _queryAdapter.query$list$stream($parameters);';
  }

  String _writeJunctionsExpand(Iterable<Junction> junctions) {
    final str = StringBuffer();
    for (final junction in junctions) {
      str.writeln(_writeJunctionExpand(junction));
    }
    return str.toString();
  }

  String _writeJunctionExpand(Junction junction) {
    final name = junction.nameProperty;
    final junctionFieldForeignKeyParent = junction.foreignKeyJunctionParent.childColumns[0];
    final primaryKeyParent = junction.foreignKeyJunctionParent.parentColumns[0];
    final junctionFieldForeignKeyChild = junction.foreignKeyJunctionChild.childColumns[0];
    final primaryKeyChild = junction.foreignKeyJunctionChild.parentColumns[0];
    final parentClassName = junction.parentElement.name;

    final junctionClass = junction.entityJunction.classElement;
    final fieldQueryDaoJunction = _findMethodLoadWithLoadOptions(junctionClass);
    if (fieldQueryDaoJunction == null) {
      throw ProcessorError(
        message:
            'The type ${junctionClass.getDisplayString(withNullability: false)} not have DAO with method @Query with return list and parameter with LoadOptions.',
        todo:
            'Create DAO with method @Query with return List<${junctionClass.getDisplayString(withNullability: false)}> and parameter LoadOptions.',
        element: junction.fieldElement,
      );
    }

    final childClass = junction.childElement;
    final fieldQueryDaoChild = _findMethodLoadWithLoadOptions(childClass);
    if (fieldQueryDaoChild == null) {
      throw ProcessorError(
        message:
            'The type ${childClass.getDisplayString(withNullability: false)} not have DAO with method @Query with return list and parameter with LoadOptions.',
        todo:
            'Create DAO with method @Query with return List<${childClass.getDisplayString(withNullability: false)}> and parameter LoadOptions.',
        element: junction.fieldElement,
      );
    }

    final String methodFilter;
    final String methodFilterResultCast;
    if (junction.fieldElement.type.isDartCoreList) {
      methodFilter = 'where';
      methodFilterResultCast = '.toList()';
    } else if (junction.fieldElement.type.isNullable) {
      methodFilter = 'firstWhereOrNull';
      methodFilterResultCast = '';
    } else {
      methodFilter = 'firstWhere';
      methodFilterResultCast = '';
    }

    return '''ExpandInfoSql<$parentClassName>('$name', (entities, expand, expandChild) async {
          final filterRelation = ['$junctionFieldForeignKeyParent', 'in', entities.map((e) => e.$primaryKeyParent).toList()];
          final relations = await floorDatabase.${fieldQueryDaoJunction.field.name}.${fieldQueryDaoChild.method.name}(LoadOptionsEntry(filter: filterRelation));
          final filterChildren = ['$primaryKeyChild', 'in', relations.map((e) => e.$junctionFieldForeignKeyChild).toList()];
          if (expand.filter?.isNotEmpty ?? false) {
            filterChildren.add(expand.filter!);
          }
          final loadOptions = LoadOptionsEntry(expand: expandChild, filter: filterChildren);
          if (expand.sort != null) {
            loadOptions.sort = expand.sort;
          }
          final children = await floorDatabase.${fieldQueryDaoChild.field.name}.${fieldQueryDaoChild.method.name}(loadOptions);
          if (children.isNotEmpty) {
            for (final entry in entities) {
              entry.$name =
                  children.$methodFilter((e) => relations.any((r) => r.$junctionFieldForeignKeyChild == e.$primaryKeyChild && r.$junctionFieldForeignKeyParent == entry.$primaryKeyParent))$methodFilterResultCast;
            }
          }
        }),''';
  }

  String _writeRelationsExpand(Iterable<Relation> relations) {
    final str = StringBuffer();
    for (final relation in relations) {
      str.writeln(_writeRelationExpand(relation));
    }
    return str.toString();
  }

  String _writeRelationExpand(Relation relation) {
    final name = relation.nameProperty;
    final parentClass = relation.parentElement;
    final childFieldForeignKey = relation.foreignKey.childColumns[0];
    final parentFieldForeignKey = relation.foreignKey.parentColumns[0];
    // TODO Validar no relation para as relações terem somente um campo

    final fieldQueryDao = _findMethodLoadWithLoadOptions(relation.childElement);
    if (fieldQueryDao == null) {
      throw ProcessorError(
        message:
            'The type ${relation.childElement.getDisplayString(withNullability: false)} not have DAO with method @Query with return list and parameter with LoadOptions.',
        todo:
            'Create DAO with method @Query with return List<${relation.childElement.getDisplayString(withNullability: false)}> and parameter LoadOptions.',
        element: relation.fieldElement,
      );
    }

    final String methodFilterResultCast;
    final String methodFilter;
    if (relation.fieldElement.type.isDartCoreList) {
      methodFilter = 'where';
      methodFilterResultCast = '.toList()';
    } else if (relation.fieldElement.type.isNullable) {
      methodFilter = 'firstWhereOrNull';
      methodFilterResultCast = '';
    } else {
      methodFilter = 'firstWhere';
      methodFilterResultCast = '';
    }
    return '''            ExpandInfoSql<${parentClass.name}>('$name', (entities, expand, expandChild) async {
              final filterChildren = ['$childFieldForeignKey', 'in', entities.map((e) => e.$parentFieldForeignKey).toList()];
              if (expand.filter?.isNotEmpty ?? false) {
                filterChildren.add(expand.filter!);
              }
              final loadOptions = LoadOptionsEntry(expand: expandChild, filter: filterChildren);
              if (expand.sort != null) {
                loadOptions.sort = expand.sort;
              }
              final children = await floorDatabase.${fieldQueryDao.field.name}.${fieldQueryDao.method.name}(loadOptions);
              if (children.isNotEmpty) {
                for (final entry in entities) {
                  entry.$name = children.$methodFilter((e) => e.$childFieldForeignKey == entry.$parentFieldForeignKey)$methodFilterResultCast;
                }
              }
            }),''';
  }

  FieldOfDaoWithAllMethods? _findMethodLoadWithLoadOptions(Element element) {
    return _allFieldOfDaoWithAllMethods.firstWhereOrNull((e) {
      if (!e.method.hasAnnotation(annotations.Query)) {
        return false;
      }
      if (e.method.parameters.length != 1) {
        return false;
      }

      final parameter = e.method.parameters[0];
      if (!parameter.type.isLoadOptions && !parameter.type.isLoadOptionsEntry) {
        return false;
      }

      var returnType = e.method.returnType;
      if (returnType.isDartAsyncFuture) {
        returnType = returnType.flatten();
      }

      if (!returnType.isDartCoreList || returnType.flatten().element != element) {
        return false;
      }

      return true;
    });
  }

  String _writeForeignKeyRelationsExpand(Iterable<ForeignKeyRelation> foreignKeyRelations) {
    final str = StringBuffer();
    for (final foreignKeyRelation in foreignKeyRelations) {
      str.writeln(_writeForeignKeyRelationExpand(foreignKeyRelation));
    }
    return str.toString();
  }

  String _writeForeignKeyRelationExpand(ForeignKeyRelation foreignKeyRelation) {
    final name = foreignKeyRelation.nameProperty;
    final childClass = foreignKeyRelation.childElement;
    final childFieldForeignKey = foreignKeyRelation.foreignKey.childColumns[0];
    final parentFieldForeignKey = foreignKeyRelation.foreignKey.parentColumns[0];
    // TODO Validar no relation para as relações terem somente um campo

    final fieldQueryDao = _findMethodLoadWithLoadOptions(foreignKeyRelation.parentElement);
    if (fieldQueryDao == null) {
      throw ProcessorError(
        message:
            'The type ${foreignKeyRelation.parentElement.getDisplayString(withNullability: false)} not have DAO with method @Query with return list and parameter with LoadOptions.',
        todo:
            'Create DAO with method @Query with return List<${foreignKeyRelation.parentElement.getDisplayString(withNullability: false)}> and parameter LoadOptions.',
        element: foreignKeyRelation.fieldElement,
      );
    }

    final String methodFilter;
    if (foreignKeyRelation.fieldElement.type.isNullable) {
      methodFilter = 'firstWhereOrNull';
    } else {
      methodFilter = 'firstWhere';
    }
    return '''            ExpandInfoSql<${childClass.name}>('$name', (entities, expand, expandChild) async {
              final filterChildren = ['$parentFieldForeignKey', 'in', entities.map((e) => e.$childFieldForeignKey).toList()];
              if (expand.filter?.isNotEmpty ?? false) {
                filterChildren.add(expand.filter!);
              }
              final loadOptions = LoadOptionsEntry(expand: expandChild, filter: filterChildren);
              if (expand.sort != null) {
                loadOptions.sort = expand.sort;
              }
              final children = await floorDatabase.${fieldQueryDao.field.name}.${fieldQueryDao.method.name}(loadOptions);
              if (children.isNotEmpty) {
                for (final entry in entities) {
                  entry.$name = children.$methodFilter((e) => e.$parentFieldForeignKey == entry.$childFieldForeignKey);
                }
              }
            }),''';
  }
}

String _generateMapper(Queryable queryable) {
  final constructor = queryable.constructor;
  return '(Map<String, Object?> row) => $constructor';
}
