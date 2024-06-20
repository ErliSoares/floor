import 'package:floor/floor.dart';
import 'package:floor/src/adapter/load_options_compiler/expression_compiler.dart';

class FilterCompiler extends ExpressionCompiler {
  FilterCompiler({
    required String sql,
    required LoadOptions loadOptions,
    required QueryInfo queryInfo,
    required List<Object?> arguments,
  }) : super(sql: sql, loadOptions: loadOptions, queryInfo: queryInfo, arguments: arguments);

  static const String _contains = 'contains',
      _notContains = 'notcontains',
      _startsWith = 'startswith',
      _endsWith = 'endswith',
      _in = 'in',
      _subString = 'substring';

  String compile(List<Object?> filter) {
    if (_isCriteria(filter[0])) {
      return _compileGroup(filter);
    }
    if (_isUnary(filter)) {
      return _compileUnary(filter);
    }
    return _compileBinary(filter);
  }

  String _compileBinary(List<Object?> filter) {
    final hasExplicitOperation = filter.length > 2;

    final operation = hasExplicitOperation ? filter[1].toString().toLowerCase() : '=';
    var value = filter[hasExplicitOperation ? 2 : 1];
    final isStringOperation = operation == _contains ||
        operation == _notContains ||
        operation == _startsWith ||
        operation == _endsWith ||
        operation == _subString;
    final isInOperation = operation == _in;

    final sqlColumn = getSqlColumn(filter[0]!);

    if (sqlColumn.converter != null) {
      value = sqlColumn.converter!.encodeObject(value);
    }

    final junction = sqlColumn.junction;
    if (junction != null) {
      if (!isInOperation) {
        throw Exception('Hoje não é suportado fazer outra operação com um campo junção sem se com o operador IN');
      }
      if (value == null) {
        return '0';
      }
      if (!(value is List)) {
        throw Exception('Não foi definido a lista de valores validos para o filtro com IN().');
      }
      if (value.isEmpty) {
        return '0';
      }

      final inExpression = _compileIn(value);

      return '''(
	SELECT 1
	FROM ${junction.table}
	WHERE ${junction.table}.${junction.tableParentField} = ${junction.parentTable}.${junction.parentTableField}
	AND ${junction.table}.${junction.tableChildField} $inExpression
)''';
    }

    if (isStringOperation) {
      return _compileStringFunction(sqlColumn, operation, value.toString(), filter);
    } else if (isInOperation) {
      if (value == null) {
        return '0';
      }
      if (!(value is List)) {
        throw Exception('Não foi definido a lista de valores validos para o filtro com IN().');
      }
      if (value.isEmpty) {
        return '0';
      }
      return sqlColumn.sqlField + ' ' + _compileIn(value);
    } else {
      final expressionType = _translateBinaryOperation(operation);
      if (value == null) {
        if (expressionType == '=') {
          return '${sqlColumn.sqlField} IS NULL';
        }
        if (expressionType == '<>') {
          return '${sqlColumn.sqlField} IS NOT NULL';
        }
        return '0';
      }

      final valueExpr = addParameterAndGetKey(value);

      return sqlColumn.sqlField + ' ' + expressionType + ' ' + valueExpr;
    }
  }

  String _compileStringFunction(ColumnSql columnSql, String clientOperation, String? value, List<Object?> filter) {
    if (value != null) value = value.toLowerCase();

    final keyParameter = addParameterAndGetKey(value);

    final nameField = columnSql.sqlField;

    switch (clientOperation) {
      case _contains:
        return '$nameField LIKE \'%\' || $keyParameter || \'%\'';
      case _notContains:
        return 'NOT ($nameField LIKE \'%\' || $keyParameter) || \'%\'';
      case _startsWith:
        if (value == null) {
          throw Exception('Condição $clientOperation não suporta valor null.');
        }
        return 'LEFT($nameField,${value.length}) = $keyParameter';
      case _endsWith:
        if (value == null) {
          throw Exception('Condição $clientOperation não suporta valor null.');
        }
        return 'RIGHT($nameField,${value.length}) = $keyParameter';
      case _subString:
        if (filter.length < 5) {
          throw Exception('A operação $clientOperation tem de ter 5 parâmetros.');
        }
        final position = int.tryParse(filter[2]?.toString() ?? '');
        if (position == null) {
          throw Exception('Para a operação $clientOperation o segundo item do array tem de ser um inteiro.');
        }
        final length = int.tryParse(filter[3]?.toString() ?? '');
        if (length == null) {
          throw Exception('Para a operação $clientOperation o terceiro item do array tem de ser um inteiro.');
        }
        return 'SUBSTRING($nameField, $position, $length) = ${filter[4]}';
      default:
        throw Exception('Operação $clientOperation não é suportada.');
    }
  }

  String _compileIn(List value) {
    final strBuffer = StringBuffer();
    strBuffer.write('IN(');
    var firstItem = true;
    for (var item in value) {
      final keyParameter = addParameterAndGetKey(item);
      if (!firstItem) {
        strBuffer.write(',');
      }
      strBuffer.write(keyParameter);
      firstItem = false;
    }
    strBuffer.write(')');
    return strBuffer.toString();
  }

  String _compileGroup(List<Object?> filter) {
    final operands = <String>[];
    var isAnd = true;
    var nextIsAnd = true;

    for (var item in filter) {
      if (item is List && _isCriteria(item)) {
        if (operands.length > 1 && isAnd != nextIsAnd)
          throw Exception('Mixing of and/or is not allowed inside a single group');

        isAnd = nextIsAnd;
        operands.add(compile(item));
        nextIsAnd = true;
      } else {
        nextIsAnd = RegExp('and|&', caseSensitive: false).hasMatch(item.toString());
      }
    }

    final result = StringBuffer();
    final op = isAnd ? 'AND' : 'OR';

    if (!isAnd) {
      result.write('(');
    }
    for (var operand in operands) {
      if (result.length > 1) {
        result.write(' ');
        result.write(op);
        result.write(' ');
      }

      result.write(operand);
    }
    if (!isAnd) {
      result.write(')');
    }
    return result.toString();
  }

  String _compileUnary(List<Object?> filter) {
    return 'NOT (${compile(filter[1] as List)})';
  }

  String _translateBinaryOperation(String clientOperation) {
    switch (clientOperation) {
      case '=':
        return clientOperation;
      case '<>':
        return clientOperation;
      case '>':
        return clientOperation;
      case '>=':
        return clientOperation;
      case '<':
        return clientOperation;
      case '<=':
        return clientOperation;
    }
    throw Exception('Operador $clientOperation não suportado.');
  }

  bool _isCriteria(Object? item) {
    return item is List;
  }

  bool _isUnary(List<Object?> filter) {
    return filter[0]?.toString() == '!';
  }
}
