/// WhatsApp button widget for quick contact
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppButton extends StatelessWidget {
  final String phoneNumber;
  final String? message;
  final String? label;
  final bool isCompact;
  final VoidCallback? onBeforeLaunch;

  const WhatsAppButton({
    super.key,
    required this.phoneNumber,
    this.message,
    this.label,
    this.isCompact = false,
    this.onBeforeLaunch,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return IconButton(
        icon: const Icon(LucideIcons.messageCircle),
        onPressed: () => _launchWhatsApp(context),
        tooltip: 'Chamar no WhatsApp',
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _launchWhatsApp(context),
      icon: const Icon(LucideIcons.messageCircle, size: 18),
      label: Text(label ?? 'Chamar no WhatsApp'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF25D366),
        side: const BorderSide(color: Color(0xFF25D366)),
      ),
    );
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    // Call callback before launching
    onBeforeLaunch?.call();

    // Clean phone number (remove non-digits)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Build WhatsApp URL
    final encodedMessage = message != null ? Uri.encodeComponent(message!) : '';
    final url = 'https://wa.me/$cleanPhone${message != null ? '?text=$encodedMessage' : ''}';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          _showError(context, 'Não foi possível abrir o WhatsApp');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erro ao abrir o WhatsApp: $e');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// WhatsApp floating action button
class WhatsAppFab extends StatelessWidget {
  final String phoneNumber;
  final String? message;

  const WhatsAppFab({
    super.key,
    required this.phoneNumber,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _launchWhatsApp(context),
      backgroundColor: const Color(0xFF25D366),
      foregroundColor: Colors.white,
      tooltip: 'Chamar no WhatsApp',
      child: const Icon(LucideIcons.messageCircle),
    );
  }

  Future<void> _launchWhatsApp(BuildContext context) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final encodedMessage = message != null ? Uri.encodeComponent(message!) : '';
    final url = 'https://wa.me/$cleanPhone${message != null ? '?text=$encodedMessage' : ''}';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          _showError(context, 'Não foi possível abrir o WhatsApp');
        }
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Erro ao abrir o WhatsApp: $e');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Helper function to launch WhatsApp
Future<bool> launchWhatsApp({
  required String phoneNumber,
  String? message,
  BuildContext? context,
}) async {
  final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
  final encodedMessage = message != null ? Uri.encodeComponent(message) : '';
  final url = 'https://wa.me/$cleanPhone${message != null ? '?text=$encodedMessage' : ''}';

  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return true;
    }
  } catch (e) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir o WhatsApp: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  return false;
}
