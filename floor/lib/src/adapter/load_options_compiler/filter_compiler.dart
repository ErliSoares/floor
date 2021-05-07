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

    final clientAccessor = filter[0].toString();
    final clientOperation = hasExplicitOperation ? filter[1].toString().toLowerCase() : '=';
    final clientValue = filter[hasExplicitOperation ? 2 : 1];
    final isStringOperation = clientOperation == _contains ||
        clientOperation == _notContains ||
        clientOperation == _startsWith ||
        clientOperation == _endsWith ||
        clientOperation == _subString;
    final isInOperation = clientOperation == _in;

    final accessorExpr = compileAccessorExpression(clientAccessor);

    String valueReturn;

    if (isStringOperation) {
      valueReturn = _compileStringFunction(accessorExpr, clientOperation, clientValue.toString(), filter);
    } else if (isInOperation) {
      valueReturn = _compileInFunction(accessorExpr, clientValue);
    } else {
      final expressionType = _translateBinaryOperation(clientOperation);
      if (clientValue == null) {
        if (expressionType == '=') {
          return 'ISNULL($accessorExpr)';
        }
        if (expressionType == '<>') {
          return '!ISNULL($accessorExpr)';
        }
        return 'FALSE';
      }

      final valueExpr = addParameterAndGetKey(clientValue);

      valueReturn = accessorExpr + ' ' + expressionType + ' ' + valueExpr;
    }

    return valueReturn;
  }

  String _compileStringFunction(String accessorExpr, String clientOperation, String? value, List<Object?> filter) {
    if (value != null) value = value.toLowerCase();

    final keyParameter = addParameterAndGetKey(value);

    switch (clientOperation) {
      case _contains:
        return 'INSTR($accessorExpr, $keyParameter) > 0';
      case _notContains:
        return 'INSTR($accessorExpr, $keyParameter) = 0';
      case _startsWith:
        if (value == null) {
          throw Exception('Condição $clientOperation não suporta valor null.');
        }
        return 'LEFT($accessorExpr,${value.length}) = $keyParameter';
      case _endsWith:
        if (value == null) {
          throw Exception('Condição $clientOperation não suporta valor null.');
        }
        return 'RIGHT($accessorExpr,${value.length}) = $keyParameter';
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
        return 'SUBSTRING($accessorExpr, $position, $length) = ${filter[4]}';
      default:
        throw Exception('Operação $clientOperation não é suportada.');
    }
  }

  String _compileInFunction(String accessorExpr, Object? value) {
    if (value == null) {
      return 'FALSE';
    }
    if (!(value is List)) {
      throw Exception('Não foi definido a lista de valores validos para o filtro com IN().');
    }
    if (value.isEmpty) {
      return 'FALSE';
    }
    final strBuffer = StringBuffer();
    strBuffer.write(accessorExpr);
    strBuffer.write(' IN(');
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
      final operandJson = item as List;

      if (_isCriteria(operandJson)) {
        if (operands.length > 1 && isAnd != nextIsAnd)
          throw Exception('Mixing of and/or is not allowed inside a single group');

        isAnd = nextIsAnd;
        operands.add(compile(operandJson));
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
    return '!(${compile(filter[1] as List)})';
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
