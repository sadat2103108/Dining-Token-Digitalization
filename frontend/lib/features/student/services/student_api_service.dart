import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class StudentApiService {
  static const String _baseUrl = 'http://10.0.2.2:8080/api/v1'; // Android emulator → localhost
  final String _token;
  final int? _userId; // needed for marketplace X-User-Id header

  StudentApiService({required String token, int? userId})
      : _token = token,
        _userId = userId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  /// Headers for marketplace endpoints that require X-User-Id.
  Map<String, String> get _marketplaceHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
        if (_userId != null) 'X-User-Id': _userId.toString(),
      };

  // ==================== AUTH ====================

  static Future<AuthResponse> login(LoginRequest request) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Login failed: ${res.body}');
  }

  /// Signup returns SignupResponse (message, email, userId) — not AuthResponse.
  /// After signup, frontend should redirect to login.
  static Future<Map<String, dynamic>> signup(SignupRequest request) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Signup failed: ${res.body}');
  }

  Future<AuthResponse> getMe() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/auth/me'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return AuthResponse.fromJson(jsonDecode(res.body));
    }
    throw Exception('Failed to fetch user info');
  }

  // ==================== WALLET ====================

  /// NOTE: /wallet/me does NOT exist in the backend.
  /// The only wallet endpoints are meal-manager-only (/wallet/topup, /wallet/student/{id}).
  /// TODO: Backend needs a student-facing wallet balance endpoint.
  Future<WalletModel> getWalletBalance() async {
    throw UnimplementedError(
      'GET /wallet/me does not exist in the backend. '
      'A student-facing wallet balance endpoint is needed.',
    );
  }

  /// NOTE: /wallet/topup exists but is MEAL_MANAGER only with different DTO.
  /// Students cannot top up their own wallet.
  /// TODO: Backend needs a student-facing wallet top-up endpoint.
  Future<WalletModel> topUpWallet(WalletTopUpRequest request) async {
    throw UnimplementedError(
      'POST /wallet/topup is meal-manager-only in the backend. '
      'A student-facing wallet top-up endpoint is needed.',
    );
  }

  // ==================== TOKENS ====================

  Future<List<TokenModel>> getMyTokens() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/tokens/me'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body['data'];
      return data.map((e) => TokenModel.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch tokens');
  }

  /// NOTE: /tokens/available does NOT exist in the backend.
  /// This fetches the student's own tokens and filters ACTIVE ones as a workaround.
  /// TODO: Backend needs a dedicated /tokens/available or /meals/available endpoint.
  Future<List<AvailableToken>> getAvailableTokens() async {
    // No backend endpoint exists — throw descriptive error
    throw UnimplementedError(
      'GET /tokens/available does not exist in the backend. '
      'A dedicated endpoint is needed to list purchasable meals.',
    );
  }

  Future<TokenModel> purchaseToken(PurchaseTokenRequest request) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/tokens/purchase'),
      headers: _headers,
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body);
      return TokenModel.fromJson(body['data']);
    }
    throw Exception('Purchase failed: ${res.body}');
  }

  Future<QrSessionModel> generateQr(String tokenId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/tokens/$tokenId/generate-qr'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return QrSessionModel.fromJson(body['data']);
    }
    throw Exception('Failed to generate QR: ${res.body}');
  }

  // ==================== MENU ====================

  /// NOTE: /menu/today does NOT exist in the backend.
  /// TODO: Backend needs a student-facing menu endpoint.
  Future<List<MenuModel>> getTodayMenu() async {
    throw UnimplementedError(
      'GET /menu/today does not exist in the backend. '
      'A student-facing menu endpoint is needed.',
    );
  }

  /// NOTE: /menu/full does NOT exist in the backend.
  /// TODO: Backend needs a student-facing full menu endpoint.
  Future<List<MenuModel>> getFullMenu() async {
    throw UnimplementedError(
      'GET /menu/full does not exist in the backend. '
      'A student-facing full menu endpoint is needed.',
    );
  }

  // ==================== MARKETPLACE ====================
  // NOTE: Marketplace endpoints use X-User-Id header (not just JWT).
  // Backend wraps all responses in ApiResponse<T> → { success, message, data }.

  Future<List<MarketplacePost>> getMarketplacePosts() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/marketplace/posts'),
      headers: _marketplaceHeaders,
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body['data'];
      return data.map((e) => MarketplacePost.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch marketplace posts');
  }

  /// Backend returns List<TokenResponse> (common dto) not MyToken.
  /// We adapt the response to MyToken format.
  Future<List<MyToken>> getMarketplaceMyTokens() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/marketplace/my-tokens'),
      headers: _marketplaceHeaders,
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body['data'];
      return data.map((e) => MyToken.fromTokenResponse(e)).toList();
    }
    throw Exception('Failed to fetch my tokens');
  }

  Future<List<MyListing>> getMyListings() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/marketplace/my-listings'),
      headers: _marketplaceHeaders,
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body['data'];
      return data.map((e) => MyListing.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch my listings');
  }

  Future<List<MyPurchase>> getMyPurchases() async {
    final res = await http.get(
      Uri.parse('$_baseUrl/marketplace/my-purchases'),
      headers: _marketplaceHeaders,
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List data = body['data'];
      return data.map((e) => MyPurchase.fromJson(e)).toList();
    }
    throw Exception('Failed to fetch my purchases');
  }

  Future<void> sendBuyRequest(String postId, {required String paymentType}) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/marketplace/buy'),
      headers: _marketplaceHeaders,
      body: jsonEncode({
        'postId': int.tryParse(postId) ?? postId,
        'paymentType': paymentType,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Buy request failed: ${res.body}');
    }
  }

  Future<void> sellToken(CreateSellRequest request) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/marketplace/sell'),
      headers: _marketplaceHeaders,
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Sell request failed: ${res.body}');
    }
  }

  Future<void> confirmListing(String listingId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/marketplace/listings/$listingId/confirm'),
      headers: _marketplaceHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception('Confirm failed: ${res.body}');
    }
  }

  Future<void> rejectListing(String listingId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/marketplace/listings/$listingId/reject'),
      headers: _marketplaceHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception('Reject failed: ${res.body}');
    }
  }

  Future<void> cancelPurchase(String purchaseId) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/marketplace/purchases/$purchaseId/cancel'),
      headers: _marketplaceHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception('Cancel failed: ${res.body}');
    }
  }

  Future<void> cancelSellRequest(String listingId) async {
    final res = await http.delete(
      Uri.parse('$_baseUrl/marketplace/$listingId'),
      headers: _marketplaceHeaders,
    );
    if (res.statusCode != 200) {
      throw Exception('Cancel sell request failed');
    }
  }

  // ==================== TRANSACTIONS ====================

  /// NOTE: /students/me/transactions does NOT exist in the backend.
  /// TODO: Backend needs a student transaction history endpoint.
  Future<List<TransactionData>> getTransactions() async {
    throw UnimplementedError(
      'GET /students/me/transactions does not exist in the backend. '
      'A student transaction history endpoint is needed.',
    );
  }

  // ==================== STUDENT PROFILE ====================

  /// NOTE: /students/{id}/profile does NOT exist in the backend.
  /// TODO: Backend needs a student profile endpoint.
  Future<StudentProfile> getSellerProfile(String studentId) async {
    throw UnimplementedError(
      'GET /students/{id}/profile does not exist in the backend. '
      'A student profile endpoint is needed.',
    );
  }

  // ==================== HALLS ====================

  /// NOTE: /halls does NOT exist in the backend.
  /// TODO: Backend needs a halls listing endpoint.
  Future<List<HallModel>> getHalls() async {
    throw UnimplementedError(
      'GET /halls does not exist in the backend. '
      'A halls listing endpoint is needed.',
    );
  }
}