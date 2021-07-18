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

    final dateStr = 'datetime($sqlField / 1000,\'unixepoch\')';
    switch (groupingInfo.groupInterval!) {
      // TODO  essa divisão por 100 não ficou legal, tinha de vim do converter
      case GroupInterval.year:
        return 'strftime(\'%Y\', $dateStr)';
      case GroupInterval.quarter:
        return 'floor( (strftime(\'%m\', $dateStr) + 2) / 3 )';
      case GroupInterval.month:
        return 'strftime(\'%Y-%m\', $dateStr)';
      case GroupInterval.day:
        return 'strftime(\'%Y-%m-%d\', $dateStr)';
      case GroupInterval.dayOfWeek:
        return 'strftime(\'%w\', $dateStr)';
      case GroupInterval.weekOfYear:
        return 'strftime(\'%W\', $dateStr)';
      case GroupInterval.hour:
        return 'strftime(\'%H\', $dateStr)';
      case GroupInterval.minute:
        return 'strftime(\'%M\', $dateStr)';
      case GroupInterval.second:
        return 'strftime(\'%S\', $dateStr)';
      case GroupInterval.numberInterval:
        if (groupingInfo.numberInterval == null) {
          throw Exception('Ao agrupar numberInterval não pode ser null se groupInterval for igual a numberInterval.');
        }
        return '$sqlField - $sqlField % ${groupingInfo.numberInterval}';
    }
  }
}
