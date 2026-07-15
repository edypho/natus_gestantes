import 'dart:math' as math;

import 'package:flutter/material.dart';

class UploadProgressController extends ChangeNotifier {
  String titulo;
  String mensagem;
  double progresso;
  UploadProgressStatus status;

  UploadProgressController({
    this.titulo = 'Enviando arquivo',
    this.mensagem = 'Preparando upload...',
    this.progresso = 0,
    this.status = UploadProgressStatus.preparing,
  });

  void preparing({String? titulo, String? mensagem}) {
    if (titulo != null) this.titulo = titulo;
    if (mensagem != null) this.mensagem = mensagem;
    progresso = 0;
    status = UploadProgressStatus.preparing;
    notifyListeners();
  }

  void uploading(double value, {String? titulo, String? mensagem}) {
    if (titulo != null) this.titulo = titulo;
    if (mensagem != null) this.mensagem = mensagem;
    progresso = value.clamp(0, 1);
    status = UploadProgressStatus.uploading;
    notifyListeners();
  }

  void success({String? titulo, String? mensagem}) {
    if (titulo != null) this.titulo = titulo;
    if (mensagem != null) this.mensagem = mensagem;
    progresso = 1;
    status = UploadProgressStatus.success;
    notifyListeners();
  }

  void error({String? titulo, String? mensagem}) {
    if (titulo != null) this.titulo = titulo;
    if (mensagem != null) this.mensagem = mensagem;
    status = UploadProgressStatus.error;
    notifyListeners();
  }
}

enum UploadProgressStatus { preparing, uploading, success, error }

class UploadProgressDialog extends StatefulWidget {
  final UploadProgressController controller;

  const UploadProgressDialog({super.key, required this.controller});

  @override
  State<UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.controller, _pulseController]),
          builder: (context, _) {
            final status = widget.controller.status;
            final progress = widget.controller.progresso;

            return Container(
              width: 360,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF8),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF40010D).withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _UploadPregnancyPainter(
                        progress: progress,
                        pulse: _pulseController.value,
                        status: status,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.controller.titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF40010D),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.controller.mensagem,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF74675F),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: status == UploadProgressStatus.error
                          ? null
                          : progress,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFF4DFD7),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _statusColor(status),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusLabel(status, progress),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _statusColor(UploadProgressStatus status) {
    switch (status) {
      case UploadProgressStatus.success:
        return const Color(0xFF3E6B4B);
      case UploadProgressStatus.error:
        return const Color(0xFFB34141);
      case UploadProgressStatus.preparing:
      case UploadProgressStatus.uploading:
        return const Color(0xFF40010D);
    }
  }

  String _statusLabel(UploadProgressStatus status, double progress) {
    switch (status) {
      case UploadProgressStatus.preparing:
        return 'Preparando envio...';
      case UploadProgressStatus.uploading:
        return '${(progress * 100).round()}% concluido';
      case UploadProgressStatus.success:
        return 'Upload concluido com sucesso';
      case UploadProgressStatus.error:
        return 'Ocorreu um erro no envio';
    }
  }
}

class _UploadPregnancyPainter extends CustomPainter {
  final double progress;
  final double pulse;
  final UploadProgressStatus status;

  const _UploadPregnancyPainter({
    required this.progress,
    required this.pulse,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 6);
    final accent = _statusColor(status);
    final baseBody = Paint()..color = const Color(0xFFD9A796);
    final bodyShade = Paint()
      ..color = const Color(0xFF40010D).withValues(alpha: 0.08);
    final pulsePaint = Paint()
      ..color = accent.withValues(alpha: 0.10 + (0.12 * pulse))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    final bellyScale = 0.70 + (progress * 0.35) + (pulse * 0.04);
    final ringRadius = 34 + (progress * 18) + (pulse * 10);

    canvas.drawCircle(center.translate(8, 10), ringRadius, pulsePaint);
    canvas.drawCircle(
      center.translate(8, 10),
      ringRadius + 14,
      pulsePaint..strokeWidth = 4,
    );

    final headRect = Rect.fromCircle(
      center: center.translate(-12, -52),
      radius: 16,
    );
    canvas.drawOval(headRect, baseBody);

    final torsoPath = Path()
      ..moveTo(center.dx - 22, center.dy - 24)
      ..quadraticBezierTo(
        center.dx - 34,
        center.dy - 6,
        center.dx - 28,
        center.dy + 28,
      )
      ..quadraticBezierTo(
        center.dx - 6,
        center.dy + 18,
        center.dx + 6,
        center.dy - 2,
      )
      ..quadraticBezierTo(
        center.dx + 10,
        center.dy - 26,
        center.dx - 12,
        center.dy - 28,
      )
      ..close();
    canvas.drawPath(torsoPath, baseBody);

    canvas.drawCircle(center.translate(18, 6), 28 * bellyScale, baseBody);

    canvas.drawArc(
      Rect.fromCircle(center: center.translate(12, 8), radius: 30 * bellyScale),
      -math.pi / 3,
      math.pi * 0.72,
      false,
      bodyShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final iconPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    if (status == UploadProgressStatus.success) {
      final path = Path()
        ..moveTo(center.dx - 8, center.dy + 8)
        ..lineTo(center.dx + 4, center.dy + 20)
        ..lineTo(center.dx + 24, center.dy - 6);
      canvas.drawPath(path, iconPaint);
    } else if (status == UploadProgressStatus.error) {
      canvas.drawLine(
        center.translate(-10, -8),
        center.translate(16, 18),
        iconPaint,
      );
      canvas.drawLine(
        center.translate(16, -8),
        center.translate(-10, 18),
        iconPaint,
      );
    } else {
      canvas.drawLine(
        center.translate(8, -12),
        center.translate(8, 16),
        iconPaint,
      );
      canvas.drawLine(
        center.translate(-4, 4),
        center.translate(8, 16),
        iconPaint,
      );
      canvas.drawLine(
        center.translate(20, 4),
        center.translate(8, 16),
        iconPaint,
      );
    }
  }

  Color _statusColor(UploadProgressStatus status) {
    switch (status) {
      case UploadProgressStatus.success:
        return const Color(0xFF3E6B4B);
      case UploadProgressStatus.error:
        return const Color(0xFFB34141);
      case UploadProgressStatus.preparing:
      case UploadProgressStatus.uploading:
        return const Color(0xFF9B6A2D);
    }
  }

  @override
  bool shouldRepaint(covariant _UploadPregnancyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.status != status;
  }
}
