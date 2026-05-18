import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? restaurantId;
  final String? storeId;

  AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.restaurantId,
    this.storeId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? '',
      restaurantId: json['restaurantId'] as String?,
      storeId: json['storeId'] as String?,
    );
  }
}

class AuthService extends ChangeNotifier {
  static const _tokenKey = 'driver_token';
  static const _userKey = 'driver_user';

  String? _token;
  AuthUser? _user;
  bool _isLoading = false;
  String? _error;

  String? get token => _token;
  AuthUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _user != null;

  late final Dio _dio;

  AuthService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ));
    _loadStoredSession();
  }

  Future<void> _loadStoredSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final userJson = prefs.getString(_userKey);

      if (_token != null && userJson != null) {
        try {
          final userData = jsonDecode(userJson) as Map<String, dynamic>;
          _user = AuthUser.fromJson(userData);
        } catch (e) {
          debugPrint('Error decoding stored user: $e');
        }

        // Verify token and refresh user data from server
        try {
          final res = await _dio.get(
            '/auth/me',
            options: Options(headers: {'Authorization': 'Bearer $_token'}),
          );
          if (res.data['success'] == true) {
            final freshUserData = (res.data['data'] ?? res.data['user']) as Map<String, dynamic>;
            _user = AuthUser.fromJson(freshUserData);
            await prefs.setString(_userKey, jsonEncode(freshUserData));
          } else if (_user == null) {
            // Only clear if we don't even have cached data
            await _clearSession();
          }
        } catch (_) {
          // If offline, keep the cached session
          if (_user == null) await _clearSession();
        }
      }
    } catch (e) {
      debugPrint('Error loading session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _dio.post('/auth/login', data: {
        'email': email.trim(),
        'password': password,
      });

      final responseBody = res.data;
      if (responseBody['success'] == true || responseBody['token'] != null) {
        // Handle nested structure from your API: { success: true, data: { token: "...", user: { ... } } }
        final nestedData = responseBody['data'] as Map<String, dynamic>?;

        final token = (responseBody['token'] ?? nestedData?['token']) as String?;
        final userData = (responseBody['user'] ?? nestedData?['user']) as Map<String, dynamic>?;

        if (token == null || userData == null) {
          debugPrint('Login parsing failed. Response: $responseBody');
          _error = 'بيانات غير صحيحة من الخادم';
          return false;
        }

        final user = AuthUser.fromJson(userData);
        if (user.role != 'delivery_driver') {
          _error = 'هذا التطبيق خاص بمندوبي التوصيل فقط';
          return false;
        }

        _token = token;
        _user = user;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_userKey, jsonEncode(userData));

        notifyListeners();
        return true;
      } else {
        _error = responseBody['error'] as String? ?? 'فشل تسجيل الدخول';
        return false;
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        _error = (e.response!.data as Map)['error'] as String? ?? 'خطأ في الشبكة';
      } else {
        _error = 'تعذر الاتصال بالخادم. تحقق من الإنترنت';
      }
      return false;
    } catch (e) {
      _error = 'حدث خطأ غير متوقع';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await _dio.post(
          '/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $_token'}),
        );
      }
    } catch (_) {}
    await _clearSession();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  String? get authHeader => _token != null ? 'Bearer $_token' : null;
}
