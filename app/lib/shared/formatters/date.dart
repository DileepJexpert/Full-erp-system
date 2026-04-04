import 'package:intl/intl.dart';

final _dateFormat = DateFormat('d MMM yyyy');
final _timeFormat = DateFormat('h:mm a');
final _dateTimeFormat = DateFormat('d MMM yyyy, h:mm a');
final _monthFormat = DateFormat('MMM yyyy');

String formatDate(DateTime date) => _dateFormat.format(date);
String formatTime(DateTime date) => _timeFormat.format(date);
String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
String formatMonth(DateTime date) => _monthFormat.format(date);
String formatDateApi(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
String formatMonthApi(DateTime date) => DateFormat('yyyy-MM').format(date);
