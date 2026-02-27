import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nexmarket/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('Formatters', () {
    group('currency', () {
      test('formats currency correctly', () {
        expect(Formatters.currency(10.5), 'R\$\u00A010,50');
        expect(Formatters.currency(1000), 'R\$\u00A01.000,00');
        expect(Formatters.currency(1234.56), 'R\$\u00A01.234,56');
      });

      test('handles zero', () {
        expect(Formatters.currency(0), 'R\$\u00A00,00');
      });

      test('handles negative numbers', () {
        expect(Formatters.currency(-10.5), '-R\$\u00A010,50');
      });
    });

    group('cpf', () {
      test('formats CPF correctly', () {
        expect(Formatters.cpf('11122233344'), '111.222.333-44');
      });

      test('handles already formatted CPF', () {
        expect(Formatters.cpf('111.222.333-44'), '111.222.333-44');
      });

      test('handles invalid length', () {
        expect(Formatters.cpf('123'), '123');
      });
    });

    group('cnpj', () {
      test('formats CNPJ correctly', () {
        expect(Formatters.cnpj('11222333000144'), '11.222.333/0001-44');
      });

      test('handles already formatted CNPJ', () {
        expect(Formatters.cnpj('11.222.333/0001-44'), '11.222.333/0001-44');
      });
    });

    group('phone', () {
      test('formats phone with 9 digits', () {
        expect(Formatters.phone('11999999999'), '(11) 99999-9999');
      });

      test('formats phone with 8 digits', () {
        expect(Formatters.phone('1133334444'), '(11) 3333-4444');
      });

      test('handles already formatted phone', () {
        expect(Formatters.phone('(11) 99999-9999'), '(11) 99999-9999');
      });
    });

    group('cep', () {
      test('formats CEP correctly', () {
        expect(Formatters.cep('12345678'), '12345-678');
      });

      test('handles already formatted CEP', () {
        expect(Formatters.cep('12345-678'), '12345-678');
      });
    });

    group('date', () {
      test('formats date correctly', () {
        final date = DateTime(2024, 1, 15);
        expect(Formatters.date(date), '15/01/2024');
      });
    });

    group('dateTime', () {
      test('formats datetime correctly', () {
        final date = DateTime(2024, 1, 15, 14, 30);
        expect(Formatters.dateTime(date), '15/01/2024 14:30');
      });
    });

    group('relativeTime', () {
      test('returns "agora" for very recent time', () {
        final now = DateTime.now();
        expect(Formatters.relativeTime(now), 'agora');
      });

      test('returns minutes ago', () {
        final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        expect(Formatters.relativeTime(fiveMinutesAgo), 'há 5 minutos');
      });

      test('returns hours ago', () {
        final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
        expect(Formatters.relativeTime(twoHoursAgo), 'há 2 horas');
      });

      test('returns days ago', () {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        expect(Formatters.relativeTime(threeDaysAgo), 'há 3 dias');
      });
    });
  });
}
