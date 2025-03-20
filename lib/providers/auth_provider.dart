import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthProvider with ChangeNotifier {
  String? _token;
  final _storage = FlutterSecureStorage();
  bool _isInitialized = false;

  bool get isAuth {
    return _token != null && _token!.isNotEmpty && _isInitialized;
  }

  String get token {
    return _token ?? '';
  }

  // Add this getter for isInitialized
  bool get isInitialized => _isInitialized;

  // Initialize auth state from storage with token validation
  Future<void> tryAutoLogin() async {
    final storedToken = await _storage.read(key: 'auth_token');

    if (storedToken != null && storedToken.isNotEmpty) {
      // Validate the token before considering the user authenticated
      final isValid = await validateToken(storedToken);

      if (isValid) {
        _token = storedToken;
        _isInitialized = true;
        notifyListeners();
      } else {
        // Token is invalid, clear it
        await logout();
      }
    } else {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Validate token by making a test request
  Future<bool> validateToken(String token) async {
    try {
      // Make a request to a simple endpoint that requires authentication
      final response = await http.get(
        Uri.parse('http://88.222.241.78/v2/api/listview/lead'), // Adjust this endpoint as needed
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('🔐 Token validation error: $e');
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      print('🔐 Attempting login with username: $username');

      final response = await http.post(
        Uri.parse('http://88.222.241.78/v2/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': username,
          'password': password,
        }),
      );

      print('🔐 Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return handleSuccessResponse(response);
      }

      print('🔐 Login failed: ${response.body}');
      return false;
    } catch (e) {
      print('🔐 Login error: $e');
      return false;
    }
  }

  bool handleSuccessResponse(http.Response response) {
    print('🔐 Login successful with status: ${response.statusCode}');

    try {
      final data = json.decode(response.body);

      // The API returns "access" as the token key
      _token = data['access'] ??
          data['token'] ??
          data['access_token'];

      if (_token != null && _token!.isNotEmpty) {
        _storage.write(key: 'auth_token', value: _token);
        print('🔐 Token stored successfully: ${_token!.substring(0, 10)}...');
        _isInitialized = true;
        notifyListeners();
        return true;
      } else {
        print('🔐 No token found in response');
        return false;
      }
    } catch (e) {
      print('🔐 Error parsing login response: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    await _storage.delete(key: 'auth_token');
    _isInitialized = true;
    notifyListeners();
  }
}