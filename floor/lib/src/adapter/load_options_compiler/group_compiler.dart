import 'package:floor/floor.dart';
import 'package:floor/src/adapter/load_options_compiler/expression_compiler.dart';

class GroupCompiler extends ExpressionCompiler {
  GroupCompiler({
    required String sql,
    required LoadOptions loadOptions,
    required QueryInfo queryInfo,
    required List<Object?> arguments,
  }) : super(sql: sql, loadOptions: loadOptions, queryInfo: queryInfo, arguments: arguments);

  String compile(List<GroupingInfo> groupingInfo) {
    final groupByBuffer = StringBuffer();
    var first = true;
    for (var item in groupingInfo) {
      if (item.selector is String && item.selector == '') {
        continue;
      }

      if (!first) {
        groupByBuffer.write(',');
      }

      final columnSql = getSqlColumn(item.selector);
      groupByBuffer.write(_compileExpressionGroup(columnSql.sqlField, item));

      first = false;
    }

    return groupByBuffer.toString();
  }

  String _compileExpressionGroup(String sqlField, GroupingInfo groupingInfo) {
    if (groupingInfo.groupInterval == null) {
      return sqlField;
    }

    switch (groupingInfo.groupInterval!) {
      case GroupInterval.year:
        return 'YEAR($sqlField)';
      case GroupInterval.quarter:
        return 'QUARTER($sqlField)';
      case GroupInterval.month:
        return 'MONTH($sqlField)';
      case GroupInterval.day:
        return 'DAY($sqlField)';
      case GroupInterval.dayOfWeek:
        return 'DAYOFWEEK($sqlField)';
      case GroupInterval.hour:
        return 'HOUR($sqlField)';
      case GroupInterval.minute:
        return 'MINUTE($sqlField)';
      case GroupInterval.second:
        return 'SECOND($sqlField)';
      case GroupInterval.numberInterval:
        if (groupingInfo.numberInterval == null) {
          throw Exception('Ao agrupar numberInterval não pode ser null se groupInterval for igual a numberInterval.');
        }
        return '$sqlField - $sqlField % ${groupingInfo.numberInterval}';
    }
  }
}
