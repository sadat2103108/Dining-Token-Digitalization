import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:frontend/core/services/service_locator.dart';
import 'package:frontend/features/dining_manager/services/dining_service.dart';
import 'package:frontend/features/dining_manager/screens/scan_result_page.dart';
import 'package:frontend/features/dining_manager/screens/stats_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late final DiningService _diningService;
  late final MobileScannerController _scannerController;

  final TextEditingController _manualQrController = TextEditingController();

  bool _isProcessing = false;
  bool _showScanner = false;
  bool _cameraFailed = false;

  @override
  void initState() {
    super.initState();
    _diningService = DiningService(ServiceLocator.apiClient);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualQrController.dispose();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────

  void _openScanner() {
    if (kIsWeb) {
      // On web, camera may or may not work — try it,
      // but _cameraFailed flag provides fallback.
      setState(() => _showScanner = true);
    } else {
      setState(() {
        _showScanner = true;
        _cameraFailed = false;
      });
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);
    _scannerController.stop();

    await _processQr(barcode.rawValue!);
  }

  Future<void> _onManualSubmit() async {
    final text = _manualQrController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    await _processQr(text);
  }

  Future<void> _processQr(String qrData) async {
    final result = await _diningService.validateQr(qrData);
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _showScanner = false;
    });

    _manualQrController.clear();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanResultPage(
          result: result,
          onScanAnother: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _onScannerError(MobileScannerException error) {
    if (!mounted) return;
    setState(() {
      _cameraFailed = true;
      _showScanner = false;
    });
  }

  // ─── UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RUET Dining Manager'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Today\'s Stats',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatsPage()),
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _showScanner ? _buildScannerView() : _buildHomeView(),
        ),
      ),
    );
  }

  // ── Home view (circular button) ────────────────────────

  Widget _buildHomeView() {
    return Column(
      children: [
        const Spacer(flex: 2),
        // Circular scan button
        GestureDetector(
          onTap: _cameraFailed || kIsWeb ? null : _openScanner,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
                const SizedBox(height: 12),
                Text(
                  _cameraFailed ? 'Camera\nUnavailable' : 'Scan QR\nCode',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          _cameraFailed
              ? 'Camera unavailable — use manual entry below'
              : 'Place the QR code in the frame to scan',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const Spacer(flex: 1),
        // Manual QR entry (always visible on web, shown on camera fail)
        if (kIsWeb || _cameraFailed) _buildManualEntry(),
        if (!kIsWeb && !_cameraFailed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextButton.icon(
              onPressed: () => setState(() => _cameraFailed = true),
              icon: const Icon(Icons.keyboard_rounded, color: Colors.white70),
              label: const Text('Enter QR manually',
                  style: TextStyle(color: Colors.white70)),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _manualQrController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Paste QR payload',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _onManualSubmit(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isProcessing ? null : _onManualSubmit,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.verified_rounded),
              label: Text(_isProcessing ? 'Verifying…' : 'Verify'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1565C0),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // On web: also offer camera scan if possible
          if (kIsWeb && !_cameraFailed)
            TextButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.camera_alt_rounded, color: Colors.white70),
              label: const Text('Try camera scan',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
    );
  }

  // ── Scanner view ───────────────────────────────────────

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            // Camera failed — switch to manual fallback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onScannerError(error);
            });
            return Center(
              child: Text(
                'Camera error: ${error.errorDetails?.message ?? 'unknown'}',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            );
          },
        ),
        // Overlay frame
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // Back / close button
        Positioned(
          top: 16,
          left: 16,
          child: CircleAvatar(
            backgroundColor: Colors.black45,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () {
                _scannerController.stop();
                setState(() => _showScanner = false);
              },
            ),
          ),
        ),
        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Validating token…',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
