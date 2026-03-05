import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:frontend/core/services/service_locator.dart';
import 'package:frontend/features/auth/screens/login_page.dart';
import 'package:frontend/features/dining_manager/services/dining_service.dart';
import 'package:frontend/features/dining_manager/screens/scan_result_page.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late final DiningService _diningService;
  late final MobileScannerController _scannerController;

  bool _isProcessing = false;
  bool _showScanner = false;

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
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ServiceLocator.tokenStorage.clearAll();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    }
  }

  void _openScanner() {
    setState(() => _showScanner = true);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);
    _scannerController.stop();

    await _processQr(barcode.rawValue!);
  }

  Future<void> _processQr(String qrData) async {
    final result = await _diningService.validateQr(qrData);
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
      _showScanner = false;
    });

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
    setState(() => _showScanner = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera error. Please try again.')),
    );
  }

  // ─── UI ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dining Manager'),
        elevation: 2,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
            tooltip: 'Logout',
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
          onTap: _openScanner,
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
                  'Scan QR\nCode',
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
          'Tap to scan student QR code',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        const Spacer(flex: 3),
      ],
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
