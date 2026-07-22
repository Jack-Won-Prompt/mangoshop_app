import 'package:intl/intl.dart';

final _won = NumberFormat('#,###');

/// 12000 -> "12,000원"
String won(num? v) => '${_won.format(v ?? 0)}원';

/// 12000 -> "12,000"
String comma(num? v) => _won.format(v ?? 0);
