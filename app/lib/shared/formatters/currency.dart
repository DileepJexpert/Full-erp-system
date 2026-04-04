import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _currencyDecimalFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

String formatRupee(double amount) => _currencyFormat.format(amount);
String formatRupeeDecimal(double amount) => _currencyDecimalFormat.format(amount);
