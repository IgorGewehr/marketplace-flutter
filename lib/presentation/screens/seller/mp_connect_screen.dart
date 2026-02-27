import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/mercadopago_provider.dart';
import '../../widgets/shared/app_feedback.dart';

/// Maximum time to wait for the user to complete OAuth in the browser.
const _pollTimeout = Duration(minutes: 15);

/// Tela de conexao OAuth com Mercado Pago.
///
/// Abre o navegador externo do sistema para autenticacao (RFC 8252),
/// e faz polling do status de conexao enquanto aguarda o usuario retornar.
class MpConnectScreen extends ConsumerStatefulWidget {
  const MpConnectScreen({super.key});

  @override
  ConsumerState<MpConnectScreen> createState() => _MpConnectScreenState();
}

enum _ScreenState { loading, waitingBrowser, success, error }

class _MpConnectScreenState extends ConsumerState<MpConnectScreen>
    with WidgetsBindingObserver {
  _ScreenState _state = _ScreenState.loading;
  String? _errorMessage;
  Timer? _pollTimer;
  DateTime? _pollStartTime;
  StreamSubscription<Uri>? _deepLinkSub;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForDeepLink();
    _startOAuthFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _deepLinkSub?.cancel();
    super.dispose();
  }

  void _listenForDeepLink() {
    final appLinks = AppLinks();
    _deepLinkSub = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'nexmarket' &&
          uri.host == 'mp-oauth-callback' &&
          _state == _ScreenState.waitingBrowser) {
        final status = uri.queryParameters['status'];
        if (status == 'success') {
          _pollTimer?.cancel();
          _checkConnection();
        } else if (status == 'error') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() {
              _state = _ScreenState.error;
              _errorMessage =
                  'A autorização foi negada ou ocorreu um erro. Tente novamente.';
            });
          }
        }
      }
    });
  }

  /// When the app resumes (user returns from browser), check immediately.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _state == _ScreenState.waitingBrowser) {
      _checkConnection();
    }
  }

  Future<void> _startOAuthFlow() async {
    setState(() {
      _state = _ScreenState.loading;
      _errorMessage = null;
    });

    try {
      final url =
          await ref.read(mpConnectionProvider.notifier).getOAuthUrl();

      if (!mounted) return;

      final uri = Uri.parse(url);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!mounted) return;

      if (!launched) {
        setState(() {
          _state = _ScreenState.error;
          _errorMessage = 'Não foi possível abrir o navegador.';
        });
        return;
      }

      setState(() => _state = _ScreenState.waitingBrowser);
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ScreenState.error;
        _errorMessage =
            'Não foi possível iniciar a conexão com o Mercado Pago. '
            'Verifique sua conexão e tente novamente.';
      });
    }
  }

  /// Returns the polling interval based on elapsed time (exponential backoff):
  /// - 0–60s   → poll every 3s
  /// - 60–120s → poll every 6s
  /// - >120s   → poll every 12s (cap)
  Duration _currentPollInterval() {
    if (_pollStartTime == null) return const Duration(seconds: 3);
    final elapsed = DateTime.now().difference(_pollStartTime!).inSeconds;
    if (elapsed < 60) return const Duration(seconds: 3);
    if (elapsed < 120) return const Duration(seconds: 6);
    return const Duration(seconds: 12);
  }

  void _startPolling() {
    _pollStartTime = DateTime.now();
    _pollTimer?.cancel();
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer(_currentPollInterval(), () async {
      await _checkConnection();
      // Only reschedule if we're still in the waiting state
      if (mounted && _state == _ScreenState.waitingBrowser) {
        _scheduleNextPoll();
      }
    });
  }

  Future<void> _checkConnection() async {
    if (_isChecking) return;
    _isChecking = true;
    try {
      // Timeout check
      if (_pollStartTime != null) {
        final elapsed = DateTime.now().difference(_pollStartTime!);
        if (elapsed > _pollTimeout) {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() {
              _state = _ScreenState.error;
              _errorMessage =
                  'Tempo esgotado. Se você já autorizou no navegador, '
                  'toque em "Tentar novamente".';
            });
          }
          return;
        }
      }

      try {
        await ref.read(mpConnectionProvider.notifier).refresh();
        final connection = ref.read(mpConnectionProvider).valueOrNull;

        if (connection?.isConnected == true && mounted) {
          _pollTimer?.cancel();
          setState(() => _state = _ScreenState.success);

          // Brief delay to show the success state + PIX reminder, then pop
          await Future.delayed(const Duration(milliseconds: 2500));
          if (mounted) {
            AppFeedback.showSuccess(context, 'Conta Mercado Pago conectada!');
            context.pop(true);
          }
        }
      } catch (_) {
        // Polling errors are ignored — will retry on next tick
      }
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar Mercado Pago'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(false),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: switch (_state) {
            _ScreenState.loading => _buildLoading(theme),
            _ScreenState.waitingBrowser => _buildWaiting(theme),
            _ScreenState.success => _buildSuccess(theme),
            _ScreenState.error => _buildError(theme),
          },
        ),
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Preparando conexão...'),
        ],
      ),
    );
  }

  Widget _buildWaiting(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // MP brand color icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF009EE3).withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.open_in_browser,
              size: 40,
              color: Color(0xFF009EE3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aguardando autorização',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Complete a autorização no navegador.\n'
            'Após autorizar, volte para este app.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 32),
          // Re-open browser button
          OutlinedButton.icon(
            onPressed: _startOAuthFlow,
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('Abrir navegador novamente'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _pollTimer?.cancel();
              // Force an immediate check before giving up
              _checkConnection();
            },
            child: const Text('Já autorizei'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0x2000A650),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              size: 48,
              color: Color(0xFF00A650),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Conectado!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF00A650),
            ),
          ),
          const SizedBox(height: 24),
          // PIX key reminder
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.rating.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.rating.withAlpha(76)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pix, color: AppColors.rating, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Para aceitar pagamentos via PIX, verifique se você tem uma chave PIX cadastrada no Mercado Pago.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
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
            _errorMessage ?? 'Erro desconhecido',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startOAuthFlow,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    );
  }
}
