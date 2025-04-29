import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  User _user = User.empty();
  final _storage = FlutterSecureStorage();
  bool _isInitialized = false;

  bool get isAuth {
    return _token != null && _token!.isNotEmpty && _isInitialized;
  }

  String get token {
    return _token ?? '';
  }
  
  // Add this getter for user information
  User get user => _user;

  // Add this getter for isInitialized
  bool get isInitialized => _isInitialized;

  // Initialize auth state from storage with token validation
  Future<void> tryAutoLogin() async {
    final storedToken = await _storage.read(key: 'auth_token');
    final storedUserData = await _storage.read(key: 'user_data');

    if (storedToken != null && storedToken.isNotEmpty) {
      // Validate the token before considering the user authenticated
      final isValid = await validateToken(storedToken);

      if (isValid) {
        _token = storedToken;
        
        // Restore user data if available
        if (storedUserData != null && storedUserData.isNotEmpty) {
          try {
            final userData = json.decode(storedUserData);
            _user = User.fromJson(userData);
          } catch (e) {
            print('Error parsing stored user data: $e');
          }
        }
        
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
        Uri.parse('https://qa.api.bussus.com/v2/api/listview/lead'), // Adjust this endpoint as needed
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
        Uri.parse('https://qa.api.bussus.com/v2/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': username,
          'password': password,
        }),
      );

      print('🔐 Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return handleSuccessResponse(response, username);
      }

      print('🔐 Login failed: ${response.body}');
      return false;
    } catch (e) {
      print('🔐 Login error: $e');
      return false;
    }
  }

  // Updated to also save user info
  bool handleSuccessResponse(http.Response response, String email) {
    print('🔐 Login successful with status: ${response.statusCode}');

    try {
      final data = json.decode(response.body);

      // The API returns "access" as the token key
      _token = data['access'] ??
          data['token'] ??
          data['access_token'];

      if (_token != null && _token!.isNotEmpty) {
        _storage.write(key: 'auth_token', value: _token);
        
        // Extract user info from response if available
        if (data['user'] != null) {
          _user = User.fromJson(data['user']);
        } else {
          // Create basic user if not available in response
          _user = User(
            username: data['username'] ?? email.split('@')[0],
            email: email,
            avatarUrl: null,
          );
        }
        
        // Save user data
        _storage.write(key: 'user_data', value: json.encode({
          'username': _user.username,
          'email': _user.email,
          'avatar_url': _user.avatarUrl,
        }));
        
        print('🔐 Token stored successfully: ${_token!.substring(0, 10)}...');
        print('👤 User data stored for: ${_user.username}');
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

  // Method to fetch user profile
  Future<void> fetchUserProfile() async {
    if (!isAuth) return;
    
    try {
      final response = await http.get(
        Uri.parse('https://qa.api.bussus.com/v2/api/user-profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _user = User.fromJson(data);
        
        // Update stored user data
        _storage.write(key: 'user_data', value: json.encode({
          'username': _user.username,
          'email': _user.email,
          'avatar_url': _user.avatarUrl,
        }));
        
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = User.empty();
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    _isInitialized = true;
    notifyListeners();
  }
}