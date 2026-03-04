import 'package:dio/dio.dart';
import 'package:frontend/core/network/api_client.dart';

// ──────────────────────────────────────────────────────────
//  LOCAL MODELS (scoped to dining_manager feature only)
// ──────────────────────────────────────────────────────────

/// Maps to backend QrValidationResponse.
class ScanResult {
  final bool isValid;
  final String message;
  final String? mealType;
  final String? mealDate;
  final String? ownerName;
  final String? status;
  final int? tokenId;

  const ScanResult({
    required this.isValid,
    required this.message,
    this.mealType,
    this.mealDate,
    this.ownerName,
    this.status,
    this.tokenId,
  });

  /// Parse from backend QrValidationResponse (inside ApiResponse.data).
  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      isValid: json['valid'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      mealType: json['mealType'] as String?,
      mealDate: json['mealDate'] as String?,
      ownerName: json['ownerName'] as String?,
      status: json['status'] as String?,
      tokenId: (json['tokenId'] as num?)?.toInt(),
    );
  }

  factory ScanResult.error(String message) =>
      ScanResult(isValid: false, message: message);
}

// ──────────────────────────────────────────────────────────
//  SERVICE
// ──────────────────────────────────────────────────────────

class DiningService {
  final ApiClient _api;

  DiningService(this._api);

  /// Validate & consume a scanned QR token.
  ///
  /// Uses `POST /tokens/validate-qr` (backend TokenController).
  /// Response wraps `QrValidationResponse` inside an `ApiResponse`.
  Future<ScanResult> validateQr(String qrData) async {
    try {
      final response = await _api.post<Map<String, dynamic>>(
        '/tokens/validate-qr',
        data: {'qrData': qrData},
      );
      if (response.data != null) {
        final body = response.data!;
        // Backend wraps in ApiResponse — actual data is in 'data' field
        final data = body['data'] as Map<String, dynamic>?;
        if (data != null) {
          return ScanResult.fromJson(data);
        }
        // Fallback: try parsing the body itself
        return ScanResult.fromJson(body);
      }
      return ScanResult.error('Empty response from server.');
    } on DioException catch (e) {
      final msg = ApiClient.getErrorMessage(e);
      return ScanResult.error(msg);
    } catch (_) {
      return ScanResult.error(
          'Unable to verify. Check internet connection or QR code.');
    }
  }
}
