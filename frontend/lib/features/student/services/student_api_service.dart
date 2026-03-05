import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/core/constants/api_constants.dart';
import '../models/models.dart';

class StudentApiService {
  // Use ApiConstants base URL instead of hardcoded emulator URL
  static const String _baseUrl = ApiConstants.baseUrl;
  final String _token;
  final int? _userId;

  /// Public accessor for the current user's ID (used to filter own posts, etc.)
  int? get userId => _userId;

  StudentApiService({required String token, int? userId})
    : _token = token,
      _userId = userId {
    print('StudentApiService initialized with base URL: $_baseUrl');
    print('Token: ${_token.substring(0, 20)}...');
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };

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

  /// GET /students/wallet
  /// Get student's current wallet balance
  Future<WalletModel> getWalletBalance() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/students/wallet'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body);
          // Response is wrapped in ApiResponse: { "message": "...", "data": { "balance": ... } }
          final data = body['data'] as Map<String, dynamic>? ?? body;

          final balance = (data['balance'] as num?)?.toInt() ?? 0;
          return WalletModel(balance: balance);
        } catch (e) {
          print('Error parsing wallet response: $e, body: ${res.body}');
          throw Exception('Invalid wallet response format: $e');
        }
      } else {
        print('Wallet fetch failed with status ${res.statusCode}: ${res.body}');
        throw Exception('Failed to fetch wallet (${res.statusCode})');
      }
    } catch (e) {
      print('Exception in getWalletBalance: $e');
      throw Exception('Failed to fetch wallet: $e');
    }
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
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/tokens/me'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body);

          // Handle both wrapped and unwrapped responses
          final data = body is List ? body : (body['data'] as List? ?? []);

          return data.map((e) => TokenModel.fromJson(e)).toList();
        } catch (e) {
          print('Error parsing token response: $e, body: ${res.body}');
          throw Exception('Invalid response format: $e');
        }
      } else {
        print('Token fetch failed with status ${res.statusCode}: ${res.body}');
        throw Exception(
          'Failed to fetch tokens (${res.statusCode}): ${res.body}',
        );
      }
    } catch (e) {
      print('Exception in getMyTokens: $e');
      throw Exception('Failed to fetch tokens: $e');
    }
  }

  /// GET /meals/available
  /// Get available meals that can be purchased as tokens
  Future<List<AvailableToken>> getAvailableTokens() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/meals/available'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] as List? ?? [];

        return data.map((e) {
          // Map backend meal DTO to AvailableToken
          final mealType = (e['mealType'] as String?) ?? 'Unknown';
          // Capitalize: LUNCH -> Lunch, DINNER -> Dinner
          final tokenType =
              mealType[0].toUpperCase() + mealType.substring(1).toLowerCase();
          final menuStr = (e['menu'] as String?) ?? 'No menu available';
          final menuItems = menuStr
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          final price = e['price'] is num ? (e['price'] as num).toInt() : 0;
          final time = (e['purchaseStartTime'] as String?) ?? '12:00 PM';

          return AvailableToken(
            mealId: (e['id'] as num).toInt(),
            tokenType: tokenType,
            price: price,
            time: time,
            menu: menuItems.isEmpty ? ['No menu available'] : menuItems,
          );
        }).toList();
      } else {
        throw Exception('Failed to fetch available tokens (${res.statusCode})');
      }
    } catch (e) {
      print('Exception in getAvailableTokens: $e');
      throw Exception('Failed to fetch available tokens: $e');
    }
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

  /// GET /meals/today
  /// Get today's available meals
  Future<List<MenuModel>> getTodayMenu() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/meals/today'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        try {
          final body = jsonDecode(res.body);
          final data = body is List ? body : (body['data'] as List? ?? []);

          return data
              .map(
                (e) => MenuModel(
                  mealType: e['mealType'] ?? 'Unknown',
                  time: e['purchaseStartTime'] ?? '12:00 PM',
                  items: [e['menu'] ?? 'No menu available'],
                ),
              )
              .toList();
        } catch (e) {
          print('Error parsing menu response: $e, body: ${res.body}');
          throw Exception('Invalid menu response format: $e');
        }
      } else {
        print('Menu fetch failed with status ${res.statusCode}: ${res.body}');
        throw Exception('Failed to fetch menu (${res.statusCode})');
      }
    } catch (e) {
      print('Exception in getTodayMenu: $e');
      throw Exception('Failed to fetch menu: $e');
    }
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

  Future<void> sendBuyRequest(
    String postId, {
    required String paymentType,
  }) async {
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

  /// GET /students/transactions
  /// Get student's transaction history
  Future<List<TransactionData>> getTransactions() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/students/transactions'),
        headers: _headers,
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] as List? ?? [];
        return data
            .map((e) => TransactionData.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        print('Transactions fetch failed: ${res.statusCode}: ${res.body}');
        throw Exception('Failed to fetch transactions (${res.statusCode})');
      }
    } catch (e) {
      print('Exception in getTransactions: $e');
      throw Exception('Failed to fetch transactions: $e');
    }
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
