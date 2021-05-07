import 'package:floor/floor.dart';
import 'package:floor/src/adapter/load_options_compiler/expression_compiler.dart';

class SortCompiler extends ExpressionCompiler {
  SortCompiler({
    required String sql,
    required LoadOptions loadOptions,
    required QueryInfo queryInfo,
    required List<Object?> arguments,
  }) : super(sql: sql, loadOptions: loadOptions, queryInfo: queryInfo, arguments: arguments);

  String compile(List<SortingInfo> orderBy) {
    final orderByBuffer = StringBuffer();
    var first = true;
    for (var item in orderBy) {
      if (item.selector == '') continue;

      if (!first) {
        orderByBuffer.write(',');
      }

      final accessorExpr = compileAccessorExpression(item.selector);
      orderByBuffer.write(accessorExpr);

      if (item.desc) {
        orderByBuffer.write(' ');
        orderByBuffer.write('DESC');
      }
      first = false;
    }

    return orderByBuffer.toString();
  }
}
