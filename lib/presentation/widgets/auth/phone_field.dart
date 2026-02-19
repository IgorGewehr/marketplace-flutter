import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/validators.dart';
import 'auth_text_field.dart';

/// Brazilian phone field with (XX) XXXXX-XXXX mask
class PhoneField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final void Function(String)? onChanged;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;

  const PhoneField({
    super.key,
    this.controller,
    this.label = 'Telefone',
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: _controller,
      focusNode: widget.focusNode,
      label: widget.label,
      hint: '(00) 00000-0000',
      errorText: widget.errorText,
      enabled: widget.enabled,
      prefixIcon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      maxLength: 15, // (XX) XXXXX-XXXX
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _PhoneFormatter(),
      ],
      validator: Validators.validatePhone,
      onChanged: widget.onChanged,
    );
  }
}

/// Input formatter for Brazilian phone numbers
class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    // Limit to 11 digits
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final formatted = _format(limited);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _format(String digits) {
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      // Opening parenthesis
      if (i == 0) buffer.write('(');
      // Closing parenthesis and space
      if (i == 2) buffer.write(') ');
      // Dash position depends on length (10 or 11 digits)
      if (digits.length == 11 && i == 7) buffer.write('-');
      if (digits.length <= 10 && i == 6) buffer.write('-');

      buffer.write(digits[i]);
    }

    return buffer.toString();
  }
}
