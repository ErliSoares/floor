import '../../../floor.dart';

abstract class ExpressionCompiler {
  ExpressionCompiler({
    required this.sql,
    required this.loadOptions,
    required this.queryInfo,
    required this.arguments,
  });

  final String sql;
  final LoadOptions loadOptions;
  final QueryInfo queryInfo;
  final List<Object?> arguments;

  String addParameterAndGetKey(Object? value) {
    arguments.add(value);
    return '?${arguments.length}';
  }

  String compileAccessorExpression(String expression){
    final expressionSql = queryInfo.sqlColumns[expression];
    if (expressionSql == null) {
      throw Exception('Expression `$expression` is not valid column result in query `$sql`');
    }
    return expressionSql;
  }
}
