import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers/mercadopago_provider.dart';
import '../../widgets/shared/app_feedback.dart';

/// Timeout for the initial OAuth URL load.
const _loadTimeoutSeconds = 30;

/// Tela de conexao OAuth com Mercado Pago via WebView.
///
/// O vendedor autoriza a plataforma a receber pagamentos em seu nome.
/// O state parameter para CSRF e gerenciado pelo backend.
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
  Timer? _loadTimeout;

  @override
  void initState() {
    super.initState();
    _loadOAuthUrl();
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    super.dispose();
  }

  Future<void> _loadOAuthUrl() async {
    _loadTimeout?.cancel();

    // Start a timeout — if the page hasn't loaded within the limit, show error
    _loadTimeout = Timer(const Duration(seconds: _loadTimeoutSeconds), () {
      if (_isLoading && mounted) {
        setState(() {
          _errorMessage =
              'A página demorou muito para carregar. Verifique sua conexão e tente novamente.';
          _isLoading = false;
        });
      }
    });

    try {
      final url =
          await ref.read(mpConnectionProvider.notifier).getOAuthUrl();

      if (kDebugMode) {
        debugPrint('MP OAuth URL: $url');
      }

      // Use the URL as-is from the backend — it already contains the state param
      _initWebView(url);
    } catch (e) {
      _loadTimeout?.cancel();
      setState(() {
        _errorMessage =
            'Não foi possível iniciar a conexão com o Mercado Pago. '
            'Verifique sua conexão e tente novamente.';
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
            _loadTimeout?.cancel();
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            _loadTimeout?.cancel();
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

            // Intercept error callback
            if (uri.path.contains('mp-oauth-callback') &&
                uri.queryParameters.containsKey('error')) {
              setState(() {
                _errorMessage = uri.queryParameters['error'] ??
                    'Autorização negada pelo Mercado Pago';
              });
              return NavigationDecision.prevent;
            }

            // Allow all other navigation - the MP OAuth flow goes through
            // multiple domains (login, 2FA, social auth, etc.) that we
            // cannot predict or whitelist reliably.
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
      // Pass the state from the URL so the backend can validate CSRF
      await ref.read(mpConnectionProvider.notifier).exchangeCode(code, state: state);

      if (mounted) {
        AppFeedback.showSuccess(context, 'Conta Mercado Pago conectada!');
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
