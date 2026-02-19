import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    group('formatCurrency', () {
      test('formats currency correctly', () {
        expect(Formatters.formatCurrency(10.5), 'R\$ 10,50');
        expect(Formatters.formatCurrency(1000), 'R\$ 1.000,00');
        expect(Formatters.formatCurrency(1234.56), 'R\$ 1.234,56');
      });

      test('handles zero', () {
        expect(Formatters.formatCurrency(0), 'R\$ 0,00');
      });

      test('handles negative numbers', () {
        expect(Formatters.formatCurrency(-10.5), '-R\$ 10,50');
      });
    });

    group('formatCPF', () {
      test('formats CPF correctly', () {
        expect(Formatters.formatCPF('11122233344'), '111.222.333-44');
      });

      test('handles already formatted CPF', () {
        expect(Formatters.formatCPF('111.222.333-44'), '111.222.333-44');
      });

      test('handles invalid length', () {
        expect(Formatters.formatCPF('123'), '123');
      });
    });

    group('formatCNPJ', () {
      test('formats CNPJ correctly', () {
        expect(Formatters.formatCNPJ('11222333000144'), '11.222.333/0001-44');
      });

      test('handles already formatted CNPJ', () {
        expect(Formatters.formatCNPJ('11.222.333/0001-44'), '11.222.333/0001-44');
      });
    });

    group('formatPhone', () {
      test('formats phone with 9 digits', () {
        expect(Formatters.formatPhone('11999999999'), '(11) 99999-9999');
      });

      test('formats phone with 8 digits', () {
        expect(Formatters.formatPhone('1133334444'), '(11) 3333-4444');
      });

      test('handles already formatted phone', () {
        expect(Formatters.formatPhone('(11) 99999-9999'), '(11) 99999-9999');
      });
    });

    group('formatCEP', () {
      test('formats CEP correctly', () {
        expect(Formatters.formatCEP('12345678'), '12345-678');
      });

      test('handles already formatted CEP', () {
        expect(Formatters.formatCEP('12345-678'), '12345-678');
      });
    });

    group('formatDate', () {
      test('formats date correctly', () {
        final date = DateTime(2024, 1, 15);
        expect(Formatters.formatDate(date), '15/01/2024');
      });
    });

    group('formatDateTime', () {
      test('formats datetime correctly', () {
        final date = DateTime(2024, 1, 15, 14, 30);
        expect(Formatters.formatDateTime(date), '15/01/2024 14:30');
      });
    });

    group('formatRelativeTime', () {
      test('returns "Agora" for very recent time', () {
        final now = DateTime.now();
        expect(Formatters.formatRelativeTime(now), 'Agora');
      });

      test('returns minutes ago', () {
        final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        expect(Formatters.formatRelativeTime(fiveMinutesAgo), '5 min atrás');
      });

      test('returns hours ago', () {
        final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
        expect(Formatters.formatRelativeTime(twoHoursAgo), '2h atrás');
      });

      test('returns days ago', () {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        expect(Formatters.formatRelativeTime(threeDaysAgo), '3d atrás');
      });
    });
  });
}
