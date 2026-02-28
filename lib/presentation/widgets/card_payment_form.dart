import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  void initState() {
    super.initState();
    _cardNumberController.addListener(_onFieldChanged);
    _holderNameController.addListener(_onFieldChanged);
    _expiryController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    _cardNumberController.removeListener(_onFieldChanged);
    _holderNameController.removeListener(_onFieldChanged);
    _expiryController.removeListener(_onFieldChanged);
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

  String _getCardBrand(String digits) {
    if (digits.startsWith('4')) return 'visa';
    if (digits.startsWith('5') || digits.startsWith('2')) return 'master';
    if (digits.startsWith('3')) return 'amex';
    if (digits.startsWith('6')) return 'elo';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = widget.isLoading || _isTokenizing;
    final cardDigits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final brand = _getCardBrand(cardDigits);

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

          // Card preview
          _CardPreview(
            cardNumber: _cardNumberController.text,
            holderName: _holderNameController.text,
            expiry: _expiryController.text,
            brand: brand,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, curve: Curves.easeOut),
          const SizedBox(height: 24),

          // Error banner
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms).shake(hz: 2, offset: const Offset(4, 0)),
            const SizedBox(height: 16),
          ],

          // Card number
          _StyledFormField(
            controller: _cardNumberController,
            label: 'Número do cartão',
            hint: '0000 0000 0000 0000',
            icon: Icons.credit_card_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19),
              _CardNumberFormatter(),
            ],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            validator: (value) {
              final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
              if (digits.length < 13 || digits.length > 19) {
                return 'Número do cartão inválido';
              }
              if (!_luhnCheck(digits)) return 'Número do cartão inválido';
              return null;
            },
            suffix: brand.isNotEmpty
                ? _CardBrandIcon(brand: brand)
                : null,
          ),
          const SizedBox(height: 14),

          // Holder name
          _StyledFormField(
            controller: _holderNameController,
            label: 'Nome no cartão',
            hint: 'NOME COMO NO CARTÃO',
            icon: Icons.person_outline,
            textCapitalization: TextCapitalization.characters,
            validator: (value) {
              if (value == null || value.trim().length < 2) {
                return 'Nome obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // Expiry and CVV row
          Row(
            children: [
              Expanded(
                child: _StyledFormField(
                  controller: _expiryController,
                  label: 'Validade',
                  hint: 'MM/AA',
                  icon: Icons.calendar_today_outlined,
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
                child: _StyledFormField(
                  controller: _cvvController,
                  label: 'CVV',
                  hint: '123',
                  icon: Icons.lock_outline,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
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
          const SizedBox(height: 14),

          // CPF
          _StyledFormField(
            controller: _documentController,
            label: 'CPF do titular',
            hint: '000.000.000-00',
            icon: Icons.badge_outlined,
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

          const SizedBox(height: 24),

          // Security badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                'Pagamento seguro via Mercado Pago',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : _tokenize,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 18),
                        const SizedBox(width: 8),
                        const Text('Confirmar cartão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual card preview that updates live as user types
class _CardPreview extends StatelessWidget {
  final String cardNumber;
  final String holderName;
  final String expiry;
  final String brand;

  const _CardPreview({
    required this.cardNumber,
    required this.holderName,
    required this.expiry,
    required this.brand,
  });

  @override
  Widget build(BuildContext context) {
    final displayNumber = cardNumber.isEmpty ? '**** **** **** ****' : cardNumber;
    final displayName = holderName.isEmpty ? 'NOME DO TITULAR' : holderName;
    final displayExpiry = expiry.isEmpty ? 'MM/AA' : expiry;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F3460),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3460).withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: chip + brand
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Chip icon
              Container(
                width: 40,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8B730), Color(0xFFC99A2E)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Icon(Icons.memory, size: 16, color: Color(0xFF8B6914)),
                ),
              ),
              if (brand.isNotEmpty)
                Text(
                  brand.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // Card number
          Text(
            displayNumber,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 3,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 20),

          // Bottom row: name + expiry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TITULAR',
                      style: TextStyle(
                        color: Colors.white.withAlpha(100),
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'VALIDADE',
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayExpiry,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card brand icon shown in the card number field suffix
class _CardBrandIcon extends StatelessWidget {
  final String brand;

  const _CardBrandIcon({required this.brand});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (brand) {
      'visa' => (const Color(0xFF1A1F71), Icons.credit_card),
      'master' => (const Color(0xFFEB001B), Icons.credit_card),
      'amex' => (const Color(0xFF006FCF), Icons.credit_card),
      'elo' => (const Color(0xFF000000), Icons.credit_card),
      _ => (Colors.grey, Icons.credit_card),
    };

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        brand.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Styled form field with modern look
class _StyledFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Widget? suffix;

  const _StyledFormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withAlpha(100)),
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(40)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.outline.withAlpha(40)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
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
