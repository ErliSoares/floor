import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:sqlparser/sqlparser.dart' as sqlparser;

class SqlColumnProcessor {
  final _engine = sqlparser.SqlEngine();

  sqlparser.SelectStatement parserSelect(String query, Element element) {
    final result = parserQuery(query, element);
    if (result is! sqlparser.SelectStatement) {
      throw InvalidGenerationSourceError(
        'O SQL informado não é um query de consulta `$query`.',
        todo: 'Altere o SQL para um query',
        element: element,
      );
    }
    return result;
  }

  sqlparser.AstNode parserQuery(String query, Element element) {
    try {
      final result = _engine.analyze(query);
      final errors = result.errors.map((e) => e.message).join(', ');
      if (result.errors.isNotEmpty) {
        throw InvalidGenerationSourceError(
          'Não foi possível analisar a query: `$query`.\nErros: $errors',
          todo: 'Ajuste os erros do SQL',
          element: element,
        );
      }
      return result.root;
    } catch (e) {
      if (e is InvalidGenerationSourceError) {
        rethrow;
      }
      throw InvalidGenerationSourceError(
        'Não foi possível analisar o SQL: `$query`. Erro: ${e.toString()}',
        todo: 'Ajuste os erros do SQL',
        element: element,
      );
    }
  }

  Map<String, String> getColumns(sqlparser.SelectStatement select) {
    final columns = select.columns;
    final scope = select.scope;
    final queryRaw = select.span!.text;

    final sqlColumns = <String, String>{};

    // a select statement can include everything from its sub queries as a
    // result, but also expressions that appear as result columns
    for (final resultColumn in columns) {
      if (resultColumn is sqlparser.StarResultColumn) {
        if (resultColumn.tableName != null) {
          final tableResolver = scope.resolve<sqlparser.ResolvesToResultSet>(resultColumn.tableName!);
          if (tableResolver == null) continue;

          final visibleColumnsForStar = tableResolver.resultSet!.resolvedColumns!.where((e) => e.includedInResults);
          for (var c in visibleColumnsForStar) {
            sqlColumns[c.name] = '${resultColumn.tableName}.${c.name}';
          }
        } else {
          // we have a * column without a table, that resolves to every columns
          // available
          final visibleColumnsForStar = scope.availableColumns.where((e) => e.includedInResults).toList();
          for (var i = 0; i < visibleColumnsForStar.length; i++) {
            final columnFirst = visibleColumnsForStar[i];
            for (var j = i + 1; j < visibleColumnsForStar.length; j++) {
              if (visibleColumnsForStar[j].name == columnFirst.name) {
                throw Exception(
                    'O campo de nome ${columnFirst.name} tem duas vezes na query \'$queryRaw\' não é possível aplicar as operações use table.* ao invés de *');
              }
            }
          }
          for (var c in visibleColumnsForStar) {
            if (c is sqlparser.ExpressionColumn) {
              sqlColumns[c.name] = c.expression!.span!.text;
            } else {
              sqlColumns[c.name] = c.name;
            }
          }
        }
      } else if (resultColumn is sqlparser.ExpressionResultColumn) {
        final expression = resultColumn.expression;
        sqlparser.Column column;

        if (expression is sqlparser.Reference) {
          column = sqlparser.ReferenceExpressionColumn(expression, overriddenName: resultColumn.as);
          sqlColumns[column.name] = resultColumn.expression.span!.text;
        } else {
          final name = _nameOfResultColumn(resultColumn, queryRaw)!;
          column = sqlparser.ExpressionColumn(name: name, expression: resultColumn.expression);
          sqlColumns[column.name] = resultColumn.expression.span!.text;
        }
      } else if (resultColumn is sqlparser.NestedStarResultColumn) {
        throw Exception('Moor extensions is not supported.');
      }
    }
    return sqlColumns;
  }

  String? _nameOfResultColumn(sqlparser.ExpressionResultColumn c, String queryRaw) {
    if (c.as != null) return c.as;

    if (c.expression is sqlparser.Reference) {
      return (c.expression as sqlparser.Reference).columnName;
    }

    // in this case it's just the literal expression. So for instance,
    // "SELECT 3+  5" has a result column called "3+ 5" (consecutive whitespace
    // is removed).
    final span = queryRaw.substring(c.firstPosition, c.lastPosition);
    // todo remove consecutive whitespace
    return span;
  }

  void registerSqlCreateTable(String sql) {
    try {
      final rootNode = _engine.parse(sql).rootNode;
      final tableInducingStatement = rootNode as sqlparser.TableInducingStatement;
      final table = _engine.schemaReader.read(tableInducingStatement);
      // TODO Error https://github.com/simolus3/moor/issues/1194
      _engine.registerTable(table);
    } catch (e) {
      log.warning('Não foi possível registrar o create table `$sql` para analisar.', e);
    }
  }
}
