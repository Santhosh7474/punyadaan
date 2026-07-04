import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _cameraReady = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization to avoid blocking the main thread during page transition animation.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _cameraReady = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    if (capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first;
      
      if (barcode.rawValue != null) {
        setState(() {
          _isProcessing = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanned: ${barcode.rawValue}'),
            backgroundColor: const Color(0xFF24963F),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        Navigator.pop(context, barcode.rawValue);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full Screen Camera View
          if (_cameraReady)
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF24963F)),
            ),
          
          // 2. Beautiful GPay-like overlay (Darkened background with clear scan window)
          Container(
            decoration: ShapeDecoration(
              shape: _ScannerOverlayShape(
                borderColor: const Color(0xFF24963F), // Theme green
                borderWidth: 4.0,
                overlayColor: Colors.black.withValues(alpha: 0.65),
                borderRadius: 16,
                borderLength: 40,
                cutOutSize: MediaQuery.of(context).size.width * 0.75, // 75% of screen width
              ),
            ),
          ),
          
          // 3. Informational Text inside the scanning area
          Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(0, (MediaQuery.of(context).size.width * 0.75 / 2) + 40),
              child: const Text(
                'Scan QR code or Barcode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          
          // 4. Back button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          
        ],
      ),
    );
  }
}


class _ScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const _ScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 4.0,
    this.overlayColor = const Color(0x88000000),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..fillType = PathFillType.evenOdd;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getOuterPath = Path()..addRect(rect);
    Rect cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );
    Path cutOutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)));

    return Path.combine(PathOperation.difference, getOuterPath, cutOutPath);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(getOuterPath(rect), paint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = rect.center;
    final halfSize = cutOutSize / 2;
    
    // Top left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfSize, center.dy - halfSize + borderLength)
        ..lineTo(center.dx - halfSize, center.dy - halfSize)
        ..lineTo(center.dx - halfSize + borderLength, center.dy - halfSize),
      borderPaint,
    );
    // Top right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfSize - borderLength, center.dy - halfSize)
        ..lineTo(center.dx + halfSize, center.dy - halfSize)
        ..lineTo(center.dx + halfSize, center.dy - halfSize + borderLength),
      borderPaint,
    );
    // Bottom right
    canvas.drawPath(
      Path()
        ..moveTo(center.dx + halfSize, center.dy + halfSize - borderLength)
        ..lineTo(center.dx + halfSize, center.dy + halfSize)
        ..lineTo(center.dx + halfSize - borderLength, center.dy + halfSize),
      borderPaint,
    );
    // Bottom left
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - halfSize + borderLength, center.dy + halfSize)
        ..lineTo(center.dx - halfSize, center.dy + halfSize)
        ..lineTo(center.dx - halfSize, center.dy + halfSize - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return _ScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
