import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/mercadopago_provider.dart';

/// Allowed domains for navigation during the OAuth flow.
const _allowedOAuthDomains = [
  'auth.mercadopago.com',
  'auth.mercadopago.com.br',
  'www.mercadopago.com',
  'www.mercadopago.com.br',
  'mercadopago.com',
  'mercadopago.com.br',
  'accounts.google.com',
];

/// Tela de conexao OAuth com Mercado Pago via WebView.
///
/// O vendedor autoriza a plataforma a receber pagamentos em seu nome.
/// Inclui protecao CSRF via state parameter e validacao de dominio.
class MpConnectScreen extends ConsumerStatefulWidget {
  const MpConnectScreen({super.key});

  @override
  ConsumerState<MpConnectScreen> createState() => _MpConnectScreenState();
}

class _MpConnectScreenState extends ConsumerState<MpConnectScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  double _loadingProgress = 0;
  String? _errorMessage;
  bool _isExchangingCode = false;

  /// Random state nonce for CSRF protection
  late final String _oauthState;

  @override
  void initState() {
    super.initState();
    _oauthState = _generateNonce();
    _loadOAuthUrl();
  }

  /// Generates a cryptographically random nonce for OAuth state parameter.
  String _generateNonce([int length = 32]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)])
        .join();
  }

  Future<void> _loadOAuthUrl() async {
    try {
      final url =
          await ref.read(mpConnectionProvider.notifier).getOAuthUrl();

      // Append state parameter to the OAuth URL for CSRF protection
      final uri = Uri.parse(url);
      final urlWithState = uri.replace(
        queryParameters: {
          ...uri.queryParametersAll,
          'state': [_oauthState],
        },
      ).toString();

      _initWebView(urlWithState);
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao gerar URL de autorização: $e';
        _isLoading = false;
      });
    }
  }

  void _initWebView(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Erro ao carregar página: ${error.description}';
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);

            // Intercept our OAuth callback redirect
            if (uri.path.contains('mp-oauth-callback') &&
                uri.queryParameters.containsKey('code')) {
              _handleOAuthCallback(request.url);
              return NavigationDecision.prevent;
            }

            // Only allow navigation to known MP and auth domains
            final host = uri.host;
            final isAllowed = _allowedOAuthDomains.any(
              (domain) => host == domain || host.endsWith('.$domain'),
            );

            // Also allow our own callback domain and initial load
            if (!isAllowed && !uri.path.contains('mp-oauth-callback')) {
              // Allow if it's our API/Cloud Functions domain
              if (!host.contains('cloudfunctions.net') &&
                  !host.contains('reidobrique.com.br')) {
                return NavigationDecision.prevent;
              }
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {
      _controller = controller;
    });
  }

  Future<void> _handleOAuthCallback(String url) async {
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];

    // Validate CSRF state parameter
    if (state != _oauthState) {
      setState(() {
        _errorMessage =
            'Erro de segurança: estado da requisição inválido. Tente novamente.';
      });
      return;
    }

    if (code == null || code.isEmpty) {
      setState(() {
        _errorMessage = 'Código de autorização não encontrado';
      });
      return;
    }

    setState(() {
      _isExchangingCode = true;
    });

    try {
      await ref.read(mpConnectionProvider.notifier).exchangeCode(code);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Conta Mercado Pago conectada!'),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      setState(() {
        _isExchangingCode = false;
        _errorMessage = 'Erro ao conectar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Mercado Pago'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          // WebView (only show if initialized and no error)
          if (_errorMessage == null && !_isExchangingCode && _controller != null)
            WebViewWidget(controller: _controller!),

          // Exchanging code state
          if (_isExchangingCode)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Conectando conta...'),
                ],
              ),
            ),

          // Error state
          if (_errorMessage != null && !_isExchangingCode)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Erro ao conectar',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _loadOAuthUrl();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading && _errorMessage == null && !_isExchangingCode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress : null,
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}
