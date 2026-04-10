import 'package:intl/intl.dart';

final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
final shortDateFormat = DateFormat('dd-MMM', 'pt_BR');
final monthYearFormat = DateFormat('MM/yyyy', 'pt_BR');

String formatCurrency(double value) => currencyFormat.format(value);
String formatDate(DateTime date) => dateFormat.format(date);
String formatShortDate(DateTime date) => shortDateFormat.format(date);

const List<String> ufs = [
  'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA',
  'MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN',
  'RS','RO','RR','SC','SP','SE','TO',
];

const List<String> months = [
  'Janeiro','Fevereiro','Março','Abril','Maio','Junho',
  'Julho','Agosto','Setembro','Outubro','Novembro','Dezembro',
];
