import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/validators.dart';
import '../../data/datasources/mp_card_tokenizer.dart';

/// Formulário de cartão de crédito reutilizável com tokenização via Mercado Pago.
///
/// Usado tanto no checkout do buyer quanto na assinatura do seller.
class CardPaymentForm extends StatefulWidget {
  final void Function(String cardTokenId, {String? bin}) onTokenized;
  final bool isLoading;

  const CardPaymentForm({
    super.key,
    required this.onTokenized,
    this.isLoading = false,
  });

  @override
  State<CardPaymentForm> createState() => _CardPaymentFormState();
}

class _CardPaymentFormState extends State<CardPaymentForm> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _documentController = TextEditingController();

  bool _isTokenizing = false;
  String? _error;

  @override
  void dispose() {
    // Clear sensitive data before disposing
    _cardNumberController.clear();
    _cvvController.clear();
    _documentController.clear();
    _cardNumberController.dispose();
    _holderNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _documentController.dispose();
    super.dispose();
  }

  Future<void> _tokenize() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTokenizing = true;
      _error = null;
    });

    try {
      final expiry = _expiryController.text.split('/');
      final month = expiry[0].trim();
      final year = expiry.length > 1 ? expiry[1].trim() : '';

      // Ensure year is 4 digits
      final fullYear = year.length == 2 ? '20$year' : year;

      final result = await MpCardTokenizer.tokenizeCard(
        cardNumber: _cardNumberController.text,
        expirationMonth: month,
        expirationYear: fullYear,
        securityCode: _cvvController.text,
        cardholderName: _holderNameController.text,
        identificationNumber: _documentController.text,
      );

      // Clear sensitive data from controllers after successful tokenization
      _cardNumberController.clear();
      _cvvController.clear();
      _documentController.clear();

      if (mounted) {
        widget.onTokenized(result.tokenId, bin: result.firstSixDigits);
      }
    } on PlatformException catch (e) {
      // Only clear CVV on failure for security; keep card number so user can retry
      _cvvController.clear();
      _holderNameController.clear();
      setState(() {
        _error = e.message ?? 'Erro ao processar cartão';
      });
    } catch (e) {
      _cvvController.clear();
      _holderNameController.clear();
      setState(() {
        _error = 'Erro ao processar cartão. Verifique os dados e tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTokenizing = false;
        });
      }
    }
  }

  /// Luhn algorithm check for credit card number validation
  bool _luhnCheck(String digits) {
    int sum = 0;
    bool alternate = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = widget.isLoading || _isTokenizing;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dados do cartão',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Error banner (above form fields so they remain visible)
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Card number
          TextFormField(
            controller: _cardNumberController,
            decoration: const InputDecoration(
              labelText: 'Número do cartão',
              hintText: '0000 0000 0000 0000',
              prefixIcon: Icon(Icons.credit_card),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              _CardNumberFormatter(),
            ],
            onChanged: (_) {
              if (_error != null) {
                setState(() => _error = null);
              }
            },
            validator: (value) {
              final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
              if (digits.length < 13 || digits.length > 19) {
                return 'Número do cartão inválido';
              }
              if (!_luhnCheck(digits)) return 'Número do cartão inválido';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Holder name
          TextFormField(
            controller: _holderNameController,
            decoration: const InputDecoration(
              labelText: 'Nome no cartão',
              hintText: 'NOME COMO NO CARTÃO',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.trim().length < 2) {
                return 'Nome obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Expiry and CVV row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _expiryController,
                  decoration: const InputDecoration(
                    labelText: 'Validade',
                    hintText: 'MM/AA',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                    _ExpiryFormatter(),
                  ],
                  validator: (value) {
                    if (value == null || value.length < 5) {
                      return 'Validade inválida';
                    }
                    final parts = value.split('/');
                    if (parts.length != 2) return 'Formato MM/AA';
                    final month = int.tryParse(parts[0]);
                    final year = int.tryParse(parts[1]);
                    if (month == null || year == null) return 'Validade inválida';
                    if (month < 1 || month > 12) return 'Mês inválido';
                    final fullYear = year < 100 ? 2000 + year : year;
                    final now = DateTime.now();
                    final expiry = DateTime(fullYear, month + 1, 0);
                    if (expiry.isBefore(now)) return 'Cartão vencido';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _cvvController,
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 3) {
                      return 'CVV inválido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // CPF
          TextFormField(
            controller: _documentController,
            decoration: const InputDecoration(
              labelText: 'CPF do titular',
              hintText: '000.000.000-00',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
              _CpfFormatter(),
            ],
            validator: (value) {
              final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
              if (digits.length != 11) return 'CPF inválido';
              if (!Validators.isValidCpf(digits)) return 'CPF inválido';
              return null;
            },
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : _tokenize,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar cartão'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formatter para número do cartão: 0000 0000 0000 0000
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatter para validade: MM/AA
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length && i < 4; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formatter para CPF: 000.000.000-00
class _CpfFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length && i < 11; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
