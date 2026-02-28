import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

/// Blocking screen shown when the app version is below the minimum required.
/// The user cannot dismiss it — they must update via the store.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tensorroot.marketplace';
  static const _appStoreUrl =
      'https://apps.apple.com/app/compre-aqui/id000000000'; // placeholder

  Future<void> _openStore() async {
    final url = Platform.isIOS ? _appStoreUrl : _playStoreUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                const Text(
                  'Atualização necessária',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  'Uma nova versão do Compre Aqui está disponível. '
                  'Atualize o app para continuar usando.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Update button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text(
                      'Atualizar agora',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
