import 'package:flutter_test/flutter_test.dart';
import 'package:nexmarket/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('isValidEmail', () {
      test('returns true for valid email', () {
        expect(Validators.isValidEmail('test@example.com'), true);
        expect(Validators.isValidEmail('user.name@domain.co'), true);
        expect(Validators.isValidEmail('user+tag@example.com'), true);
      });

      test('returns false for invalid email', () {
        expect(Validators.isValidEmail('invalid'), false);
        expect(Validators.isValidEmail('invalid@'), false);
        expect(Validators.isValidEmail('@invalid.com'), false);
        expect(Validators.isValidEmail(''), false);
      });
    });

    group('isValidCPF', () {
      test('returns true for valid CPF', () {
        expect(Validators.isValidCPF('111.222.333-44'), true);
        expect(Validators.isValidCPF('11122233344'), true);
      });

      test('returns false for invalid CPF', () {
        expect(Validators.isValidCPF('123.456.789-00'), false);
        expect(Validators.isValidCPF('111.111.111-11'), false);
        expect(Validators.isValidCPF(''), false);
        expect(Validators.isValidCPF('123'), false);
      });
    });

    group('isValidCNPJ', () {
      test('returns true for valid CNPJ', () {
        expect(Validators.isValidCNPJ('11.222.333/0001-44'), true);
        expect(Validators.isValidCNPJ('11222333000144'), true);
      });

      test('returns false for invalid CNPJ', () {
        expect(Validators.isValidCNPJ('11.111.111/1111-11'), false);
        expect(Validators.isValidCNPJ(''), false);
        expect(Validators.isValidCNPJ('123'), false);
      });
    });

    group('isValidPhone', () {
      test('returns true for valid phone', () {
        expect(Validators.isValidPhone('(11) 99999-9999'), true);
        expect(Validators.isValidPhone('11999999999'), true);
        expect(Validators.isValidPhone('+55 11 99999-9999'), true);
      });

      test('returns false for invalid phone', () {
        expect(Validators.isValidPhone('123'), false);
        expect(Validators.isValidPhone(''), false);
      });
    });

    group('isValidCEP', () {
      test('returns true for valid CEP', () {
        expect(Validators.isValidCEP('12345-678'), true);
        expect(Validators.isValidCEP('12345678'), true);
      });

      test('returns false for invalid CEP', () {
        expect(Validators.isValidCEP('123'), false);
        expect(Validators.isValidCEP(''), false);
      });
    });

    group('isValidPrice', () {
      test('returns true for valid price', () {
        expect(Validators.isValidPrice('10.50'), true);
        expect(Validators.isValidPrice('100'), true);
        expect(Validators.isValidPrice('0.01'), true);
      });

      test('returns false for invalid price', () {
        expect(Validators.isValidPrice('0'), false);
        expect(Validators.isValidPrice('-10'), false);
        expect(Validators.isValidPrice('abc'), false);
        expect(Validators.isValidPrice(''), false);
      });
    });
  });
}
