import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/validators.dart';
import 'auth_text_field.dart';

/// CPF/CNPJ text field with auto-detection, formatting, and validation
class CpfCnpjField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? errorText;
  final bool enabled;
  final void Function(String)? onChanged;
  final void Function(String type)? onTypeDetected;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;

  const CpfCnpjField({
    super.key,
    this.controller,
    this.label = 'CPF ou CNPJ',
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.onTypeDetected,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<CpfCnpjField> createState() => _CpfCnpjFieldState();
}

class _CpfCnpjFieldState extends State<CpfCnpjField> {
  late TextEditingController _controller;
  String? _documentType;

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

  void _onChanged(String value) {
    // Detect document type
    final digits = value.replaceAll(RegExp(r'\D'), '');
    String? newType;
    if (digits.length >= 11 && digits.length < 14) {
      newType = 'cpf';
    } else if (digits.length >= 14) {
      newType = 'cnpj';
    }

    if (newType != _documentType) {
      _documentType = newType;
      if (newType != null) {
        widget.onTypeDetected?.call(newType);
      }
    }

    widget.onChanged?.call(value);
  }

  String? _getHint() {
    if (_documentType == 'cpf') return '000.000.000-00';
    if (_documentType == 'cnpj') return '00.000.000/0000-00';
    return '000.000.000-00 ou 00.000.000/0000-00';
  }

  IconData _getIcon() {
    if (_documentType == 'cnpj') return Icons.business_outlined;
    return Icons.person_outline;
  }

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: _controller,
      focusNode: widget.focusNode,
      label: widget.label,
      hint: _getHint(),
      errorText: widget.errorText,
      enabled: widget.enabled,
      prefixIcon: _getIcon(),
      keyboardType: TextInputType.number,
      textInputAction: widget.textInputAction,
      maxLength: 18, // Max formatted CNPJ length
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CpfCnpjFormatter(),
      ],
      validator: Validators.validateCpfCnpj,
      onChanged: _onChanged,
    );
  }
}

/// Input formatter that applies CPF or CNPJ mask based on length
class _CpfCnpjFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    String formatted;
    if (digits.length <= 11) {
      // Format as CPF: 000.000.000-00
      formatted = _formatCpf(digits);
    } else {
      // Format as CNPJ: 00.000.000/0000-00
      formatted = _formatCnpj(digits.substring(0, 14.clamp(0, digits.length)));
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatCpf(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write('.');
      if (i == 9) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _formatCnpj(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
