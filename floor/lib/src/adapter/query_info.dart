import 'package:flutter/foundation.dart';

/// Data to process loadOptions
class QueryInfo {
  QueryInfo({
    required this.sqlColumns,
    required this.columnsIndex,
    this.orderByClauseIndex,
    this.groupByClauseIndex,
    this.whereClauseIndex,
    this.whereExpressionIndex,
    this.limitClauseIndex,
  });

  Map<String, String> sqlColumns;

  RangeIndex columnsIndex;

  RangeIndex? orderByClauseIndex;

  RangeIndex? groupByClauseIndex;

  RangeIndex? limitClauseIndex;

  RangeIndex? whereClauseIndex;
  RangeIndex? whereExpressionIndex;
}

/// pair of start and end values
class RangeIndex {
  /// Creates pair of start and end values.
  const RangeIndex(this.start, this.end);

  /// The value of the start.
  final int start;

  /// The value of the end.
  final int end;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is RangeIndex && other.start == start && other.end == end;
  }

  @override
  int get hashCode => start.hashCode ^ end.hashCode;

  @override
  String toString() {
    return '${objectRuntimeType(this, 'RangeIndex')}($start, $end)';
  }
}
