import 'package:intl/intl.dart';

final _takaFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: '৳',
  decimalDigits: 0,
);

String formatTaka(int amount) => _takaFormat.format(amount);
