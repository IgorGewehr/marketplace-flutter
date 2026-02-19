/// Validators for form inputs
/// Includes CPF, CNPJ, email, phone, and password validation
library;

class Validators {
  Validators._();

  // ==================== CPF Validation ====================

  /// Validate CPF using mod 11 algorithm
  static bool isValidCpf(String cpf) {
    // Remove non-digits
    final digits = cpf.replaceAll(RegExp(r'\D'), '');

    // Must be 11 digits
    if (digits.length != 11) return false;

    // Check for known invalid patterns
    if (RegExp(r'^(\d)\1{10}$').hasMatch(digits)) return false;

    // Calculate first check digit
    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += int.parse(digits[i]) * (10 - i);
    }
    var remainder = (sum * 10) % 11;
    if (remainder == 10) remainder = 0;
    if (remainder != int.parse(digits[9])) return false;

    // Calculate second check digit
    sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += int.parse(digits[i]) * (11 - i);
    }
    remainder = (sum * 10) % 11;
    if (remainder == 10) remainder = 0;
    if (remainder != int.parse(digits[10])) return false;

    return true;
  }

  /// Format CPF: 000.000.000-00
  static String formatCpf(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) return cpf;
    return '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
  }

  // ==================== CNPJ Validation ====================

  /// Validate CNPJ using mod 11 algorithm
  static bool isValidCnpj(String cnpj) {
    // Remove non-digits
    final digits = cnpj.replaceAll(RegExp(r'\D'), '');

    // Must be 14 digits
    if (digits.length != 14) return false;

    // Check for known invalid patterns
    if (RegExp(r'^(\d)\1{13}$').hasMatch(digits)) return false;

    // First check digit weights
    const weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    var sum = 0;
    for (var i = 0; i < 12; i++) {
      sum += int.parse(digits[i]) * weights1[i];
    }
    var remainder = sum % 11;
    var checkDigit1 = remainder < 2 ? 0 : 11 - remainder;
    if (checkDigit1 != int.parse(digits[12])) return false;

    // Second check digit weights
    const weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
    sum = 0;
    for (var i = 0; i < 13; i++) {
      sum += int.parse(digits[i]) * weights2[i];
    }
    remainder = sum % 11;
    var checkDigit2 = remainder < 2 ? 0 : 11 - remainder;
    if (checkDigit2 != int.parse(digits[13])) return false;

    return true;
  }

  /// Format CNPJ: 00.000.000/0000-00
  static String formatCnpj(String cnpj) {
    final digits = cnpj.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 14) return cnpj;
    return '${digits.substring(0, 2)}.${digits.substring(2, 5)}.${digits.substring(5, 8)}/${digits.substring(8, 12)}-${digits.substring(12)}';
  }

  // ==================== CPF/CNPJ Combined ====================

  /// Detect if input is CPF or CNPJ based on length
  static String? detectDocumentType(String document) {
    final digits = document.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) return 'cpf';
    if (digits.length == 14) return 'cnpj';
    return null;
  }

  /// Validate CPF or CNPJ (auto-detect)
  static bool isValidCpfCnpj(String document) {
    final type = detectDocumentType(document);
    if (type == 'cpf') return isValidCpf(document);
    if (type == 'cnpj') return isValidCnpj(document);
    return false;
  }

  /// Format CPF or CNPJ (auto-detect)
  static String formatCpfCnpj(String document) {
    final type = detectDocumentType(document);
    if (type == 'cpf') return formatCpf(document);
    if (type == 'cnpj') return formatCnpj(document);
    return document;
  }

  /// Get validation error for CPF/CNPJ
  static String? validateCpfCnpj(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe seu CPF ou CNPJ';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11) {
      return 'CPF incompleto';
    }
    if (digits.length == 11 && !isValidCpf(value)) {
      return 'CPF inválido';
    }
    if (digits.length > 11 && digits.length < 14) {
      return 'CNPJ incompleto';
    }
    if (digits.length == 14 && !isValidCnpj(value)) {
      return 'CNPJ inválido';
    }
    if (digits.length > 14) {
      return 'Documento inválido';
    }
    return null;
  }

  // ==================== Email Validation ====================

  /// Validate email format
  static bool isValidEmail(String email) {
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email.trim());
  }

  /// Get validation error for email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe seu email';
    }
    if (!isValidEmail(value)) {
      return 'Email inválido';
    }
    return null;
  }

  // ==================== Phone Validation ====================

  /// Validate Brazilian phone number
  static bool isValidPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    // 10 digits (landline) or 11 digits (mobile)
    return digits.length == 10 || digits.length == 11;
  }

  /// Format phone: (XX) XXXXX-XXXX or (XX) XXXX-XXXX
  static String formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    }
    return phone;
  }

  /// Get validation error for phone
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe seu telefone';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Telefone incompleto';
    }
    if (!isValidPhone(value)) {
      return 'Telefone inválido';
    }
    return null;
  }

  // ==================== Password Validation ====================

  /// Check password strength
  static PasswordStrength getPasswordStrength(String password) {
    if (password.length < 8) return PasswordStrength.weak;

    var score = 0;

    // Length bonus
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // Complexity bonus
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    return PasswordStrength.strong;
  }

  /// Get validation error for password.
  /// Requires minimum 8 characters with at least 1 uppercase letter,
  /// 1 number, and 1 special character.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe uma senha';
    }
    if (value.length < 8) {
      return 'Senha deve ter no mínimo 8 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Senha deve conter pelo menos 1 letra maiúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Senha deve conter pelo menos 1 número';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Senha deve conter pelo menos 1 caractere especial';
    }
    return null;
  }

  /// Validate password confirmation
  static String? validatePasswordConfirmation(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirme sua senha';
    }
    if (value != password) {
      return 'Senhas não conferem';
    }
    return null;
  }

  // ==================== Name Validation ====================

  /// Get validation error for name
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe seu nome';
    }
    if (value.trim().length < 3) {
      return 'Nome muito curto';
    }
    // Check for at least two words (first and last name)
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length < 2) {
      return 'Informe nome completo';
    }
    return null;
  }

  // ==================== Date Validation ====================

  /// Validate birth date (must be at least 18 years old)
  static String? validateBirthDate(DateTime? value, {int minAge = 18}) {
    if (value == null) {
      return 'Informe sua data de nascimento';
    }
    final now = DateTime.now();
    final age = now.year - value.year;
    final hasHadBirthday = now.month > value.month ||
        (now.month == value.month && now.day >= value.day);
    final actualAge = hasHadBirthday ? age : age - 1;

    if (actualAge < minAge) {
      return 'Você deve ter no mínimo $minAge anos';
    }
    if (actualAge > 120) {
      return 'Data inválida';
    }
    return null;
  }

  // ==================== Generic Required ====================

  /// Generic required field validation
  static String? validateRequired(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? 'Informe $fieldName' : 'Campo obrigatório';
    }
    return null;
  }
}

/// Password strength levels
enum PasswordStrength {
  weak,
  medium,
  strong;

  String get label => switch (this) {
        PasswordStrength.weak => 'Fraca',
        PasswordStrength.medium => 'Média',
        PasswordStrength.strong => 'Forte',
      };

  double get value => switch (this) {
        PasswordStrength.weak => 0.33,
        PasswordStrength.medium => 0.66,
        PasswordStrength.strong => 1.0,
      };
}
