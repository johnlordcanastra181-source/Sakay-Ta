import 'package:intl/intl.dart';

class Formatters {
  static final _peso = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  );

  static final _pesoCompact = NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 0,
  );

  static String peso(double value) => _peso.format(value);

  static String pesoCompact(double value) => _pesoCompact.format(value);

  static String phone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length != 12 && digits.length != 11) return raw;
    final d = digits.length == 12 ? digits.substring(1) : digits;
    return '+63 ${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }

  static String shortDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  static String shortTime(DateTime date) => DateFormat('h:mm a').format(date);

  static String fullDateTime(DateTime date) =>
      DateFormat('MMM d, yyyy · h:mm a').format(date);

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(date);
  }
}
