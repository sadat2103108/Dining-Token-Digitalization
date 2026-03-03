/// Represents a QR response from the backend (matches QrResponse DTO).
/// Backend returns: { tokenId: Long, qrCode: String }
class QrSessionModel {
  final int tokenId;
  final String qrCode;

  const QrSessionModel({
    required this.tokenId,
    required this.qrCode,
  });

  factory QrSessionModel.fromJson(Map<String, dynamic> json) => QrSessionModel(
        tokenId: json['tokenId'] as int,
        qrCode: json['qrCode'] as String,
      );

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'qrCode': qrCode,
      };

  /// Convenience: use tokenId as a string identifier.
  String get sessionId => tokenId.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrSessionModel &&
          runtimeType == other.runtimeType &&
          tokenId == other.tokenId;

  @override
  int get hashCode => tokenId.hashCode;

  @override
  String toString() =>
      'QrSessionModel(tokenId: $tokenId, qrCode: ${qrCode.substring(0, qrCode.length > 20 ? 20 : qrCode.length)}...)';
}
