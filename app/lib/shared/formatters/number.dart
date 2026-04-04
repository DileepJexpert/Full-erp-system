import 'package:intl/intl.dart';

final _indianNumberFormat = NumberFormat('#,##,###', 'en_IN');

String formatIndianNumber(int number) => _indianNumberFormat.format(number);
String formatPercentage(double value) => '${(value * 100).toStringAsFixed(1)}%';
String formatDecimal(double value) => value.toStringAsFixed(2);
