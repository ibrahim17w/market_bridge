import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    return 'http://localhost:3000';
  }

  static Map<String, String> get publicHeaders => {
    'Content-Type': 'application/json',
  };

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<bool> isLoggedIn() async => (await getToken()) != null;

  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
  };

  static Future<Map<String, String>> get authHeaders async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // FIX: For multipart requests, NEVER send 'Content-Type': 'application/json'.
  // The http package sets multipart/form-data automatically with the correct boundary.
  static Future<Map<String, String>> get multipartAuthHeaders async {
    final token = await getToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  static Future<Map<String, dynamic>?> decodeToken() async {
    final token = await getToken();
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return jsonDecode(payload);
  }

  static Future<String?> getUserRole() async {
    final payload = await decodeToken();
    return payload?['role'] as String?;
  }

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
    Map<String, dynamic>? store,
    String preferredLanguage = 'en',
  }) async {
    final body = <String, dynamic>{
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role,
      'preferred_language': preferredLanguage,
    };

    if (store != null) body['store'] = store;

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw Exception(data['error'] ?? 'Registration failed');
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await setToken(data['token']);
      return data;
    }
    throw Exception(data['error'] ?? 'Login failed');
  }

  static Future<void> logout() async => clearToken();

  static Future<void> resendVerification(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/resend-verification'),
      headers: headers,
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed to resend');
    }
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/me'),
      headers: await authHeaders,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Failed');
  }

  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/me'),
      headers: await authHeaders,
      body: jsonEncode({'full_name': fullName, 'phone': phone}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Update failed');
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/me/password'),
      headers: await authHeaders,
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed');
    }
  }

  static Future<void> deleteAccount() async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/me'),
      headers: await authHeaders,
    );
    if (response.statusCode == 200) {
      await clearToken();
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed');
    }
  }

  static Future<void> updatePreferredLanguage(String lang) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/me/language'),
      headers: await authHeaders,
      body: jsonEncode({'preferred_language': lang}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update language');
    }
  }

  static Future<void> forgotPassword(String email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/forgot-password'),
      headers: headers,
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed');
    }
  }

  static Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/reset-password'),
      headers: headers,
      body: jsonEncode({
        'email': email,
        'code': code,
        'new_password': newPassword,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Failed');
    }
  }

  // STORES — now public so guests can browse
  static Future<List<dynamic>> fetchStores() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stores'),
      headers: publicHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed');
  }

  static Future<Map<String, dynamic>> fetchStore(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stores/$id'),
      headers: publicHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed');
  }

  static Future<Map<String, dynamic>> getMyStore() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/my-store'),
      headers: await authHeaders,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Failed');
  }

  // PRODUCTS — now public so guests can browse
  static Future<List<dynamic>> fetchProducts(int storeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/products/$storeId'),
      headers: publicHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed');
  }

  static Future<Map<String, dynamic>> createProduct({
    required String name,
    required double price,
    required int quantity,
    String? description,
    String? barcode,
    File? image,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/products'),
    );
    // FIX: Use multipartAuthHeaders instead of authHeaders
    request.headers.addAll(await multipartAuthHeaders);
    request.fields['name'] = name;
    request.fields['price'] = price.toString();
    request.fields['quantity'] = quantity.toString();
    if (description != null) request.fields['description'] = description;
    if (barcode != null) request.fields['barcode'] = barcode;
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) return data;
    throw Exception(data['error'] ?? 'Failed');
  }

  static Future<Map<String, dynamic>> updateProduct({
    required int id,
    required String name,
    required double price,
    required int quantity,
    String? description,
    String? barcode,
    File? image,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/api/products/$id'),
    );
    // FIX: Use multipartAuthHeaders instead of authHeaders
    request.headers.addAll(await multipartAuthHeaders);
    request.fields['name'] = name;
    request.fields['price'] = price.toString();
    request.fields['quantity'] = quantity.toString();
    if (description != null) request.fields['description'] = description;
    if (barcode != null) request.fields['barcode'] = barcode;
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Failed');
  }

  static Future<Map<String, dynamic>> updateMyStore({
    String? name,
    String? city,
    String? village,
    String? country,
    String? phone,
    double? lat,
    double? lng,
    File? image,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/api/my-store'),
    );
    // FIX: Use multipartAuthHeaders instead of authHeaders
    request.headers.addAll(await multipartAuthHeaders);
    if (name != null) request.fields['name'] = name;
    if (city != null) request.fields['city'] = city;
    if (village != null) request.fields['village'] = village;
    if (country != null) request.fields['country'] = country;
    if (phone != null) request.fields['phone'] = phone;
    if (lat != null) request.fields['lat'] = lat.toString();
    if (lng != null) request.fields['lng'] = lng.toString();
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      try {
        return jsonDecode(response.body);
      } catch (_) {
        throw Exception('Server returned invalid data');
      }
    }

    String errorMsg;
    try {
      final data = jsonDecode(response.body);
      errorMsg = data['error'] ?? 'Failed (status ${response.statusCode})';
    } catch (_) {
      errorMsg =
          'Server error (${response.statusCode}). Please check your backend.';
    }
    throw Exception(errorMsg);
  }

  static Future<void> deleteProduct(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/products/$id'),
      headers: await authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed');
    }
  }

  // NEW: Marketplace feed for guests and logged-in users
  static Future<List<dynamic>> fetchMarketplaceFeed() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/marketplace/feed'),
      headers: publicHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed');
  }

  // ==================== NEW ENDPOINTS FOR HOME SCREEN ====================

  /// Track product view for analytics
  static Future<void> trackProductView(int productId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/products/$productId/view'),
        headers: await authHeaders,
      );
    } catch (_) {
      // Silently fail - analytics shouldn't break UX
    }
  }

  /// Track search query for analytics
  static Future<void> trackSearch(String query) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/search/track'),
        headers: await authHeaders,
        body: jsonEncode({'query': query}),
      );
    } catch (_) {
      // Silently fail
    }
  }

  /// Get trending products (most viewed)
  static Future<List<dynamic>> fetchTrendingProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/products/trending'),
      headers: publicHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load trending');
  }

  /// Get sponsored/top stores
  static Future<List<dynamic>> fetchSponsoredStores() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/stores/sponsored'),
      headers: publicHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load sponsored stores');
  }

  /// Get personalized recommendations (requires auth)
  static Future<List<dynamic>> fetchRecommendations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/recommendations'),
      headers: await authHeaders,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    // Fallback: return empty list if not logged in or error
    return [];
  }
}
