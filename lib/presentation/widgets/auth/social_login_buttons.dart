import 'package:flutter/material.dart';

/// Social login buttons for authentication
class SocialLoginButtons extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final bool isLoading;

  const SocialLoginButtons({
    super.key,
    this.onGooglePressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GoogleSignInButton(
          onPressed: onGooglePressed,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

/// Google Sign In Button with official styling
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.text = 'Continuar com Google',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onPressed == null || isLoading;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha((255 * 0.3).round()),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onSurface,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Google Logo
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CustomPaint(
                          painter: _GoogleLogoPainter(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDisabled
                              ? theme.colorScheme.onSurface.withAlpha((255 * 0.5).round())
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for Google "G" logo
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Blue section
    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    // Red section
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;

    // Yellow section
    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;

    // Green section
    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    // Draw simplified G shape
    final path = Path();

    // Blue (right side)
    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      -0.5,
      2.0,
    );
    canvas.drawPath(path, bluePaint);

    // Red (top right)
    path.reset();
    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57,
      1.2,
    );
    canvas.drawPath(path, redPaint);

    // Yellow (bottom left)
    path.reset();
    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      1.5,
      1.2,
    );
    canvas.drawPath(path, yellowPaint);

    // Green (bottom)
    path.reset();
    path.addArc(
      Rect.fromCircle(center: center, radius: radius),
      0.3,
      1.2,
    );
    canvas.drawPath(path, greenPaint);

    // White center hole
    canvas.drawCircle(
      center,
      radius * 0.5,
      Paint()..color = Colors.white,
    );

    // Blue bar
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - radius * 0.1,
        center.dy - radius * 0.25,
        radius * 1.1,
        radius * 0.5,
      ),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Apple Sign In Button (future use)
class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const AppleSignInButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.text = 'Continuar com Apple',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onPressed == null || isLoading;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.apple,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
