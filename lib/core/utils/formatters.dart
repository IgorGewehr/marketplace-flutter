import 'package:intl/intl.dart';

/// Formatters for currency, date, phone, and other common formatting needs
class Formatters {
  Formatters._();

  // === Currency Formatters ===
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final NumberFormat _currencyCompactFormat = NumberFormat.compactCurrency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 0,
  );

  /// Format value as Brazilian Real (R$)
  static String currency(double value) {
    return _currencyFormat.format(value);
  }

  /// Format value as compact currency (R$ 1.5K, R$ 2M)
  static String currencyCompact(double value) {
    return _currencyCompactFormat.format(value);
  }

  /// Format cents to currency
  static String currencyFromCents(int cents) {
    return currency(cents / 100);
  }

  // === Date Formatters ===
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'pt_BR');
  static final DateFormat _shortDateFormat = DateFormat('dd/MM', 'pt_BR');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'pt_BR');
  static final DateFormat _dayMonthFormat = DateFormat('dd MMM', 'pt_BR');
  static final DateFormat _isoFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");

  /// Format date as dd/MM/yyyy
  static String date(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Format date with time as dd/MM/yyyy HH:mm
  static String dateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  /// Format time as HH:mm
  static String time(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Format as short date dd/MM
  static String shortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  /// Format as month and year (Janeiro 2024)
  static String monthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  /// Format as day and short month (15 Jan)
  static String dayMonth(DateTime date) {
    return _dayMonthFormat.format(date);
  }

  /// Format as relative time (há 5 minutos, há 2 horas, ontem, etc)
  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'agora';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'há $minutes ${minutes == 1 ? 'minuto' : 'minutos'}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'há $hours ${hours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inDays == 1) {
      return 'ontem';
    } else if (difference.inDays < 7) {
      return 'há ${difference.inDays} dias';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'há $weeks ${weeks == 1 ? 'semana' : 'semanas'}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'há $months ${months == 1 ? 'mês' : 'meses'}';
    } else {
      return _dateFormat.format(date);
    }
  }

  /// Parse ISO 8601 date string
  static DateTime? parseIso(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  /// Format to ISO 8601 string
  static String toIso(DateTime date) {
    return date.toUtc().toIso8601String();
  }

  // === Phone Formatters ===

  /// Format phone number as (XX) XXXXX-XXXX or (XX) XXXX-XXXX
  static String phone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    } else if (digits.length == 13 && digits.startsWith('55')) {
      return '+55 (${digits.substring(2, 4)}) ${digits.substring(4, 9)}-${digits.substring(9)}';
    }

    return phone;
  }

  /// Get only digits from phone
  static String phoneDigitsOnly(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  // === Document Formatters ===

  /// Format CPF as XXX.XXX.XXX-XX
  static String cpf(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return cpf;

    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
  }

  /// Format CNPJ as XX.XXX.XXX/XXXX-XX
  static String cnpj(String cnpj) {
    final digits = cnpj.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14) return cnpj;

    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
  }

  /// Format CPF or CNPJ based on length
  static String cpfCnpj(String document) {
    final digits = document.replaceAll(RegExp(r'\D'), '');
    return digits.length <= 11 ? cpf(document) : cnpj(document);
  }

  // === CEP Formatter ===

  /// Format CEP as XXXXX-XXX
  static String cep(String cep) {
    final digits = cep.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 8) return cep;

    return '${digits.substring(0, 5)}-${digits.substring(5)}';
  }

  // === Number Formatters ===

  /// Format number with thousands separator
  static String number(num value, {int decimalDigits = 0}) {
    return NumberFormat.decimalPattern('pt_BR').format(value);
  }

  /// Format as percentage
  static String percentage(double value, {int decimalDigits = 0}) {
    return NumberFormat.percentPattern('pt_BR').format(value / 100);
  }

  /// Format file size (bytes to KB, MB, GB)
  static String fileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  // === Text Formatters ===

  /// Capitalize first letter
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Capitalize first letter of each word
  static String titleCase(String text) {
    return text.split(' ').map(capitalize).join(' ');
  }

  /// Truncate text with ellipsis
  static String truncate(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - suffix.length)}$suffix';
  }

  /// Get initials from name (João Silva -> JS)
  static String initials(String name, {int maxLength = 2}) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words.take(maxLength).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    return initials;
  }

  // === Order Number Formatter ===

  /// Format order number as YYYY-XXXXXXX
  static String orderNumber(String orderId, {DateTime? date}) {
    final year = (date ?? DateTime.now()).year;
    final shortId = orderId.length > 7 ? orderId.substring(0, 7).toUpperCase() : orderId.toUpperCase();
    return '$year-$shortId';
  }
}
