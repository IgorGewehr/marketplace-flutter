import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Styled text field with validation for auth forms
class AuthTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? errorText;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool autofocus;
  final bool readOnly;
  final bool enabled;
  final int? maxLength;
  final int maxLines;
  final IconData? prefixIcon;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final AutovalidateMode autovalidateMode;

  const AuthTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.autofocus = false,
    this.readOnly = false,
    this.enabled = true,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffix,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured;
  String? _errorText;
  bool _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  void _toggleObscure() {
    setState(() {
      _obscured = !_obscured;
    });
  }

  void _validateOnChange(String value) {
    if (_hasInteracted && widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(value);
      });
    }
    widget.onChanged?.call(value);
  }

  void _onFocusLost() {
    if (!_hasInteracted) {
      setState(() {
        _hasInteracted = true;
        if (widget.validator != null) {
          _errorText = widget.validator!(widget.controller?.text ?? '');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = (widget.errorText ?? _errorText) != null;

    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) _onFocusLost();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: hasError
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),

          // Text Field
          TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            obscureText: _obscured,
            autofocus: widget.autofocus,
            readOnly: widget.readOnly,
            enabled: widget.enabled,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
            inputFormatters: widget.inputFormatters,
            autovalidateMode: widget.autovalidateMode,
            validator: widget.validator,
            onChanged: _validateOnChange,
            onFieldSubmitted: widget.onSubmitted,
            onTap: widget.onTap,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: hasError
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    )
                  : null,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _toggleObscure,
                    )
                  : widget.suffix,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLowest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha((255 * 0.3).round()),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha((255 * 0.3).round()),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.error,
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withAlpha((255 * 0.2).round()),
                ),
              ),
            ),
          ),

          // Error Text
          if (hasError)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 14,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.errorText ?? _errorText ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
