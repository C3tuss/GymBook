import 'package:intl/intl.dart';

final NumberFormat _weightFormat = NumberFormat('##0.00', 'pt_BR');
final NumberFormat _signedWeightFormat = NumberFormat('+#,##0.00;-#,##0.00', 'pt_BR');

String formatWeight(double value) => _weightFormat.format(value);

String formatSignedWeight(double value) => _signedWeightFormat.format(value);

String formatDate(DateTime date) => DateFormat('dd/MM/yyyy', 'pt_BR').format(date);

String formatWeekday(DateTime date) =>
    DateFormat('EEEE', 'pt_BR').format(date);

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isFutureDay(DateTime date, {DateTime? today}) =>
    dateOnly(date).isAfter(dateOnly(today ?? DateTime.now()));
