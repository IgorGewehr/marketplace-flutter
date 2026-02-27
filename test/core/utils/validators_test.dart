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

    group('isValidCpf', () {
      test('returns true for valid CPF', () {
        expect(Validators.isValidCpf('529.982.247-25'), true);
        expect(Validators.isValidCpf('52998224725'), true);
      });

      test('returns false for invalid CPF', () {
        expect(Validators.isValidCpf('123.456.789-00'), false);
        expect(Validators.isValidCpf('111.111.111-11'), false);
        expect(Validators.isValidCpf(''), false);
        expect(Validators.isValidCpf('123'), false);
      });
    });

    group('isValidCnpj', () {
      test('returns true for valid CNPJ', () {
        expect(Validators.isValidCnpj('11.222.333/0001-81'), true);
        expect(Validators.isValidCnpj('11222333000181'), true);
      });

      test('returns false for invalid CNPJ', () {
        expect(Validators.isValidCnpj('11.111.111/1111-11'), false);
        expect(Validators.isValidCnpj(''), false);
        expect(Validators.isValidCnpj('123'), false);
      });
    });

    group('isValidPhone', () {
      test('returns true for valid phone', () {
        expect(Validators.isValidPhone('(11) 99999-9999'), true);
        expect(Validators.isValidPhone('11999999999'), true);
        expect(Validators.isValidPhone('1133334444'), true);
      });

      test('returns false for invalid phone', () {
        expect(Validators.isValidPhone('123'), false);
        expect(Validators.isValidPhone(''), false);
      });
    });
  });
}
